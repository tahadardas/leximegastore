<?php
/**
 * Plugin Name:       Lexi API
 * Plugin URI:        https://lexistore.sy/
 * Description:       REST API endpoints for the Lexi Mega Store Flutter mobile application. Provides guest checkout, ShamCash payments, shipping cities, invoices, and admin management.
 * Version:           1.3.0
 * Author:            Lexi Dev Team
 * Author URI:        https://lexistore.sy/
 * License:           GPL-2.0+
 * License URI:       https://www.gnu.org/licenses/gpl-2.0.html
 * Text Domain:       lexi-api
 * Requires PHP:      7.4
 * Requires at least: 5.8
 * WC requires at least: 6.0
 * WC tested up to:   8.5
 */

defined('ABSPATH') || die('TESTING_IF_THIS_IS_LIVE');

/* ── Constants ────────────────────────────────────────────── */
define('LEXI_API_VERSION', '1.3.0');
define('LEXI_API_PLUGIN_DIR', plugin_dir_path(__FILE__));
define('LEXI_API_PLUGIN_URL', plugin_dir_url(__FILE__));
define('LEXI_API_NAMESPACE', 'lexi/v1');
define('LEXI_API_DB_VERSION', '1.3.2');

/* ── Activation / Deactivation ────────────────────────────── */
register_activation_hook(__FILE__, 'lexi_api_activate');
register_deactivation_hook(__FILE__, 'lexi_api_deactivate');

/**
 * Plugin activation: create DB tables, seed data, store DB version, set defaults.
 */
function lexi_api_activate()
{
	// Check WooCommerce dependency.
	if (!class_exists('WooCommerce')) {
		deactivate_plugins(plugin_basename(__FILE__));
		wp_die(
			esc_html__('Lexi API requires WooCommerce to be installed and active.', 'lexi-api'),
			'Plugin Activation Error',
			array('back_link' => true)
		);
	}

	require_once LEXI_API_PLUGIN_DIR . 'includes/class-shipping-cities.php';
	require_once LEXI_API_PLUGIN_DIR . 'includes/class-support.php';
	require_once LEXI_API_PLUGIN_DIR . 'includes/class-merch.php';
	require_once LEXI_API_PLUGIN_DIR . 'includes/class-notifications.php';
	require_once LEXI_API_PLUGIN_DIR . 'includes/class-intel.php';
	require_once LEXI_API_PLUGIN_DIR . 'includes/class-ai-core.php';
	require_once LEXI_API_PLUGIN_DIR . 'includes/class-auth-tokens.php';
	Lexi_Shipping_Cities::create_table();
	Lexi_Shipping_Cities::seed();
	Lexi_Support::create_tables();
	Lexi_Merch::create_tables();
	Lexi_Notifications::create_table();
	Lexi_Intel::create_tables();
	Lexi_AI_Core::instance()->create_tables();
	Lexi_Auth_Tokens::create_table();

	// Store DB version.
	update_option('lexi_api_db_version', LEXI_API_DB_VERSION);

	// Set default ShamCash options if not already set.
	if (!get_option('lexi_shamcash_account_name')) {
		update_option('lexi_shamcash_account_name', 'Lexi Mega Store');
		update_option('lexi_shamcash_qr_value', 'shamcash://pay?account=lexi-store');
		update_option('lexi_shamcash_barcode_value', 'LEXI-STORE-001');
		update_option('lexi_shamcash_instructions_ar', 'يرجى كتابة رقم الطلب في ملاحظات التحويل ثم رفع صورة الإيصال.');
	}

	// Flush rewrite rules so REST endpoints work immediately.
	flush_rewrite_rules();
}

/**
 * Plugin deactivation: clean up transients (tables are kept).
 */
function lexi_api_deactivate()
{
	flush_rewrite_rules();
}

/* ── HPOS Compatibility ───────────────────────────────────── */
add_action('before_woocommerce_init', function () {
	if (class_exists('\Automattic\WooCommerce\Utilities\FeaturesUtil')) {
		\Automattic\WooCommerce\Utilities\FeaturesUtil::declare_compatibility(
			'custom_order_tables',
			__FILE__,
			true
		);
	}
});

/* ── Bootstrap ────────────────────────────────────────────── */
add_action('plugins_loaded', 'lexi_api_init', 20);

