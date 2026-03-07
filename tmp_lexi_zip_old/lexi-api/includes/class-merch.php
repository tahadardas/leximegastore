<?php
/**
 * Merchandising data layer and storefront helpers.
 *
 * @package Lexi_API
 */

defined('ABSPATH') || exit;

class Lexi_Merch
{
    private const CATEGORY_SORT_META = 'lexi_sort_order';

    private const TABLE_CATEGORY_PRODUCT_ORDER = 'lexi_category_product_order';
    private const TABLE_HOME_SECTIONS = 'lexi_home_sections';
    private const TABLE_HOME_SECTION_ITEMS = 'lexi_home_section_items';
    private const TABLE_SEARCH_HISTORY = 'lexi_search_history';
    private const OPTION_HOME_AD_BANNERS = 'lexi_home_ad_banners';

    /**
     * Create/upgrade merchandising tables.
     */
    public static function create_tables(): void
    {
        global $wpdb;

        require_once ABSPATH . 'wp-admin/includes/upgrade.php';

        $charset = $wpdb->get_charset_collate();

        $table_category_product_order = self::category_product_order_table();
        $table_home_sections = self::home_sections_table();
        $table_home_section_items = self::home_section_items_table();
        $table_search_history = self::search_history_table();

        $sql_category_product_order = "CREATE TABLE {$table_category_product_order} (
            id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
            term_id BIGINT UNSIGNED NOT NULL,
            product_id BIGINT UNSIGNED NOT NULL,
            sort_order INT NOT NULL DEFAULT 0,
            pinned TINYINT(1) NOT NULL DEFAULT 0,
            created_at DATETIME NOT NULL,
            updated_at DATETIME NOT NULL,
            PRIMARY KEY (id),
            UNIQUE KEY uniq_term_product (term_id, product_id),
            KEY idx_term_sort (term_id, pinned, sort_order),
            KEY idx_product (product_id)
        ) {$charset};";

