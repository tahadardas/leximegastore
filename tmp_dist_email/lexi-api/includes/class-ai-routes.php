<?php
/**
 * AI Core REST API Routes
 * 
 * Public endpoints:
 * - /ai/track - Event tracking
 * - /ai/reco/for-you - Personalized recommendations
 * - /ai/reco/similar - Similar products
 * - /ai/reco/trending - Trending products
 * - /ai/reco/bundles - Frequently bought together
 * 
 * Admin endpoints:
 * - /admin/ai/overview - Dashboard KPIs
 * - /admin/ai/funnel - Conversion funnel
 * - /admin/ai/trending - Trending products
 * - /admin/ai/opportunities - Improvement opportunities
 * - /admin/ai/wishlist-top - Top wishlisted products
 * - /admin/ai/search - Search analytics
 * - /admin/ai/activity - Activity timeline
 */

if (!defined('ABSPATH')) {
    exit;
}

class Lexi_AI_Routes
{

    private static $instance = null;

    public static function instance()
    {
        if (self::$instance === null) {
            self::$instance = new self();
        }
        return self::$instance;
    }

    /**
     * Register all AI routes
     */
    public function register_routes()
    {
        // Public tracking endpoint
        register_rest_route('lexi/v1', '/ai/track', [
            'methods' => 'POST',
            'callback' => [$this, 'track_event'],
            'permission_callback' => '__return_true',
        ]);

        // Recommendation endpoints
        register_rest_route('lexi/v1', '/ai/reco/for-you', [
            'methods' => 'GET',
            'callback' => [$this, 'get_for_you'],
            'permission_callback' => '__return_true',
        ]);

        register_rest_route('lexi/v1', '/ai/reco/similar', [
            'methods' => 'GET',
            'callback' => [$this, 'get_similar'],
            'permission_callback' => '__return_true',
        ]);

        register_rest_route('lexi/v1', '/ai/reco/trending', [
            'methods' => 'GET',
            'callback' => [$this, 'get_trending'],
            'permission_callback' => '__return_true',
        ]);

        register_rest_route('lexi/v1', '/ai/reco/bundles', [
            'methods' => 'GET',
            'callback' => [$this, 'get_bundles'],
            'permission_callback' => '__return_true',
        ]);

        // Admin endpoints
        register_rest_route('lexi/v1', '/admin/ai/overview', [
            'methods' => 'GET',
            'callback' => [$this, 'admin_overview'],
            'permission_callback' => [$this, 'check_admin_permission'],
        ]);

        register_rest_route('lexi/v1', '/admin/ai/funnel', [
            'methods' => 'GET',
            'callback' => [$this, 'admin_funnel'],
            'permission_callback' => [$this, 'check_admin_permission'],
        ]);

        register_rest_route('lexi/v1', '/admin/ai/trending', [
            'methods' => 'GET',
            'callback' => [$this, 'admin_trending'],
            'permission_callback' => [$this, 'check_admin_permission'],
        ]);

        register_rest_route('lexi/v1', '/admin/ai/opportunities', [
            'methods' => 'GET',
            'callback' => [$this, 'admin_opportunities'],
            'permission_callback' => [$this, 'check_admin_permission'],
        ]);

        register_rest_route('lexi/v1', '/admin/ai/wishlist-top', [
            'methods' => 'GET',
            'callback' => [$this, 'admin_wishlist_top'],
            'permission_callback' => [$this, 'check_admin_permission'],
        ]);

        register_rest_route('lexi/v1', '/admin/ai/search', [
            'methods' => 'GET',
            'callback' => [$this, 'admin_search'],
            'permission_callback' => [$this, 'check_admin_permission'],
        ]);

        register_rest_route('lexi/v1', '/admin/ai/wishlist-summary', [
            'methods' => 'GET',
            'callback' => [$this, 'admin_wishlist_summary'],
            'permission_callback' => [$this, 'check_admin_permission'],
        ]);

        register_rest_route('lexi/v1', '/admin/ai/activity', [
            'methods' => 'GET',
            'callback' => [$this, 'admin_activity'],
            'permission_callback' => [$this, 'check_admin_permission'],
        ]);
    }

