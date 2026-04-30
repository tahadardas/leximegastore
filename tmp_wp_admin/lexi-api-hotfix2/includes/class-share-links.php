<?php
/**
 * Canonical share links fallback handler.
 *
 * Handles: /s/{type}/{id}
 *
 * @package Lexi_API
 */

defined('ABSPATH') || exit;

class Lexi_Share_Links
{
    /**
     * Bootstrap rewrite + redirect hooks.
     */
    public static function init(): void
    {
        add_action('init', array(__CLASS__, 'register_rewrite_rules'), 8);
        add_filter('query_vars', array(__CLASS__, 'register_query_vars'));
        add_action('template_redirect', array(__CLASS__, 'handle_request'), 1);
    }

    public static function register_rewrite_rules(): void
    {
        add_rewrite_rule(
            '^s/([^/]+)/([^/]+)/?$',
            'index.php?lexi_share_type=$matches[1]&lexi_share_id=$matches[2]',
            'top'
        );
        add_rewrite_rule(
            '^index\.php/s/([^/]+)/([^/]+)/?$',
            'index.php?lexi_share_type=$matches[1]&lexi_share_id=$matches[2]',
            'top'
        );
    }

    /**
     * @param array<int,string> $vars
     * @return array<int,string>
     */
    public static function register_query_vars(array $vars): array
    {
        $vars[] = 'lexi_share_type';
        $vars[] = 'lexi_share_id';
        return $vars;
    }

    public static function handle_request(): void
    {
        $type = sanitize_key((string) get_query_var('lexi_share_type'));
        $id = trim((string) get_query_var('lexi_share_id'));

        if ('' === $type || '' === $id) {
            $request_uri = isset($_SERVER['REQUEST_URI'])
                ? (string) wp_unslash($_SERVER['REQUEST_URI'])
                : '';
            $path = (string) wp_parse_url($request_uri, PHP_URL_PATH);
            if (preg_match('#/(?:index\.php/)?s/([^/]+)/([^/]+)/?$#i', $path, $matches)) {
                $type = sanitize_key((string) ($matches[1] ?? ''));
                $id = trim((string) ($matches[2] ?? ''));
            }
        }

        if ('' === $type || '' === $id) {
            self::maybe_redirect_numeric_product_path();
            return;
        }

        $destination = self::resolve_destination($type, $id);
        if ('' === $destination) {
            $destination = home_url('/');
        }

        wp_safe_redirect($destination, 302);
        exit;
    }

    private static function maybe_redirect_numeric_product_path(): void
    {
        $request_uri = isset($_SERVER['REQUEST_URI'])
            ? (string) wp_unslash($_SERVER['REQUEST_URI'])
            : '';
        $path = (string) wp_parse_url($request_uri, PHP_URL_PATH);

        if (!preg_match('#/(?:index\.php/)?product/([^/?#]+)/?$#i', $path, $matches)) {
            return;
        }

        $raw_ref = (string) ($matches[1] ?? '');
        $decoded_ref = trim(rawurldecode($raw_ref));
        if ('' === $decoded_ref || !ctype_digit($decoded_ref)) {
            // Keep normal slug product URLs handled by WordPress/WooCommerce.
            return;
        }

        $destination = self::resolve_product_url($decoded_ref);
        if ('' === $destination) {
            $destination = self::shop_url();
        }

        if ('' === $destination) {
            return;
        }

        $current = home_url('/' . ltrim($path, '/'));
        if (self::same_destination($destination, $current)) {
            return;
        }

        wp_safe_redirect($destination, 302);
        exit;
    }

    private static function resolve_destination(string $type, string $id): string
    {
        switch ($type) {
            case 'p':
                return self::resolve_product_url($id);
            case 'c':
                return self::resolve_category_url($id);
            case 'b':
                return self::resolve_brand_url($id);
            case 'o':
                return self::resolve_private_login_url('/account/orders/' . rawurlencode($id));
            case 'i':
                return self::resolve_private_login_url('/account/orders/' . rawurlencode($id));
            case 't':
                return self::resolve_private_login_url('/account/support/tickets/' . rawurlencode($id));
            default:
                return home_url('/');
        }
    }

