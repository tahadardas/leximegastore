<?php
/**
 * AI Core - Database tables and core functions
 * 
 * Creates and manages:
 * - Raw events table
 * - Aggregated metrics tables
 * - Abandoned cart tracking
 * - Order items for co-occurrence
 */

if (!defined('ABSPATH')) {
    exit;
}

class Lexi_AI_Core
{

    const EVENTS_TABLE = 'lexi_ai_events';
    const PRODUCT_METRICS_TABLE = 'lexi_ai_product_metrics_daily';
    const SEARCH_METRICS_TABLE = 'lexi_ai_search_metrics_daily';
    const USER_SEGMENTS_TABLE = 'lexi_ai_user_segments';
    const CART_STATE_TABLE = 'lexi_ai_cart_state';
    const ORDER_ITEMS_TABLE = 'lexi_ai_order_items';

    const EVENT_TYPES = [
        'view_product',
        'view_category',
        'search',
        'add_to_cart',
        'remove_from_cart',
        'add_wishlist',
        'remove_wishlist',
        'checkout_start',
        'purchase'
    ];

    private static $instance = null;

    public static function instance()
    {
        if (self::$instance === null) {
            self::$instance = new self();
        }
        return self::$instance;
    }

    /**
     * Create all AI tables on plugin activation
     */
    public function create_tables()
    {
        global $wpdb;
        $charset_collate = $wpdb->get_charset_collate();

        // Raw events table
        $events_table = $wpdb->prefix . self::EVENTS_TABLE;
        $sql_events = "CREATE TABLE $events_table (
            id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
            actor_type ENUM('user','guest') NOT NULL DEFAULT 'guest',
            user_id BIGINT UNSIGNED NULL,
            device_id VARCHAR(64) NULL,
            session_id VARCHAR(64) NULL,
            city VARCHAR(64) NULL,
            event_type ENUM('view_product','view_category','search','add_to_cart','remove_from_cart','add_wishlist','remove_wishlist','checkout_start','purchase') NOT NULL,
            product_id BIGINT UNSIGNED NULL,
            category_id BIGINT UNSIGNED NULL,
            query_text VARCHAR(120) NULL,
            value_num DOUBLE NULL,
            meta_json LONGTEXT NULL,
            created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
            PRIMARY KEY (id),
            INDEX idx_event_created (event_type, created_at),
            INDEX idx_product_created (product_id, created_at),
            INDEX idx_category_created (category_id, created_at),
            INDEX idx_user_created (user_id, created_at),
            INDEX idx_device_created (device_id, created_at),
            INDEX idx_query (query_text)
        ) $charset_collate;";

