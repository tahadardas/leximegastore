<?php
/**
 * Store intelligence data layer:
 * - Event tracking storage
 * - Purchase aggregation hooks
 * - Analytics query helpers
 * - Admin action helpers
 *
 * @package Lexi_API
 */

defined('ABSPATH') || exit;

class Lexi_Intel
{
    private const TABLE_EVENTS = 'lexi_events';
    private const TABLE_ORDER_ITEMS_AGG = 'lexi_order_items_agg';
    private const TABLE_OFFERS = 'lexi_offers';
    private const PURCHASE_META_KEY = '_lexi_purchase_event_recorded';
    private const RATE_LIMIT_PREFIX = 'lexi_evt_rl_';

    /**
     * Boot runtime hooks.
     */
    public static function init(): void
    {
        add_action('woocommerce_payment_complete', array(__CLASS__, 'capture_purchase_event'));
        add_action('woocommerce_order_status_processing', array(__CLASS__, 'capture_purchase_event'));
        add_action('woocommerce_order_status_completed', array(__CLASS__, 'capture_purchase_event'));
    }

    /**
     * Create/upgrade intelligence tables.
     */
    public static function create_tables(): void
    {
        global $wpdb;

        require_once ABSPATH . 'wp-admin/includes/upgrade.php';

        $charset = $wpdb->get_charset_collate();
        $events = self::events_table();
        $order_items = self::order_items_agg_table();
        $offers = self::offers_table();

        $sql_events = "CREATE TABLE {$events} (
            id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
            event_type VARCHAR(32) NOT NULL,
            product_id BIGINT UNSIGNED NULL,
            category_id BIGINT UNSIGNED NULL,
            query_text VARCHAR(120) NULL,
            value_num DOUBLE NULL,
            user_id BIGINT UNSIGNED NULL,
            device_id VARCHAR(64) NULL,
            session_id VARCHAR(64) NULL,
            city VARCHAR(64) NULL,
            created_at DATETIME NOT NULL,
            PRIMARY KEY (id),
            KEY idx_event_type_created (event_type, created_at),
            KEY idx_product_created (product_id, created_at),
            KEY idx_category_created (category_id, created_at),
            KEY idx_query_text (query_text),
            KEY idx_user_id (user_id),
            KEY idx_device_id (device_id),
            KEY idx_session_id (session_id)
        ) {$charset};";

