<?php
/**
 * iOS Universal Links association endpoint.
 *
 * Serves:
 * - /apple-app-site-association
 * - /.well-known/apple-app-site-association
 *
 * @package Lexi_API
 */

defined('ABSPATH') || exit;

class Lexi_iOS_App_Links
{
    private const OPTION_APP_IDS = 'lexi_ios_universal_links_app_ids';
    private const DEFAULT_APP_ID = 'TEAMID.com.leximegastore.leximegastore';

    public static function init(): void
    {
        add_action('template_redirect', array(__CLASS__, 'maybe_serve_aasa'), 0);
    }

    public static function maybe_serve_aasa(): void
    {
        $request_uri = isset($_SERVER['REQUEST_URI']) ? (string) wp_unslash($_SERVER['REQUEST_URI']) : '';
        $path = (string) wp_parse_url($request_uri, PHP_URL_PATH);
        if (!self::is_aasa_request($path)) {
            return;
        }

        $payload = self::build_payload();

        status_header(200);
        header('Content-Type: application/json; charset=utf-8');
        header('X-Robots-Tag: noindex, nofollow', true);
        header('Cache-Control: public, max-age=300');
        header('Vary: Accept');

        echo wp_json_encode($payload, JSON_UNESCAPED_SLASHES | JSON_PRETTY_PRINT); // phpcs:ignore WordPress.Security.EscapeOutput.OutputNotEscaped
        exit;
    }

    private static function is_aasa_request(string $path): bool
    {
        $normalized = '/' . ltrim(trim($path), '/');
        return (bool) preg_match('#/(?:\.well-known/)?apple-app-site-association$#i', $normalized);
    }

    /**
     * @return array<string,mixed>
     */
    private static function build_payload(): array
    {
        $details = self::build_details();

        $paths = apply_filters(
            'lexi_ios_universal_links_paths',
            array(
                '/product/*',
                '/s/*',
                '/index.php/product/*',
                '/index.php/s/*',
            )
        );
        if (!is_array($paths)) {
            $paths = array('/product/*');
        }

        $normalized_paths = array();
        foreach ($paths as $path) {
            $value = trim((string) $path);
            if ('' !== $value) {
                $normalized_paths[] = $value;
            }
        }
        $normalized_paths = array_values(array_unique($normalized_paths));
        if (empty($normalized_paths)) {
            $normalized_paths = array('/product/*');
        }

        foreach ($details as $index => $detail) {
            $details[$index]['paths'] = $normalized_paths;
        }

        return array(
            'applinks' => array(
                'apps' => array(),
                'details' => $details,
            ),
        );
    }

    /**
     * @return array<int,array<string,mixed>>
     */
    private static function build_details(): array
    {
        $app_ids = self::normalized_app_ids();
        $details = array();

        foreach ($app_ids as $app_id) {
            $details[] = array(
                'appID' => $app_id,
                'paths' => array(), // paths are injected in build_payload.
            );
        }

        $filtered = apply_filters('lexi_ios_universal_links_details', $details, $app_ids);
        return is_array($filtered) ? array_values($filtered) : $details;
    }

    /**
     * @return array<int,string>
     */
    private static function normalized_app_ids(): array
    {
        $raw = (string) get_option(self::OPTION_APP_IDS, self::DEFAULT_APP_ID);
        $parts = preg_split('/[\r\n,;]+/', $raw);
        if (!is_array($parts)) {
            $parts = array();
        }

        $parts = apply_filters('lexi_ios_universal_links_app_ids', $parts);
        if (!is_array($parts)) {
            return array();
        }

        $normalized = array();
        foreach ($parts as $item) {
            $value = trim((string) $item);
            if ('' === $value) {
                continue;
            }

            // TEAMID.bundle.id
            if ((bool) preg_match('/^[A-Z0-9]{6,16}\.[A-Za-z0-9.\-]+$/', $value)) {
                $normalized[] = $value;
            }
        }

        if (empty($normalized)) {
            $normalized[] = self::DEFAULT_APP_ID;
        }

        return array_values(array_unique($normalized));
    }
}

if (class_exists('Lexi_iOS_App_Links')) {
    Lexi_iOS_App_Links::init();
}