        $sql_home_sections = "CREATE TABLE {$table_home_sections} (
            id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
            title_ar VARCHAR(120) NOT NULL,
            type VARCHAR(30) NOT NULL,
            term_id BIGINT UNSIGNED NULL,
            sort_order INT NOT NULL DEFAULT 0,
            is_active TINYINT(1) NOT NULL DEFAULT 1,
            created_at DATETIME NOT NULL,
            updated_at DATETIME NOT NULL,
            PRIMARY KEY (id),
            KEY idx_sort (sort_order),
            KEY idx_active (is_active),
            KEY idx_type (type)
        ) {$charset};";

        $sql_home_section_items = "CREATE TABLE {$table_home_section_items} (
            id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
            section_id BIGINT UNSIGNED NOT NULL,
            product_id BIGINT UNSIGNED NOT NULL,
            sort_order INT NOT NULL DEFAULT 0,
            pinned TINYINT(1) NOT NULL DEFAULT 0,
            created_at DATETIME NOT NULL,
            updated_at DATETIME NOT NULL,
            PRIMARY KEY (id),
            UNIQUE KEY uniq_section_product (section_id, product_id),
            KEY idx_section_sort (section_id, pinned, sort_order),
            KEY idx_section (section_id)
        ) {$charset};";

        $sql_search_history = "CREATE TABLE {$table_search_history} (
            id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
            query_text VARCHAR(255) NOT NULL,
            hit_count BIGINT UNSIGNED NOT NULL DEFAULT 1,
            last_searched_at DATETIME NOT NULL,
            created_at DATETIME NOT NULL,
            PRIMARY KEY (id),
            UNIQUE KEY uniq_query (query_text),
            KEY idx_hits (hit_count DESC),
            KEY idx_last_searched (last_searched_at)
        ) {$charset};";

        dbDelta($sql_category_product_order);
        dbDelta($sql_home_sections);
        dbDelta($sql_home_section_items);
        dbDelta($sql_search_history);
    }

    public static function category_product_order_table(): string
    {
        global $wpdb;
        return $wpdb->prefix . self::TABLE_CATEGORY_PRODUCT_ORDER;
    }

    public static function home_sections_table(): string
    {
        global $wpdb;
        return $wpdb->prefix . self::TABLE_HOME_SECTIONS;
    }

    public static function home_section_items_table(): string
    {
        global $wpdb;
        return $wpdb->prefix . self::TABLE_HOME_SECTION_ITEMS;
    }

    public static function search_history_table(): string
    {
        global $wpdb;
        return $wpdb->prefix . self::TABLE_SEARCH_HISTORY;
    }

    public static function now(): string
    {
        return (string) current_time('mysql');
    }

    private static function normalize_text($value): string
    {
        if (class_exists('Lexi_Text')) {
            return Lexi_Text::normalize($value);
        }

        return (string) $value;
    }

    /**
     * Safely get wishlist count without throwing if Lexi_AI_Core is unavailable.
     */
    public static function get_wishlist_count_safe(int $product_id): int
    {
        try {
            if (!class_exists('Lexi_AI_Core')) {
                return 0;
            }
            $instance = Lexi_AI_Core::instance();
            if (!is_object($instance) || !method_exists($instance, 'get_product_wishlist_count')) {
                return 0;
            }
            return (int) $instance->get_product_wishlist_count($product_id);
        } catch (Throwable $e) {
            return 0;
        }
    }

    /**
     * Track a search query frequency.
     */
    public static function track_search_query(?string $query): void
    {
        if (null === $query) {
            return;
        }

        $normalized = trim(strtolower($query));
        if (mb_strlen($normalized) < 2) {
            return;
        }

        global $wpdb;
        $table = self::search_history_table();
        $now = self::now();

        $wpdb->query($wpdb->prepare(
            "INSERT INTO {$table} (query_text, hit_count, last_searched_at, created_at)
             VALUES (%s, 1, %s, %s)
             ON DUPLICATE KEY UPDATE
                hit_count = hit_count + 1,
                last_searched_at = VALUES(last_searched_at)",
            $normalized,
            $now,
            $now
        ));
    }

    /**
     * Get trending search queries.
     *
     * @return string[]
     */
    public static function get_trending_searches(int $limit = 10): array
    {
        global $wpdb;
        $table = self::search_history_table();

        $results = $wpdb->get_col($wpdb->prepare(
            "SELECT query_text FROM {$table}
             ORDER BY hit_count DESC, last_searched_at DESC
             LIMIT %d",
            $limit
        ));

        return is_array($results) ? $results : array();
    }

    public static function bool_int($value): int
    {
        if (is_bool($value)) {
            return $value ? 1 : 0;
        }
        if (is_numeric($value)) {
            return ((int) $value) > 0 ? 1 : 0;
        }

        $normalized = strtolower(trim((string) $value));
        return in_array($normalized, array('1', 'true', 'yes', 'on'), true) ? 1 : 0;
    }

    public static function get_category_sort_order(int $term_id): int
    {
        return (int) get_term_meta($term_id, self::CATEGORY_SORT_META, true);
    }

    public static function set_category_sort_order(int $term_id, int $sort_order): void
    {
        update_term_meta($term_id, self::CATEGORY_SORT_META, max(0, $sort_order));
    }

    /**
     * @return array<int, WP_Term>
     */
    public static function get_sorted_categories(bool $hide_empty = true): array
    {
        $terms = get_terms(array(
            'taxonomy' => 'product_cat',
            'hide_empty' => $hide_empty,
            'orderby' => 'name',
            'order' => 'ASC',
        ));

        if (is_wp_error($terms) || !is_array($terms)) {
            return array();
        }

        usort($terms, function ($a, $b) {
            $a_order = self::get_category_sort_order((int) $a->term_id);
            $b_order = self::get_category_sort_order((int) $b->term_id);

            if ($a_order === $b_order) {
                return strcasecmp((string) $a->name, (string) $b->name);
            }

            return $a_order <=> $b_order;
        });

        return $terms;
    }

    /**
     * @return array<int, array<string, mixed>>
     */
    public static function get_category_order_rows(int $term_id): array
    {
        global $wpdb;

        if ($term_id <= 0) {
            return array();
        }

        $table = self::category_product_order_table();

        $rows = $wpdb->get_results(
            $wpdb->prepare(
                "SELECT term_id, product_id, sort_order, pinned
                 FROM {$table}
                 WHERE term_id = %d
                 ORDER BY pinned DESC, sort_order ASC, id ASC",
                $term_id
            ),
            ARRAY_A
        );

        if (!is_array($rows)) {
            return array();
        }

        $out = array();
        foreach ($rows as $row) {
            if (!is_array($row)) {
                continue;
            }

            $out[] = array(
                'term_id' => (int) ($row['term_id'] ?? 0),
                'product_id' => (int) ($row['product_id'] ?? 0),
                'sort_order' => (int) ($row['sort_order'] ?? 0),
                'pinned' => ((int) ($row['pinned'] ?? 0)) === 1,
            );
        }

        return $out;
    }

    /**
     * @return array<int, array{pinned: bool, sort_order: int}>
     */
    public static function get_category_order_map(int $term_id): array
    {
        $rows = self::get_category_order_rows($term_id);
        $map = array();

        foreach ($rows as $row) {
            $product_id = (int) ($row['product_id'] ?? 0);
            if ($product_id <= 0) {
                continue;
            }

            $map[$product_id] = array(
                'pinned' => !empty($row['pinned']),
                'sort_order' => (int) ($row['sort_order'] ?? 0),
            );
        }

        return $map;
    }

    /**
     * @return array<int, int>
     */
    public static function get_category_product_ids_by_date(int $term_id, string $search = ''): array
    {
        if ($term_id <= 0) {
            return array();
        }

        $args = array(
            'post_type' => 'product',
            'post_status' => 'publish',
            'posts_per_page' => -1,
            'fields' => 'ids',
            'orderby' => 'date',
            'order' => 'DESC',
            'tax_query' => array(
                array(
                    'taxonomy' => 'product_cat',
                    'field' => 'term_id',
                    'terms' => array($term_id),
                ),
            ),
        );

        if ('' !== trim($search)) {
            $args['s'] = trim($search);
        }

        $query = new WP_Query($args);
        $ids = is_array($query->posts) ? $query->posts : array();

        return array_values(array_map('intval', $ids));
    }

    /**
     * @return array<int, int>
     */
    public static function get_manual_sorted_product_ids_for_category(int $term_id, string $search = ''): array
    {
        $all_ids = self::get_category_product_ids_by_date($term_id, $search);
        if (empty($all_ids)) {
            return array();
        }

        $all_lookup = array_fill_keys($all_ids, true);

        $ordered_rows = self::get_category_order_rows($term_id);
        $ordered_ids = array();

        foreach ($ordered_rows as $row) {
            $product_id = (int) ($row['product_id'] ?? 0);
            if ($product_id <= 0) {
                continue;
            }
            if (!isset($all_lookup[$product_id])) {
                continue;
            }
            $ordered_ids[] = $product_id;
        }

        $ordered_ids = array_values(array_unique($ordered_ids));
        $remaining = array_values(array_diff($all_ids, $ordered_ids));

        return array_merge($ordered_ids, $remaining);
    }

    /**
     * @param array<int, int> $ids
     * @return array<int, WC_Product>
     */
    public static function get_products_by_ids(array $ids): array
    {
        $ids = array_values(array_filter(array_map('intval', $ids), function ($id) {
            return $id > 0;
        }));

        if (empty($ids)) {
            return array();
        }

        $query = new WP_Query(array(
            'post_type' => 'product',
            'post_status' => 'publish',
            'posts_per_page' => count($ids),
            'post__in' => $ids,
            'orderby' => 'post__in',
        ));

        $products = array();
        if (!empty($query->posts) && is_array($query->posts)) {
            foreach ($query->posts as $post) {
                $product = wc_get_product((int) $post->ID);
                if (!$product instanceof WC_Product) {
                    continue;
                }
                $products[(int) $post->ID] = $product;
            }
        }

        return $products;
    }

    public static function normalize_image_url(string $url): string
    {
        $url = trim($url);
        if ('' === $url) {
            return '';
        }

        if (0 === strpos($url, '//')) {
            $url = 'https:' . $url;
        }

        if (0 === strpos($url, '/')) {
            $url = rtrim(home_url('/'), '/') . $url;
        }

        if (0 === strpos($url, 'http://')) {
            $url = 'https://' . substr($url, 7);
        }

        return $url;
    }

    private static function normalize_image_url_or_null($url): ?string
    {
        if (!is_string($url)) {
            return null;
        }

        $normalized = self::normalize_image_url($url);
        return '' !== $normalized ? $normalized : null;
    }

    private static function attachment_image_url_or_null(int $attachment_id, string $size): ?string
    {
        if ($attachment_id <= 0) {
            return null;
        }

        $raw = wp_get_attachment_image_url($attachment_id, $size);
        if (!$raw) {
            return null;
        }

        return self::normalize_image_url_or_null((string) $raw);
    }

    /**
     * @return array{thumb:?string,medium:?string,large:?string}
     */
    private static function build_image_size_payload(int $attachment_id): array
    {
        $thumb = self::attachment_image_url_or_null($attachment_id, 'woocommerce_thumbnail');
        $medium = self::attachment_image_url_or_null($attachment_id, 'medium');
        $large = self::attachment_image_url_or_null($attachment_id, 'large');
        $full = self::attachment_image_url_or_null($attachment_id, 'full');

        $thumb = $thumb ?: $medium ?: $large ?: $full;
        $medium = $medium ?: $thumb ?: $large ?: $full;
        $large = $large ?: $full ?: $medium ?: $thumb;

        return array(
            'thumb' => $thumb ?: null,
            'medium' => $medium ?: null,
            'large' => $large ?: null,
        );
    }

    /**
     * Convert mixed Woo/meta price values to a nullable float.
     *
     * Handles localized separators and Arabic-Indic digits.
     */
    private static function parse_price_value($value): ?float
    {
        if (null === $value) {
            return null;
        }

        if (is_int($value) || is_float($value)) {
            return (float) $value;
        }

        $raw = trim((string) $value);
        if ('' === $raw) {
            return null;
        }

        // Normalize Arabic-Indic and Persian digits + localized separators.
        $raw = strtr($raw, array(
            "\u{0660}" => '0', "\u{0661}" => '1', "\u{0662}" => '2', "\u{0663}" => '3', "\u{0664}" => '4',
            "\u{0665}" => '5', "\u{0666}" => '6', "\u{0667}" => '7', "\u{0668}" => '8', "\u{0669}" => '9',
            "\u{06F0}" => '0', "\u{06F1}" => '1', "\u{06F2}" => '2', "\u{06F3}" => '3', "\u{06F4}" => '4',
            "\u{06F5}" => '5', "\u{06F6}" => '6', "\u{06F7}" => '7', "\u{06F8}" => '8', "\u{06F9}" => '9',
            "\u{066B}" => '.', "\u{066C}" => ',', "\u{060C}" => ',',
        ));

        $raw = preg_replace('/\s+/u', '', $raw);
        $raw = is_string($raw) ? $raw : '';

        // Keep only number-relevant characters.
        $raw = preg_replace('/[^0-9\-\.,]/', '', $raw);
        $raw = is_string($raw) ? $raw : '';
        if ('' === $raw || '-' === $raw) {
            return null;
        }

        $is_negative = '-' === substr($raw, 0, 1);
        $raw = str_replace('-', '', $raw);
        if ('' === $raw) {
            return null;
        }

        $has_dot = false !== strpos($raw, '.');
        $has_comma = false !== strpos($raw, ',');

        if ($has_dot && $has_comma) {
            // Mixed separators: the last separator is considered decimal.
            $last_dot = strrpos($raw, '.');
            $last_comma = strrpos($raw, ',');
            $decimal_sep = ($last_dot !== false && $last_dot > $last_comma) ? '.' : ',';
            $thousands_sep = '.' === $decimal_sep ? ',' : '.';

            $normalized = str_replace($thousands_sep, '', $raw);
            if (',' === $decimal_sep) {
                $normalized = str_replace(',', '.', $normalized);
            }
        } elseif ($has_dot || $has_comma) {
            // Single separator type: decide if it is thousands or decimal.
            $sep = $has_dot ? '.' : ',';
            $parts = explode($sep, $raw);

            if (count($parts) > 2) {
                $last = (string) array_pop($parts);
                $left = implode('', $parts);
                $normalized = strlen($last) <= 2 ? ($left . '.' . $last) : ($left . $last);
            } else {
                $left = (string) ($parts[0] ?? '');
                $right = (string) ($parts[1] ?? '');

                if ('' === $right) {
                    $normalized = $left;
                } elseif (3 === strlen($right) && '' !== $left) {
                    // Common thousands grouping: 12,500 or 12.500.
                    $normalized = $left . $right;
                } else {
                    $normalized = $left . '.' . $right;
                }
            }
        } else {
            $normalized = preg_replace('/[.,]/', '', $raw);
            $normalized = is_string($normalized) ? $normalized : '';
        }

        $normalized = preg_replace('/[^0-9\.]/', '', $normalized);
        $normalized = is_string($normalized) ? $normalized : '';

        // Keep only the first decimal point.
        $first_dot = strpos($normalized, '.');
        if (false !== $first_dot) {
            $int_part = substr($normalized, 0, $first_dot + 1);
            $frac_part = str_replace('.', '', substr($normalized, $first_dot + 1));
            $normalized = $int_part . $frac_part;
        }

        if ($is_negative) {
            $normalized = '-' . $normalized;
        }

        if ($normalized === '' || $normalized === '.' || $normalized === '-.') {
            return null;
        }

        return is_numeric($normalized) ? (float) $normalized : null;
    }

    /**
     * Read first valid positive price from known meta keys.
     *
     * @param array<int, string> $meta_keys
     */
    private static function first_price_from_meta_keys(int $product_id, array $meta_keys): ?float
    {
        if ($product_id <= 0) {
            return null;
        }

        foreach ($meta_keys as $meta_key) {
            $meta_key = trim((string) $meta_key);
            if ('' === $meta_key) {
                continue;
            }

            $raw = get_post_meta($product_id, $meta_key, true);
            $parsed = self::parse_price_value($raw);
            if (null !== $parsed && $parsed > 0) {
                return $parsed;
            }
        }

        return null;
    }

    /**
     * Scan all product meta keys for likely numeric price values.
     *
     * This is a final fallback for custom importers that save prices
     * in non-standard meta keys.
     *
     * @param array<int, string> $preferred_key_parts
     */
    private static function first_price_from_meta_scan(int $product_id, array $preferred_key_parts = array('price', 'regular_price', 'sale_price', "\u{0633}\u{0639}\u{0631}")): ?float
    {
        if ($product_id <= 0) {
            return null;
        }

        $all_meta = get_post_meta($product_id);
        if (!is_array($all_meta) || empty($all_meta)) {
            return null;
        }

        $normalized_parts = array_values(array_filter(array_map(function ($part) {
            return strtolower(trim((string) $part));
        }, $preferred_key_parts)));
        if (empty($normalized_parts)) {
            $normalized_parts = array('price');
        }

        $excluded_key_parts = array(
            'date',
            'timestamp',
            'currency',
            'hash',
            'nonce',
            'wc_average',
            'tax',
            'fee',
            'shipping',
        );

        foreach ($all_meta as $meta_key => $meta_values) {
            $key = strtolower(trim((string) $meta_key));
            if ('' === $key) {
                continue;
            }

            $is_preferred = false;
            foreach ($normalized_parts as $part) {
                if (false !== strpos($key, $part)) {
                    $is_preferred = true;
                    break;
                }
            }
            if (!$is_preferred) {
                continue;
            }

            $is_excluded = false;
            foreach ($excluded_key_parts as $part) {
                if (false !== strpos($key, $part)) {
                    $is_excluded = true;
                    break;
                }
            }
            if ($is_excluded) {
                continue;
            }

            $values = is_array($meta_values) ? $meta_values : array($meta_values);
            foreach ($values as $raw_value) {
                $parsed = self::parse_price_value($raw_value);
                if (null !== $parsed && $parsed > 0) {
                    return $parsed;
                }
            }
        }

        return null;
    }

    /**
     * Public wrapper for price parsing used by debug/admin tools.
     */
    public static function parse_price_for_debug($value): ?float
    {
        return self::parse_price_value($value);
    }

    /**
     * Collect likely price-like post meta values for diagnostics.
     *
     * @return array<int, array{key: string, raw: string, parsed: float}>
     */
    public static function get_product_price_meta_candidates(int $product_id, int $limit = 80): array
    {
        if ($product_id <= 0) {
            return array();
        }

        $all_meta = get_post_meta($product_id);
        if (!is_array($all_meta) || empty($all_meta)) {
            return array();
        }

        $limit = max(1, min(300, $limit));
        $candidates = array();
        $parts = array(
            'price',
            'regular',
            'sale',
            'amount',
            'cost',
            "\u{0633}\u{0639}\u{0631}",
            "\u{0627}\u{0644}\u{0633}\u{0639}\u{0631}",
        );

        foreach ($all_meta as $meta_key => $meta_values) {
            $key = trim((string) $meta_key);
            if ('' === $key) {
                continue;
            }

            $key_lc = strtolower($key);
            $is_candidate_key = false;
            foreach ($parts as $part) {
                if (false !== strpos($key_lc, strtolower((string) $part))) {
                    $is_candidate_key = true;
                    break;
                }
            }
            if (!$is_candidate_key) {
                continue;
            }

            $values = is_array($meta_values) ? $meta_values : array($meta_values);
            foreach ($values as $raw_value) {
                if (is_scalar($raw_value)) {
                    $raw_value_str = (string) $raw_value;
                } else {
                    $raw_value_str = (string) wp_json_encode($raw_value);
                }
                $parsed = self::parse_price_value($raw_value_str);
                if (null === $parsed) {
                    continue;
                }

                $candidates[] = array(
                    'key' => $key,
                    'raw' => $raw_value_str,
                    'parsed' => (float) $parsed,
                );
                if (count($candidates) >= $limit) {
                    return $candidates;
                }
            }
        }

        return $candidates;
    }

    /**
     * Resolve product prices from WooCommerce data with robust fallbacks.
     *
     * @return array{price: float, regular_price: float, sale_price: ?float}
     */
    public static function resolve_product_prices(WC_Product $product): array
    {
        $price = self::parse_price_value($product->get_price());
        $regular_price = self::parse_price_value($product->get_regular_price());
        $sale_price = self::parse_price_value($product->get_sale_price());
        $product_id = (int) $product->get_id();

        // Variable parents can have empty top-level price; use variation mins.
        if ($product instanceof WC_Product_Variable) {
            $variation_prices = $product->get_variation_prices(true);
            if (is_array($variation_prices)) {
                $parse_values = function (array $values): array {
                    $parsed_values = array();
                    foreach ($values as $value) {
                        $parsed = self::parse_price_value($value);
                        if (null !== $parsed) {
                            $parsed_values[] = (float) $parsed;
                        }
                    }
                    return $parsed_values;
                };

                $price_values = isset($variation_prices['price']) && is_array($variation_prices['price'])
                    ? $parse_values($variation_prices['price'])
                    : array();
                $regular_values = isset($variation_prices['regular_price']) && is_array($variation_prices['regular_price'])
                    ? $parse_values($variation_prices['regular_price'])
                    : array();
                $sale_values = isset($variation_prices['sale_price']) && is_array($variation_prices['sale_price'])
                    ? $parse_values($variation_prices['sale_price'])
                    : array();

                if ((null === $price || $price <= 0) && !empty($price_values)) {
                    $price = min($price_values);
                }
                if ((null === $regular_price || $regular_price <= 0) && !empty($regular_values)) {
                    $regular_price = min($regular_values);
                }
                if ((null === $sale_price || $sale_price <= 0) && !empty($sale_values)) {
                    $positive_sales = array_values(array_filter($sale_values, function ($v) {
                        return $v > 0;
                    }));
                    $sale_price = !empty($positive_sales) ? min($positive_sales) : $sale_price;
                }
            }
        }

        // Meta fallback for imported products that keep numeric strings in meta.
        if (null === $price || $price <= 0) {
            $price = self::first_price_from_meta_keys($product_id, array(
                '_price',
                'price',
                '_lexi_price',
                'lexi_price',
                '_product_price',
                'product_price',
                "\u{0633}\u{0639}\u{0631}",
                "\u{0627}\u{0644}\u{0633}\u{0639}\u{0631}",
            ));
            if (null === $price || $price <= 0) {
                $price = self::first_price_from_meta_scan($product_id, array('price', "\u{0633}\u{0639}\u{0631}"));
            }
        }
        if (null === $regular_price || $regular_price <= 0) {
            $regular_price = self::first_price_from_meta_keys($product_id, array(
                '_regular_price',
                'regular_price',
                '_lexi_regular_price',
                'lexi_regular_price',
                '_product_regular_price',
                "\u{0627}\u{0644}\u{0633}\u{0639}\u{0631}_\u{0627}\u{0644}\u{0623}\u{0635}\u{0644}\u{064A}",
            ));
            if (null === $regular_price || $regular_price <= 0) {
                $regular_price = self::first_price_from_meta_scan($product_id, array('regular_price', 'price', "\u{0633}\u{0639}\u{0631}"));
            }
        }
        if (null === $sale_price || $sale_price <= 0) {
            $sale_price = self::first_price_from_meta_keys($product_id, array(
                '_sale_price',
                'sale_price',
                '_lexi_sale_price',
                'lexi_sale_price',
                '_product_sale_price',
                "\u{0633}\u{0639}\u{0631}_\u{0627}\u{0644}\u{0628}\u{064A}\u{0639}",
            ));
            if (null === $sale_price || $sale_price <= 0) {
                $sale_price = self::first_price_from_meta_scan($product_id, array('sale_price', "\u{0633}\u{0639}\u{0631}"));
            }
        }

        if (null !== $sale_price && $sale_price <= 0) {
            $sale_price = null;
        }

        if (null !== $sale_price && null !== $regular_price && $regular_price > 0 && $sale_price >= $regular_price) {
            $sale_price = null;
        }

        if ((null === $price || $price <= 0) && null !== $sale_price && $sale_price > 0) {
            $price = $sale_price;
        }
        if ((null === $price || $price <= 0) && null !== $regular_price && $regular_price > 0) {
            $price = $regular_price;
        }
        if ((null === $regular_price || $regular_price <= 0) && null !== $price && $price > 0) {
            $regular_price = $price;
        }

        return array(
            'price' => (null !== $price && $price > 0) ? (float) $price : 0.0,
            'regular_price' => (null !== $regular_price && $regular_price > 0) ? (float) $regular_price : 0.0,
            'sale_price' => (null !== $sale_price && $sale_price > 0) ? (float) $sale_price : null,
        );
    }

    private static function normalize_price_or_null($value): ?float
    {
        $parsed = self::parse_price_value($value);
        if (null === $parsed || $parsed <= 0) {
            return null;
        }
        return (float) $parsed;
    }

    private static function calculate_discount_percent(?float $regular_price, ?float $sale_price): ?int
    {
        if (null === $regular_price || null === $sale_price) {
            return null;
        }
        if ($regular_price <= 0 || $sale_price <= 0 || $sale_price >= $regular_price) {
            return null;
        }

        $percent = (int) round((($regular_price - $sale_price) / $regular_price) * 100);
        if ($percent <= 0) {
            return null;
        }

        return min(100, $percent);
    }

    /**
     * @return array<int, array<string, mixed>>
     */
    private static function build_category_payloads(int $product_id): array
    {
        $out = array();
        $terms = get_the_terms($product_id, 'product_cat');
        if (!$terms || is_wp_error($terms)) {
            return $out;
        }

        foreach ($terms as $term) {
            if (!is_object($term) || !isset($term->term_id)) {
                continue;
            }

            $out[] = array(
                'id' => (int) $term->term_id,
                'name' => isset($term->name) ? self::normalize_text($term->name) : '',
                'slug' => isset($term->slug) ? (string) $term->slug : '',
            );
        }

        return $out;
    }

    /**
     * @return array{
     *   price_min:?float,price_max:?float,
     *   regular_min:?float,regular_max:?float,
     *   sale_min:?float,sale_max:?float
     * }
     */
    private static function build_variable_price_ranges(WC_Product $product): array
    {
        $empty = array(
            'price_min' => null,
            'price_max' => null,
            'regular_min' => null,
            'regular_max' => null,
            'sale_min' => null,
            'sale_max' => null,
        );

        if (!($product instanceof WC_Product_Variable)) {
            return $empty;
        }

        $variation_prices = $product->get_variation_prices(true);
        if (!is_array($variation_prices)) {
            return $empty;
        }

        $parse_values = function (array $values): array {
            $parsed = array();
            foreach ($values as $raw) {
                $value = self::normalize_price_or_null($raw);
                if (null !== $value) {
                    $parsed[] = $value;
                }
            }
            return $parsed;
        };

        $price_values = isset($variation_prices['price']) && is_array($variation_prices['price'])
            ? $parse_values($variation_prices['price'])
            : array();
        $regular_values = isset($variation_prices['regular_price']) && is_array($variation_prices['regular_price'])
            ? $parse_values($variation_prices['regular_price'])
            : array();
        $sale_values = isset($variation_prices['sale_price']) && is_array($variation_prices['sale_price'])
            ? $parse_values($variation_prices['sale_price'])
            : array();

        return array(
            'price_min' => !empty($price_values) ? min($price_values) : null,
            'price_max' => !empty($price_values) ? max($price_values) : null,
            'regular_min' => !empty($regular_values) ? min($regular_values) : null,
            'regular_max' => !empty($regular_values) ? max($regular_values) : null,
            'sale_min' => !empty($sale_values) ? min($sale_values) : null,
            'sale_max' => !empty($sale_values) ? max($sale_values) : null,
        );
    }

    /**
     * @return array{
     *   stock_quantity:?int,total_in_stock:?int,variants_in_stock:?int,total_variants:?int
     * }
     */
    private static function build_stock_payload(WC_Product $product): array
    {
        $stock_quantity = $product->managing_stock() ? $product->get_stock_quantity() : null;
        $normalized_stock_quantity = is_numeric($stock_quantity) ? (int) $stock_quantity : null;

        $payload = array(
            'stock_quantity' => $normalized_stock_quantity,
            'total_in_stock' => null,
            'variants_in_stock' => null,
            'total_variants' => null,
        );

        if (!($product instanceof WC_Product_Variable)) {
            return $payload;
        }

        $children = $product->get_children();
        if (!is_array($children) || empty($children)) {
            return $payload;
        }

        $variants_in_stock = 0;
        $total_in_stock = 0;
        $total_variants = 0;

        foreach ($children as $variation_id) {
            $variation = wc_get_product((int) $variation_id);
            if (!$variation || !($variation instanceof WC_Product_Variation)) {
                continue;
            }
            if ('publish' !== get_post_status((int) $variation_id)) {
                continue;
            }

            $total_variants++;
            if ($variation->is_in_stock()) {
                $variants_in_stock++;
            }

            if ($variation->managing_stock()) {
                $qty = $variation->get_stock_quantity();
                if (is_numeric($qty) && (int) $qty > 0) {
                    $total_in_stock += (int) $qty;
                }
            }
        }

        $payload['variants_in_stock'] = $variants_in_stock;
        $payload['total_variants'] = $total_variants;
        $payload['total_in_stock'] = $total_in_stock > 0 ? $total_in_stock : 0;
        if (null === $payload['stock_quantity']) {
            $payload['stock_quantity'] = $payload['total_in_stock'];
        }

        return $payload;
    }

    /**
     * @return array<int, array<string, mixed>>
     */
    private static function build_product_attributes(WC_Product $product): array
    {
        $attributes = array();
        $raw_attributes = $product->get_attributes();
        if (!is_array($raw_attributes)) {
            return $attributes;
        }

        foreach ($raw_attributes as $attribute) {
            if (!$attribute instanceof WC_Product_Attribute) {
                continue;
            }

            $options = array();
            if ($attribute->is_taxonomy()) {
                $taxonomy = $attribute->get_name();
                $terms = wc_get_product_terms($product->get_id(), $taxonomy, array('fields' => 'names'));
                if (is_array($terms)) {
                    $options = array_values(array_map(array(__CLASS__, 'normalize_text'), $terms));
                }
            } else {
                $options = array_values(array_map(array(__CLASS__, 'normalize_text'), $attribute->get_options()));
            }

            $attributes[] = array(
                'name' => self::normalize_text(wc_attribute_label($attribute->get_name())),
                'slug' => (string) $attribute->get_name(),
                'options' => $options,
                'visible' => (bool) $attribute->get_visible(),
                'variation' => (bool) $attribute->get_variation(),
            );
        }

        return $attributes;
    }

    /**
     * @param array<int, array{pinned: bool, sort_order: int}>|null $order_map
     * @return array<string, mixed>
     */
    public static function format_product_for_api(WC_Product $product, ?int $context_term_id = null, ?array $order_map = null): array
    {
        $images = array();
        $card_images = array();
        $attachment_ids = $product->get_gallery_image_ids();
        $thumb_id = $product->get_image_id();

        if ($thumb_id) {
            array_unshift($attachment_ids, $thumb_id);
        }

        foreach (array_unique($attachment_ids) as $img_id) {
            $sizes = self::build_image_size_payload((int) $img_id);
            $src = isset($sizes['large']) && is_string($sizes['large'])
                ? $sizes['large']
                : (isset($sizes['medium']) && is_string($sizes['medium'])
                    ? $sizes['medium']
                    : (isset($sizes['thumb']) && is_string($sizes['thumb']) ? $sizes['thumb'] : ''));

            if ('' === trim($src)) {
                continue;
            }

            $images[] = array(
                'id' => (int) $img_id,
                'src' => $src,
                'thumb' => $sizes['thumb'],
                'medium' => $sizes['medium'],
                'large' => $sizes['large'],
                'alt' => self::normalize_text(
                    get_post_meta($img_id, '_wp_attachment_image_alt', true) ?: $product->get_name()
                ),
            );

            $card_url = isset($sizes['medium']) && is_string($sizes['medium'])
                ? $sizes['medium']
                : (isset($sizes['thumb']) && is_string($sizes['thumb'])
                    ? $sizes['thumb']
                    : (isset($sizes['large']) && is_string($sizes['large']) ? $sizes['large'] : ''));
            if ('' !== trim($card_url)) {
                $card_images[] = $card_url;
            }
        }

        $primary_image = array(
            'thumb' => null,
            'medium' => null,
            'large' => null,
        );
        if (!empty($images)) {
            $first = $images[0];
            $primary_image = array(
                'thumb' => isset($first['thumb']) && is_string($first['thumb']) ? $first['thumb'] : null,
                'medium' => isset($first['medium']) && is_string($first['medium']) ? $first['medium'] : null,
                'large' => isset($first['large']) && is_string($first['large']) ? $first['large'] : null,
            );
        }

        $featured_image = isset($primary_image['large']) && is_string($primary_image['large'])
            ? $primary_image['large']
            : (isset($primary_image['medium']) && is_string($primary_image['medium'])
                ? $primary_image['medium']
                : (isset($primary_image['thumb']) && is_string($primary_image['thumb']) ? $primary_image['thumb'] : null));
        $categories = self::build_category_payloads((int) $product->get_id());
        $category_ids = array_values(array_map('intval', wp_list_pluck($categories, 'id')));

        $prices = self::resolve_product_prices($product);
        $price = self::normalize_price_or_null($prices['price'] ?? null);
        $regular_price = self::normalize_price_or_null($prices['regular_price'] ?? null);
        $sale_price = self::normalize_price_or_null($prices['sale_price'] ?? null);

        if (null !== $sale_price && null !== $regular_price && $sale_price >= $regular_price) {
            $sale_price = null;
        }
        if (null === $price && null !== $sale_price) {
            $price = $sale_price;
        }
        if (null === $price && null !== $regular_price) {
            $price = $regular_price;
        }
        if (null === $regular_price && null !== $price) {
            $regular_price = $price;
        }

        $ranges = self::build_variable_price_ranges($product);
        if ($product instanceof WC_Product_Variable && null !== $ranges['price_min']) {
            $price = $ranges['price_min'];
        }
        if ($product instanceof WC_Product_Variable && null === $regular_price && null !== $ranges['regular_min']) {
            $regular_price = $ranges['regular_min'];
        }
        if ($product instanceof WC_Product_Variable && null === $sale_price && null !== $ranges['sale_min']) {
            $sale_price = $ranges['sale_min'];
        }

        $stock = self::build_stock_payload($product);
        $discount_percent = self::calculate_discount_percent($regular_price, $sale_price);

        $payload = array(
            // Stable contract core
            'id' => (int) $product->get_id(),
            'name' => self::normalize_text($product->get_name()),
            'slug' => (string) $product->get_slug(),
            'type' => (string) $product->get_type(),
            'status' => (string) $product->get_status(),
            'sku' => (string) $product->get_sku(),
            'description' => self::normalize_text(wp_strip_all_tags((string) $product->get_description())),
            'short_description' => self::normalize_text(wp_strip_all_tags((string) $product->get_short_description())),
            'price' => $price,
            'regular_price' => $regular_price,
            'sale_price' => $sale_price,
            'currency' => (string) get_woocommerce_currency(),
            'discount_percent' => $discount_percent,
            'stock_status' => (string) $product->get_stock_status(),
            'stock_quantity' => $stock['stock_quantity'],
            'in_stock' => (bool) $product->is_in_stock(),
            'rating_avg' => (float) $product->get_average_rating(),
            'rating_count' => (int) $product->get_rating_count(),

            // Backward-compatible aliases already consumed by app
            'rating' => (float) $product->get_average_rating(),
            'reviews_count' => (int) $product->get_review_count(),

            // Media/categories
            'image' => $primary_image,
            'images' => $images,
            'card_images' => array_values(array_unique(array_values(array_filter($card_images, function ($url) {
                return is_string($url) && '' !== trim($url);
            })))),
            'featured_image' => $featured_image,
            'categories' => $categories,
            'category_ids' => $category_ids,

            // Variable helpers
            'price_min' => $ranges['price_min'],
            'price_max' => $ranges['price_max'],
            'regular_min' => $ranges['regular_min'],
            'regular_max' => $ranges['regular_max'],
            'sale_min' => $ranges['sale_min'],
            'sale_max' => $ranges['sale_max'],
            'total_in_stock' => $stock['total_in_stock'],
            'variants_in_stock' => $stock['variants_in_stock'],
            'total_variants' => $stock['total_variants'],

            // Extended commerce data
            'shipping_class_id' => $product->get_shipping_class_id() > 0 ? (int) $product->get_shipping_class_id() : null,
            'shipping_class' => (string) $product->get_shipping_class(),
            'tax_status' => (string) $product->get_tax_status(),
            'tax_class' => (string) $product->get_tax_class(),
            'attributes' => self::build_product_attributes($product),
            'variations' => self::extract_variations_for_api($product),

            'date_on_sale_from' => $product->get_date_on_sale_from() ? $product->get_date_on_sale_from()->getTimestamp() : null,
            'date_on_sale_to' => $product->get_date_on_sale_to() ? $product->get_date_on_sale_to()->getTimestamp() : null,
            'created_at' => $product->get_date_created()
                ? $product->get_date_created()->format('c')
                : null,
            'wishlist_count' => self::get_wishlist_count_safe((int) $product->get_id()),
        );

        if (null !== $context_term_id && $context_term_id > 0) {
            $order = is_array($order_map) ? ($order_map[(int) $product->get_id()] ?? null) : null;
            $payload['pinned'] = is_array($order) ? (bool) ($order['pinned'] ?? false) : false;
            $payload['sort_order'] = is_array($order) ? (int) ($order['sort_order'] ?? 0) : null;
        }

        return $payload;
    }

    /**
     * Return normalized color variations for variable products.
     *
     * @return array<int, array<string, mixed>>
     */
    private static function extract_variations_for_api(WC_Product $product): array
    {
        if (!$product->is_type('variable') || !($product instanceof WC_Product_Variable)) {
            return array();
        }

        $result = array();
        $children = $product->get_children();
        foreach ($children as $variation_id) {
            $variation = wc_get_product((int) $variation_id);
            if (!$variation || !($variation instanceof WC_Product_Variation)) {
                continue;
            }

            if ('publish' !== get_post_status((int) $variation_id)) {
                continue;
            }

            $raw_attributes = $variation->get_attributes();
            $label = '';
            $color_value = '';

            foreach ($raw_attributes as $attr_key => $attr_value) {
                $value = trim((string) $attr_value);
                if ('' === $value) {
                    continue;
                }

                if ('' === $label) {
                    $label = $value;
                }

                if (false !== stripos((string) $attr_key, 'color') || false !== stripos((string) $attr_key, 'لون')) {
                    $color_value = $value;
                    if ('' === $label) {
                        $label = $value;
                    }
                }
            }

            if ('' === $label) {
                $label = (string) $variation->get_name();
            }

            $prices = self::resolve_product_prices($variation);
            $price = self::normalize_price_or_null($prices['price'] ?? null);
            $regular_price = self::normalize_price_or_null($prices['regular_price'] ?? null);
            $sale_price = self::normalize_price_or_null($prices['sale_price'] ?? null);
            if (null !== $sale_price && null !== $regular_price && $sale_price >= $regular_price) {
                $sale_price = null;
            }
            if (null === $price && null !== $sale_price) {
                $price = $sale_price;
            }
            if (null === $price && null !== $regular_price) {
                $price = $regular_price;
            }
            if (null === $regular_price && null !== $price) {
                $regular_price = $price;
            }

            $image_url = '';

            $image_id = (int) $variation->get_image_id();
            if ($image_id <= 0) {
                $image_id = (int) $product->get_image_id();
            }
            if ($image_id > 0) {
                $raw = wp_get_attachment_image_url($image_id, 'woocommerce_single');
                if ($raw) {
                    $image_url = self::normalize_image_url((string) $raw);
                }
            }

            $result[] = array(
                'id' => (int) $variation->get_id(),
                'label' => $label,
                'color' => $color_value,
                'color_label' => $color_value,
                'price' => $price,
                'regular_price' => $regular_price,
                'sale_price' => $sale_price,
                'discount_percent' => self::calculate_discount_percent($regular_price, $sale_price),
                'in_stock' => (bool) $variation->is_in_stock(),
                'stock_status' => (string) $variation->get_stock_status(),
                'stock_quantity' => $variation->managing_stock() ? (int) ($variation->get_stock_quantity() ?? 0) : null,
                'image_url' => $image_url,
            );
        }

        return $result;
    }

    /**
     * @return array<int, array<string, mixed>>
     */
    public static function get_home_sections(bool $only_active = true): array
    {
        global $wpdb;

        $table = self::home_sections_table();
        $where = $only_active ? 'WHERE is_active = 1' : '';

        $rows = $wpdb->get_results(
            "SELECT id, title_ar, type, term_id, sort_order, is_active, created_at, updated_at
             FROM {$table}
             {$where}
             ORDER BY sort_order ASC, id ASC",
            ARRAY_A
        );

        if (!is_array($rows)) {
            return array();
        }

        $sections = array();
        foreach ($rows as $row) {
            if (!is_array($row)) {
                continue;
            }

            $sections[] = array(
                'id' => (int) ($row['id'] ?? 0),
                'title_ar' => self::normalize_text($row['title_ar'] ?? ''),
                'type' => self::normalize_section_type((string) ($row['type'] ?? 'manual_products')),
                'term_id' => isset($row['term_id']) ? (int) $row['term_id'] : null,
                'sort_order' => (int) ($row['sort_order'] ?? 0),
                'is_active' => ((int) ($row['is_active'] ?? 0)) === 1,
                'created_at' => (string) ($row['created_at'] ?? ''),
                'updated_at' => (string) ($row['updated_at'] ?? ''),
            );
        }

        return $sections;
    }

    /**
     * @return array<int, array<string, mixed>>
     */
    public static function get_home_section_items(int $section_id): array
    {
        global $wpdb;

        if ($section_id <= 0) {
            return array();
        }

        $table = self::home_section_items_table();

        $rows = $wpdb->get_results(
            $wpdb->prepare(
                "SELECT id, section_id, product_id, sort_order, pinned, created_at, updated_at
                 FROM {$table}
                 WHERE section_id = %d
                 ORDER BY pinned DESC, sort_order ASC, id ASC",
                $section_id
            ),
            ARRAY_A
        );

        if (!is_array($rows)) {
            return array();
        }

        $items = array();
        foreach ($rows as $row) {
            if (!is_array($row)) {
                continue;
            }

            $items[] = array(
                'id' => (int) ($row['id'] ?? 0),
                'section_id' => (int) ($row['section_id'] ?? 0),
                'product_id' => (int) ($row['product_id'] ?? 0),
                'sort_order' => (int) ($row['sort_order'] ?? 0),
                'pinned' => ((int) ($row['pinned'] ?? 0)) === 1,
                'created_at' => (string) ($row['created_at'] ?? ''),
                'updated_at' => (string) ($row['updated_at'] ?? ''),
            );
        }

        return $items;
    }

    public static function normalize_section_type(string $type): string
    {
        $type = strtolower(trim($type));
        $allowed = array('manual_products', 'category', 'on_sale', 'newest', 'top_rated', 'flash_deals', 'hero_banner');

        return in_array($type, $allowed, true) ? $type : 'manual_products';
    }

    /**
     * @return array<int, array<string, mixed>>
     */
    public static function get_home_ad_banners(bool $only_active = true): array
    {
        $raw = get_option(self::OPTION_HOME_AD_BANNERS, array());

        if (is_string($raw)) {
            $decoded = json_decode($raw, true);
            if (is_array($decoded)) {
                $raw = $decoded;
            }
        }

        if (!is_array($raw)) {
            return array();
        }

        $items = array();
        foreach ($raw as $index => $item) {
            if (!is_array($item)) {
                continue;
            }

            $normalized = self::normalize_home_ad_banner_row($item, $index + 1);
            if ('' === (string) ($normalized['image_url'] ?? '')) {
                continue;
            }

            if ($only_active && empty($normalized['is_active'])) {
                continue;
            }

            $items[] = $normalized;
        }

        usort($items, function ($a, $b) {
            $a_order = isset($a['sort_order']) ? (int) $a['sort_order'] : 0;
            $b_order = isset($b['sort_order']) ? (int) $b['sort_order'] : 0;
            if ($a_order === $b_order) {
                return strcmp((string) ($a['id'] ?? ''), (string) ($b['id'] ?? ''));
            }
            return $a_order <=> $b_order;
        });

        return array_values($items);
    }

    /**
     * @param array<int, array<string, mixed>> $items
     * @return array<int, array<string, mixed>>
     */
    public static function save_home_ad_banners(array $items): array
    {
        $normalized_items = array();
        foreach ($items as $index => $item) {
            if (!is_array($item)) {
                continue;
            }

            $normalized = self::normalize_home_ad_banner_row($item, $index + 1);
            if ('' === (string) ($normalized['image_url'] ?? '')) {
                continue;
            }

            $normalized_items[] = $normalized;
        }

        usort($normalized_items, function ($a, $b) {
            $a_order = isset($a['sort_order']) ? (int) $a['sort_order'] : 0;
            $b_order = isset($b['sort_order']) ? (int) $b['sort_order'] : 0;
            if ($a_order === $b_order) {
                return strcmp((string) ($a['id'] ?? ''), (string) ($b['id'] ?? ''));
            }
            return $a_order <=> $b_order;
        });

        update_option(self::OPTION_HOME_AD_BANNERS, array_values($normalized_items), false);
        return array_values($normalized_items);
    }

    /**
     * @param array<string, mixed> $item
     * @return array<string, mixed>
     */
    private static function normalize_home_ad_banner_row(array $item, int $fallback_sort_order = 0): array
    {
        $id = '';
        if (isset($item['id'])) {
            $id = sanitize_key((string) $item['id']);
        }
        if ('' === $id) {
            $id = sanitize_key((string) wp_generate_uuid4());
        }

        $image_url = self::normalize_image_url((string) ($item['image_url'] ?? ''));
        $link_url = self::normalize_home_ad_banner_link((string) ($item['link_url'] ?? ''));
        $cta_text = self::normalize_text($item['cta_text'] ?? '');
        if ('' === $cta_text) {
            $cta_text = 'تسوق الآن';
        }

        $sort_order = isset($item['sort_order']) ? (int) $item['sort_order'] : $fallback_sort_order;
        if ($sort_order < 0) {
            $sort_order = 0;
        }

        return array(
            'id' => $id,
            'image_url' => $image_url,
            'link_url' => $link_url,
            'title_ar' => self::normalize_text($item['title_ar'] ?? ''),
            'subtitle_ar' => self::normalize_text($item['subtitle_ar'] ?? ''),
            'badge' => self::normalize_text($item['badge'] ?? ''),
            'is_active' => self::bool_int($item['is_active'] ?? true) === 1,
            'sort_order' => $sort_order,
            'gradient_start' => self::normalize_argb_hex((string) ($item['gradient_start'] ?? ''), 'FF131313'),
            'gradient_end' => self::normalize_argb_hex((string) ($item['gradient_end'] ?? ''), 'FF2A2417'),
            'cta_text' => $cta_text,
            'text_color' => self::normalize_argb_hex((string) ($item['text_color'] ?? ($item['text_color_hex'] ?? '')), 'FFFFFFFF'),
            'badge_color' => self::normalize_argb_hex((string) ($item['badge_color'] ?? ($item['badge_color_hex'] ?? '')), 'FFFACB21'),
        );
    }

    private static function normalize_argb_hex(string $value, string $fallback = 'FFFFFFFF'): string
    {
        $fallback = strtoupper(trim(str_replace('#', '', $fallback)));
        if (6 === strlen($fallback) && preg_match('/^[0-9A-F]{6}$/', $fallback)) {
            $fallback = 'FF' . $fallback;
        }
        if (!preg_match('/^[0-9A-F]{8}$/', $fallback)) {
            $fallback = 'FFFFFFFF';
        }

        $value = strtoupper(trim(str_replace('#', '', $value)));
        if (6 === strlen($value) && preg_match('/^[0-9A-F]{6}$/', $value)) {
            $value = 'FF' . $value;
        }

        if (!preg_match('/^[0-9A-F]{8}$/', $value)) {
            return $fallback;
        }

        return $value;
    }

    private static function normalize_home_ad_banner_link(string $url): string
    {
        $url = trim($url);
        if ('' === $url) {
            return '';
        }

        // Keep app-internal links as relative paths (e.g. /deals, /categories/3/products).
        if (0 === strpos($url, '/')) {
            return $url;
        }

        if (0 === strpos($url, '//')) {
            $url = 'https:' . $url;
        }

        if (0 === strpos($url, 'http://')) {
            $url = 'https://' . substr($url, 7);
        }

        if (0 === strpos($url, 'https://')) {
            return esc_url_raw($url);
        }

        return '';
    }

    /**
     * True when product has a valid sell price (> 0).
     */
    public static function has_display_price(WC_Product $product): bool
    {
        $prices = self::resolve_product_prices($product);
        $price = self::normalize_price_or_null($prices['price'] ?? null);
        if (null !== $price && $price > 0) {
            return true;
        }

        if ($product instanceof WC_Product_Variable) {
            $ranges = self::build_variable_price_ranges($product);
            return null !== $ranges['price_min'] && $ranges['price_min'] > 0;
        }

        return false;
    }

    /**
     * @param array<string, mixed> $section
     * @return array<int, array<string, mixed>>
     */
    public static function resolve_products_for_section(array $section, int $limit = 12, bool $exclude_unpriced = true): array
    {
        $limit = max(1, min(50, $limit));
        $section_id = (int) ($section['id'] ?? 0);
        $type = self::normalize_section_type((string) ($section['type'] ?? 'manual_products'));

        // 1. Always prioritize manual items if they exist for this section ID
        if ($section_id > 0) {
            $manual_items = self::get_home_section_items($section_id);
            if (!empty($manual_items)) {
                $ids = array_values(array_filter(array_map(function ($row) {
                    return isset($row['product_id']) ? (int) $row['product_id'] : 0;
                }, $manual_items)));

                if (!empty($ids)) {
                    // Manual selection found, use it and ignore dynamic logic
                    if (count($ids) > $limit) {
                        $ids = array_slice($ids, 0, $limit);
                    }

                    $products = self::get_products_by_ids($ids);
                    $result = array();
                    foreach ($ids as $id) {
                        if (!isset($products[$id])) {
                            continue;
                        }
                        if ($exclude_unpriced && !self::has_display_price($products[$id])) {
                            continue;
                        }
                        $result[] = self::format_product_for_api($products[$id]);
                    }
                    return $result;
                }
            }
        }

        // 2. Fall back to dynamic logic if no manual items defined
        if ('category' === $type) {
            $term_id = isset($section['term_id']) ? (int) $section['term_id'] : 0;
            if ($term_id <= 0) {
                return array();
            }

            $ids = self::get_manual_sorted_product_ids_for_category($term_id);
            if (empty($ids)) {
                return array();
            }

            $ids = array_slice($ids, 0, $limit);
            $products = self::get_products_by_ids($ids);
            $order_map = self::get_category_order_map($term_id);

            $result = array();
            foreach ($ids as $id) {
                if (!isset($products[$id])) {
                    continue;
                }
                if ($exclude_unpriced && !self::has_display_price($products[$id])) {
                    continue;
                }
                $result[] = self::format_product_for_api($products[$id], $term_id, $order_map);
            }
            return $result;
        }

        $query_args = array(
            'post_type' => 'product',
            'post_status' => 'publish',
            'posts_per_page' => $limit,
        );

        if ($exclude_unpriced) {
            $query_args['meta_query'] = array( // phpcs:ignore
                array(
                    'key' => '_price',
                    'value' => 0,
                    'compare' => '>',
                    'type' => 'NUMERIC',
                ),
            );
        }

        if ('newest' === $type) {
            $query_args['orderby'] = 'date';
            $query_args['order'] = 'DESC';
        } elseif ('top_rated' === $type) {
            $query_args['meta_key'] = '_wc_average_rating';
            $query_args['orderby'] = 'meta_value_num';
            $query_args['order'] = 'DESC';
        } elseif ('flash_deals' === $type) {
            $flash_ids = self::get_active_flash_deal_ids(false);
            if (empty($flash_ids)) {
                return array();
            }

            $query_args['post__in'] = $flash_ids;
            $query_args['orderby'] = 'date';
            $query_args['order'] = 'DESC';
        } elseif ('on_sale' === $type) {
            $sale_ids = wc_get_product_ids_on_sale();
            $sale_ids = array_values(array_filter(array_map('intval', is_array($sale_ids) ? $sale_ids : array())));
            if (empty($sale_ids)) {
                return array();
            }

            $query_args['post__in'] = $sale_ids;
            $query_args['orderby'] = 'date';
            $query_args['order'] = 'DESC';
        }

        $query = new WP_Query($query_args);
        if (!is_array($query->posts)) {
            return array();
        }

        $result = array();
        foreach ($query->posts as $post) {
            $product = wc_get_product((int) $post->ID);
            if (!$product instanceof WC_Product) {
                continue;
            }
            if ($exclude_unpriced && !self::has_display_price($product)) {
                continue;
            }
            $result[] = self::format_product_for_api($product);
        }

        return $result;
    }

    public static function product_summary(int $product_id): ?array
    {
        $product = wc_get_product($product_id);
        if (!$product instanceof WC_Product) {
            return null;
        }
        if ('publish' !== get_post_status($product_id)) {
            return null;
        }

        $image = array(
            'thumb' => null,
            'medium' => null,
            'large' => null,
        );
        $image_url = '';
        $thumb_id = $product->get_image_id();
        if ($thumb_id) {
            $image = self::build_image_size_payload((int) $thumb_id);
            $image_url = isset($image['medium']) && is_string($image['medium'])
                ? $image['medium']
                : (isset($image['thumb']) && is_string($image['thumb'])
                    ? $image['thumb']
                    : (isset($image['large']) && is_string($image['large']) ? $image['large'] : ''));
        }

        return array(
            'id' => (int) $product->get_id(),
            'name' => self::normalize_text($product->get_name()),
            'image' => $image,
            'image_url' => $image_url,
            'price' => (float) ((self::resolve_product_prices($product))['price'] ?? 0.0),
            'in_stock' => (bool) $product->is_in_stock(),
        );
    }

    /**
     * @return array<int, int>
     */
    public static function get_active_flash_deal_ids(bool $include_upcoming = false): array
    {
        $meta_query_args = array(
            'post_type' => 'product',
            'post_status' => 'publish',
            'posts_per_page' => -1,
            'fields' => 'ids',
            'meta_query' => array(
                array(
                    'key' => '_lexi_flash_deal_active',
                    'value' => 'yes',
                    'compare' => '=',
                ),
            ),
        );
        $meta_query = new WP_Query($meta_query_args);

        $sale_ids = wc_get_product_ids_on_sale();
        $sale_ids = array_values(array_filter(array_map('intval', is_array($sale_ids) ? $sale_ids : array())));

        $candidate_ids = array();
        if (is_array($meta_query->posts)) {
            $candidate_ids = array_merge($candidate_ids, array_map('intval', $meta_query->posts));
        }
        if (!empty($sale_ids)) {
            $candidate_ids = array_merge($candidate_ids, $sale_ids);
        }
        $candidate_ids = array_values(array_unique(array_filter(array_map('intval', $candidate_ids))));

        $now_ts = current_time('timestamp');
        $ids = array();

        if (empty($candidate_ids)) {
            return $ids;
        }

        foreach ($candidate_ids as $raw_id) {
            $product_id = (int) $raw_id;
            if ($product_id <= 0) {
                continue;
            }

            $product = wc_get_product($product_id);
            if ($product instanceof WC_Product_Variation) {
                $product_id = (int) $product->get_parent_id();
                $product = wc_get_product($product_id);
            }
            if (!$product instanceof WC_Product) {
                continue;
            }

            if (!self::is_flash_deal_valid_for_time($product, $now_ts, $include_upcoming)) {
                continue;
            }

            $ids[] = $product_id;
        }

        return array_values(array_unique(array_map('intval', $ids)));
    }

    /**
     * Get products with valid flash deals.
     *
     * @param bool $include_upcoming When true, include upcoming (not-yet-started) deals.
     * @return array<int, array<string, mixed>>
     */
    public static function get_flash_deals(bool $include_upcoming = true): array
    {
        $ids = self::get_active_flash_deal_ids($include_upcoming);
        if (empty($ids)) {
            return array();
        }

        $products = self::get_products_by_ids($ids);
        $result = array();
        foreach ($ids as $product_id) {
            if (!isset($products[$product_id])) {
                continue;
            }
            $result[] = self::format_product_for_api($products[$product_id]);
        }

        return $result;
    }

    /**
     * Flush public products list transients so merchandising changes appear
     * immediately in storefront listing endpoints.
     */
    public static function invalidate_products_list_cache(): void
    {
        global $wpdb;

        $prefixes = array(
            '_transient_lexi_products_list_v3_',
            '_transient_timeout_lexi_products_list_v3_',
        );

        foreach ($prefixes as $prefix) {
            // phpcs:ignore WordPress.DB.DirectDatabaseQuery.DirectQuery,WordPress.DB.DirectDatabaseQuery.NoCaching
            $wpdb->query(
                $wpdb->prepare(
                    "DELETE FROM {$wpdb->options} WHERE option_name LIKE %s",
                    $wpdb->esc_like($prefix) . '%'
                )
            );
        }
    }

    private static function is_flash_deal_valid_for_time(
        WC_Product $product,
        int $now_ts,
        bool $include_upcoming
    ): bool {
        $prices = self::resolve_product_prices($product);
        $sale_price = isset($prices['sale_price']) ? (float) $prices['sale_price'] : 0.0;
        if ($sale_price <= 0) {
            return false;
        }

        $from = $product->get_date_on_sale_from();
        $to = $product->get_date_on_sale_to();

        $from_ts = $from ? (int) $from->getTimestamp() : 0;
        $to_ts = $to ? (int) $to->getTimestamp() : 0;

        if ($to_ts > 0 && $to_ts < $now_ts) {
            return false;
        }

        if (!$include_upcoming && $from_ts > 0 && $from_ts > $now_ts) {
            return false;
        }

        return true;
    }
}