function lexi_api_init()
{
	if (!class_exists('WooCommerce')) {
		add_action('admin_notices', function () {
			echo '<div class="notice notice-error"><p>';
			esc_html_e('Lexi API requires WooCommerce to be installed and active.', 'lexi-api');
			echo '</p></div>';
		});
		return;
	}

	// Autoload includes.
	$includes = array(
		'class-security.php',
		'class-shipping-cities.php',
		'class-support.php',
		'class-merch.php',
		'class-auth-tokens.php',
		'class-emails.php',
		'class-notifications.php',
		'class-notification-hooks.php',
		'class-invoices.php',
		'class-intel.php',
		'class-ai-core.php',
		'class-ai-routes.php',
		'class-plugin.php',
	);

	foreach ($includes as $file) {
		require_once LEXI_API_PLUGIN_DIR . 'includes/' . $file;
	}

	// Run DB upgrades when plugin version changes.
	$installed_db_version = (string) get_option('lexi_api_db_version', '');
	if ($installed_db_version !== LEXI_API_DB_VERSION) {
		Lexi_Support::create_tables();
		Lexi_Merch::create_tables();
		Lexi_Intel::create_tables();
		Lexi_Notifications::create_table();
		Lexi_Auth_Tokens::create_table();
		update_option('lexi_api_db_version', LEXI_API_DB_VERSION);
	}

	// Initialize notification hooks
	Lexi_Notification_Hooks::init();

	// ── CORS ──
	// Allow the Flutter web app (any origin) to call our REST endpoints.
	add_action('rest_api_init', 'lexi_api_cors_headers', 15);

	// Public image proxy to bypass browser CORS restrictions for uploads on Flutter Web.
	add_action('wp_ajax_nopriv_lexi_media_proxy', 'lexi_api_media_proxy');
	add_action('wp_ajax_lexi_media_proxy', 'lexi_api_media_proxy');

	// Initialize the plugin instance (registers all REST routes).
	Lexi_Plugin::instance();
	Lexi_Intel::init();
}

/* ── CORS Support ─────────────────────────────────────────── */

/**
 * Register CORS headers on every REST API response.
 *
 * Called via rest_api_init so the filter is only active for REST requests.
 */
function lexi_api_send_cors_headers(): void
{
	$origin = get_http_origin();

	// Fallback: get_http_origin() may return empty for admin-ajax requests.
	if (empty($origin) && !empty($_SERVER['HTTP_ORIGIN'])) {
		$origin = sanitize_text_field(wp_unslash($_SERVER['HTTP_ORIGIN']));
	}
	$origin = trim((string) $origin);

	// Allow production origins explicitly.
	$allowed = array(
		'https://leximega.store',
		'https://www.leximega.store',
	);

	$origin_no_slash = rtrim($origin, '/');

	// Allow local dev hosts (Flutter web uses random ports).
	$is_local = (bool) preg_match(
		'#^https?://(localhost|127\.0\.0\.1|\[::1\])(:\d+)?$#i',
		$origin_no_slash
	);
	$is_allowed_origin = '' !== $origin_no_slash && (
		$is_local || in_array($origin_no_slash, $allowed, true)
	);

	// Important for CDN/proxy caches so they don't reuse CORS between origins.
	header('Vary: Origin');

	if ($is_allowed_origin) {
		header('Access-Control-Allow-Origin: ' . esc_url_raw($origin_no_slash));
		header('Access-Control-Allow-Credentials: true');
	} elseif ('' === $origin_no_slash) {
		// Non-browser tools (curl/health checks) may omit Origin.
		header('Access-Control-Allow-Origin: *');
	}

	header('Access-Control-Allow-Methods: GET, POST, PUT, PATCH, DELETE, OPTIONS');

	// Always include baseline headers + any browser-requested headers.
	$allow_headers = array(
		'authorization' => 'Authorization',
		'content-type' => 'Content-Type',
		'accept' => 'Accept',
		'x-wp-nonce' => 'X-WP-Nonce',
		'x-requested-with' => 'X-Requested-With',
		'device-id' => 'Device-Id',
		'cache-control' => 'Cache-Control',
		'pragma' => 'Pragma',
	);
	if (isset($_SERVER['HTTP_ACCESS_CONTROL_REQUEST_HEADERS'])) {
		$requested_raw = (string) wp_unslash($_SERVER['HTTP_ACCESS_CONTROL_REQUEST_HEADERS']);
		$requested_parts = explode(',', strtolower($requested_raw));
		foreach ($requested_parts as $part) {
			$clean = (string) preg_replace('/[^a-z0-9\-]/', '', trim($part));
			if ('' !== $clean && !isset($allow_headers[$clean])) {
				$allow_headers[$clean] = $clean;
			}
		}
	}
	header('Access-Control-Allow-Headers: ' . implode(', ', array_values($allow_headers)));
	header('Access-Control-Expose-Headers: X-WP-Total, X-WP-TotalPages, Link');

	// Flutter web dev server uses a random port on every restart.
	// If we cache preflight for 24h, the browser remembers the old port and
	// rejects images with "Access-Control-Allow-Origin mismatch".
	// => Don't cache preflight for localhost; keep 24h for production.
	header('Access-Control-Max-Age: ' . ($is_local ? '0' : '600'));
}

function lexi_api_cors_headers()
{
	// Remove WordPress default CORS header so we can set our own.
	remove_filter('rest_pre_serve_request', 'rest_send_cors_headers');

	add_filter('rest_pre_serve_request', function ($served) {
		lexi_api_send_cors_headers();
		return $served;
	});
}