    /**
     * Check admin permission
     */
    public function check_admin_permission()
    {
        return current_user_can('manage_woocommerce');
    }

    /**
     * Track event endpoint
     */
    public function track_event($request)
    {
        $ai = Lexi_AI_Core::instance();

        $data = [
            'event_type' => sanitize_text_field($request->get_param('event_type') ?? ''),
            'product_id' => $request->get_param('product_id'),
            'category_id' => $request->get_param('category_id'),
            'query_text' => $request->get_param('query_text'),
            'device_id' => sanitize_text_field($request->get_param('device_id') ?? ''),
            'session_id' => sanitize_text_field($request->get_param('session_id') ?? ''),
            'city' => sanitize_text_field($request->get_param('city') ?? ''),
            'value_num' => $request->get_param('value_num'),
            'meta' => $request->get_param('meta'),
        ];

        // Rate limiting by device_id/session_id
        $rate_key = 'lexi_ai_rate_' . ($data['device_id'] ?: $data['session_id']);
        $count = get_transient($rate_key);
        if ($count !== false && $count > 100) {
            return new WP_REST_Response(['success' => true], 200); // Silent fail
        }
        set_transient($rate_key, ($count ?: 0) + 1, MINUTE_IN_SECONDS);

        $result = $ai->track_event($data);

        return new WP_REST_Response(['success' => $result], 200);
    }

    /**
     * Get "For You" recommendations
     */
    public function get_for_you($request)
    {
        $ai = Lexi_AI_Core::instance();

        $limit = min(20, max(1, (int) $request->get_param('limit') ?: 20));
        $user_id = get_current_user_id();
        $device_id = sanitize_text_field($request->get_param('device_id') ?? '');

        // Get user's top categories
        $top_categories = $ai->get_user_top_categories($user_id, $device_id);

        if (empty($top_categories)) {
            // Fallback to trending
            return $this->get_trending($request);
        }

        $category_ids = array_keys($top_categories);

        // Get products from top categories ordered by score
        $args = [
            'post_type' => 'product',
            'post_status' => 'publish',
            'posts_per_page' => $limit,
            'tax_query' => [
                [
                    'taxonomy' => 'product_cat',
                    'field' => 'term_id',
                    'terms' => $category_ids,
                ],
            ],
            'meta_query' => [
                [
                    'key' => '_stock_status',
                    'value' => 'instock',
                ],
            ],
        ];

        $query = new WP_Query($args);
        $products = $this->format_products($query->posts);

        return new WP_REST_Response([
            'success' => true,
            'data' => $products,
        ], 200);
    }

    /**
     * Get similar products
     */
    public function get_similar($request)
    {
        $ai = Lexi_AI_Core::instance();

        $product_id = (int) $request->get_param('product_id');
        $limit = min(12, max(1, (int) $request->get_param('limit') ?: 12));

        if (!$product_id) {
            return new WP_REST_Response([
                'success' => false,
                'message' => 'Product ID required',
            ], 400);
        }

        $product_ids = $ai->get_similar($product_id, $limit);
        $products = $this->format_products($product_ids);

        return new WP_REST_Response([
            'success' => true,
            'data' => $products,
        ], 200);
    }

    /**
     * Get trending products
     */
    public function get_trending($request)
    {
        $ai = Lexi_AI_Core::instance();

        $range = $request->get_param('range') ?: '24h';
        $limit = min(20, max(1, (int) $request->get_param('limit') ?: 20));

        $trending = $ai->get_trending($range, $limit);

        $products = [];
        foreach ($trending as $item) {
            $product = wc_get_product($item->product_id);
            if ($product && $product->is_in_stock()) {
                $products[] = $this->format_product($product, [
                    'score' => (float) $item->score,
                    'views' => (int) $item->views,
                    'purchases' => (int) $item->purchases,
                ]);
            }
        }

        return new WP_REST_Response([
            'success' => true,
            'data' => $products,
        ], 200);
    }