    private static function resolve_product_url(string $id): string
    {
        $product = null;
        if (ctype_digit($id)) {
            $product = wc_get_product((int) $id);
        }

        if (!$product instanceof WC_Product) {
            $post = get_page_by_path(sanitize_title($id), OBJECT, 'product');
            if ($post instanceof WP_Post) {
                $product = wc_get_product((int) $post->ID);
            }
        }

        if ($product instanceof WC_Product) {
            $url = get_permalink((int) $product->get_id());
            if (is_string($url) && '' !== trim($url)) {
                return $url;
            }
        }

        return self::shop_url();
    }

    private static function resolve_category_url(string $id): string
    {
        $term = self::resolve_term($id, 'product_cat');
        if ($term instanceof WP_Term) {
            $url = get_term_link($term);
            if (!is_wp_error($url)) {
                return (string) $url;
            }
        }

        return self::shop_url();
    }

    private static function resolve_brand_url(string $id): string
    {
        foreach (self::brand_taxonomy_candidates() as $taxonomy) {
            if (!taxonomy_exists($taxonomy)) {
                continue;
            }

            $term = self::resolve_term($id, $taxonomy);
            if (!$term instanceof WP_Term) {
                continue;
            }

            $url = get_term_link($term);
            if (!is_wp_error($url)) {
                return (string) $url;
            }
        }

        return self::shop_url();
    }

    private static function resolve_private_login_url(string $relativePath): string
    {
        $destination = home_url('/' . ltrim($relativePath, '/'));
        if (is_user_logged_in()) {
            return $destination;
        }

        return wp_login_url($destination);
    }

    private static function shop_url(): string
    {
        $shop = '';
        if (function_exists('wc_get_page_permalink')) {
            $shop = (string) wc_get_page_permalink('shop');
        }
        if ('' !== trim($shop)) {
            return $shop;
        }

        return home_url('/');
    }

    private static function same_destination(string $left, string $right): bool
    {
        return self::normalize_for_compare($left) === self::normalize_for_compare($right);
    }

    private static function normalize_for_compare(string $url): string
    {
        $trimmed = trim($url);
        if ('' === $trimmed) {
            return '';
        }

        $parts = wp_parse_url($trimmed);
        if (!is_array($parts)) {
            return untrailingslashit($trimmed);
        }

        $scheme = strtolower((string) ($parts['scheme'] ?? ''));
        $host = strtolower((string) ($parts['host'] ?? ''));
        $port = isset($parts['port']) ? ':' . (int) $parts['port'] : '';
        $path = isset($parts['path']) ? untrailingslashit((string) $parts['path']) : '';
        $query = isset($parts['query']) && '' !== (string) $parts['query']
            ? '?' . (string) $parts['query']
            : '';

        return $scheme . '://' . $host . $port . $path . $query;
    }

    private static function resolve_term(string $id, string $taxonomy): ?WP_Term
    {
        if (ctype_digit($id)) {
            $term = get_term((int) $id, $taxonomy);
            if ($term instanceof WP_Term && !is_wp_error($term)) {
                return $term;
            }
        }

        $slug = sanitize_title($id);
        if ('' !== $slug) {
            $term = get_term_by('slug', $slug, $taxonomy);
            if ($term instanceof WP_Term) {
                return $term;
            }
        }

        $name = sanitize_text_field($id);
        if ('' !== $name) {
            $term = get_term_by('name', $name, $taxonomy);
            if ($term instanceof WP_Term) {
                return $term;
            }
        }

        return null;
    }

    /**
     * @return array<int,string>
     */
    private static function brand_taxonomy_candidates(): array
    {
        return array(
            'product_brand',
            'pwb-brand',
            'yith_product_brand',
            'berocket_brand',
            'brand',
            'pa_brand',
        );
    }
}

if (class_exists('Lexi_Share_Links')) {
    Lexi_Share_Links::init();
}