/**
 * Handle preflight OPTIONS requests early — before WordPress tries to route them.
 *
 * Browsers send an OPTIONS request before any cross-origin POST/PUT/DELETE.
 * If WordPress returns a 403 for the unknown route the browser aborts.
 */
/**
 * Handle preflight OPTIONS requests early — before WordPress tries to route them.
 * Modified to hook into 'plugins_loaded' for earlier execution.
 */
add_action('plugins_loaded', function () {
	// Only handle if it's an OPTIONS request
	if (isset($_SERVER['REQUEST_METHOD']) && 'OPTIONS' === $_SERVER['REQUEST_METHOD']) {
		
		// 1. Send CORS Headers immediately
		lexi_api_send_cors_headers();

		// 2. Kill the request with 200 OK
		if (!headers_sent()) {
			status_header(200);
		}
		exit;
	}
}, 1);

/**
 * Proxy upload images through WordPress (admin-ajax) so Flutter Web can render
 * them even when static uploads don't return CORS headers.
 *
 * URL shape:
 * /wp-admin/admin-ajax.php?action=lexi_media_proxy&url=<encoded-image-url>
 */
function lexi_api_media_proxy(): void
{
	lexi_api_send_cors_headers();

	if (isset($_SERVER['REQUEST_METHOD']) && 'OPTIONS' === $_SERVER['REQUEST_METHOD']) {
		status_header(200);
		exit;
	}

	$raw_url = isset($_GET['url']) ? wp_unslash((string) $_GET['url']) : '';
	$image_url = esc_url_raw(trim($raw_url));

	if ('' === $image_url) {
		lexi_api_media_proxy_error(400, 'رابط الصورة غير صالح.');
	}

	$target = wp_parse_url($image_url);
	$home = wp_parse_url(home_url('/'));

	$target_host = strtolower((string) ($target['host'] ?? ''));
	$home_host = strtolower((string) ($home['host'] ?? ''));
	$target_path = strtolower((string) ($target['path'] ?? ''));
	$scheme = strtolower((string) ($target['scheme'] ?? ''));

	$allowed_hosts = array_unique(array_filter(array(
		$home_host,
		lexi_api_starts_with($home_host, 'www.') ? substr($home_host, 4) : ('www.' . $home_host),
	)));

	$is_allowed_host = in_array($target_host, $allowed_hosts, true);
	$is_upload_path = lexi_api_starts_with($target_path, '/wp-content/uploads/');
	$is_http = in_array($scheme, array('http', 'https'), true);

	if (!$is_http || !$is_allowed_host || !$is_upload_path) {
		lexi_api_media_proxy_error(403, 'مصدر الصورة غير مسموح.');
	}

	$response = wp_safe_remote_get($image_url, array(
		'timeout' => 20,
		'redirection' => 3,
		'sslverify' => true,
	));

	if (is_wp_error($response)) {
		lexi_api_media_proxy_error(502, 'تعذر جلب الصورة حالياً.');
	}

	$status = (int) wp_remote_retrieve_response_code($response);
	if (200 !== $status) {
		lexi_api_media_proxy_error($status > 0 ? $status : 502, 'تعذر تحميل الصورة.');
	}

	$body = wp_remote_retrieve_body($response);
	if (!is_string($body) || '' === $body) {
		lexi_api_media_proxy_error(502, 'تعذر تحميل الصورة.');
	}

	$content_type = (string) wp_remote_retrieve_header($response, 'content-type');
	if ('' === trim($content_type)) {
		$file_type = wp_check_filetype($image_url);
		$content_type = (string) ($file_type['type'] ?? 'image/jpeg');
	}

	header('Content-Type: ' . sanitize_text_field($content_type));

	// Don't cache proxy responses for localhost — each Flutter dev session uses
	// a new random port, and cached responses carry the old port's CORS origin.
	$origin = get_http_origin();
	if (empty($origin) && !empty($_SERVER['HTTP_ORIGIN'])) {
		$origin = sanitize_text_field(wp_unslash($_SERVER['HTTP_ORIGIN']));
	}
	$is_dev = preg_match('#^http://(localhost|127\.0\.0\.1)(:\d+)?$#', $origin);
	header('Cache-Control: ' . ($is_dev ? 'no-store' : 'public, max-age=86400'));
	header('X-Content-Type-Options: nosniff');
	echo $body; // phpcs:ignore WordPress.Security.EscapeOutput.OutputNotEscaped
	exit;
}

/**
 * PHP 7.4 compatible prefix check.
 */
function lexi_api_starts_with(string $haystack, string $needle): bool
{
	if ($needle === '') {
		return true;
	}

	return 0 === strpos($haystack, $needle);
}

/**
 * Return JSON error for the media proxy endpoint.
 */
function lexi_api_media_proxy_error(int $status, string $message): void
{
	status_header($status);
	header('Content-Type: application/json; charset=utf-8');
	echo wp_json_encode(array(
		'success' => false,
		'error' => array(
			'code' => 'media_proxy_error',
			'message' => $message,
		),
	));
	exit;
}