    /**
     * Get bundles (frequently bought together)
     */
    public function get_bundles($request)
    {
        $ai = Lexi_AI_Core::instance();

        $product_id = (int) $request->get_param('product_id');
        $limit = min(10, max(1, (int) $request->get_param('limit') ?: 10));

        if (!$product_id) {
            return new WP_REST_Response([
                'success' => false,
                'message' => 'Product ID required',
            ], 400);
        }

        $bundles = $ai->get_bundles($product_id, $limit);

        $products = [];
        foreach ($bundles as $item) {
            $product = wc_get_product($item->product_id);
            if ($product && $product->is_in_stock()) {
                $products[] = $this->format_product($product, [
                    'co_occurrence' => (int) $item->co_occurrence,
                ]);
            }
        }

        return new WP_REST_Response([
            'success' => true,
            'data' => $products,
        ], 200);
    }

    /**
     * Admin: Overview dashboard
     */
    public function admin_overview($request)
    {
        $ai = Lexi_AI_Core::instance();

        $range = $request->get_param('range') ?: 'today';
        $overview = $ai->get_overview($range);

        return new WP_REST_Response([
            'success' => true,
            'data' => $overview,
        ], 200);
    }

    /**
     * Admin: Funnel data
     */
    public function admin_funnel($request)
    {
        $ai = Lexi_AI_Core::instance();

        $range = $request->get_param('range') ?: 'today';
        $funnel = $ai->get_funnel($range);

        return new WP_REST_Response([
            'success' => true,
            'data' => $funnel,
        ], 200);
    }

    /**
     * Admin: Trending products
     */
    public function admin_trending($request)
    {
        $ai = Lexi_AI_Core::instance();

        $range = $request->get_param('range') ?: '24h';
        $limit = min(30, max(1, (int) $request->get_param('limit') ?: 30));

        $trending = $ai->get_trending($range, $limit);

        $products = [];
        foreach ($trending as $item) {
            $product = wc_get_product($item->product_id);
            if ($product) {
                $prices = Lexi_Merch::resolve_product_prices($product);
                $products[] = [
                    'id' => $item->product_id,
                    'name' => $product->get_name(),
                    'sku' => $product->get_sku(),
                    'price' => (float) ($prices['price'] ?? 0.0),
                    'views' => (int) $item->views,
                    'wishlist_add' => (int) $item->wishlist_add,
                    'add_to_cart' => (int) $item->add_to_cart,
                    'purchases' => (int) $item->purchases,
                    'revenue' => (float) $item->revenue,
                    'score' => (float) $item->score,
                ];
            }
        }

        return new WP_REST_Response([
            'success' => true,
            'data' => $products,
        ], 200);
    }

    /**
     * Admin: Opportunities
     */
    public function admin_opportunities($request)
    {
        $ai = Lexi_AI_Core::instance();

        $range = $request->get_param('range') ?: '7d';
        $limit = min(30, max(1, (int) $request->get_param('limit') ?: 30));

        $opportunities = $ai->get_opportunities($range, $limit);

        $products = [];
        foreach ($opportunities as $item) {
            $product = wc_get_product($item->product_id);
            if ($product) {
                $prices = Lexi_Merch::resolve_product_prices($product);
                $suggested_action = '';
                if ($item->opportunity_type === 'high_views_no_sales') {
                    $suggested_action = 'Consider reviewing price or adding promotional content';
                } elseif ($item->opportunity_type === 'low_cart_rate') {
                    $suggested_action = 'Improve product description or add social proof';
                } elseif ($item->opportunity_type === 'high_cart_low_purchase') {
                    $suggested_action = 'Check for shipping issues or checkout friction';
                }

                $products[] = [
                    'id' => $item->product_id,
                    'name' => $product->get_name(),
                    'sku' => $product->get_sku(),
                    'price' => (float) ($prices['price'] ?? 0.0),
                    'views' => (int) $item->views,
                    'add_to_cart' => (int) $item->add_to_cart,
                    'purchases' => (int) $item->purchases,
                    'opportunity_type' => $item->opportunity_type,
                    'suggested_action_ar' => $suggested_action,
                ];
            }
        }

        return new WP_REST_Response([
            'success' => true,
            'data' => $products,
        ], 200);
    }