        $sql_order_items = "CREATE TABLE {$order_items} (
            id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
            order_id BIGINT UNSIGNED NOT NULL,
            product_id BIGINT UNSIGNED NOT NULL,
            qty INT NOT NULL DEFAULT 0,
            line_total DOUBLE NOT NULL DEFAULT 0,
            created_at DATETIME NOT NULL,
            PRIMARY KEY (id),
            KEY idx_product_created (product_id, created_at),
            KEY idx_order_id (order_id)
        ) {$charset};";

        $sql_offers = "CREATE TABLE {$offers} (
            id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
            title_ar VARCHAR(180) NOT NULL,
            start_at DATETIME NULL,
            end_at DATETIME NULL,
            type VARCHAR(20) NOT NULL DEFAULT 'flash',
            product_ids_json LONGTEXT NULL,
            is_active TINYINT(1) NOT NULL DEFAULT 0,
            created_by BIGINT UNSIGNED NULL,
            created_at DATETIME NOT NULL,
            updated_at DATETIME NOT NULL,
            PRIMARY KEY (id),
            KEY idx_is_active (is_active),
            KEY idx_type (type),
            KEY idx_created_at (created_at)
        ) {$charset};";

        dbDelta($sql_events);
        dbDelta($sql_order_items);
        dbDelta($sql_offers);
    }

    public static function events_table(): string
    {
        global $wpdb;
        return $wpdb->prefix . self::TABLE_EVENTS;
    }

    public static function order_items_agg_table(): string
    {
        global $wpdb;
        return $wpdb->prefix . self::TABLE_ORDER_ITEMS_AGG;
    }

    public static function offers_table(): string
    {
        global $wpdb;
        return $wpdb->prefix . self::TABLE_OFFERS;
    }

    /**
     * Dedicated permission callback for admin intelligence endpoints.
     * Always returns 403 on failure with required Arabic message.
     */
    public static function admin_intel_access()
    {
        if (!is_user_logged_in()) {
            return new WP_Error(
                'rest_forbidden',
                'غير مصرح لك بالوصول',
                array('status' => 403)
            );
        }

        $user = wp_get_current_user();
        $roles = is_array($user->roles) ? $user->roles : array();

        $allowed = current_user_can('manage_woocommerce')
            || in_array('administrator', $roles, true)
            || in_array('shop_manager', $roles, true);

        if ($allowed) {
            return true;
        }

        return new WP_Error(
            'rest_forbidden',
            'غير مصرح لك بالوصول',
            array('status' => 403)
        );
    }

    /**
     * Public event ingest endpoint.
     */
    public static function track_public_event(WP_REST_Request $request): WP_REST_Response
    {
        $body = (array) $request->get_json_params();
        if (empty($body)) {
            $body = (array) $request->get_body_params();
        }

        $event_type = self::sanitize_event_type((string) ($body['event_type'] ?? ''));
        if (!in_array($event_type, self::public_event_types(), true)) {
            return Lexi_Security::error('invalid_event_type', 'نوع الحدث غير صالح.', 422);
        }

        $device_id = self::trimmed((string) ($body['device_id'] ?? ''), 64);
        $session_id = self::trimmed((string) ($body['session_id'] ?? ''), 64);

        if (!self::check_rate_limit($device_id)) {
            return Lexi_Security::error('rate_limited', 'تم تجاوز الحد المسموح حالياً.', 429);
        }

        $product_id = absint((int) ($body['product_id'] ?? 0));
        $category_id = absint((int) ($body['category_id'] ?? 0));
        $query_text = self::trimmed((string) ($body['query_text'] ?? ''), 120);
        $city = self::trimmed((string) ($body['city'] ?? ''), 64);
        $value_num = self::extract_value_num($event_type, $body);
        $user_id = get_current_user_id();

        $stored = self::insert_event(array(
            'event_type' => $event_type,
            'product_id' => $product_id > 0 ? $product_id : null,
            'category_id' => $category_id > 0 ? $category_id : null,
            'query_text' => '' !== $query_text ? $query_text : null,
            'value_num' => $value_num,
            'user_id' => $user_id > 0 ? (int) $user_id : null,
            'device_id' => '' !== $device_id ? $device_id : null,
            'session_id' => '' !== $session_id ? $session_id : null,
            'city' => '' !== $city ? $city : null,
        ));

        if (!$stored) {
            return Lexi_Security::error('track_failed', 'تعذر تسجيل الحدث حالياً.', 500);
        }

        return Lexi_Security::success(array('tracked' => true));
    }

    /**
     * Capture purchase event + order items aggregation without changing checkout flow.
     */
    public static function capture_purchase_event($order_id): void
    {
        $order_id = absint((int) $order_id);
        if ($order_id <= 0) {
            return;
        }

        $order = wc_get_order($order_id);
        if (!$order instanceof WC_Order) {
            return;
        }

        if (self::bool_meta($order->get_meta(self::PURCHASE_META_KEY, true))) {
            return;
        }

        $is_paid = $order->is_paid() || in_array($order->get_status(), array('processing', 'completed'), true);
        if (!$is_paid) {
            return;
        }

        global $wpdb;
        $table_items = self::order_items_agg_table();
        $now = self::now();

        $wpdb->query($wpdb->prepare("DELETE FROM {$table_items} WHERE order_id = %d", $order_id));

        // Order-level purchase event (used for revenue + AOV + purchase count).
        self::insert_event(array(
            'event_type' => 'purchase',
            'product_id' => null,
            'category_id' => null,
            'query_text' => null,
            'value_num' => (float) $order->get_total(),
            'user_id' => ($order->get_user_id() > 0) ? (int) $order->get_user_id() : null,
            'device_id' => null,
            'session_id' => null,
            'city' => self::trimmed((string) $order->get_billing_city(), 64),
        ));

        foreach ($order->get_items() as $item) {
            if (!$item instanceof WC_Order_Item_Product) {
                continue;
            }

            $product_id = (int) $item->get_product_id();
            if ($product_id <= 0) {
                continue;
            }

            $qty = max(1, (int) $item->get_quantity());
            $line_total = (float) $item->get_total();

            $wpdb->insert(
                $table_items,
                array(
                    'order_id' => $order_id,
                    'product_id' => $product_id,
                    'qty' => $qty,
                    'line_total' => $line_total,
                    'created_at' => $now,
                ),
                array('%d', '%d', '%d', '%f', '%s')
            );

            // Product-level purchase event (used for product intelligence scoring).
            self::insert_event(array(
                'event_type' => 'purchase',
                'product_id' => $product_id,
                'category_id' => self::resolve_primary_category_id($product_id),
                'query_text' => null,
                'value_num' => $line_total,
                'user_id' => ($order->get_user_id() > 0) ? (int) $order->get_user_id() : null,
                'device_id' => null,
                'session_id' => null,
                'city' => self::trimmed((string) $order->get_billing_city(), 64),
            ));
        }

        $order->update_meta_data(self::PURCHASE_META_KEY, '1');
        $order->save();
    }

    /**
     * Overview KPI metrics.
     *
     * @return array<string, mixed>
     */
    public static function get_overview(string $range): array
    {
        global $wpdb;
        list($start, $end) = self::resolve_range($range, array('today', '7d', '30d'), 'today');
        $table = self::events_table();

        $sessions = (int) $wpdb->get_var($wpdb->prepare(
            "SELECT COUNT(DISTINCT CASE
                WHEN session_id IS NOT NULL AND session_id <> '' THEN CONCAT('s:', session_id)
                WHEN device_id IS NOT NULL AND device_id <> '' THEN CONCAT('d:', device_id)
                ELSE NULL
            END)
            FROM {$table}
            WHERE created_at BETWEEN %s AND %s",
            $start,
            $end
        ));

        $rows = $wpdb->get_row($wpdb->prepare(
            "SELECT
                SUM(CASE WHEN event_type = 'view_product' THEN 1 ELSE 0 END) AS product_views,
                SUM(CASE WHEN event_type = 'add_to_cart' THEN 1 ELSE 0 END) AS add_to_cart,
                SUM(CASE WHEN event_type = 'checkout_start' THEN 1 ELSE 0 END) AS checkout_start,
                SUM(CASE WHEN event_type = 'purchase' AND product_id IS NULL THEN 1 ELSE 0 END) AS purchases,
                SUM(CASE WHEN event_type = 'purchase' AND product_id IS NULL THEN COALESCE(value_num, 0) ELSE 0 END) AS revenue
            FROM {$table}
            WHERE created_at BETWEEN %s AND %s",
            $start,
            $end
        ), ARRAY_A);

        $product_views = (int) ($rows['product_views'] ?? 0);
        $add_to_cart = (int) ($rows['add_to_cart'] ?? 0);
        $checkout_start = (int) ($rows['checkout_start'] ?? 0);
        $purchases = (int) ($rows['purchases'] ?? 0);
        $revenue = (float) ($rows['revenue'] ?? 0);

        return array(
            'sessions' => $sessions,
            'product_views' => $product_views,
            'add_to_cart' => $add_to_cart,
            'checkout_start' => $checkout_start,
            'purchases' => $purchases,
            'revenue' => round($revenue, 2),
            'conversion_rate' => self::safe_rate($purchases, $sessions),
            'add_to_cart_rate' => self::safe_rate($add_to_cart, $sessions),
            'checkout_rate' => self::safe_rate($checkout_start, $add_to_cart),
            'avg_order_value' => ($purchases > 0) ? round($revenue / $purchases, 2) : 0.0,
        );
    }

    /**
     * Trending products with weighted score.
     *
     * @return array<int, array<string, mixed>>
     */
    public static function get_trending_products(string $range, int $limit = 20): array
    {
        global $wpdb;
        list($start, $end) = self::resolve_range($range, array('24h', '7d'), '24h');
        $limit = self::normalize_limit($limit, 20, 100);
        $table = self::events_table();

        $rows = $wpdb->get_results($wpdb->prepare(
            "SELECT
                product_id,
                SUM(CASE WHEN event_type = 'view_product' THEN 1 ELSE 0 END) AS views,
                SUM(CASE WHEN event_type = 'add_to_cart' THEN 1 ELSE 0 END) AS add_to_cart,
                SUM(CASE WHEN event_type = 'add_wishlist' THEN 1 ELSE 0 END) AS wishlist_add,
                SUM(CASE WHEN event_type = 'purchase' THEN 1 ELSE 0 END) AS purchases
            FROM {$table}
            WHERE product_id IS NOT NULL
              AND event_type IN ('view_product','add_to_cart','add_wishlist','purchase')
              AND created_at BETWEEN %s AND %s
            GROUP BY product_id
            ORDER BY views DESC
            LIMIT %d",
            $start,
            $end,
            $limit * 3
        ), ARRAY_A);

        if (!is_array($rows)) {
            return array();
        }

        $items = array();
        foreach ($rows as $row) {
            $product_id = (int) ($row['product_id'] ?? 0);
            if ($product_id <= 0) {
                continue;
            }

            $summary = Lexi_Merch::product_summary($product_id);
            if (!is_array($summary)) {
                continue;
            }

            $views = (int) ($row['views'] ?? 0);
            $add_to_cart = (int) ($row['add_to_cart'] ?? 0);
            $wishlist_add = (int) ($row['wishlist_add'] ?? 0);
            $purchases = (int) ($row['purchases'] ?? 0);
            $score = ($views * 1) + ($add_to_cart * 5) + ($wishlist_add * 3) + ($purchases * 10);

            $items[] = array(
                'product_id' => $product_id,
                'name' => (string) ($summary['name'] ?? ''),
                'image' => (string) ($summary['image_url'] ?? ''),
                'price' => (float) ($summary['price'] ?? 0),
                'views' => $views,
                'add_to_cart' => $add_to_cart,
                'wishlist_add' => $wishlist_add,
                'purchases' => $purchases,
                'score' => (int) $score,
            );
        }

        usort($items, function ($a, $b) {
            $cmp = ((int) ($b['score'] ?? 0)) <=> ((int) ($a['score'] ?? 0));
            if (0 !== $cmp) {
                return $cmp;
            }
            return ((int) ($b['views'] ?? 0)) <=> ((int) ($a['views'] ?? 0));
        });

        return array_slice($items, 0, $limit);
    }

    /**
     * High views / low conversion opportunities.
     *
     * @return array<int, array<string, mixed>>
     */
    public static function get_opportunities(string $range, int $limit = 30): array
    {
        global $wpdb;
        list($start, $end) = self::resolve_range($range, array('7d', '30d'), '7d');
        $limit = self::normalize_limit($limit, 30, 100);
        $table = self::events_table();

        $rows = $wpdb->get_results($wpdb->prepare(
            "SELECT
                product_id,
                SUM(CASE WHEN event_type = 'view_product' THEN 1 ELSE 0 END) AS views,
                SUM(CASE WHEN event_type = 'add_to_cart' THEN 1 ELSE 0 END) AS add_to_cart,
                SUM(CASE WHEN event_type = 'purchase' THEN 1 ELSE 0 END) AS purchases
            FROM {$table}
            WHERE product_id IS NOT NULL
              AND event_type IN ('view_product','add_to_cart','purchase')
              AND created_at BETWEEN %s AND %s
            GROUP BY product_id
            HAVING views >= %d
            ORDER BY views DESC
            LIMIT %d",
            $start,
            $end,
            100,
            $limit * 4
        ), ARRAY_A);

        if (!is_array($rows)) {
            return array();
        }

        $items = array();
        foreach ($rows as $row) {
            $product_id = (int) ($row['product_id'] ?? 0);
            if ($product_id <= 0) {
                continue;
            }

            $views = (int) ($row['views'] ?? 0);
            $add_to_cart = (int) ($row['add_to_cart'] ?? 0);
            $purchases = (int) ($row['purchases'] ?? 0);
            $conversion_rate = self::safe_rate($purchases, $views);

            if ($conversion_rate > 0.03) {
                continue;
            }

            $summary = Lexi_Merch::product_summary($product_id);
            if (!is_array($summary)) {
                continue;
            }

            $items[] = array(
                'product_id' => $product_id,
                'name' => (string) ($summary['name'] ?? ''),
                'image' => (string) ($summary['image_url'] ?? ''),
                'price' => (float) ($summary['price'] ?? 0),
                'views' => $views,
                'add_to_cart' => $add_to_cart,
                'purchases' => $purchases,
                'conversion_rate' => $conversion_rate,
                'suggested_action_ar' => self::suggest_action_ar($views, $add_to_cart, $purchases),
            );
        }

        usort($items, function ($a, $b) {
            $a_conv = (float) ($a['conversion_rate'] ?? 0);
            $b_conv = (float) ($b['conversion_rate'] ?? 0);
            if ($a_conv === $b_conv) {
                return ((int) ($b['views'] ?? 0)) <=> ((int) ($a['views'] ?? 0));
            }
            return $a_conv <=> $b_conv;
        });

        return array_slice($items, 0, $limit);
    }

    /**
     * Wishlist leaders.
     *
     * @return array<int, array<string, mixed>>
     */
    public static function get_wishlist_top(string $range, int $limit = 30): array
    {
        global $wpdb;
        list($start, $end) = self::resolve_range($range, array('7d', '30d'), '7d');
        $limit = self::normalize_limit($limit, 30, 100);
        $table = self::events_table();

        $rows = $wpdb->get_results($wpdb->prepare(
            "SELECT
                product_id,
                SUM(CASE WHEN event_type = 'add_wishlist' THEN 1 WHEN event_type = 'remove_wishlist' THEN -1 ELSE 0 END) AS favorites_count
            FROM {$table}
            WHERE product_id IS NOT NULL
              AND event_type IN ('add_wishlist','remove_wishlist')
              AND created_at BETWEEN %s AND %s
            GROUP BY product_id
            HAVING favorites_count > 0
            ORDER BY favorites_count DESC
            LIMIT %d",
            $start,
            $end,
            $limit
        ), ARRAY_A);

        if (!is_array($rows)) {
            return array();
        }

        $items = array();
        foreach ($rows as $row) {
            $product_id = (int) ($row['product_id'] ?? 0);
            if ($product_id <= 0) {
                continue;
            }
            $summary = Lexi_Merch::product_summary($product_id);
            if (!is_array($summary)) {
                continue;
            }

            $items[] = array(
                'product_id' => $product_id,
                'name' => (string) ($summary['name'] ?? ''),
                'image' => (string) ($summary['image_url'] ?? ''),
                'price' => (float) ($summary['price'] ?? 0),
                'favorites_count' => (int) ($row['favorites_count'] ?? 0),
            );
        }

        return $items;
    }

    /**
     * Search intelligence.
     *
     * @return array<string, array<int, array<string, mixed>>>
     */
    public static function get_search_intelligence(string $range, int $limit = 50): array
    {
        global $wpdb;
        list($start, $end) = self::resolve_range($range, array('7d', '30d'), '7d');
        $limit = self::normalize_limit($limit, 50, 200);
        $table = self::events_table();

        $rows = $wpdb->get_results($wpdb->prepare(
            "SELECT
                query_text,
                COUNT(*) AS searches,
                SUM(CASE WHEN COALESCE(value_num, -1) = 0 THEN 1 ELSE 0 END) AS zero_results
            FROM {$table}
            WHERE event_type = 'search'
              AND query_text IS NOT NULL
              AND query_text <> ''
              AND created_at BETWEEN %s AND %s
            GROUP BY query_text
            ORDER BY searches DESC
            LIMIT %d",
            $start,
            $end,
            $limit
        ), ARRAY_A);

        if (!is_array($rows)) {
            return array(
                'top_queries' => array(),
                'zero_result_queries' => array(),
            );
        }

        $top = array();
        $zero = array();
        foreach ($rows as $row) {
            $item = array(
                'query' => (string) ($row['query_text'] ?? ''),
                'searches' => (int) ($row['searches'] ?? 0),
                'zero_results' => (int) ($row['zero_results'] ?? 0),
            );
            $top[] = $item;
            if ($item['zero_results'] > 0) {
                $zero[] = $item;
            }
        }

        usort($zero, function ($a, $b) {
            $cmp = ((int) ($b['zero_results'] ?? 0)) <=> ((int) ($a['zero_results'] ?? 0));
            if (0 !== $cmp) {
                return $cmp;
            }
            return ((int) ($b['searches'] ?? 0)) <=> ((int) ($a['searches'] ?? 0));
        });

        return array(
            'top_queries' => $top,
            'zero_result_queries' => array_slice($zero, 0, min(30, count($zero))),
        );
    }

    /**
     * Frequently bought together bundles.
     *
     * @return array<string, mixed>
     */
    public static function get_bundles(string $range, int $product_id, int $limit = 10): array
    {
        global $wpdb;

        $product_id = absint($product_id);
        $limit = self::normalize_limit($limit, 10, 50);
        list($start, $end) = self::resolve_range($range, array('30d', '7d'), '30d');

        if ($product_id <= 0) {
            return array(
                'product_id' => 0,
                'product_name' => '',
                'with_products' => array(),
            );
        }

        $base_summary = Lexi_Merch::product_summary($product_id);
        $table = self::order_items_agg_table();

        $rows = $wpdb->get_results($wpdb->prepare(
            "SELECT
                oi2.product_id AS with_product_id,
                SUM(LEAST(oi1.qty, oi2.qty)) AS together_count
            FROM {$table} oi1
            INNER JOIN {$table} oi2 ON oi1.order_id = oi2.order_id AND oi2.product_id <> oi1.product_id
            WHERE oi1.product_id = %d
              AND oi1.created_at BETWEEN %s AND %s
            GROUP BY oi2.product_id
            ORDER BY together_count DESC
            LIMIT %d",
            $product_id,
            $start,
            $end,
            $limit
        ), ARRAY_A);

        $with_products = array();
        if (is_array($rows)) {
            foreach ($rows as $row) {
                $with_id = (int) ($row['with_product_id'] ?? 0);
                if ($with_id <= 0) {
                    continue;
                }
                $summary = Lexi_Merch::product_summary($with_id);
                if (!is_array($summary)) {
                    continue;
                }
                $with_products[] = array(
                    'id' => $with_id,
                    'name' => (string) ($summary['name'] ?? ''),
                    'image' => (string) ($summary['image_url'] ?? ''),
                    'count' => (int) ($row['together_count'] ?? 0),
                );
            }
        }

        return array(
            'product_id' => $product_id,
            'product_name' => is_array($base_summary) ? (string) ($base_summary['name'] ?? '') : '',
            'with_products' => $with_products,
        );
    }

    /**
     * Stock alerts and risk flags.
     *
     * @return array<string, array<int, array<string, mixed>>>
     */
    public static function get_stock_alerts(): array
    {
        $low_default = (int) get_option('woocommerce_notify_low_stock_amount', 2);
        if ($low_default <= 0) {
            $low_default = 2;
        }

        $out_ids = wc_get_products(array(
            'status' => 'publish',
            'stock_status' => 'outofstock',
            'limit' => 200,
            'return' => 'ids',
        ));

        $out_of_stock = self::map_product_ids_to_alert_items($out_ids);

        $managed_ids = wc_get_products(array(
            'status' => 'publish',
            'stock_status' => 'instock',
            'limit' => 500,
            'return' => 'ids',
        ));

        $low_stock = array();
        if (is_array($managed_ids)) {
            foreach ($managed_ids as $id_raw) {
                $id = absint((int) $id_raw);
                if ($id <= 0) {
                    continue;
                }
                $product = wc_get_product($id);
                if (!$product instanceof WC_Product) {
                    continue;
                }
                if (!$product->managing_stock()) {
                    continue;
                }
                $qty = (int) $product->get_stock_quantity();
                $threshold = (int) $product->get_low_stock_amount();
                if ($threshold <= 0) {
                    $threshold = $low_default;
                }
                if ($qty > $threshold) {
                    continue;
                }
                $summary = Lexi_Merch::product_summary($id);
                if (!is_array($summary)) {
                    continue;
                }
                $low_stock[] = array(
                    'product_id' => $id,
                    'name' => (string) ($summary['name'] ?? ''),
                    'image' => (string) ($summary['image_url'] ?? ''),
                    'price' => (float) ($summary['price'] ?? 0),
                    'stock_qty' => $qty,
                    'low_stock_threshold' => $threshold,
                );
            }
        }

        $high_demand_low_stock = self::attach_high_demand_view_counts($low_stock);

        return array(
            'out_of_stock' => $out_of_stock,
            'low_stock' => $low_stock,
            'high_demand_low_stock' => $high_demand_low_stock,
        );
    }

    /**
     * Create draft offer from suggested actions.
     *
     * @param array<string, mixed> $body
     * @return array<string, mixed>
     */
    public static function create_offer_draft(array $body): array
    {
        global $wpdb;

        $title_ar = self::trimmed((string) ($body['title_ar'] ?? ''), 180);
        $type = strtolower(trim((string) ($body['type'] ?? 'flash')));
        $allowed_types = array('flash', 'seasonal', 'manual');
        if (!in_array($type, $allowed_types, true)) {
            $type = 'flash';
        }

        $product_ids = self::normalize_int_list($body['product_ids'] ?? array());
        if ('' === $title_ar || empty($product_ids)) {
            return array(
                'ok' => false,
                'error' => 'بيانات العرض غير مكتملة.',
            );
        }

        $start_at = self::normalize_datetime((string) ($body['start_at'] ?? ''));
        $end_at = self::normalize_datetime((string) ($body['end_at'] ?? ''));
        $now = self::now();

        $table = self::offers_table();
        $inserted = $wpdb->insert(
            $table,
            array(
                'title_ar' => $title_ar,
                'start_at' => $start_at,
                'end_at' => $end_at,
                'type' => $type,
                'product_ids_json' => wp_json_encode($product_ids),
                'is_active' => 0,
                'created_by' => get_current_user_id() > 0 ? (int) get_current_user_id() : null,
                'created_at' => $now,
                'updated_at' => $now,
            ),
            array('%s', '%s', '%s', '%s', '%s', '%d', '%d', '%s', '%s')
        );

        if (!$inserted) {
            return array(
                'ok' => false,
                'error' => 'تعذر إنشاء مسودة العرض حالياً.',
            );
        }

        return array(
            'ok' => true,
            'offer_id' => (int) $wpdb->insert_id,
            'is_active' => 0,
        );
    }

    /**
     * Pin product into a home section.
     *
     * @param int    $product_id Product ID.
     * @param string $section    trending|best_seller|flash_deals
     * @return array<string, mixed>
     */
    public static function pin_product_home(int $product_id, string $section): array
    {
        global $wpdb;

        $product_id = absint($product_id);
        if ($product_id <= 0) {
            return array('ok' => false, 'error' => 'المنتج غير صالح.');
        }

        $product = wc_get_product($product_id);
        if (!$product instanceof WC_Product || 'publish' !== get_post_status($product_id)) {
            return array('ok' => false, 'error' => 'المنتج غير موجود.');
        }

        $section = strtolower(trim($section));
        $mapping = array(
            'trending' => 'المنتجات الرائجة',
            'best_seller' => 'الأكثر مبيعًا',
            'flash_deals' => 'عروض البرق',
        );
        if (!isset($mapping[$section])) {
            return array('ok' => false, 'error' => 'القسم المطلوب غير صالح.');
        }

        $title_ar = $mapping[$section];
        $sections_table = Lexi_Merch::home_sections_table();
        $items_table = Lexi_Merch::home_section_items_table();
        $now = Lexi_Merch::now();

        $section_id = (int) $wpdb->get_var($wpdb->prepare(
            "SELECT id FROM {$sections_table}
             WHERE title_ar = %s
             ORDER BY sort_order ASC, id ASC
             LIMIT 1",
            $title_ar
        ));

        if ($section_id <= 0) {
            $max_sort = (int) $wpdb->get_var("SELECT COALESCE(MAX(sort_order), 0) FROM {$sections_table}");
            $created = $wpdb->insert(
                $sections_table,
                array(
                    'title_ar' => $title_ar,
                    'type' => 'manual_products',
                    'term_id' => null,
                    'sort_order' => $max_sort + 1,
                    'is_active' => 1,
                    'created_at' => $now,
                    'updated_at' => $now,
                ),
                array('%s', '%s', '%d', '%d', '%d', '%s', '%s')
            );
            if (!$created) {
                return array('ok' => false, 'error' => 'تعذر إنشاء قسم الصفحة الرئيسية.');
            }
            $section_id = (int) $wpdb->insert_id;
        }

        // Keep new pin at top.
        $wpdb->query($wpdb->prepare(
            "UPDATE {$items_table}
             SET sort_order = sort_order + 1, updated_at = %s
             WHERE section_id = %d AND product_id <> %d",
            $now,
            $section_id,
            $product_id
        ));

        $saved = $wpdb->replace(
            $items_table,
            array(
                'section_id' => $section_id,
                'product_id' => $product_id,
                'sort_order' => 1,
                'pinned' => 1,
                'created_at' => $now,
                'updated_at' => $now,
            ),
            array('%d', '%d', '%d', '%d', '%s', '%s')
        );

        if (!$saved) {
            return array('ok' => false, 'error' => 'تعذر تثبيت المنتج حالياً.');
        }

        return array(
            'ok' => true,
            'section' => $section,
            'section_id' => $section_id,
            'product_id' => $product_id,
        );
    }

    /* ---------------------------------------------------------------------
     * Internal helpers
     * -------------------------------------------------------------------*/

    /**
     * @return array<int, string>
     */
    private static function public_event_types(): array
    {
        return array(
            'view_product',
            'view_category',
            'search',
            'add_to_cart',
            'add_wishlist',
            'remove_wishlist',
            'checkout_start',
        );
    }

    private static function sanitize_event_type(string $event_type): string
    {
        $event_type = strtolower(trim($event_type));
        $event_type = preg_replace('/[^a-z_]/', '', $event_type);
        return is_string($event_type) ? $event_type : '';
    }

    private static function extract_value_num(string $event_type, array $body): ?float
    {
        if ('search' === $event_type && array_key_exists('results_count', $body)) {
            return (float) max(0, (int) ($body['results_count'] ?? 0));
        }

        if (array_key_exists('value_num', $body)) {
            return (float) ($body['value_num'] ?? 0);
        }

        return null;
    }

    private static function insert_event(array $event): bool
    {
        global $wpdb;
        $table = self::events_table();
        $now = self::now();

        $inserted = $wpdb->insert(
            $table,
            array(
                'event_type' => (string) ($event['event_type'] ?? ''),
                'product_id' => $event['product_id'],
                'category_id' => $event['category_id'],
                'query_text' => $event['query_text'],
                'value_num' => $event['value_num'],
                'user_id' => $event['user_id'],
                'device_id' => $event['device_id'],
                'session_id' => $event['session_id'],
                'city' => $event['city'],
                'created_at' => $now,
            ),
            array('%s', '%d', '%d', '%s', '%f', '%d', '%s', '%s', '%s', '%s')
        );

        return (bool) $inserted;
    }

    private static function check_rate_limit(string $device_id): bool
    {
        $source = '' !== $device_id ? $device_id : self::client_ip();
        if ('' === $source) {
            return true;
        }

        $key = self::RATE_LIMIT_PREFIX . md5($source);
        $count = (int) get_transient($key);
        if ($count >= 60) {
            return false;
        }
        set_transient($key, $count + 1, MINUTE_IN_SECONDS);
        return true;
    }

    private static function client_ip(): string
    {
        $ip = '';
        if (isset($_SERVER['HTTP_X_FORWARDED_FOR'])) {
            $parts = explode(',', (string) $_SERVER['HTTP_X_FORWARDED_FOR']);
            $ip = trim((string) ($parts[0] ?? ''));
        } elseif (isset($_SERVER['REMOTE_ADDR'])) {
            $ip = trim((string) $_SERVER['REMOTE_ADDR']);
        }

        return self::trimmed($ip, 64);
    }

    private static function bool_meta($value): bool
    {
        if (is_bool($value)) {
            return $value;
        }
        if (is_numeric($value)) {
            return ((int) $value) > 0;
        }
        $value = strtolower(trim((string) $value));
        return in_array($value, array('1', 'true', 'yes', 'on'), true);
    }

    private static function resolve_primary_category_id(int $product_id): ?int
    {
        $terms = get_the_terms($product_id, 'product_cat');
        if (!$terms || is_wp_error($terms)) {
            return null;
        }
        $first = reset($terms);
        if (!$first || !isset($first->term_id)) {
            return null;
        }
        $term_id = (int) $first->term_id;
        return $term_id > 0 ? $term_id : null;
    }

    /**
     * @param string      $range
     * @param array<int, string> $allowed
     * @param string      $fallback
     * @return array{0:string,1:string}
     */
    private static function resolve_range(string $range, array $allowed, string $fallback): array
    {
        $range = strtolower(trim($range));
        if (!in_array($range, $allowed, true)) {
            $range = $fallback;
        }

        $now_ts = current_time('timestamp');
        $end = wp_date('Y-m-d H:i:s', $now_ts);

        if ('today' === $range) {
            $start = wp_date('Y-m-d 00:00:00', $now_ts);
            return array($start, $end);
        }

        if ('24h' === $range) {
            $start = wp_date('Y-m-d H:i:s', $now_ts - DAY_IN_SECONDS);
            return array($start, $end);
        }

        if ('30d' === $range) {
            $start = wp_date('Y-m-d H:i:s', $now_ts - (30 * DAY_IN_SECONDS));
            return array($start, $end);
        }

        // Default 7d.
        $start = wp_date('Y-m-d H:i:s', $now_ts - (7 * DAY_IN_SECONDS));
        return array($start, $end);
    }

    private static function normalize_limit(int $limit, int $default, int $max): int
    {
        if ($limit <= 0) {
            $limit = $default;
        }
        return min($max, max(1, $limit));
    }

    private static function safe_rate(int $numerator, int $denominator): float
    {
        if ($denominator <= 0) {
            return 0.0;
        }
        return round($numerator / $denominator, 4);
    }

    private static function suggest_action_ar(int $views, int $add_to_cart, int $purchases): string
    {
        if ($purchases <= 0 && $views >= 100) {
            return 'جرّب تخفيض 5–10% لمدة 48 ساعة';
        }

        $atc_rate = ($views > 0) ? ($add_to_cart / $views) : 0.0;
        if ($atc_rate < 0.07) {
            return 'أضف صور أو تحسين الوصف';
        }

        return 'ارفع المنتج إلى العروض الرئيسية';
    }

    /**
     * @param array<int, int|string> $ids
     * @return array<int, array<string, mixed>>
     */
    private static function map_product_ids_to_alert_items($ids): array
    {
        if (!is_array($ids)) {
            return array();
        }

        $items = array();
        foreach ($ids as $id_raw) {
            $id = absint((int) $id_raw);
            if ($id <= 0) {
                continue;
            }
            $summary = Lexi_Merch::product_summary($id);
            if (!is_array($summary)) {
                continue;
            }
            $product = wc_get_product($id);
            $items[] = array(
                'product_id' => $id,
                'name' => (string) ($summary['name'] ?? ''),
                'image' => (string) ($summary['image_url'] ?? ''),
                'price' => (float) ($summary['price'] ?? 0),
                'stock_qty' => ($product instanceof WC_Product) ? (int) $product->get_stock_quantity() : 0,
            );
        }

        return $items;
    }

    /**
     * @param array<int, array<string, mixed>> $low_stock
     * @return array<int, array<string, mixed>>
     */
    private static function attach_high_demand_view_counts(array $low_stock): array
    {
        global $wpdb;
        if (empty($low_stock)) {
            return array();
        }

        $ids = array();
        foreach ($low_stock as $item) {
            $ids[] = (int) ($item['product_id'] ?? 0);
        }
        $ids = array_values(array_filter(array_unique($ids)));
        if (empty($ids)) {
            return array();
        }

        $table = self::events_table();
        list($start, $end) = self::resolve_range('7d', array('7d'), '7d');
        $ids_sql = implode(',', array_map('intval', $ids));

        $rows = $wpdb->get_results($wpdb->prepare(
            "SELECT product_id, COUNT(*) AS views
             FROM {$table}
             WHERE event_type = 'view_product'
               AND created_at BETWEEN %s AND %s
               AND product_id IN ({$ids_sql})
             GROUP BY product_id",
            $start,
            $end
        ), ARRAY_A);

        $view_map = array();
        if (is_array($rows)) {
            foreach ($rows as $row) {
                $view_map[(int) ($row['product_id'] ?? 0)] = (int) ($row['views'] ?? 0);
            }
        }

        $out = array();
        foreach ($low_stock as $item) {
            $product_id = (int) ($item['product_id'] ?? 0);
            $views = (int) ($view_map[$product_id] ?? 0);
            if ($views < 50) {
                continue;
            }
            $item['views_7d'] = $views;
            $out[] = $item;
        }

        usort($out, function ($a, $b) {
            return ((int) ($b['views_7d'] ?? 0)) <=> ((int) ($a['views_7d'] ?? 0));
        });

        return $out;
    }

    /**
     * @param array<int, mixed>|mixed $list
     * @return array<int, int>
     */
    private static function normalize_int_list($list): array
    {
        if (!is_array($list)) {
            return array();
        }

        $result = array();
        foreach ($list as $value) {
            $id = absint((int) $value);
            if ($id > 0) {
                $result[] = $id;
            }
        }
        return array_values(array_unique($result));
    }

    private static function normalize_datetime(string $value): ?string
    {
        $value = trim($value);
        if ('' === $value) {
            return null;
        }
        $ts = strtotime($value);
        if (false === $ts) {
            return null;
        }
        return wp_date('Y-m-d H:i:s', $ts);
    }

    private static function trimmed(string $value, int $max): string
    {
        $value = sanitize_text_field($value);
        if (function_exists('mb_substr')) {
            return (string) mb_substr($value, 0, $max);
        }
        return (string) substr($value, 0, $max);
    }

    private static function now(): string
    {
        return (string) current_time('mysql');
    }
}

