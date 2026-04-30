<?php
/**
 * Android App Links statement endpoint.
 *
 * Serves: /.well-known/assetlinks.json
 *
 * @package Lexi_API
 */

defined('ABSPATH') || exit;

class Lexi_Android_App_Links
{
    private const OPTION_PACKAGE = 'lexi_android_package_name';
    private const OPTION_FINGERPRINTS = 'lexi_android_app_links_fingerprints';

    private const DEFAULT_PACKAGE = 'com.leximegastore.app';
    private const DEFAULT_DEBUG_FINGERPRINT = '39:DC:F1:0B:E4:F4:22:CC:CD:52:E5:DD:0A:9B:38:F3:C9:F5:86:B1:45:CE:54:BD:7F:1D:B3:37:9E:93:66:41';
    private const DEFAULT_RELEASE_FINGERPRINT = '8C:6C:A3:BD:3F:25:14:68:E0:AC:BA:F8:56:B8:66:70:5E:67:E4:84:4D:3C:27:3B:CD:25:68:C6:AB:0D:BB:A8';

    public static function init(): void
    {
        add_action('template_redirect', array(__CLASS__, 'maybe_serve_assetlinks'), 0);
    }

    public static function maybe_serve_assetlinks(): void
    {
        $request_uri = isset($_SERVER['REQUEST_URI']) ? (string) wp_unslash($_SERVER['REQUEST_URI']) : '';
        $path = (string) wp_parse_url($request_uri, PHP_URL_PATH);
        if (!self::is_assetlinks_request($path)) {
            return;
        }

        $statements = self::build_statements();

        while (ob_get_level() > 0) {
            ob_end_clean();
        }

        status_header(200);
        header('Content-Type: application/json; charset=utf-8');
        header('X-Robots-Tag: noindex, nofollow', true);
        header('Cache-Control: public, max-age=300');
        header('Vary: Accept');

        echo wp_json_encode($statements, JSON_UNESCAPED_SLASHES | JSON_PRETTY_PRINT); // phpcs:ignore WordPress.Security.EscapeOutput.OutputNotEscaped
        exit;
    }

    private static function is_assetlinks_request(string $path): bool
    {
        $normalized = '/' . ltrim(trim($path), '/');
        return (bool) preg_match('#/\.well-known/assetlinks\.json$#i', $normalized);
    }

    /**
     * @return array<int,array<string,mixed>>
     */
    private static function build_statements(): array
    {
        $package_name = self::normalized_package_name();
        $fingerprints = self::normalized_fingerprints();

        $statements = array();
        if ('' !== $package_name && !empty($fingerprints)) {
            $statements[] = array(
                'relation' => array('delegate_permission/common.handle_all_urls'),
                'target' => array(
                    'namespace' => 'android_app',
                    'package_name' => $package_name,
                    'sha256_cert_fingerprints' => $fingerprints,
                ),
            );
        }

        $filtered = apply_filters(
            'lexi_android_assetlinks_statements',
            $statements,
            $package_name,
            $fingerprints
        );

        return is_array($filtered) ? array_values($filtered) : $statements;
    }

    private static function normalized_package_name(): string
    {
        $raw = (string) get_option(self::OPTION_PACKAGE, self::DEFAULT_PACKAGE);
        $filtered = apply_filters('lexi_android_app_links_package_name', $raw);
        $package = trim((string) $filtered);
        if ('' === $package) {
            return '';
        }

        // Keep valid Java package chars only.
        $package = (string) preg_replace('/[^a-zA-Z0-9_.]/', '', $package);
        return trim($package);
    }

    /**
     * @return array<int,string>
     */
    private static function normalized_fingerprints(): array
    {
        $raw = (string) get_option(
            self::OPTION_FINGERPRINTS,
            self::DEFAULT_DEBUG_FINGERPRINT . ',' . self::DEFAULT_RELEASE_FINGERPRINT
        );

        $items = preg_split('/[\r\n,;]+/', $raw);
        if (!is_array($items)) {
            $items = array();
        }

        $items = apply_filters('lexi_android_app_links_fingerprints', $items);
        if (!is_array($items)) {
            return array();
        }

        $normalized = array();
        foreach ($items as $item) {
            $fingerprint = self::normalize_single_fingerprint((string) $item);
            if ('' !== $fingerprint) {
                $normalized[] = $fingerprint;
            }
        }

        return array_values(array_unique($normalized));
    }

    private static function normalize_single_fingerprint(string $value): string
    {
        $upper = strtoupper(trim($value));
        if ('' === $upper) {
            return '';
        }

        $hex = (string) preg_replace('/[^A-F0-9]/', '', $upper);
        if (64 !== strlen($hex)) {
            return '';
        }

        return implode(':', str_split($hex, 2));
    }
}

if (class_exists('Lexi_Android_App_Links')) {
    Lexi_Android_App_Links::init();
}