        // Product metrics daily aggregation
        $product_metrics_table = $wpdb->prefix . self::PRODUCT_METRICS_TABLE;
        $sql_product_metrics = "CREATE TABLE $product_metrics_table (
            day DATE NOT NULL,
            product_id BIGINT UNSIGNED NOT NULL,
            views INT UNSIGNED NOT NULL DEFAULT 0,
            wishlist_add INT UNSIGNED NOT NULL DEFAULT 0,
            add_to_cart INT UNSIGNED NOT NULL DEFAULT 0,
            purchases INT UNSIGNED NOT NULL DEFAULT 0,
            revenue DOUBLE NOT NULL DEFAULT 0,
            score DOUBLE NOT NULL DEFAULT 0,
            PRIMARY KEY (day, product_id),
            INDEX idx_score (score DESC),
            INDEX idx_day (day)
        ) $charset_collate;";

        // Search metrics daily aggregation
        $search_metrics_table = $wpdb->prefix . self::SEARCH_METRICS_TABLE;
        $sql_search_metrics = "CREATE TABLE $search_metrics_table (
            day DATE NOT NULL,
            query_text VARCHAR(120) NOT NULL,
            searches INT UNSIGNED NOT NULL DEFAULT 0,
            zero_results INT UNSIGNED NOT NULL DEFAULT 0,
            PRIMARY KEY (day, query_text),
            INDEX idx_day (day),
            INDEX idx_searches (searches DESC)
        ) $charset_collate;";

        // User segments (anonymous-friendly)
        $user_segments_table = $wpdb->prefix . self::USER_SEGMENTS_TABLE;
        $sql_user_segments = "CREATE TABLE $user_segments_table (
            actor_key VARCHAR(80) NOT NULL,
            top_categories_json LONGTEXT NULL,
            last_active_at DATETIME NULL,
            updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
            PRIMARY KEY (actor_key),
            INDEX idx_last_active (last_active_at)
        ) $charset_collate;";

        // Abandoned cart tracking
        $cart_state_table = $wpdb->prefix . self::CART_STATE_TABLE;
        $sql_cart_state = "CREATE TABLE $cart_state_table (
            actor_key VARCHAR(80) NOT NULL,
            last_add_to_cart_at DATETIME NULL,
            last_checkout_start_at DATETIME NULL,
            last_purchase_at DATETIME NULL,
            cart_snapshot_json LONGTEXT NULL,
            updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
            PRIMARY KEY (actor_key)
        ) $charset_collate;";

        // Order items for co-occurrence (bundles)
        $order_items_table = $wpdb->prefix . self::ORDER_ITEMS_TABLE;
        $sql_order_items = "CREATE TABLE $order_items_table (
            id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
            order_id BIGINT UNSIGNED NOT NULL,
            product_id BIGINT UNSIGNED NOT NULL,
            qty INT UNSIGNED NOT NULL,
            line_total DOUBLE NOT NULL,
            created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
            PRIMARY KEY (id),
            INDEX idx_product_created (product_id, created_at),
            INDEX idx_order (order_id)
        ) $charset_collate;";

        require_once(ABSPATH . 'wp-admin/includes/upgrade.php');
        dbDelta($sql_events);
        dbDelta($sql_product_metrics);
        dbDelta($sql_search_metrics);
        dbDelta($sql_user_segments);
        dbDelta($sql_cart_state);
        dbDelta($sql_order_items);

        // Schedule cron jobs
        $this->schedule_cron_jobs();
    }

    /**
     * Schedule aggregation cron jobs
     */
    private function schedule_cron_jobs()
    {
        if (!wp_next_scheduled('lexi_ai_hourly_aggregation')) {
            wp_schedule_event(time(), 'hourly', 'lexi_ai_hourly_aggregation');
        }
        if (!wp_next_scheduled('lexi_ai_daily_aggregation')) {
            wp_schedule_event(time(), 'daily', 'lexi_ai_daily_aggregation');
        }
    }

    /**
     * Clear scheduled cron jobs
     */
    public function clear_cron_jobs()
    {
        wp_clear_scheduled_hook('lexi_ai_hourly_aggregation');
        wp_clear_scheduled_hook('lexi_ai_daily_aggregation');
    }

    /**
     * Track an event
     * 
     * @param array $data Event data
     * @return bool Success
     */
    public function track_event($data)
    {
        global $wpdb;

        // Validate event_type
        if (!in_array($data['event_type'] ?? '', self::EVENT_TYPES)) {
            return false;
        }

        // Determine actor
        $user_id = get_current_user_id();
        $device_id = sanitize_text_field($data['device_id'] ?? '');
        $session_id = sanitize_text_field($data['session_id'] ?? '');

        $actor_type = $user_id > 0 ? 'user' : 'guest';

        // Build insert data
        $insert_data = [
            'actor_type' => $actor_type,
            'user_id' => $user_id > 0 ? $user_id : null,
            'device_id' => $device_id ?: null,
            'session_id' => $session_id ?: null,
            'city' => sanitize_text_field($data['city'] ?? ''),
            'event_type' => $data['event_type'],
            'product_id' => absint($data['product_id'] ?? 0) ?: null,
            'category_id' => absint($data['category_id'] ?? 0) ?: null,
            'query_text' => $this->sanitize_query($data['query_text'] ?? ''),
            'value_num' => isset($data['value_num']) ? floatval($data['value_num']) : null,
            'meta_json' => isset($data['meta']) ? wp_json_encode($data['meta']) : null,
            'created_at' => current_time('mysql'),
        ];

        $result = $wpdb->insert(
            $wpdb->prefix . self::EVENTS_TABLE,
            $insert_data,
            ['%s', '%d', '%s', '%s', '%s', '%s', '%d', '%d', '%s', '%f', '%s', '%s']
        );

        if ($result === false) {
            return false;
        }

        // Update cart state for cart-related events
        $this->update_cart_state($data, $user_id, $device_id);

        // Update user segment
        $this->update_user_segment($data, $user_id, $device_id);

        return true;
    }

    /**
     * Sanitize query text
     */
    private function sanitize_query($query)
    {
        $query = sanitize_text_field($query);
        $query = mb_substr($query, 0, 120);
        return $query;
    }

    /**
     * Update cart state for abandoned cart tracking
     */
    private function update_cart_state($data, $user_id, $device_id)
    {
        global $wpdb;

        $actor_key = $user_id > 0 ? "user:{$user_id}" : "guest:{$device_id}";
        if (empty($actor_key) || strpos($actor_key, 'guest:') === 0 && empty($device_id)) {
            return;
        }

        $event_type = $data['event_type'];
        $table = $wpdb->prefix . self::CART_STATE_TABLE;
        $now = current_time('mysql');

        // Check if record exists
        $existing = $wpdb->get_row($wpdb->prepare(
            "SELECT * FROM $table WHERE actor_key = %s",
            $actor_key
        ));

        $update_data = ['updated_at' => $now];

        switch ($event_type) {
            case 'add_to_cart':
                $update_data['last_add_to_cart_at'] = $now;
                if (isset($data['meta']['cart'])) {
                    $update_data['cart_snapshot_json'] = wp_json_encode($data['meta']['cart']);
                }
                break;
            case 'checkout_start':
                $update_data['last_checkout_start_at'] = $now;
                break;
            case 'purchase':
                $update_data['last_purchase_at'] = $now;
                break;
        }

        if ($existing) {
            $wpdb->update($table, $update_data, ['actor_key' => $actor_key]);
        } else {
            $update_data['actor_key'] = $actor_key;
            $wpdb->insert($table, $update_data);
        }
    }

    /**
     * Update user segment
     */
    private function update_user_segment($data, $user_id, $device_id)
    {
        global $wpdb;

        $actor_key = $user_id > 0 ? "user:{$user_id}" : "guest:{$device_id}";
        if (empty($actor_key) || strpos($actor_key, 'guest:') === 0 && empty($device_id)) {
            return;
        }

        // Only update for category/product views
        if (!in_array($data['event_type'], ['view_product', 'view_category', 'add_to_cart', 'add_wishlist'])) {
            return;
        }

        $table = $wpdb->prefix . self::USER_SEGMENTS_TABLE;
        $now = current_time('mysql');

        // Get or create segment
        $existing = $wpdb->get_row($wpdb->prepare(
            "SELECT * FROM $table WHERE actor_key = %s",
            $actor_key
        ));

        $categories = [];
        if ($existing && $existing->top_categories_json) {
            $categories = json_decode($existing->top_categories_json, true) ?: [];
        }

        // Add category weight
        $category_id = $data['category_id'] ?? 0;
        if (!$category_id && $data['product_id'] ?? 0) {
            // Get product category
            $terms = wp_get_post_terms($data['product_id'], 'product_cat');
            if (!empty($terms)) {
                $category_id = $terms[0]->term_id;
            }
        }

        if ($category_id) {
            $weight = 1;
            if ($data['event_type'] === 'add_to_cart')
                $weight = 3;
            if ($data['event_type'] === 'add_wishlist')
                $weight = 2;

            if (!isset($categories[$category_id])) {
                $categories[$category_id] = 0;
            }
            $categories[$category_id] += $weight;
        }

        // Keep top 5 categories
        arsort($categories);
        $categories = array_slice($categories, 0, 5, true);

        $update_data = [
            'top_categories_json' => wp_json_encode($categories),
            'last_active_at' => $now,
            'updated_at' => $now,
        ];

        if ($existing) {
            $wpdb->update($table, $update_data, ['actor_key' => $actor_key]);
        } else {
            $update_data['actor_key'] = $actor_key;
            $wpdb->insert($table, $update_data);
        }
    }

    /**
     * Record purchase from WooCommerce order
     */
    public function record_purchase($order_id)
    {
        $order = wc_get_order($order_id);
        if (!$order) {
            return;
        }

        $user_id = $order->get_user_id();
        $items = $order->get_items();

        foreach ($items as $item) {
            $product_id = $item->get_product_id();
            $qty = $item->get_quantity();
            $line_total = $item->get_total();

            // Track event
            $this->track_event([
                'event_type' => 'purchase',
                'product_id' => $product_id,
                'value_num' => $line_total,
                'meta' => [
                    'order_id' => $order_id,
                    'qty' => $qty,
                ],
            ]);

            // Store in order items table
            $this->store_order_item($order_id, $product_id, $qty, $line_total);
        }

        // Update cart state
        $device_id = get_post_meta($order_id, '_lexi_device_id', true);
        $this->update_cart_state(['event_type' => 'purchase'], $user_id, $device_id);
    }

    /**
     * Store order item for co-occurrence analysis
     */
    private function store_order_item($order_id, $product_id, $qty, $line_total)
    {
        global $wpdb;

        $wpdb->insert(
            $wpdb->prefix . self::ORDER_ITEMS_TABLE,
            [
                'order_id' => $order_id,
                'product_id' => $product_id,
                'qty' => $qty,
                'line_total' => $line_total,
                'created_at' => current_time('mysql'),
            ],
            ['%d', '%d', '%d', '%f', '%s']
        );
    }

    /**
     * Hourly aggregation job
     */
    public function hourly_aggregation()
    {
        $this->aggregate_events_to_daily();
    }

    /**
     * Daily aggregation job
     */
    public function daily_aggregation()
    {
        $this->recompute_scores();
        $this->cleanup_old_events();
    }

    /**
     * Aggregate events into daily metrics
     */
    private function aggregate_events_to_daily()
    {
        global $wpdb;

        $today = current_time('Y-m-d');
        $yesterday = date('Y-m-d', strtotime('-1 day'));

        // Aggregate product metrics
        $events_table = $wpdb->prefix . self::EVENTS_TABLE;
        $metrics_table = $wpdb->prefix . self::PRODUCT_METRICS_TABLE;

        // Get counts for each product for today
        $product_metrics = $wpdb->get_results($wpdb->prepare(
            "SELECT 
                product_id,
                SUM(CASE WHEN event_type = 'view_product' THEN 1 ELSE 0 END) as views,
                SUM(CASE WHEN event_type = 'add_wishlist' THEN 1 ELSE 0 END) as wishlist_add,
                SUM(CASE WHEN event_type = 'add_to_cart' THEN 1 ELSE 0 END) as add_to_cart,
                SUM(CASE WHEN event_type = 'purchase' THEN 1 ELSE 0 END) as purchases,
                SUM(CASE WHEN event_type = 'purchase' THEN value_num ELSE 0 END) as revenue
            FROM $events_table 
            WHERE product_id IS NOT NULL 
            AND DATE(created_at) = %s
            GROUP BY product_id",
            $today
        ));

        foreach ($product_metrics as $m) {
            $score = $this->calculate_score($m->views, $m->wishlist_add, $m->add_to_cart, $m->purchases);

            // Upsert
            $existing = $wpdb->get_row($wpdb->prepare(
                "SELECT * FROM $metrics_table WHERE day = %s AND product_id = %d",
                $today,
                $m->product_id
            ));

            if ($existing) {
                $wpdb->update(
                    $metrics_table,
                    [
                        'views' => $existing->views + $m->views,
                        'wishlist_add' => $existing->wishlist_add + $m->wishlist_add,
                        'add_to_cart' => $existing->add_to_cart + $m->add_to_cart,
                        'purchases' => $existing->purchases + $m->purchases,
                        'revenue' => $existing->revenue + $m->revenue,
                        'score' => $existing->score + $score,
                    ],
                    ['day' => $today, 'product_id' => $m->product_id]
                );
            } else {
                $wpdb->insert(
                    $metrics_table,
                    [
                        'day' => $today,
                        'product_id' => $m->product_id,
                        'views' => $m->views,
                        'wishlist_add' => $m->wishlist_add,
                        'add_to_cart' => $m->add_to_cart,
                        'purchases' => $m->purchases,
                        'revenue' => $m->revenue,
                        'score' => $score,
                    ]
                );
            }
        }

        // Aggregate search metrics
        $search_table = $wpdb->prefix . self::SEARCH_METRICS_TABLE;

        $search_metrics = $wpdb->get_results($wpdb->prepare(
            "SELECT 
                query_text,
                COUNT(*) as searches,
                SUM(CASE WHEN meta_json LIKE '%zero_results%' OR meta_json LIKE '%\"results_count\":0%' THEN 1 ELSE 0 END) as zero_results
            FROM $events_table 
            WHERE event_type = 'search' 
            AND query_text IS NOT NULL
            AND DATE(created_at) = %s
            GROUP BY query_text",
            $today
        ));

        foreach ($search_metrics as $s) {
            $existing = $wpdb->get_row($wpdb->prepare(
                "SELECT * FROM $search_table WHERE day = %s AND query_text = %s",
                $today,
                $s->query_text
            ));

            if ($existing) {
                $wpdb->update(
                    $search_table,
                    [
                        'searches' => $existing->searches + $s->searches,
                        'zero_results' => $existing->zero_results + $s->zero_results,
                    ],
                    ['day' => $today, 'query_text' => $s->query_text]
                );
            } else {
                $wpdb->insert(
                    $search_table,
                    [
                        'day' => $today,
                        'query_text' => $s->query_text,
                        'searches' => $s->searches,
                        'zero_results' => $s->zero_results,
                    ]
                );
            }
        }
    }

    /**
     * Calculate product score
     */
    private function calculate_score($views, $wishlist_add, $add_to_cart, $purchases)
    {
        return ($views * 1) + ($wishlist_add * 3) + ($add_to_cart * 5) + ($purchases * 10);
    }

    /**
     * Recompute all scores (daily maintenance)
     */
    private function recompute_scores()
    {
        global $wpdb;

        $metrics_table = $wpdb->prefix . self::PRODUCT_METRICS_TABLE;

        // Recompute scores for all products
        $wpdb->query(
            "UPDATE $metrics_table 
            SET score = (views * 1) + (wishlist_add * 3) + (add_to_cart * 5) + (purchases * 10)"
        );
    }

    /**
     * Cleanup old events (keep 90 days)
     */
    private function cleanup_old_events()
    {
        global $wpdb;

        $events_table = $wpdb->prefix . self::EVENTS_TABLE;
        $cutoff = date('Y-m-d', strtotime('-90 days'));

        $wpdb->query($wpdb->prepare(
            "DELETE FROM $events_table WHERE DATE(created_at) < %s",
            $cutoff
        ));
    }

    /**
     * Get trending products
     */
    public function get_trending($range = '24h', $limit = 20)
    {
        global $wpdb;

        $metrics_table = $wpdb->prefix . self::PRODUCT_METRICS_TABLE;

        if ($range === '24h') {
            $days = [current_time('Y-m-d')];
        } else {
            $days = [];
            for ($i = 0; $i < 7; $i++) {
                $days[] = date('Y-m-d', strtotime("-$i days"));
            }
        }

        $days_str = "'" . implode("','", $days) . "'";

        $results = $wpdb->get_results($wpdb->prepare(
            "SELECT 
                product_id,
                SUM(views) as views,
                SUM(wishlist_add) as wishlist_add,
                SUM(add_to_cart) as add_to_cart,
                SUM(purchases) as purchases,
                SUM(revenue) as revenue,
                SUM(score) as score
            FROM $metrics_table
            WHERE day IN ($days_str)
            GROUP BY product_id
            ORDER BY score DESC
            LIMIT %d",
            $limit
        ));

        return $results;
    }

    /**
     * Get user's top categories
     */
    public function get_user_top_categories($user_id = 0, $device_id = '')
    {
        global $wpdb;

        $actor_key = $user_id > 0 ? "user:{$user_id}" : "guest:{$device_id}";

        $table = $wpdb->prefix . self::USER_SEGMENTS_TABLE;

        $segment = $wpdb->get_row($wpdb->prepare(
            "SELECT top_categories_json FROM $table WHERE actor_key = %s",
            $actor_key
        ));

        if (!$segment || !$segment->top_categories_json) {
            return [];
        }

        return json_decode($segment->top_categories_json, true) ?: [];
    }

    /**
     * Get frequently bought together products
     */
    public function get_bundles($product_id, $limit = 10)
    {
        global $wpdb;

        $order_items = $wpdb->prefix . self::ORDER_ITEMS_TABLE;

        // Find orders containing this product
        $orders = $wpdb->get_col($wpdb->prepare(
            "SELECT DISTINCT order_id FROM $order_items WHERE product_id = %d",
            $product_id
        ));

        if (empty($orders)) {
            return [];
        }

        $orders_str = implode(',', $orders);

        // Find other products in those orders
        $results = $wpdb->get_results($wpdb->prepare(
            "SELECT 
                product_id,
                COUNT(DISTINCT order_id) as co_occurrence
            FROM $order_items
            WHERE order_id IN ($orders_str)
            AND product_id != %d
            GROUP BY product_id
            ORDER BY co_occurrence DESC
            LIMIT %d",
            $product_id,
            $limit
        ));

        return $results;
    }

    /**
     * Get similar products (same category, similar price)
     */
    public function get_similar($product_id, $limit = 12)
    {
        $product = wc_get_product($product_id);
        if (!$product) {
            return [];
        }

        $price = $product->get_price();
        $min_price = $price * 0.8;
        $max_price = $price * 1.2;

        $terms = wp_get_post_terms($product_id, 'product_cat');
        if (empty($terms)) {
            return [];
        }

        $category_ids = array_map(function ($t) {
            return $t->term_id;
        }, $terms);

        $args = [
            'post_type' => 'product',
            'post_status' => 'publish',
            'posts_per_page' => $limit,
            'post__not_in' => [$product_id],
            'tax_query' => [
                [
                    'taxonomy' => 'product_cat',
                    'field' => 'term_id',
                    'terms' => $category_ids,
                ],
            ],
            'meta_query' => [
                [
                    'key' => '_price',
                    'value' => [$min_price, $max_price],
                    'compare' => 'BETWEEN',
                    'type' => 'NUMERIC',
                ],
            ],
        ];

        $query = new WP_Query($args);
        return $query->posts;
    }

    /**
     * Get opportunities (high views, low conversion)
     */
    public function get_opportunities($range = '7d', $limit = 30)
    {
        global $wpdb;

        $metrics_table = $wpdb->prefix . self::PRODUCT_METRICS_TABLE;

        $days = [];
        $days_count = $range === '7d' ? 7 : 30;
        for ($i = 0; $i < $days_count; $i++) {
            $days[] = date('Y-m-d', strtotime("-$i days"));
        }

        $days_str = "'" . implode("','", $days) . "'";

        $results = $wpdb->get_results($wpdb->prepare(
            "SELECT 
                product_id,
                SUM(views) as views,
                SUM(add_to_cart) as add_to_cart,
                SUM(purchases) as purchases,
                SUM(score) as score,
                CASE 
                    WHEN SUM(views) > 10 AND SUM(purchases) = 0 THEN 'high_views_no_sales'
                    WHEN SUM(views) > 50 AND SUM(add_to_cart) < 5 THEN 'low_cart_rate'
                    WHEN SUM(add_to_cart) > 10 AND SUM(purchases) < 3 THEN 'high_cart_low_purchase'
                    ELSE 'other'
                END as opportunity_type
            FROM $metrics_table
            WHERE day IN ($days_str)
            GROUP BY product_id
            HAVING views > 10 AND (purchases = 0 OR purchases / views < 0.05)
            ORDER BY views DESC
            LIMIT %d",
            $limit
        ));

        return $results;
    }

    /**
     * Get abandoned carts
     */
    public function get_abandoned_carts($hours = 6, $limit = 50)
    {
        global $wpdb;

        $table = $wpdb->prefix . self::CART_STATE_TABLE;
        $cutoff = date('Y-m-d H:i:s', strtotime("-{$hours} hours"));

        return $wpdb->get_results($wpdb->prepare(
            "SELECT * FROM $table
            WHERE last_add_to_cart_at IS NOT NULL
            AND last_add_to_cart_at < %s
            AND (last_purchase_at IS NULL OR last_purchase_at < last_add_to_cart_at)
            ORDER BY last_add_to_cart_at DESC
            LIMIT %d",
            $cutoff,
            $limit
        ));
    }

    /**
     * Get overview KPIs
     */
    public function get_overview($range = 'today')
    {
        global $wpdb;

        $events_table = $wpdb->prefix . self::EVENTS_TABLE;

        if ($range === 'today') {
            $where = "DATE(created_at) = '" . current_time('Y-m-d') . "'";
        } elseif ($range === '7d') {
            $where = "created_at >= '" . date('Y-m-d', strtotime('-7 days')) . "'";
        } else {
            $where = "created_at >= '" . date('Y-m-d', strtotime('-30 days')) . "'";
        }

        $stats = $wpdb->get_row(
            "SELECT 
                COUNT(DISTINCT session_id) as sessions,
                SUM(CASE WHEN event_type = 'view_product' THEN 1 ELSE 0 END) as views,
                SUM(CASE WHEN event_type = 'add_to_cart' THEN 1 ELSE 0 END) as add_to_cart,
                SUM(CASE WHEN event_type = 'checkout_start' THEN 1 ELSE 0 END) as checkout_start,
                SUM(CASE WHEN event_type = 'purchase' THEN 1 ELSE 0 END) as purchases,
                SUM(CASE WHEN event_type = 'purchase' THEN value_num ELSE 0 END) as revenue
            FROM $events_table
            WHERE $where"
        );

        $conversion_rate = 0;
        if ($stats->views > 0) {
            $conversion_rate = ($stats->purchases / $stats->views) * 100;
        }

        $avg_order_value = 0;
        if ($stats->purchases > 0) {
            $avg_order_value = $stats->revenue / $stats->purchases;
        }

        return [
            'sessions' => (int) $stats->sessions,
            'views' => (int) $stats->views,
            'add_to_cart' => (int) $stats->add_to_cart,
            'checkout_start' => (int) $stats->checkout_start,
            'purchases' => (int) $stats->purchases,
            'revenue' => (float) $stats->revenue,
            'conversion_rate' => round($conversion_rate, 2),
            'avg_order_value' => round($avg_order_value, 2),
        ];
    }

    /**
     * Get funnel data
     */
    public function get_funnel($range = 'today')
    {
        global $wpdb;

        $events_table = $wpdb->prefix . self::EVENTS_TABLE;

        if ($range === 'today') {
            $where = "DATE(created_at) = '" . current_time('Y-m-d') . "'";
        } else {
            $where = "created_at >= '" . date('Y-m-d', strtotime('-7 days')) . "'";
        }

        $stats = $wpdb->get_row(
            "SELECT 
                SUM(CASE WHEN event_type = 'view_product' THEN 1 ELSE 0 END) as views,
                SUM(CASE WHEN event_type = 'add_to_cart' THEN 1 ELSE 0 END) as add_to_cart,
                SUM(CASE WHEN event_type = 'checkout_start' THEN 1 ELSE 0 END) as checkout_start,
                SUM(CASE WHEN event_type = 'purchase' THEN 1 ELSE 0 END) as purchase
            FROM $events_table
            WHERE $where"
        );

        $views = (int) $stats->views;
        $add_to_cart = (int) $stats->add_to_cart;
        $checkout_start = (int) $stats->checkout_start;
        $purchase = (int) $stats->purchase;

        return [
            [
                'stage' => 'views',
                'label_ar' => 'Views',
                'count' => $views,
                'rate' => 100,
            ],
            [
                'stage' => 'add_to_cart',
                'label_ar' => 'Add to Cart',
                'count' => $add_to_cart,
                'rate' => $views > 0 ? round(($add_to_cart / $views) * 100, 1) : 0,
            ],
            [
                'stage' => 'checkout_start',
                'label_ar' => 'Checkout Start',
                'count' => $checkout_start,
                'rate' => $add_to_cart > 0 ? round(($checkout_start / $add_to_cart) * 100, 1) : 0,
            ],
            [
                'stage' => 'purchase',
                'label_ar' => 'Purchase',
                'count' => $purchase,
                'rate' => $checkout_start > 0 ? round(($purchase / $checkout_start) * 100, 1) : 0,
            ],
        ];
    }

    /**
     * Get search analytics
     */
    public function get_search_analytics($range = '7d', $limit = 50)
    {
        global $wpdb;

        $search_table = $wpdb->prefix . self::SEARCH_METRICS_TABLE;

        $days = [];
        $days_count = $range === '7d' ? 7 : 30;
        for ($i = 0; $i < $days_count; $i++) {
            $days[] = date('Y-m-d', strtotime("-$i days"));
        }

        $days_str = "'" . implode("','", $days) . "'";

        $top_queries = $wpdb->get_results($wpdb->prepare(
            "SELECT 
                query_text,
                SUM(searches) as searches,
                SUM(zero_results) as zero_results
            FROM $search_table
            WHERE day IN ($days_str)
            GROUP BY query_text
            ORDER BY searches DESC
            LIMIT %d",
            $limit
        ));

        $zero_result_queries = $wpdb->get_results($wpdb->prepare(
            "SELECT 
                query_text,
                SUM(zero_results) as zero_results
            FROM $search_table
            WHERE day IN ($days_str)
            AND zero_results > 0
            GROUP BY query_text
            ORDER BY zero_results DESC
            LIMIT %d",
            $limit
        ));

        return [
            'top_queries' => $top_queries,
            'zero_result_queries' => $zero_result_queries,
        ];
    }

    /**
     * Get hourly activity timeline
     */
    public function get_activity_timeline($range = '24h')
    {
        global $wpdb;

        $events_table = $wpdb->prefix . self::EVENTS_TABLE;

        if ($range === '24h') {
            $where = "created_at >= '" . date('Y-m-d H:i:s', strtotime('-24 hours')) . "'";
        } else {
            $where = "created_at >= '" . date('Y-m-d H:i:s', strtotime('-7 days')) . "'";
        }

        $results = $wpdb->get_results(
            "SELECT 
                DATE_FORMAT(created_at, '%Y-%m-%d %H:00:00') as hour,
                SUM(CASE WHEN event_type = 'view_product' THEN 1 ELSE 0 END) as views,
                SUM(CASE WHEN event_type = 'search' THEN 1 ELSE 0 END) as searches,
                SUM(CASE WHEN event_type = 'add_to_cart' THEN 1 ELSE 0 END) as add_to_cart,
                SUM(CASE WHEN event_type = 'purchase' THEN 1 ELSE 0 END) as purchases
            FROM $events_table
            WHERE $where
            GROUP BY hour
            ORDER BY hour ASC"
        );

        return $results;
    }

    /**
     * Get wishlist top products
     */
    public function get_wishlist_top($range = '7d', $limit = 30)
    {
        global $wpdb;

        $metrics_table = $wpdb->prefix . self::PRODUCT_METRICS_TABLE;

        $days = [];
        $days_count = $range === '7d' ? 7 : 30;
        for ($i = 0; $i < $days_count; $i++) {
            $days[] = date('Y-m-d', strtotime("-$i days"));
        }

        $days_str = "'" . implode("','", $days) . "'";

        return $wpdb->get_results($wpdb->prepare(
            "SELECT 
                product_id,
                SUM(wishlist_add) as wishlist_add
            FROM $metrics_table
            WHERE day IN ($days_str)
            GROUP BY product_id
            HAVING wishlist_add > 0
            ORDER BY wishlist_add DESC
            LIMIT %d",
            $limit
        ));
    }

    /**
     * Get comprehensive wishlist analytics
     */
    public function get_wishlist_analytics($range = '7d')
    {
        global $wpdb;
        $events_table = $wpdb->prefix . self::EVENTS_TABLE;

        if ($range === 'today') {
            $where = "DATE(created_at) = '" . current_time('Y-m-d') . "'";
        } elseif ($range === '7d') {
            $where = "created_at >= '" . date('Y-m-d', strtotime('-7 days')) . "'";
        } else {
            $where = "created_at >= '" . date('Y-m-d', strtotime('-30 days')) . "'";
        }

        $stats = $wpdb->get_row(
            "SELECT 
                SUM(CASE WHEN event_type = 'add_wishlist' THEN 1 ELSE 0 END) as total_adds,
                SUM(CASE WHEN event_type = 'remove_wishlist' THEN 1 ELSE 0 END) as total_removes,
                COUNT(DISTINCT CASE WHEN event_type = 'add_wishlist' THEN product_id END) as unique_products
            FROM $events_table
            WHERE $where"
        );

        return [
            'total_adds' => (int) ($stats->total_adds ?? 0),
            'total_removes' => (int) ($stats->total_removes ?? 0),
            'net_saves' => (int) (($stats->total_adds ?? 0) - ($stats->total_removes ?? 0)),
            'unique_products_saved' => (int) ($stats->unique_products ?? 0),
        ];
    }

    /**
     * Get total wishlist count for a product from metrics.
     */
    public function get_product_wishlist_count($product_id)
    {
        global $wpdb;
        $metrics_table = $wpdb->prefix . self::PRODUCT_METRICS_TABLE;

        $count = $wpdb->get_var($wpdb->prepare(
            "SELECT SUM(wishlist_add) FROM $metrics_table WHERE product_id = %d",
            $product_id
        ));

        return (int) ($count ?? 0);
    }

    /**
     * Check if user has high interest in product
     */
    public function check_high_interest($user_id, $device_id, $product_id)
    {
        global $wpdb;

        $events_table = $wpdb->prefix . self::EVENTS_TABLE;
        $cutoff = date('Y-m-d H:i:s', strtotime('-48 hours'));

        $actor_where = $user_id > 0
            ? $wpdb->prepare("user_id = %d", $user_id)
            : $wpdb->prepare("device_id = %s", $device_id);

        $view_count = $wpdb->get_var($wpdb->prepare(
            "SELECT COUNT(*) FROM $events_table
            WHERE $actor_where
            AND product_id = %d
            AND event_type = 'view_product'
            AND created_at >= %s",
            $product_id,
            $cutoff
        ));

        $purchase_count = $wpdb->get_var($wpdb->prepare(
            "SELECT COUNT(*) FROM $events_table
            WHERE $actor_where
            AND product_id = %d
            AND event_type = 'purchase'
            AND created_at >= %s",
            $product_id,
            $cutoff
        ));

        return [
            'high_interest' => $view_count >= 3 && $purchase_count == 0,
            'view_count' => (int) $view_count,
        ];
    }
}

// Initialize
Lexi_AI_Core::instance();