    /**
     * Admin: Wishlist top products
     */
    public function admin_wishlist_top($request)
    {
        $ai = Lexi_AI_Core::instance();

        $range = $request->get_param('range') ?: '7d';
        $limit = min(30, max(1, (int) $request->get_param('limit') ?: 30));

        $wishlist = $ai->get_wishlist_top($range, $limit);

        $products = [];
        foreach ($wishlist as $item) {
            $product = wc_get_product($item->product_id);
            if ($product) {
                $prices = Lexi_Merch::resolve_product_prices($product);
                $products[] = [
                    'id' => $item->product_id,
                    'name' => $product->get_name(),
                    'sku' => $product->get_sku(),
                    'price' => (float) ($prices['price'] ?? 0.0),
                    'wishlist_add' => (int) $item->wishlist_add,
                ];
            }
        }

        return new WP_REST_Response([
            'success' => true,
            'data' => $products,
        ], 200);
    }

    /**
     * Admin: Search analytics
     */
    public function admin_search($request)
    {
        $ai = Lexi_AI_Core::instance();

        $range = $request->get_param('range') ?: '7d';
        $limit = min(50, max(1, (int) $request->get_param('limit') ?: 50));

        $search = $ai->get_search_analytics($range, $limit);

        return new WP_REST_Response([
            'success' => true,
            'data' => [
                'top_queries' => $search['top_queries'],
                'zero_result_queries' => $search['zero_result_queries'],
            ],
        ], 200);
    }

    /**
     * Admin: Activity timeline
     */
    public function admin_activity($request)
    {
        $ai = Lexi_AI_Core::instance();

        $range = $request->get_param('range') ?: '24h';

        $activity = $ai->get_activity_timeline($range);

        return new WP_REST_Response([
            'success' => true,
            'data' => $activity,
        ], 200);
    }

    /**
     * Admin: Wishlist summary analytics
     */
    public function admin_wishlist_summary($request)
    {
        $ai = Lexi_AI_Core::instance();
        $range = $request->get_param('range') ?: '7d';

        $analytics = $ai->get_wishlist_analytics($range);
        $top_items = $ai->get_wishlist_top($range, 15);

        $formatted_top = [];
        foreach ($top_items as $item) {
            $product = wc_get_product($item->product_id);
            if ($product) {
                $prices = Lexi_Merch::resolve_product_prices($product);
                $formatted_top[] = [
                    'id' => (int) $item->product_id,
                    'name' => $product->get_name(),
                    'sku' => $product->get_sku(),
                    'price' => (float) ($prices['price'] ?? 0.0),
                    'wishlist_add' => (int) $item->wishlist_add,
                ];
            }
        }

        $analytics['top_products'] = $formatted_top;

        return new WP_REST_Response([
            'success' => true,
            'data' => $analytics,
        ], 200);
    }

    /**
     * Format products for API response
     */
    private function format_products($product_ids)
    {
        $products = [];
        foreach ($product_ids as $product_id) {
            $product = wc_get_product($product_id);
            if ($product) {
                $products[] = $this->format_product($product);
            }
        }
        return $products;
    }

    /**
     * Format single product for API response
     */
    private function format_product($product, $extra = [])
    {
        $image_id = $product->get_image_id();
        $image_url = $image_id ? wp_get_attachment_url($image_id) : wc_placeholder_img_src();
        $prices = Lexi_Merch::resolve_product_prices($product);

        $categories = wp_get_post_terms($product->get_id(), 'product_cat');
        $category_names = array_map(function ($t) {
            return $t->name;
        }, $categories);

        return array_merge([
            'id' => $product->get_id(),
            'name' => $product->get_name(),
            'slug' => $product->get_slug(),
            'price' => (float) ($prices['price'] ?? 0.0),
            'regular_price' => (float) ($prices['regular_price'] ?? 0.0),
            'sale_price' => isset($prices['sale_price']) ? $prices['sale_price'] : null,
            'currency' => 'SYP',
            'image_url' => $image_url,
            'categories' => $category_names,
            'stock_status' => $product->get_stock_status(),
            'low_stock' => $product->get_stock_quantity() !== null && $product->get_stock_quantity() < 5,
        ], $extra);
    }
}

// Initialize
Lexi_AI_Routes::instance();
