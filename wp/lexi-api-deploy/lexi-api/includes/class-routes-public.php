<?php
/**
 * Public REST routes: products, categories, home sections, shipping and ShamCash config.
 *
 * @package Lexi_API
 */

defined('ABSPATH') || exit;

class Lexi_Routes_Public
{
    private const LOG_SOURCE = 'lexi-api-public';
    private const PRODUCTS_LIST_CACHE_TTL = 300;
    private const CATEGORIES_CACHE_TTL = 600;
    private const HOME_SECTIONS_CACHE_TTL = 90;
    private const SHIPPING_CITIES_CACHE_TTL = 600;
    private const SHIPPING_RATE_CACHE_TTL = 300;
    private const CATEGORIES_PAGE_SLUGS_CACHE_TTL = 600;
    private const CATEGORIES_PAGE_SLUGS_CACHE_KEY = 'lexi_categories_page_slugs_v1';

    /**
     * Register all public routes.
     */
    public static function register(): void
    {
        $ns = LEXI_API_NAMESPACE;

        register_rest_route($ns, '/products', array(
            'methods' => WP_REST_Server::READABLE,
            'callback' => array(__CLASS__, 'get_products'),
            'permission_callback' => array('Lexi_Security', 'public_access'),
            'args' => array(
                'page' => array('default' => 1, 'sanitize_callback' => 'absint'),
                'per_page' => array('default' => 20, 'sanitize_callback' => 'absint'),
                'search' => array('default' => '', 'sanitize_callback' => 'sanitize_text_field'),
                'category' => array('default' => '', 'sanitize_callback' => 'sanitize_text_field'),
                'category_id' => array('default' => 0, 'sanitize_callback' => 'absint'),
                'brand' => array('default' => '', 'sanitize_callback' => 'sanitize_text_field'),
                'brand_id' => array('default' => 0, 'sanitize_callback' => 'absint'),
                'min_price' => array('default' => '', 'sanitize_callback' => 'sanitize_text_field'),
                'max_price' => array('default' => '', 'sanitize_callback' => 'sanitize_text_field'),
                'sort' => array('default' => 'manual', 'sanitize_callback' => 'sanitize_text_field'),
                'include_unpriced' => array('default' => 0, 'sanitize_callback' => 'absint'),
            ),
        ));

        register_rest_route('custom/v1', '/products', array(
            'methods' => WP_REST_Server::READABLE,
            'callback' => array(__CLASS__, 'get_products_custom'),
            'permission_callback' => array('Lexi_Security', 'public_access'),
            'args' => array(
                'page' => array('default' => 1, 'sanitize_callback' => 'absint'),
                'per_page' => array('default' => 20, 'sanitize_callback' => 'absint'),
                'search' => array('default' => '', 'sanitize_callback' => 'sanitize_text_field'),
                'category' => array('default' => '', 'sanitize_callback' => 'sanitize_text_field'),
                'category_id' => array('default' => 0, 'sanitize_callback' => 'absint'),
                'brand' => array('default' => '', 'sanitize_callback' => 'sanitize_text_field'),
                'brand_id' => array('default' => 0, 'sanitize_callback' => 'absint'),
                'min_price' => array('default' => '', 'sanitize_callback' => 'sanitize_text_field'),
                'max_price' => array('default' => '', 'sanitize_callback' => 'sanitize_text_field'),
                'sort' => array('default' => 'newest', 'sanitize_callback' => 'sanitize_text_field'),
                'include_unpriced' => array('default' => 0, 'sanitize_callback' => 'absint'),
            ),
        ));

        register_rest_route($ns, '/search/suggest', array(
            'methods' => WP_REST_Server::READABLE,
            'callback' => array(__CLASS__, 'search_suggest'),
            'permission_callback' => array('Lexi_Security', 'public_access'),
            'args' => array(
                'q' => array('default' => '', 'sanitize_callback' => 'sanitize_text_field'),
                'limit' => array('default' => 10, 'sanitize_callback' => 'absint'),
            ),
        ));

        register_rest_route($ns, '/search/suggestions', array(
            'methods' => WP_REST_Server::READABLE,
            'callback' => array(__CLASS__, 'search_suggestions'),
            'permission_callback' => array('Lexi_Security', 'public_access'),
            'args' => array(
                'q' => array('default' => '', 'sanitize_callback' => 'sanitize_text_field'),
                'limit' => array('default' => 10, 'sanitize_callback' => 'absint'),
            ),
        ));

        register_rest_route($ns, '/search', array(
            'methods' => WP_REST_Server::READABLE,
            'callback' => array(__CLASS__, 'search_full'),
            'permission_callback' => array('Lexi_Security', 'public_access'),
            'args' => array(
                'q' => array('default' => '', 'sanitize_callback' => 'sanitize_text_field'),
                'page' => array('default' => 1, 'sanitize_callback' => 'absint'),
                'per_page' => array('default' => 20, 'sanitize_callback' => 'absint'),
                'sort' => array('default' => 'relevance', 'sanitize_callback' => 'sanitize_text_field'),
                'min_price' => array('default' => '', 'sanitize_callback' => 'sanitize_text_field'),
                'max_price' => array('default' => '', 'sanitize_callback' => 'sanitize_text_field'),
                'in_stock' => array('default' => '', 'sanitize_callback' => 'sanitize_text_field'),
                'category_id' => array('default' => 0, 'sanitize_callback' => 'absint'),
            ),
        ));

        register_rest_route($ns, '/search/products', array(
            'methods' => WP_REST_Server::READABLE,
            'callback' => array(__CLASS__, 'search_products'),
            'permission_callback' => array('Lexi_Security', 'public_access'),
            'args' => array(
                'q' => array('default' => '', 'sanitize_callback' => 'sanitize_text_field'),
                'page' => array('default' => 1, 'sanitize_callback' => 'absint'),
                'limit' => array('default' => 20, 'sanitize_callback' => 'absint'),
                'sort' => array('default' => 'relevance', 'sanitize_callback' => 'sanitize_text_field'),
                'min_price' => array('default' => '', 'sanitize_callback' => 'sanitize_text_field'),
                'max_price' => array('default' => '', 'sanitize_callback' => 'sanitize_text_field'),
                'in_stock' => array('default' => '', 'sanitize_callback' => 'sanitize_text_field'),
                'category_id' => array('default' => 0, 'sanitize_callback' => 'absint'),
            ),
        ));

        register_rest_route($ns, '/search/trending', array(
            'methods' => WP_REST_Server::READABLE,
            'callback' => array(__CLASS__, 'search_trending'),
            'permission_callback' => array('Lexi_Security', 'public_access'),
            'args' => array(
                'limit' => array('default' => 10, 'sanitize_callback' => 'absint'),
            ),
        ));

        register_rest_route($ns, '/products/(?P<id>\d+)', array(
            'methods' => WP_REST_Server::READABLE,
            'callback' => array(__CLASS__, 'get_product_by_id'),
            'permission_callback' => array('Lexi_Security', 'public_access'),
            'args' => array(
                'id' => array(
                    'required' => true,
                    'validate_callback' => function ($v) {
                        return is_numeric($v);
                    },
                    'sanitize_callback' => 'absint',
                ),
            ),
        ));

        register_rest_route($ns, '/products/(?P<id>\d+)/reviews', array(
            array(
                'methods' => WP_REST_Server::READABLE,
                'callback' => array(__CLASS__, 'get_product_reviews'),
                'permission_callback' => array('Lexi_Security', 'public_access'),
                'args' => array(
                    'id' => array(
                        'required' => true,
                        'sanitize_callback' => 'absint',
                    ),
                    'page' => array('default' => 1, 'sanitize_callback' => 'absint'),
                    'per_page' => array('default' => 10, 'sanitize_callback' => 'absint'),
                ),
            ),
            array(
                'methods' => WP_REST_Server::CREATABLE,
                'callback' => array(__CLASS__, 'create_product_review'),
                'permission_callback' => array('Lexi_Security', 'customer_access'),
                'args' => array(
                    'id' => array(
                        'required' => true,
                        'sanitize_callback' => 'absint',
                    ),
                ),
            ),
        ));

        register_rest_route($ns, '/products/(?P<id>\d+)/similar', array(
            'methods' => WP_REST_Server::READABLE,
            'callback' => array(__CLASS__, 'get_similar_products'),
            'permission_callback' => array('Lexi_Security', 'public_access'),
            'args' => array(
                'id' => array(
                    'required' => true,
                    'sanitize_callback' => 'absint',
                ),
                'limit' => array('default' => 12, 'sanitize_callback' => 'absint'),
            ),
        ));

        register_rest_route($ns, '/categories', array(
            'methods' => WP_REST_Server::READABLE,
            'callback' => array(__CLASS__, 'get_categories'),
            'permission_callback' => array('Lexi_Security', 'public_access'),
            'args' => array(
                'include_empty' => array('default' => 0, 'sanitize_callback' => 'absint'),
                'view' => array('default' => '', 'sanitize_callback' => 'sanitize_text_field'),
            ),
        ));

        register_rest_route($ns, '/categories/(?P<id>\d+)', array(
            'methods' => WP_REST_Server::READABLE,
            'callback' => array(__CLASS__, 'get_category_by_id'),
            'permission_callback' => array('Lexi_Security', 'public_access'),
            'args' => array(
                'id' => array(
                    'required' => true,
                    'validate_callback' => function ($v) {
                        return is_numeric($v);
                    },
                    'sanitize_callback' => 'absint',
                ),
            ),
        ));

        register_rest_route($ns, '/home/sections', array(
            'methods' => WP_REST_Server::READABLE,
            'callback' => array(__CLASS__, 'get_home_sections'),
            'permission_callback' => array('Lexi_Security', 'public_access'),
            'args' => array(
                'items_limit' => array('default' => 12, 'sanitize_callback' => 'absint'),
                'include_unpriced' => array('default' => 0, 'sanitize_callback' => 'absint'),
            ),
        ));

        register_rest_route($ns, '/home/ad-banners', array(
            'methods' => WP_REST_Server::READABLE,
            'callback' => array(__CLASS__, 'get_home_ad_banners'),
            'permission_callback' => array('Lexi_Security', 'public_access'),
            'args' => array(
                'include_inactive' => array('default' => 0, 'sanitize_callback' => 'absint'),
            ),
        ));

        register_rest_route($ns, '/shipping/cities', array(
            'methods' => WP_REST_Server::READABLE,
            'callback' => array(__CLASS__, 'get_shipping_cities'),
            'permission_callback' => array('Lexi_Security', 'public_access'),
        ));

        register_rest_route($ns, '/shipping/rate', array(
            'methods' => WP_REST_Server::READABLE,
            'callback' => array(__CLASS__, 'get_shipping_rate'),
            'permission_callback' => array('Lexi_Security', 'public_access'),
            'args' => array(
                'city_id' => array('required' => true, 'sanitize_callback' => 'absint'),
            ),
        ));

        register_rest_route($ns, '/payments/shamcash/config', array(
            'methods' => WP_REST_Server::READABLE,
            'callback' => array(__CLASS__, 'get_shamcash_config'),
            'permission_callback' => array('Lexi_Security', 'public_access'),
        ));
    }

    /**
     * GET /products
     */
    public static function get_products(WP_REST_Request $request): WP_REST_Response
    {
        $trace_id = self::new_trace_id();
        self::log_route_start('/products', $request, $trace_id);

        $dependency_error = self::ensure_woocommerce_dependency($trace_id);
        if (null !== $dependency_error) {
            return $dependency_error;
        }

        try {
            return Lexi_Security::success(self::build_products_payload($request, $trace_id, '/products'));
        } catch (Throwable $e) {
            self::log_route_error('/products', $trace_id, $e);
            return Lexi_Security::error(
                'products_error',
                'ØªØ¹Ø°Ø± Ø¬Ù„Ø¨ Ø§Ù„Ù…Ù†ØªØ¬Ø§Øª Ø­Ø§Ù„ÙŠØ§Ù‹.',
                500,
                array('trace_id' => $trace_id)
            );
        }
    }

    /**
     * GET /custom/v1/products
     */
    public static function get_products_custom(WP_REST_Request $request): WP_REST_Response
    {
        $trace_id = self::new_trace_id();
        self::log_route_start('/custom/v1/products', $request, $trace_id);

        $dependency_error = self::ensure_woocommerce_dependency($trace_id);
        if (null !== $dependency_error) {
            return $dependency_error;
        }

        try {
            $payload = self::build_products_payload($request, $trace_id, '/custom/v1/products');
            return new WP_REST_Response($payload, 200);
        } catch (Throwable $e) {
            self::log_route_error('/custom/v1/products', $trace_id, $e);
            return Lexi_Security::error(
                'products_error',
                'ØªØ¹Ø°Ø± Ø¬Ù„Ø¨ Ø§Ù„Ù…Ù†ØªØ¬Ø§Øª Ø­Ø§Ù„ÙŠØ§Ù‹.',
                500,
                array('trace_id' => $trace_id)
            );
        }
    }

    /**
     * @return array<string, mixed>
     */
    private static function build_products_payload(
        WP_REST_Request $request,
        string $trace_id,
        string $route_for_logs
    ): array {
        $page = max(1, (int) $request->get_param('page'));
        $per_page = min(100, max(1, (int) $request->get_param('per_page')));
        $search = trim((string) $request->get_param('search'));
        $category_id = self::resolve_category_id($request);
        $min_price = $request->get_param('min_price');
        $max_price = $request->get_param('max_price');
        $sort = self::normalize_sort((string) $request->get_param('sort'));
        $include_unpriced = Lexi_Merch::bool_int($request->get_param('include_unpriced')) === 1;

        $brand_filter = self::resolve_brand_filter($request);
        $brand_term_id = (int) ($brand_filter['id'] ?? 0);
        $brand_token = isset($brand_filter['token']) ? (string) $brand_filter['token'] : '';
        $brand_taxonomy = isset($brand_filter['taxonomy']) ? (string) $brand_filter['taxonomy'] : '';

        $cache_fingerprint = array(
            'page' => $page,
            'per_page' => $per_page,
            'search' => strtolower($search),
            'category_id' => $category_id,
            'brand_id' => $brand_term_id,
            'brand_token' => strtolower($brand_token),
            'sort' => $sort,
            'min_price' => is_scalar($min_price) ? (string) $min_price : '',
            'max_price' => is_scalar($max_price) ? (string) $max_price : '',
            'include_unpriced' => $include_unpriced ? 1 : 0,
        );
        $cache_key = 'lexi_products_list_v4_' . md5(wp_json_encode($cache_fingerprint));
        $cached = get_transient($cache_key);
        if (is_array($cached)) {
            self::log_route_success($route_for_logs, $trace_id, array(
                'cached' => true,
                'category_id' => $category_id,
                'brand_id' => $brand_term_id,
                'sort' => $sort,
                'path' => $category_id > 0 && 'manual' === $sort ? 'manual' : 'query',
            ));
            return $cached;
        }

        if ($category_id > 0 && 'manual' === $sort) {
            $payload = self::get_products_manual_in_category(
                $category_id,
                $page,
                $per_page,
                $search,
                $min_price,
                $max_price,
                $include_unpriced,
                $brand_term_id,
                $brand_token,
                $brand_taxonomy
            );
            $path = 'manual';
        } else {
            $payload = self::get_products_by_query(
                $category_id,
                $page,
                $per_page,
                $search,
                $min_price,
                $max_price,
                $sort,
                $include_unpriced,
                $brand_term_id,
                $brand_token,
                $brand_taxonomy
            );
            $path = 'query';
        }

        $payload = self::attach_products_filter_meta($payload, $category_id, $brand_filter);
        set_transient($cache_key, $payload, self::PRODUCTS_LIST_CACHE_TTL);

        self::log_route_success($route_for_logs, $trace_id, array(
            'category_id' => $category_id,
            'brand_id' => $brand_term_id,
            'sort' => $sort,
            'include_unpriced' => $include_unpriced ? 1 : 0,
            'path' => $path,
            'total' => isset($payload['total']) ? (int) $payload['total'] : 0,
        ));

        return $payload;
    }
    /**
     * GET /search/suggest
     */
    public static function search_suggest(WP_REST_Request $request): WP_REST_Response
    {
        $trace_id = self::new_trace_id();
        self::log_route_start('/search/suggest', $request, $trace_id);

        $dependency_error = self::ensure_woocommerce_dependency($trace_id);
        if (null !== $dependency_error) {
            return $dependency_error;
        }

        try {
            $query = trim((string) $request->get_param('q'));
            $limit = min(20, max(1, (int) $request->get_param('limit')));

            if ('' === $query) {
                return Lexi_Security::success(array(
                    'suggestions' => array(),
                    'products' => array(),
                    'categories' => array(),
                ));
            }

            $cache_key = 'lexi_search_suggest_' . md5(strtolower($query) . '|' . $limit);
            $cached = get_transient($cache_key);
            if (is_array($cached)) {
                self::log_route_success('/search/suggest', $trace_id, array('cached' => true));
                return Lexi_Security::success($cached);
            }

            Lexi_Merch::track_search_query($query);

            $products_limit = min(6, $limit);
            $categories_limit = min(4, $limit);
            $product_ids = self::get_search_candidate_product_ids($query, max(24, $products_limit * 4));

            $products = array();
            $product_names = array();
            $currency = (string) get_woocommerce_currency();
            if ('' === $currency) {
                $currency = 'SYP';
            }

            foreach (array_slice($product_ids, 0, $products_limit) as $product_id) {
                $product = wc_get_product((int) $product_id);
                if (!$product instanceof WC_Product) {
                    continue;
                }
                if ('publish' !== get_post_status((int) $product_id)) {
                    continue;
                }

                $thumb_url = '';
                $thumb_id = (int) $product->get_image_id();
                if ($thumb_id > 0) {
                    $raw_thumb = wp_get_attachment_image_url($thumb_id, 'woocommerce_thumbnail');
                    if ($raw_thumb) {
                        $thumb_url = Lexi_Merch::normalize_image_url((string) $raw_thumb);
                    }
                }

                $prices = Lexi_Merch::resolve_product_prices($product);

                $products[] = array(
                    'id' => (int) $product->get_id(),
                    'name' => self::normalize_text($product->get_name()),
                    'price' => $prices['price'] ?? null,
                    'sale_price' => isset($prices['sale_price']) ? $prices['sale_price'] : null,
                    'regular_price' => $prices['regular_price'] ?? null,
                    'currency' => $currency,
                    'image' => $thumb_url,
                    'rating' => (float) $product->get_average_rating(),
                    'reviews_count' => (int) $product->get_review_count(),
                    'in_stock' => (bool) $product->is_in_stock(),
                );

                $product_names[] = self::normalize_text($product->get_name());
            }

            $term_args = array(
                'taxonomy' => 'product_cat',
                'hide_empty' => false,
                'search' => $query,
                'number' => $categories_limit,
                'orderby' => 'count',
                'order' => 'DESC',
            );
            $terms = get_terms($term_args);

            $categories = array();
            $category_names = array();
            if (is_array($terms)) {
                foreach ($terms as $term) {
                    if (!is_object($term) || !isset($term->term_id)) {
                        continue;
                    }

                    $term_id = (int) $term->term_id;
                    $term_image = '';
                    $thumb_id = (int) get_term_meta($term_id, 'thumbnail_id', true);
                    if ($thumb_id > 0) {
                        $raw = wp_get_attachment_image_url($thumb_id, 'woocommerce_thumbnail');
                        if ($raw) {
                            $term_image = Lexi_Merch::normalize_image_url((string) $raw);
                        }
                    }

                    $name = isset($term->name) ? self::normalize_text($term->name) : '';
                    $categories[] = array(
                        'id' => $term_id,
                        'name' => $name,
                        'image' => $term_image,
                    );
                    $category_names[] = $name;
                }
            }

            $suggestion_texts = self::build_query_suggestions(
                $query,
                array_merge($product_names, $category_names),
                $limit
            );
            $highlight = self::highlight_prefix($query);
            $suggestions = array_map(function ($text) use ($highlight) {
                return array(
                    'type' => 'query',
                    'text' => (string) $text,
                    'highlight' => $highlight,
                );
            }, $suggestion_texts);

            $payload = array(
                'suggestions' => $suggestions,
                'products' => $products,
                'categories' => $categories,
            );

            set_transient($cache_key, $payload, 2 * MINUTE_IN_SECONDS);

            self::log_route_success('/search/suggest', $trace_id, array(
                'products' => count($products),
                'categories' => count($categories),
            ));
            return Lexi_Security::success($payload);
        } catch (Throwable $e) {
            self::log_route_error('/search/suggest', $trace_id, $e);
            return Lexi_Security::error(
                'search_suggest_error',
                'ØªØ¹Ø°Ø± Ø¬Ù„Ø¨ Ø§Ù‚ØªØ±Ø§Ø­Ø§Øª Ø§Ù„Ø¨Ø­Ø« Ø­Ø§Ù„ÙŠØ§Ù‹.',
                500,
                array('trace_id' => $trace_id)
            );
        }
    }
    /**
     * GET /search/suggestions
     */
    public static function search_suggestions(WP_REST_Request $request): WP_REST_Response
    {
        $legacy_response = self::search_suggest($request);
        $legacy_data = $legacy_response->get_data();

        if (!is_array($legacy_data) || !($legacy_data['success'] ?? false)) {
            return $legacy_response;
        }

        $payload = isset($legacy_data['data']) && is_array($legacy_data['data'])
            ? $legacy_data['data']
            : array();

        $suggestion_values = array();
        if (isset($payload['suggestions']) && is_array($payload['suggestions'])) {
            foreach ($payload['suggestions'] as $item) {
                if (is_array($item) && isset($item['text'])) {
                    $value = trim((string) $item['text']);
                    if ('' !== $value) {
                        $suggestion_values[] = $value;
                    }
                    continue;
                }
                $value = trim((string) $item);
                if ('' !== $value) {
                    $suggestion_values[] = $value;
                }
            }
        }

        return new WP_REST_Response(array(
            'q' => trim((string) $request->get_param('q')),
            'suggestions' => $suggestion_values,
            'products' => isset($payload['products']) && is_array($payload['products']) ? $payload['products'] : array(),
            'categories' => isset($payload['categories']) && is_array($payload['categories']) ? $payload['categories'] : array(),
        ), $legacy_response->get_status());
    }

    /**
     * GET /search/products
     */
    public static function search_products(WP_REST_Request $request): WP_REST_Response
    {
        $limit = max(1, (int) $request->get_param('limit'));
        $request->set_param('per_page', $limit);

        $legacy_response = self::search_full($request);
        $legacy_data = $legacy_response->get_data();

        if (!is_array($legacy_data) || !($legacy_data['success'] ?? false)) {
            return $legacy_response;
        }

        $items = isset($legacy_data['data']) && is_array($legacy_data['data']) ? $legacy_data['data'] : array();
        $meta = isset($legacy_data['meta']) && is_array($legacy_data['meta']) ? $legacy_data['meta'] : array();

        $page = max(1, (int) ($meta['page'] ?? 1));
        $per_page = max(1, (int) ($meta['per_page'] ?? $limit));
        $total = max(0, (int) ($meta['total'] ?? 0));
        $total_pages = max(1, (int) ($meta['total_pages'] ?? 1));
        $next_page = $page < $total_pages ? $page + 1 : null;

        return new WP_REST_Response(array(
            'q' => trim((string) $request->get_param('q')),
            'items' => $items,
            'page' => $page,
            'limit' => $per_page,
            'total' => $total,
            'total_pages' => $total_pages,
            'next_page' => $next_page,
        ), $legacy_response->get_status());
    }

    /**
     * GET /search
     */
    public static function search_full(WP_REST_Request $request): WP_REST_Response
    {
        $trace_id = self::new_trace_id();
        self::log_route_start('/search', $request, $trace_id);

        $dependency_error = self::ensure_woocommerce_dependency($trace_id);
        if (null !== $dependency_error) {
            return $dependency_error;
        }

        try {
            $query = trim((string) $request->get_param('q'));
            $page = max(1, (int) $request->get_param('page'));
            $requested_per_page = (int) $request->get_param('per_page');
            if ($requested_per_page <= 0) {
                $requested_per_page = (int) $request->get_param('limit');
            }
            if ($requested_per_page <= 0) {
                $requested_per_page = 20;
            }
            $per_page = min(60, max(1, $requested_per_page));
            $sort = self::normalize_search_sort((string) $request->get_param('sort'));
            $min_price = $request->get_param('min_price');
            $max_price = $request->get_param('max_price');
            $in_stock = Lexi_Merch::bool_int($request->get_param('in_stock')) === 1;
            $category_id = absint((int) $request->get_param('category_id'));

            if ('' === $query) {
                return new WP_REST_Response(array(
                    'success' => true,
                    'data' => array(),
                    'meta' => array(
                        'page' => $page,
                        'per_page' => $per_page,
                        'total' => 0,
                        'total_pages' => 1,
                    ),
                ));
            }

            Lexi_Merch::track_search_query($query);

            $candidate_ids = self::get_search_candidate_product_ids($query, 500);
            if (empty($candidate_ids)) {
                return new WP_REST_Response(array(
                    'success' => true,
                    'data' => array(),
                    'meta' => array(
                        'page' => $page,
                        'per_page' => $per_page,
                        'total' => 0,
                        'total_pages' => 1,
                    ),
                ));
            }

            if ('on_sale' === $sort) {
                $sale_ids = wc_get_product_ids_on_sale();
                $sale_ids = array_values(array_filter(array_map('intval', is_array($sale_ids) ? $sale_ids : array())));
                $candidate_ids = array_values(array_intersect($candidate_ids, $sale_ids));
            }

            if (empty($candidate_ids)) {
                return new WP_REST_Response(array(
                    'success' => true,
                    'data' => array(),
                    'meta' => array(
                        'page' => $page,
                        'per_page' => $per_page,
                        'total' => 0,
                        'total_pages' => 1,
                    ),
                ));
            }

            $args = array(
                'post_type' => 'product',
                'post_status' => 'publish',
                'post__in' => $candidate_ids,
                'ignore_sticky_posts' => true,
                'posts_per_page' => $per_page,
                'paged' => $page,
                'orderby' => 'post__in',
                'order' => 'ASC',
            );

            if ($category_id > 0) {
                $args['tax_query'] = array(
                    array(
                        'taxonomy' => 'product_cat',
                        'field' => 'term_id',
                        'terms' => array($category_id),
                    ),
                );
            }

            $meta_query = array();
            if ('' !== (string) $min_price && is_numeric($min_price)) {
                $meta_query[] = array(
                    'key' => '_price',
                    'value' => (float) $min_price,
                    'compare' => '>=',
                    'type' => 'NUMERIC',
                );
            }
            if ('' !== (string) $max_price && is_numeric($max_price)) {
                $meta_query[] = array(
                    'key' => '_price',
                    'value' => (float) $max_price,
                    'compare' => '<=',
                    'type' => 'NUMERIC',
                );
            }
            if ($in_stock) {
                $meta_query[] = array(
                    'key' => '_stock_status',
                    'value' => 'instock',
                    'compare' => '=',
                );
            }
            if (!empty($meta_query)) {
                $meta_query['relation'] = 'AND';
                $args['meta_query'] = $meta_query; // phpcs:ignore
            }

            if ('newest' === $sort) {
                $args['orderby'] = 'date';
                $args['order'] = 'DESC';
            } elseif ('price_asc' === $sort) {
                $args['meta_key'] = '_price';
                $args['orderby'] = 'meta_value_num';
                $args['order'] = 'ASC';
            } elseif ('price_desc' === $sort) {
                $args['meta_key'] = '_price';
                $args['orderby'] = 'meta_value_num';
                $args['order'] = 'DESC';
            } elseif ('top_rated' === $sort) {
                $args['meta_key'] = '_wc_average_rating';
                $args['orderby'] = 'meta_value_num';
                $args['order'] = 'DESC';
            }

            $query_obj = new WP_Query($args);
            $items = array();
            foreach ($query_obj->posts as $post) {
                $product = wc_get_product((int) $post->ID);
                if (!$product instanceof WC_Product) {
                    continue;
                }
                $items[] = Lexi_Merch::format_product_for_api($product);
            }

            self::log_route_success('/search', $trace_id, array(
                'query_length' => self::search_query_length($query),
                'total' => (int) $query_obj->found_posts,
                'page' => $page,
            ));

            return new WP_REST_Response(array(
                'success' => true,
                'data' => $items,
                'meta' => array(
                    'page' => $page,
                    'per_page' => $per_page,
                    'total' => (int) $query_obj->found_posts,
                    'total_pages' => max(1, (int) $query_obj->max_num_pages),
                ),
            ));
        } catch (Throwable $e) {
            self::log_route_error('/search', $trace_id, $e);
            return Lexi_Security::error(
                'search_error',
                'ØªØ¹Ø°Ø± ØªÙ†ÙÙŠØ° Ø§Ù„Ø¨Ø­Ø« Ø­Ø§Ù„ÙŠØ§Ù‹.',
                500,
                array('trace_id' => $trace_id)
            );
        }
    }
    /**
     * GET /search/trending
     */
    public static function search_trending(WP_REST_Request $request): WP_REST_Response
    {
        $trace_id = self::new_trace_id();
        self::log_route_start('/search/trending', $request, $trace_id);

        try {
            $limit = min(20, max(1, (int) $request->get_param('limit')));
            $cache_key = 'lexi_search_trending_' . $limit;
            $cached = get_transient($cache_key);
            if (is_array($cached)) {
                self::log_route_success('/search/trending', $trace_id, array('cached' => true));
                return Lexi_Security::success($cached);
            }

            $queries = Lexi_Merch::get_trending_searches($limit);
            $payload = array(
                'queries' => $queries,
                'items' => $queries,
            );

            set_transient($cache_key, $payload, 5 * MINUTE_IN_SECONDS);

            self::log_route_success('/search/trending', $trace_id, array('items' => count($queries)));
            return Lexi_Security::success($payload);
        } catch (Throwable $e) {
            self::log_route_error('/search/trending', $trace_id, $e);
            return Lexi_Security::error(
                'trending_error',
                'ØªØ¹Ø°Ø± Ø¬Ù„Ø¨ Ø§Ù„ÙƒÙ„Ù…Ø§Øª Ø§Ù„Ø£ÙƒØ«Ø± Ø¨Ø­Ø«Ø§Ù‹.',
                500,
                array('trace_id' => $trace_id)
            );
        }
    }
    /**
     * GET /products/{id}
     */
    public static function get_product_by_id(WP_REST_Request $request): WP_REST_Response
    {
        $trace_id = self::new_trace_id();
        self::log_route_start('/products/{id}', $request, $trace_id);

        $dependency_error = self::ensure_woocommerce_dependency($trace_id);
        if (null !== $dependency_error) {
            return $dependency_error;
        }

        try {
            $id = (int) $request->get_param('id');
            $product = wc_get_product($id);

            if (!$product || 'publish' !== get_post_status($id)) {
                return Lexi_Security::error('product_not_found', 'Ø§Ù„Ù…Ù†ØªØ¬ ØºÙŠØ± Ù…ÙˆØ¬ÙˆØ¯.', 404, array('trace_id' => $trace_id));
            }

            self::log_route_success('/products/{id}', $trace_id, array('product_id' => $id));
            return Lexi_Security::success(Lexi_Merch::format_product_for_api($product));
        } catch (Throwable $e) {
            self::log_route_error('/products/{id}', $trace_id, $e);
            return Lexi_Security::error('product_error', 'ØªØ¹Ø°Ø± ØªØ­Ù…ÙŠÙ„ Ø¨ÙŠØ§Ù†Ø§Øª Ø§Ù„Ù…Ù†ØªØ¬ Ø­Ø§Ù„ÙŠØ§Ù‹.', 500, array('trace_id' => $trace_id));
        }
    }
    /**
     * GET /products/{id}/reviews
     */
    public static function get_product_reviews(WP_REST_Request $request): WP_REST_Response
    {
        $product_id = (int) $request->get_param('id');
        $page = max(1, (int) $request->get_param('page'));
        $per_page = min(50, max(1, (int) $request->get_param('per_page')));

        $product = wc_get_product($product_id);
        if (!$product || 'publish' !== get_post_status($product_id)) {
            return Lexi_Security::error('product_not_found', 'Ø§Ù„Ù…Ù†ØªØ¬ ØºÙŠØ± Ù…ÙˆØ¬ÙˆØ¯.', 404);
        }

        $args = array(
            'post_id' => $product_id,
            'status' => 'approve',
            'type' => 'review',
            'number' => $per_page,
            'offset' => ($page - 1) * $per_page,
            'orderby' => 'comment_date_gmt',
            'order' => 'DESC',
        );

        $comments = get_comments($args);
        $total = get_comments(array(
            'post_id' => $product_id,
            'status' => 'approve',
            'type' => 'review',
            'count' => true,
        ));

        $items = array();
        foreach ($comments as $comment) {
            $items[] = array(
                'id' => (int) $comment->comment_ID,
                'author' => (string) $comment->comment_author,
                'content' => trim(wp_strip_all_tags((string) $comment->comment_content)),
                'rating' => (int) get_comment_meta((int) $comment->comment_ID, 'rating', true),
                'created_at' => mysql2date('c', (string) $comment->comment_date_gmt),
            );
        }

        return Lexi_Security::success(array(
            'items' => $items,
            'page' => $page,
            'per_page' => $per_page,
            'total' => (int) $total,
            'total_pages' => max(1, (int) ceil(((int) $total) / $per_page)),
        ));
    }

    /**
     * POST /products/{id}/reviews
     */
    public static function create_product_review(WP_REST_Request $request): WP_REST_Response
    {
        $product_id = (int) $request->get_param('id');
        $body = (array) $request->get_json_params();
        if (empty($body)) {
            $body = (array) $request->get_body_params();
        }

        $product = wc_get_product($product_id);
        if (!$product || 'publish' !== get_post_status($product_id)) {
            return Lexi_Security::error('product_not_found', 'Ø§Ù„Ù…Ù†ØªØ¬ ØºÙŠØ± Ù…ÙˆØ¬ÙˆØ¯.', 404);
        }

        $rating = (int) ($body['rating'] ?? 0);
        $content = sanitize_textarea_field((string) ($body['content'] ?? ''));

        if ($rating < 1 || $rating > 5 || '' === trim($content)) {
            return Lexi_Security::error('invalid_review', 'ÙŠØ±Ø¬Ù‰ Ø¥Ø¯Ø®Ø§Ù„ ØªÙ‚ÙŠÙŠÙ… ØµØ­ÙŠØ­ Ù…Ø¹ Ù†Øµ Ø§Ù„Ù…Ø±Ø§Ø¬Ø¹Ø©.', 422);
        }

        $user_id = get_current_user_id();
        if ($user_id <= 0) {
            return Lexi_Security::error('unauthorized', 'ÙŠÙ„Ø²Ù… ØªØ³Ø¬ÙŠÙ„ Ø§Ù„Ø¯Ø®ÙˆÙ„ Ù„Ø¥Ø¶Ø§ÙØ© ØªÙ‚ÙŠÙŠÙ….', 401);
        }

        $user = get_userdata($user_id);
        if (!$user) {
            return Lexi_Security::error('user_not_found', 'Ø§Ù„Ù…Ø³ØªØ®Ø¯Ù… ØºÙŠØ± Ù…ÙˆØ¬ÙˆØ¯.', 404);
        }

        $comment_id = wp_insert_comment(array(
            'comment_post_ID' => $product_id,
            'comment_author' => (string) $user->display_name,
            'comment_author_email' => (string) $user->user_email,
            'comment_content' => $content,
            'comment_type' => 'review',
            'user_id' => $user_id,
            'comment_approved' => 1,
        ));

        if (!$comment_id) {
            return Lexi_Security::error('review_failed', 'ØªØ¹Ø°Ø± Ø¥Ø±Ø³Ø§Ù„ Ø§Ù„ØªÙ‚ÙŠÙŠÙ… Ø­Ø§Ù„ÙŠØ§Ù‹.', 500);
        }

        update_comment_meta($comment_id, 'rating', $rating);
        if (function_exists('wc_update_product_rating_counts')) {
            wc_update_product_rating_counts($product_id);
        }
        if (function_exists('wc_update_product_rating')) {
            wc_update_product_rating($product_id);
        }
        if (function_exists('wc_update_product_review_count')) {
            wc_update_product_review_count($product_id);
        }

        return Lexi_Security::success(array(
            'id' => (int) $comment_id,
            'message' => 'ØªÙ… Ø¥Ø±Ø³Ø§Ù„ Ø§Ù„ØªÙ‚ÙŠÙŠÙ… Ø¨Ù†Ø¬Ø§Ø­.',
        ), 201);
    }

    /**
     * GET /products/{id}/similar
     */
    public static function get_similar_products(WP_REST_Request $request): WP_REST_Response
    {
        $trace_id = self::new_trace_id();
        self::log_route_start('/products/{id}/similar', $request, $trace_id);

        $dependency_error = self::ensure_woocommerce_dependency($trace_id);
        if (null !== $dependency_error) {
            return $dependency_error;
        }

        try {
            $product_id = (int) $request->get_param('id');
            $limit = min(24, max(1, (int) $request->get_param('limit')));

            $product = wc_get_product($product_id);
            if (!$product || 'publish' !== get_post_status($product_id)) {
                return Lexi_Security::error('product_not_found', 'Ø§Ù„Ù…Ù†ØªØ¬ ØºÙŠØ± Ù…ÙˆØ¬ÙˆØ¯.', 404, array('trace_id' => $trace_id));
            }

            $terms = get_the_terms($product_id, 'product_cat');
            if (!$terms || is_wp_error($terms)) {
                return Lexi_Security::success(array());
            }

            $term_ids = array();
            foreach ($terms as $term) {
                $term_ids[] = (int) $term->term_id;
            }

            if (empty($term_ids)) {
                return Lexi_Security::success(array());
            }

            $query = new WP_Query(array(
                'post_type' => 'product',
                'post_status' => 'publish',
                'posts_per_page' => $limit,
                'post__not_in' => array($product_id),
                'orderby' => 'date',
                'order' => 'DESC',
                'tax_query' => array(
                    array(
                        'taxonomy' => 'product_cat',
                        'field' => 'term_id',
                        'terms' => $term_ids,
                    ),
                ),
            ));

            $items = array();
            foreach ($query->posts as $post) {
                $item = wc_get_product((int) $post->ID);
                if (!$item instanceof WC_Product) {
                    continue;
                }
                $items[] = Lexi_Merch::format_product_for_api($item);
            }

            self::log_route_success('/products/{id}/similar', $trace_id, array(
                'product_id' => $product_id,
                'items' => count($items),
            ));
            return Lexi_Security::success($items);
        } catch (Throwable $e) {
            self::log_route_error('/products/{id}/similar', $trace_id, $e);
            return Lexi_Security::error('similar_error', 'ØªØ¹Ø°Ø± ØªØ­Ù…ÙŠÙ„ Ù…Ù†ØªØ¬Ø§Øª Ù…Ø´Ø§Ø¨Ù‡Ø© Ø­Ø§Ù„ÙŠØ§Ù‹.', 500, array('trace_id' => $trace_id));
        }
    }
    /**
     * GET /categories
     */
    public static function get_categories(WP_REST_Request $request): WP_REST_Response
    {
        $trace_id = self::new_trace_id();
        self::log_route_start('/categories', $request, $trace_id);

        $dependency_error = self::ensure_woocommerce_dependency($trace_id);
        if (null !== $dependency_error) {
            return $dependency_error;
        }

        try {
            $include_empty = Lexi_Merch::bool_int($request->get_param('include_empty')) === 1;
            $view = self::normalize_categories_view($request);
            $cache_key = 'lexi_categories_list_v2_' . md5(($include_empty ? '1' : '0') . '|' . $view);
            $cached = get_transient($cache_key);
            if (is_array($cached)) {
                self::log_route_success('/categories', $trace_id, array(
                    'count' => count($cached),
                    'view' => $view,
                    'cached' => true,
                ));
                return Lexi_Security::success($cached);
            }

            $rows = 'categories_page' === $view
                ? self::get_categories_page_ordered_rows(!$include_empty)
                : Lexi_Merch::get_admin_ordered_category_rows(!$include_empty);
            $children_count_map = self::build_children_count_map($rows);
            $categories = array();

            foreach ($rows as $index => $row) {
                $term = isset($row['term']) && $row['term'] instanceof WP_Term
                    ? $row['term']
                    : null;
                if (!$term instanceof WP_Term) {
                    continue;
                }

                $term_id = (int) $term->term_id;
                $category = self::format_category($term, (int) ($children_count_map[$term_id] ?? 0));
                $category['depth'] = max(0, (int) ($row['depth'] ?? 0));
                $category['admin_order_index'] = (int) $index;
                $category['order_index'] = (int) $index;
                if ('categories_page' === $view) {
                    $category['categories_page_order_index'] = (int) $index;
                }
                $categories[] = $category;
            }

            set_transient($cache_key, $categories, self::CATEGORIES_CACHE_TTL);

            self::log_route_success('/categories', $trace_id, array(
                'count' => count($categories),
                'view' => $view,
            ));
            return Lexi_Security::success($categories);
        } catch (Throwable $e) {
            self::log_route_error('/categories', $trace_id, $e);
            return Lexi_Security::error('categories_error', 'ØªØ¹Ø°Ø± ØªØ­Ù…ÙŠÙ„ Ø§Ù„ØªØµÙ†ÙŠÙØ§Øª Ø­Ø§Ù„ÙŠØ§Ù‹.', 500, array('trace_id' => $trace_id));
        }
    }
    /**
     * GET /categories/{id}
     */
    public static function get_category_by_id(WP_REST_Request $request): WP_REST_Response
    {
        $trace_id = self::new_trace_id();
        self::log_route_start('/categories/{id}', $request, $trace_id);

        $dependency_error = self::ensure_woocommerce_dependency($trace_id);
        if (null !== $dependency_error) {
            return $dependency_error;
        }

        try {
            $id = (int) $request->get_param('id');
            $term = get_term($id, 'product_cat');

            if (!$term || is_wp_error($term)) {
                return Lexi_Security::error('category_not_found', 'Ø§Ù„ØªØµÙ†ÙŠÙ ØºÙŠØ± Ù…ÙˆØ¬ÙˆØ¯.', 404, array('trace_id' => $trace_id));
            }

            self::log_route_success('/categories/{id}', $trace_id, array('category_id' => $id));
            return Lexi_Security::success(self::format_category($term));
        } catch (Throwable $e) {
            self::log_route_error('/categories/{id}', $trace_id, $e);
            return Lexi_Security::error('category_error', 'ØªØ¹Ø°Ø± ØªØ­Ù…ÙŠÙ„ Ø§Ù„ØªØµÙ†ÙŠÙ Ø­Ø§Ù„ÙŠØ§Ù‹.', 500, array('trace_id' => $trace_id));
        }
    }
    /**
     * GET /home/sections
     */
    public static function get_home_sections(WP_REST_Request $request): WP_REST_Response
    {
        $trace_id = self::new_trace_id();
        self::log_route_start('/home/sections', $request, $trace_id);

        $dependency_error = self::ensure_woocommerce_dependency($trace_id);
        if (null !== $dependency_error) {
            return $dependency_error;
        }

        try {
            $items_limit = min(50, max(1, (int) $request->get_param('items_limit')));
            $include_unpriced = Lexi_Merch::bool_int($request->get_param('include_unpriced')) === 1;
            $cache_key = 'lexi_home_sections_v2_' . md5($items_limit . '|' . ($include_unpriced ? '1' : '0'));
            $cached = get_transient($cache_key);
            if (is_array($cached)) {
                self::log_route_success('/home/sections', $trace_id, array(
                    'sections' => count($cached),
                    'cached' => true,
                ));
                return Lexi_Security::success($cached);
            }

            $sections = Lexi_Merch::get_home_sections(true);

            $data = array();
            foreach ($sections as $section) {
                $resolved_items = Lexi_Merch::resolve_products_for_section($section, $items_limit, !$include_unpriced);

                $data[] = array(
                    'id' => (int) ($section['id'] ?? 0),
                    'title_ar' => self::normalize_text($section['title_ar'] ?? ''),
                    'type' => (string) ($section['type'] ?? 'manual_products'),
                    'term_id' => isset($section['term_id']) ? (int) $section['term_id'] : null,
                    'sort_order' => (int) ($section['sort_order'] ?? 0),
                    'items' => $resolved_items,
                );
            }

            set_transient($cache_key, $data, self::HOME_SECTIONS_CACHE_TTL);

            self::log_route_success('/home/sections', $trace_id, array('sections' => count($data)));
            return Lexi_Security::success($data);
        } catch (Throwable $e) {
            self::log_route_error('/home/sections', $trace_id, $e);
            return Lexi_Security::error('home_sections_error', 'ØªØ¹Ø°Ø± ØªØ­Ù…ÙŠÙ„ Ø£Ù‚Ø³Ø§Ù… Ø§Ù„ØµÙØ­Ø© Ø§Ù„Ø±Ø¦ÙŠØ³ÙŠØ© Ø­Ø§Ù„ÙŠØ§Ù‹.', 500, array('trace_id' => $trace_id));
        }
    }
    /**
     * GET /home/ad-banners
     */
    public static function get_home_ad_banners(WP_REST_Request $request): WP_REST_Response
    {
        $trace_id = self::new_trace_id();
        self::log_route_start('/home/ad-banners', $request, $trace_id);

        try {
            $include_inactive = Lexi_Merch::bool_int($request->get_param('include_inactive')) === 1;
            $items = Lexi_Merch::get_home_ad_banners(!$include_inactive);

            self::log_route_success('/home/ad-banners', $trace_id, array('items' => count($items)));
            return Lexi_Security::success($items);
        } catch (Throwable $e) {
            self::log_route_error('/home/ad-banners', $trace_id, $e);
            return Lexi_Security::error('home_ad_banners_error', 'Unable to load ad banners right now.', 500, array('trace_id' => $trace_id));
        }
    }

    /**
     * GET /shipping/cities
     */
    public static function get_shipping_cities(WP_REST_Request $request): WP_REST_Response
    {
        $cache_key = 'lexi_shipping_cities_v1';
        $cached = get_transient($cache_key);
        if (is_array($cached)) {
            return Lexi_Security::success($cached);
        }

        $cities = Lexi_Shipping_Cities::get_active();

        $cities = array_map(function ($city) {
            return array(
                'id' => (int) $city['id'],
                'name' => self::normalize_text($city['name'] ?? ''),
                'price' => (float) $city['price'],
                'sort_order' => (int) $city['sort_order'],
            );
        }, $cities);

        set_transient($cache_key, $cities, self::SHIPPING_CITIES_CACHE_TTL);
        return Lexi_Security::success($cities);
    }

    /**
     * GET /shipping/rate?city_id=
     */
    public static function get_shipping_rate(WP_REST_Request $request): WP_REST_Response
    {
        $city_id = absint((int) $request->get_param('city_id'));
        if ($city_id <= 0) {
            return Lexi_Security::error('city_not_found', 'المدينة غير موجودة أو غير متاحة.', 404);
        }

        $cache_key = 'lexi_shipping_rate_v1_' . $city_id;
        $cached = get_transient($cache_key);
        if (is_array($cached)) {
            return Lexi_Security::success($cached);
        }

        $city = Lexi_Shipping_Cities::get_by_id($city_id);

        if (!$city || !$city['is_active']) {
            return Lexi_Security::error('city_not_found', 'Ø§Ù„Ù…Ø¯ÙŠÙ†Ø© ØºÙŠØ± Ù…ÙˆØ¬ÙˆØ¯Ø© Ø£Ùˆ ØºÙŠØ± Ù…ØªØ§Ø­Ø©.', 404);
        }

        $payload = array(
            'city_id' => (int) $city['id'],
            'name' => self::normalize_text($city['name'] ?? ''),
            'price' => (float) $city['price'],
            'rate' => (float) $city['price'],
        );

        set_transient($cache_key, $payload, self::SHIPPING_RATE_CACHE_TTL);
        return Lexi_Security::success($payload);
    }

    /**
     * GET /payments/shamcash/config
     */
    public static function get_shamcash_config(WP_REST_Request $request): WP_REST_Response
    {
        return Lexi_Security::success(array(
            'account_name' => self::normalize_text(get_option('lexi_shamcash_account_name', '')),
            'qr_value' => get_option('lexi_shamcash_qr_value', ''),
            'barcode_value' => get_option('lexi_shamcash_barcode_value', ''),
            'instructions_ar' => self::normalize_text(get_option('lexi_shamcash_instructions_ar', '')),
        ));
    }

    /**
     * @return array<string, mixed>
     */
    private static function get_products_manual_in_category(
        int $category_id,
        int $page,
        int $per_page,
        string $search,
        $min_price,
        $max_price,
        bool $include_unpriced = false,
        int $brand_term_id = 0,
        string $brand_token = '',
        string $brand_taxonomy = ''
    ): array {
        $ids = Lexi_Merch::get_manual_sorted_product_ids_for_category($category_id, $search);
        $order_map = Lexi_Merch::get_category_order_map($category_id);

        $filtered_ids = array();
        $cache = array();

        foreach ($ids as $id) {
            $product = wc_get_product((int) $id);
            if (!$product instanceof WC_Product) {
                continue;
            }

            if ('publish' !== get_post_status((int) $id)) {
                continue;
            }

            $prices = Lexi_Merch::resolve_product_prices($product);
            $price = (float) ($prices['price'] ?? 0.0);
            if (!self::price_in_range($price, $min_price, $max_price)) {
                continue;
            }
            if (!$include_unpriced && !Lexi_Merch::has_display_price($product)) {
                continue;
            }
            if (!self::product_matches_brand_filter($product, $brand_term_id, $brand_token, $brand_taxonomy)) {
                continue;
            }

            $cache[(int) $id] = $product;
            $filtered_ids[] = (int) $id;
        }

        $total = count($filtered_ids);
        $offset = ($page - 1) * $per_page;
        $paged_ids = array_slice($filtered_ids, $offset, $per_page);

        $items = array();
        foreach ($paged_ids as $id) {
            $product = $cache[$id] ?? wc_get_product($id);
            if (!$product instanceof WC_Product) {
                continue;
            }

            $items[] = self::format_product_for_listing(
                $product,
                $category_id,
                $order_map,
                $brand_taxonomy
            );
        }

        $total_pages = max(1, (int) ceil($total / $per_page));
        return array(
            'items' => $items,
            'page' => $page,
            'per_page' => $per_page,
            'total' => $total,
            'total_pages' => $total_pages,
            'has_more' => $page < $total_pages,
        );
    }

    /**
     * @return array<string, mixed>
     */
    private static function get_products_by_query(
        int $category_id,
        int $page,
        int $per_page,
        string $search,
        $min_price,
        $max_price,
        string $sort,
        bool $include_unpriced = false,
        int $brand_term_id = 0,
        string $brand_token = '',
        string $brand_taxonomy = ''
    ): array {
        $args = array(
            'post_type' => 'product',
            'post_status' => 'publish',
            'posts_per_page' => $per_page,
            'paged' => $page,
            'fields' => 'ids',
            'ignore_sticky_posts' => true,
            'orderby' => 'date',
            'order' => 'DESC',
        );

        $tax_query = array();
        if ($category_id > 0) {
            $tax_query[] = array(
                'taxonomy' => 'product_cat',
                'field' => 'term_id',
                'terms' => array($category_id),
            );
        }

        $has_brand_filter = $brand_term_id > 0 || '' !== trim($brand_token);
        if ($has_brand_filter && '' !== $brand_taxonomy) {
            $brand_terms = array();
            $brand_field = 'slug';
            if ($brand_term_id > 0) {
                $brand_terms = array($brand_term_id);
                $brand_field = 'term_id';
            } else {
                $brand_terms = array(sanitize_title($brand_token));
                if ('' === trim($brand_terms[0])) {
                    $brand_terms = array($brand_token);
                }
            }

            $tax_query[] = array(
                'taxonomy' => $brand_taxonomy,
                'field' => $brand_field,
                'terms' => $brand_terms,
            );
        }
        if (!empty($tax_query)) {
            if (count($tax_query) > 1) {
                $tax_query['relation'] = 'AND';
            }
            $args['tax_query'] = $tax_query;
        }

        if ($has_brand_filter && '' === $brand_taxonomy && '' === $search && '' !== $brand_token) {
            $search = $brand_token;
        }

        if ('' !== $search) {
            $args['s'] = $search;
        }

        $meta_query = array();
        if ('' !== (string) $min_price && is_numeric($min_price)) {
            $meta_query[] = array(
                'key' => '_price',
                'value' => (float) $min_price,
                'compare' => '>=',
                'type' => 'NUMERIC',
            );
        }
        if ('' !== (string) $max_price && is_numeric($max_price)) {
            $meta_query[] = array(
                'key' => '_price',
                'value' => (float) $max_price,
                'compare' => '<=',
                'type' => 'NUMERIC',
            );
        }
        if (!$include_unpriced) {
            $meta_query[] = array(
                'key' => '_price',
                'value' => 0,
                'compare' => '>',
                'type' => 'NUMERIC',
            );
        }

        if (!empty($meta_query)) {
            $meta_query['relation'] = 'AND';
            $args['meta_query'] = $meta_query; // phpcs:ignore
        }

        if ('newest' === $sort || 'manual' === $sort) {
            $args['orderby'] = 'date';
            $args['order'] = 'DESC';
        } elseif ('price_asc' === $sort) {
            $args['meta_key'] = '_price';
            $args['orderby'] = 'meta_value_num';
            $args['order'] = 'ASC';
        } elseif ('price_desc' === $sort) {
            $args['meta_key'] = '_price';
            $args['orderby'] = 'meta_value_num';
            $args['order'] = 'DESC';
        } elseif ('top_rated' === $sort) {
            $args['meta_key'] = '_wc_average_rating';
            $args['orderby'] = 'meta_value_num';
            $args['order'] = 'DESC';
        } elseif ('best_selling' === $sort) {
            $args['meta_key'] = 'total_sales';
            $args['orderby'] = 'meta_value_num';
            $args['order'] = 'DESC';
        } elseif ('flash_deals' === $sort) {
            $flash_ids = Lexi_Merch::get_active_flash_deal_ids(false);
            $flash_ids = array_values(array_filter(array_map('intval', is_array($flash_ids) ? $flash_ids : array())));
            if (empty($flash_ids)) {
                return array(
                    'items' => array(),
                    'page' => $page,
                    'per_page' => $per_page,
                    'total' => 0,
                    'total_pages' => 1,
                    'has_more' => false,
                );
            }
            $args['post__in'] = $flash_ids;
            $args['orderby'] = 'date';
            $args['order'] = 'DESC';
        } elseif ('on_sale' === $sort) {
            $sale_ids = wc_get_product_ids_on_sale();
            $sale_ids = array_values(array_filter(array_map('intval', is_array($sale_ids) ? $sale_ids : array())));
            if (empty($sale_ids)) {
                return array(
                    'items' => array(),
                    'page' => $page,
                    'per_page' => $per_page,
                    'total' => 0,
                    'total_pages' => 1,
                    'has_more' => false,
                );
            }
            $args['post__in'] = $sale_ids;
            $args['orderby'] = 'date';
            $args['order'] = 'DESC';
        }

        $order_map = $category_id > 0 ? Lexi_Merch::get_category_order_map($category_id) : null;

        if ($has_brand_filter && '' === $brand_taxonomy) {
            $ids_query_args = $args;
            $ids_query_args['fields'] = 'ids';
            $ids_query_args['posts_per_page'] = -1;
            $ids_query_args['paged'] = 1;
            $ids_query_args['no_found_rows'] = true;
            $ids_query_args['ignore_sticky_posts'] = true;

            $ids_query = new WP_Query($ids_query_args);
            $all_ids = is_array($ids_query->posts) ? $ids_query->posts : array();
            $matched_ids = array();
            foreach ($all_ids as $raw_id) {
                $id = (int) $raw_id;
                if ($id <= 0) {
                    continue;
                }
                $product = wc_get_product($id);
                if (!$product instanceof WC_Product) {
                    continue;
                }
                if (!self::product_matches_brand_filter($product, $brand_term_id, $brand_token, $brand_taxonomy)) {
                    continue;
                }
                if (!$include_unpriced && !Lexi_Merch::has_display_price($product)) {
                    continue;
                }
                $matched_ids[] = $id;
            }

            $total = count($matched_ids);
            $total_pages = max(1, (int) ceil($total / $per_page));
            $offset = ($page - 1) * $per_page;
            $paged_ids = array_slice($matched_ids, $offset, $per_page);

            $items = array();
            foreach ($paged_ids as $id) {
                $product = wc_get_product((int) $id);
                if (!$product instanceof WC_Product) {
                    continue;
                }
                $items[] = self::format_product_for_listing(
                    $product,
                    $category_id > 0 ? $category_id : null,
                    $order_map,
                    $brand_taxonomy
                );
            }

            return array(
                'items' => $items,
                'page' => $page,
                'per_page' => $per_page,
                'total' => $total,
                'total_pages' => $total_pages,
                'has_more' => $page < $total_pages,
            );
        }

        $query = new WP_Query($args);

        $items = array();
        $current_q_page = $page;
        $max_q_pages = (int) $query->max_num_pages;
        $internal_page_limit = 2;
        $pages_tried = 1;

        while (count($items) < $per_page && $pages_tried <= $internal_page_limit) {
            foreach ($query->posts as $post_id) {
                if (count($items) >= $per_page) {
                    break;
                }

                $product = wc_get_product((int) $post_id);
                if (!$product instanceof WC_Product) {
                    continue;
                }
                if (!$include_unpriced && !Lexi_Merch::has_display_price($product)) {
                    continue;
                }
                if (!self::product_matches_brand_filter($product, $brand_term_id, $brand_token, $brand_taxonomy)) {
                    continue;
                }

                $items[] = self::format_product_for_listing(
                    $product,
                    $category_id > 0 ? $category_id : null,
                    $order_map,
                    $brand_taxonomy
                );
            }

            if (count($items) >= $per_page || $current_q_page >= $max_q_pages) {
                break;
            }

            $pages_tried++;
            $current_q_page++;
            $args['paged'] = $current_q_page;
            $query = new WP_Query($args);
            if (empty($query->posts)) {
                break;
            }
        }

        $total = (int) $query->found_posts;
        $total_pages = max(1, (int) ceil($total / $per_page));

        return array(
            'items' => $items,
            'page' => $page,
            'per_page' => $per_page,
            'total' => $total,
            'total_pages' => $total_pages,
            'has_more' => $current_q_page < $max_q_pages || count($items) >= $per_page,
        );
    }

    /**
     * @param array<string, mixed> $payload
     * @param array<string, mixed> $brand_filter
     * @return array<string, mixed>
     */
    private static function attach_products_filter_meta(
        array $payload,
        int $category_id,
        array $brand_filter
    ): array {
        $page = max(1, (int) ($payload['page'] ?? 1));
        $per_page = max(1, (int) ($payload['per_page'] ?? 20));
        $total = max(0, (int) ($payload['total'] ?? 0));
        $total_pages = max(1, (int) ($payload['total_pages'] ?? 1));

        $payload['page'] = $page;
        $payload['per_page'] = $per_page;
        $payload['total'] = $total;
        $payload['total_pages'] = $total_pages;
        $payload['has_more'] = isset($payload['has_more'])
            ? (bool) $payload['has_more']
            : ($page < $total_pages || ($total > 0 && ($page * $per_page) < $total));

        if ($category_id > 0) {
            $term = get_term($category_id, 'product_cat');
            if ($term && !is_wp_error($term)) {
                $payload['filter_type'] = 'category';
                $payload['filter_id'] = (int) $term->term_id;
                $payload['filter_name'] = self::normalize_text($term->name ?? '');
                $payload['filter_description'] = self::normalize_text(
                    wp_strip_all_tags((string) ($term->description ?? ''))
                );
            }
        } else {
            $brand_id = (int) ($brand_filter['id'] ?? 0);
            $brand_name = self::normalize_text((string) ($brand_filter['name'] ?? ''));
            if ('' === $brand_name) {
                $brand_name = self::normalize_text((string) ($brand_filter['token'] ?? ''));
            }
            $brand_description = self::normalize_text(
                wp_strip_all_tags((string) ($brand_filter['description'] ?? ''))
            );
            if ($brand_id > 0 || '' !== $brand_name) {
                $payload['filter_type'] = 'brand';
                $payload['filter_id'] = $brand_id > 0 ? $brand_id : null;
                $payload['filter_name'] = $brand_name;
                $payload['filter_description'] = $brand_description;
            }
        }

        return $payload;
    }

    /**
     * @return array<string, mixed>
     */
    private static function resolve_brand_filter(WP_REST_Request $request): array
    {
        $raw_brand = trim((string) $request->get_param('brand'));
        $brand_id = absint((int) $request->get_param('brand_id'));

        if ($brand_id <= 0 && '' !== $raw_brand && is_numeric($raw_brand)) {
            $brand_id = absint((int) $raw_brand);
        }

        $taxonomy = self::resolve_brand_taxonomy();
        $term = null;

        if ('' !== $taxonomy && $brand_id > 0) {
            $candidate = get_term($brand_id, $taxonomy);
            if ($candidate && !is_wp_error($candidate)) {
                $term = $candidate;
            }
        }

        if ('' !== $taxonomy && (!$term || is_wp_error($term)) && '' !== $raw_brand) {
            $candidate = get_term_by('slug', sanitize_title($raw_brand), $taxonomy);
            if (!$candidate || is_wp_error($candidate)) {
                $candidate = get_term_by('name', $raw_brand, $taxonomy);
            }
            if ($candidate && !is_wp_error($candidate)) {
                $term = $candidate;
            }
        }

        if ($term && !is_wp_error($term)) {
            return array(
                'id' => (int) $term->term_id,
                'taxonomy' => $taxonomy,
                'token' => (string) ($term->slug ?? ''),
                'name' => self::normalize_text($term->name ?? ''),
                'description' => self::normalize_text(
                    wp_strip_all_tags((string) ($term->description ?? ''))
                ),
            );
        }

        return array(
            'id' => $brand_id,
            'taxonomy' => $taxonomy,
            'token' => self::normalize_text($raw_brand),
            'name' => '',
            'description' => '',
        );
    }

    private static function resolve_brand_taxonomy(): string
    {
        foreach (self::brand_taxonomy_candidates() as $taxonomy) {
            if (taxonomy_exists($taxonomy)) {
                return $taxonomy;
            }
        }

        return '';
    }

    /**
     * @return array<int, string>
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

    /**
     * @return array{id:int,name:string}
     */
    private static function resolve_product_brand(
        WC_Product $product,
        string $brand_taxonomy = ''
    ): array {
        $taxonomy = '' !== $brand_taxonomy ? $brand_taxonomy : self::resolve_brand_taxonomy();
        if ('' !== $taxonomy) {
            $terms = get_the_terms($product->get_id(), $taxonomy);
            if (is_array($terms) && !empty($terms)) {
                $first = array_shift($terms);
                if ($first && !is_wp_error($first)) {
                    return array(
                        'id' => (int) ($first->term_id ?? 0),
                        'name' => self::normalize_text($first->name ?? ''),
                    );
                }
            }
        }

        $attributes = $product->get_attributes();
        foreach ($attributes as $attribute) {
            if (!$attribute instanceof WC_Product_Attribute) {
                continue;
            }

            $attribute_name = strtolower(self::normalize_text($attribute->get_name()));
            $attribute_label = strtolower(self::normalize_text(wc_attribute_label($attribute->get_name())));
            $is_brand_attribute =
                false !== strpos($attribute_name, 'brand')
                || false !== strpos($attribute_label, 'brand')
                || false !== strpos($attribute_label, 'العلام')
                || false !== strpos($attribute_label, 'مارك');
            if (!$is_brand_attribute) {
                continue;
            }

            if ($attribute->is_taxonomy()) {
                $terms = wc_get_product_terms(
                    (int) $product->get_id(),
                    $attribute->get_name(),
                    array('fields' => 'all')
                );
                if (is_array($terms) && !empty($terms)) {
                    $first = array_shift($terms);
                    if ($first && !is_wp_error($first)) {
                        return array(
                            'id' => (int) ($first->term_id ?? 0),
                            'name' => self::normalize_text($first->name ?? ''),
                        );
                    }
                }
                continue;
            }

            $options = $attribute->get_options();
            if (is_array($options) && !empty($options)) {
                return array(
                    'id' => 0,
                    'name' => self::normalize_text((string) $options[0]),
                );
            }
        }

        return array('id' => 0, 'name' => '');
    }

    private static function product_matches_brand_filter(
        WC_Product $product,
        int $brand_term_id = 0,
        string $brand_token = '',
        string $brand_taxonomy = ''
    ): bool {
        $token = strtolower(trim(self::normalize_text($brand_token)));
        if ($brand_term_id <= 0 && '' === $token) {
            return true;
        }

        if ('' !== $brand_taxonomy) {
            if ($brand_term_id > 0 && has_term($brand_term_id, $brand_taxonomy, $product->get_id())) {
                return true;
            }
            if ('' !== $token) {
                if (has_term($token, $brand_taxonomy, $product->get_id())) {
                    return true;
                }
                if (has_term(sanitize_title($token), $brand_taxonomy, $product->get_id())) {
                    return true;
                }
            }
        }

        $brand = self::resolve_product_brand($product, $brand_taxonomy);
        if ($brand_term_id > 0 && (int) $brand['id'] === $brand_term_id) {
            return true;
        }

        if ('' === $token) {
            return false;
        }

        $brand_name = strtolower(trim((string) $brand['name']));
        if ('' !== $brand_name && false !== strpos($brand_name, $token)) {
            return true;
        }

        $haystack = strtolower(self::normalize_text(
            $product->get_name() . ' ' . wp_strip_all_tags((string) $product->get_short_description())
        ));
        return false !== strpos($haystack, $token);
    }

    /**
     * @param array<int, array{pinned: bool, sort_order: int}>|null $order_map
     * @return array<string, mixed>
     */
    private static function format_product_for_listing(
        WC_Product $product,
        ?int $context_term_id = null,
        ?array $order_map = null,
        string $brand_taxonomy = ''
    ): array {
        $full = Lexi_Merch::format_product_for_list_api($product, $context_term_id, $order_map);
        $brand = self::resolve_product_brand($product, $brand_taxonomy);

        $image = self::pick_primary_image_url($full);
        $card_images = array();
        if (isset($full['card_images']) && is_array($full['card_images'])) {
            foreach ($full['card_images'] as $raw_url) {
                $url = trim((string) $raw_url);
                if ('' === $url) {
                    continue;
                }
                $card_images[] = $url;
            }
        }
        if (empty($card_images) && '' !== $image) {
            $card_images[] = $image;
        }

        $images = array();
        if ('' !== $image) {
            $images[] = $image;
        }
        if (isset($full['images']) && is_array($full['images'])) {
            foreach ($full['images'] as $entry) {
                if (!is_array($entry)) {
                    continue;
                }
                $src = trim((string) ($entry['src'] ?? ''));
                if ('' !== $src) {
                    $images[] = $src;
                }
            }
        }
        $images = array_values(array_unique($images));

        return array(
            'id' => (int) ($full['id'] ?? $product->get_id()),
            'name' => self::normalize_text($full['name'] ?? $product->get_name()),
            'price' => $full['price'] ?? null,
            'regular_price' => $full['regular_price'] ?? null,
            'sale_price' => $full['sale_price'] ?? null,
            'image' => $image,
            'featured_image' => $image,
            'images' => $images,
            'card_images' => array_values(array_unique($card_images)),
            'categories' => isset($full['categories']) && is_array($full['categories'])
                ? $full['categories']
                : array(),
            'category_ids' => isset($full['category_ids']) && is_array($full['category_ids'])
                ? array_values(array_map('intval', $full['category_ids']))
                : array(),
            'stock_status' => (string) ($full['stock_status'] ?? $product->get_stock_status()),
            'in_stock' => (bool) ($full['in_stock'] ?? $product->is_in_stock()),
            'rating' => isset($full['rating']) ? (float) $full['rating'] : (float) $product->get_average_rating(),
            'reviews_count' => isset($full['reviews_count']) ? (int) $full['reviews_count'] : (int) $product->get_review_count(),
            'short_description' => self::normalize_text((string) ($full['short_description'] ?? '')),
            'description' => self::normalize_text((string) ($full['description'] ?? '')),
            'wishlist_count' => isset($full['wishlist_count']) ? (int) $full['wishlist_count'] : 0,
            'date_on_sale_to' => isset($full['date_on_sale_to']) ? (int) $full['date_on_sale_to'] : null,
            'brand_id' => (int) $brand['id'] > 0 ? (int) $brand['id'] : null,
            'brand_name' => (string) $brand['name'],
        );
    }

    /**
     * @param array<string, mixed> $payload
     */
    private static function pick_primary_image_url(array $payload): string
    {
        $featured = trim((string) ($payload['featured_image'] ?? ''));
        if ('' !== $featured) {
            return $featured;
        }

        $image = isset($payload['image']) && is_array($payload['image'])
            ? $payload['image']
            : array();
        foreach (array('large', 'medium', 'thumb') as $size) {
            $candidate = trim((string) ($image[$size] ?? ''));
            if ('' !== $candidate) {
                return $candidate;
            }
        }

        if (isset($payload['card_images']) && is_array($payload['card_images']) && !empty($payload['card_images'])) {
            return trim((string) $payload['card_images'][0]);
        }

        return '';
    }

    private static function price_in_range(float $price, $min_price, $max_price): bool
    {
        if ('' !== (string) $min_price && is_numeric($min_price) && $price < (float) $min_price) {
            return false;
        }

        if ('' !== (string) $max_price && is_numeric($max_price) && $price > (float) $max_price) {
            return false;
        }

        return true;
    }

    private static function normalize_sort(string $raw): string
    {
        $value = strtolower(trim($raw));
        $allowed = array(
            'manual',
            'newest',
            'price_asc',
            'price_desc',
            'top_rated',
            'on_sale',
            'flash_deals',
            'best_selling',
        );

        return in_array($value, $allowed, true) ? $value : 'manual';
    }

    /**
     * @return array<int, int>
     */
    private static function get_search_candidate_product_ids(string $query, int $limit = 200): array
    {
        global $wpdb;

        $query = trim($query);
        if ('' === $query) {
            return array();
        }

        $limit = max(1, min(500, $limit));

        $search_ids = get_posts(array(
            'post_type' => 'product',
            'post_status' => 'publish',
            'fields' => 'ids',
            'posts_per_page' => $limit,
            'no_found_rows' => true,
            'ignore_sticky_posts' => true,
            'orderby' => 'date',
            'order' => 'DESC',
            's' => $query,
        ));

        $like = '%' . $wpdb->esc_like($query) . '%';
        $sku_ids = $wpdb->get_col(
            $wpdb->prepare(
                "SELECT DISTINCT p.ID
                 FROM {$wpdb->posts} p
                 INNER JOIN {$wpdb->postmeta} pm ON pm.post_id = p.ID
                 WHERE p.post_type = 'product'
                   AND p.post_status = 'publish'
                   AND pm.meta_key = '_sku'
                   AND pm.meta_value LIKE %s
                 ORDER BY p.post_date DESC
                 LIMIT %d",
                $like,
                $limit
            )
        );

        $ids = array_values(array_unique(array_map('intval', array_merge(
            is_array($search_ids) ? $search_ids : array(),
            is_array($sku_ids) ? $sku_ids : array()
        ))));

        if (count($ids) > $limit) {
            $ids = array_slice($ids, 0, $limit);
        }

        return $ids;
    }

    /**
     * @param array<int, string> $candidates
     * @return array<int, string>
     */
    private static function build_query_suggestions(string $query, array $candidates, int $limit = 10): array
    {
        $limit = max(1, min(20, $limit));
        $normalized_query = strtolower(trim($query));
        $seen = array();
        $suggestions = array();

        $base = trim($query);
        if ('' !== $base) {
            $seen[strtolower($base)] = true;
            $suggestions[] = $base;
        }

        foreach ($candidates as $candidate) {
            $text = trim((string) $candidate);
            if ('' === $text) {
                continue;
            }

            $normalized = strtolower($text);
            if (isset($seen[$normalized])) {
                continue;
            }

            if ('' !== $normalized_query && false === stripos($normalized, $normalized_query)) {
                continue;
            }

            $seen[$normalized] = true;
            $suggestions[] = $text;
            if (count($suggestions) >= $limit) {
                break;
            }
        }

        return $suggestions;
    }

    private static function highlight_prefix(string $query): string
    {
        $query = trim($query);
        if ('' === $query) {
            return '';
        }

        if (function_exists('mb_substr')) {
            return (string) mb_substr($query, 0, 24);
        }

        return substr($query, 0, 24);
    }

    private static function search_query_length(string $query): int
    {
        $query = trim($query);
        if ('' === $query) {
            return 0;
        }

        if (function_exists('mb_strlen')) {
            return (int) mb_strlen($query);
        }

        return strlen($query);
    }

    private static function normalize_search_sort(string $raw): string
    {
        $value = strtolower(trim($raw));
        $allowed = array('relevance', 'newest', 'price_asc', 'price_desc', 'top_rated', 'on_sale');
        return in_array($value, $allowed, true) ? $value : 'relevance';
    }

    private static function resolve_category_id(WP_REST_Request $request): int
    {
        $category_id = absint((int) $request->get_param('category_id'));
        if ($category_id > 0) {
            return $category_id;
        }

        $legacy_category = trim((string) $request->get_param('category'));
        if ('' === $legacy_category) {
            return 0;
        }

        if (is_numeric($legacy_category)) {
            return absint((int) $legacy_category);
        }

        $term = get_term_by('slug', $legacy_category, 'product_cat');
        if ($term && !is_wp_error($term)) {
            return (int) $term->term_id;
        }

        return 0;
    }

    private static function new_trace_id(): string
    {
        try {
            return 'lexi_' . wp_generate_uuid4();
        } catch (Throwable $e) {
            return 'lexi_' . uniqid('', true);
        }
    }

    private static function logger(): ?WC_Logger
    {
        if (function_exists('wc_get_logger')) {
            return wc_get_logger();
        }
        return null;
    }

    /**
     * @param array<string, mixed> $context
     */
    private static function log(string $level, string $message, array $context = array()): void
    {
        $context['source'] = self::LOG_SOURCE;

        $logger = self::logger();
        if ($logger instanceof WC_Logger && method_exists($logger, $level)) {
            $logger->{$level}($message, $context);
            return;
        }

        if (defined('WP_DEBUG') && WP_DEBUG) {
            error_log('[lexi-api-public] ' . $message . ' | ' . wp_json_encode($context));
        }
    }

    private static function ensure_woocommerce_dependency(string $trace_id): ?WP_REST_Response
    {
        if (class_exists('WooCommerce') && function_exists('wc_get_product')) {
            return null;
        }

        self::log('error', 'WooCommerce dependency missing', array('trace_id' => $trace_id));
        return Lexi_Security::error(
            'dependency_missing',
            'ØªØ¹Ø°Ø± ØªÙ†ÙÙŠØ° Ø§Ù„Ø·Ù„Ø¨ Ù„Ø£Ù† WooCommerce ØºÙŠØ± Ù…ÙØ¹Ù‘Ù„.',
            503,
            array(
                'dependency' => 'woocommerce',
                'trace_id' => $trace_id,
            )
        );
    }

    private static function log_route_start(string $route, WP_REST_Request $request, string $trace_id): void
    {
        $params = $request->get_params();
        unset($params['password'], $params['token'], $params['authorization']);

        self::log('info', 'route.start', array(
            'trace_id' => $trace_id,
            'route' => $route,
            'method' => $request->get_method(),
            'params' => $params,
        ));
    }

    /**
     * @param array<string, mixed> $meta
     */
    private static function log_route_success(string $route, string $trace_id, array $meta = array()): void
    {
        self::log('info', 'route.success', array_merge(array(
            'trace_id' => $trace_id,
            'route' => $route,
        ), $meta));
    }

    private static function log_route_error(string $route, string $trace_id, Throwable $error): void
    {
        self::log('error', 'route.error', array(
            'trace_id' => $trace_id,
            'route' => $route,
            'error_message' => $error->getMessage(),
            'error_file' => $error->getFile(),
            'error_line' => $error->getLine(),
        ));
    }

    private static function normalize_categories_view(WP_REST_Request $request): string
    {
        $view = strtolower(trim((string) $request->get_param('view')));
        return 'categories_page' === $view ? 'categories_page' : 'admin_ordered';
    }

    /**
     * Uses the live WordPress /categories page as the source of truth for
     * public category order, then appends each visible parent's children.
     *
     * @return array<int, array{term: WP_Term, depth: int}>
     */
    private static function get_categories_page_ordered_rows(bool $hide_empty = true): array
    {
        $slugs = self::get_categories_page_slugs();
        if (empty($slugs)) {
            return Lexi_Merch::get_admin_ordered_category_rows($hide_empty);
        }

        $admin_rows = Lexi_Merch::get_admin_ordered_category_rows($hide_empty);
        $terms_by_id = array();
        $terms_by_slug = array();
        $top_level_terms = array();
        $children_by_parent = array();

        foreach ($admin_rows as $row) {
            $term = isset($row['term']) && $row['term'] instanceof WP_Term
                ? $row['term']
                : null;
            if (!$term instanceof WP_Term) {
                continue;
            }

            $term_id = (int) $term->term_id;
            $parent_id = isset($term->parent) ? (int) $term->parent : 0;
            $terms_by_id[$term_id] = $term;
            $slug = sanitize_title((string) ($term->slug ?? ''));
            if ('' !== $slug) {
                $terms_by_slug[$slug] = $term;
            }
            if ($parent_id <= 0) {
                $top_level_terms[] = $term;
                continue;
            }

            if (!isset($children_by_parent[$parent_id])) {
                $children_by_parent[$parent_id] = array();
            }
            $children_by_parent[$parent_id][] = $term;
        }

        $rows = array();
        $visited = array();
        $append_with_children = function (
            WP_Term $term,
            int $depth
        ) use (&$append_with_children, &$children_by_parent, &$rows, &$visited): void {
            $term_id = (int) $term->term_id;
            if (isset($visited[$term_id])) {
                return;
            }

            $visited[$term_id] = true;
            $rows[] = array(
                'term' => $term,
                'depth' => $depth,
            );

            foreach (($children_by_parent[$term_id] ?? array()) as $child) {
                if ($child instanceof WP_Term) {
                    $append_with_children($child, $depth + 1);
                }
            }
        };

        foreach ($slugs as $slug) {
            $term = $terms_by_slug[$slug] ?? null;
            if (!$term instanceof WP_Term) {
                continue;
            }

            $term_id = (int) $term->term_id;
            if (!isset($terms_by_id[$term_id])) {
                continue;
            }

            $append_with_children($terms_by_id[$term_id], 0);
        }

        foreach ($top_level_terms as $term) {
            if ($term instanceof WP_Term) {
                $append_with_children($term, 0);
            }
        }

        foreach ($terms_by_id as $term) {
            if ($term instanceof WP_Term) {
                $append_with_children($term, 0);
            }
        }

        return !empty($rows) ? $rows : Lexi_Merch::get_admin_ordered_category_rows($hide_empty);
    }

    /**
     * @return array<int, string>
     */
    private static function get_categories_page_slugs(): array
    {
        $cached = get_transient(self::CATEGORIES_PAGE_SLUGS_CACHE_KEY);
        if (is_array($cached)) {
            return $cached;
        }

        $page = get_page_by_path('categories');
        if (!$page instanceof WP_Post) {
            set_transient(
                self::CATEGORIES_PAGE_SLUGS_CACHE_KEY,
                array(),
                self::CATEGORIES_PAGE_SLUGS_CACHE_TTL
            );
            return array();
        }

        $content = (string) $page->post_content;
        $rendered = (string) apply_filters('the_content', $content);
        if ('' === trim($rendered)) {
            $rendered = $content;
        }

        if (!preg_match_all('#/product-category/([^/"\'\?#]+)#i', $rendered, $matches)) {
            set_transient(
                self::CATEGORIES_PAGE_SLUGS_CACHE_KEY,
                array(),
                self::CATEGORIES_PAGE_SLUGS_CACHE_TTL
            );
            return array();
        }

        $slugs = array();
        $seen = array();
        foreach (($matches[1] ?? array()) as $raw_slug) {
            $slug = sanitize_title(rawurldecode((string) $raw_slug));
            if ('' === $slug || isset($seen[$slug])) {
                continue;
            }

            $seen[$slug] = true;
            $slugs[] = $slug;
        }

        set_transient(
            self::CATEGORIES_PAGE_SLUGS_CACHE_KEY,
            $slugs,
            self::CATEGORIES_PAGE_SLUGS_CACHE_TTL
        );

        return $slugs;
    }

    /**
     * @param array<int, array{term: WP_Term, depth: int}> $rows
     * @return array<int, int>
     */
    private static function build_children_count_map(array $rows): array
    {
        $counts = array();
        foreach ($rows as $row) {
            $term = isset($row['term']) && $row['term'] instanceof WP_Term
                ? $row['term']
                : null;
            if (!$term instanceof WP_Term) {
                continue;
            }

            $term_id = (int) $term->term_id;
            if (!isset($counts[$term_id])) {
                $counts[$term_id] = 0;
            }

            $parent_id = isset($term->parent) ? (int) $term->parent : 0;
            if ($parent_id > 0) {
                if (!isset($counts[$parent_id])) {
                    $counts[$parent_id] = 0;
                }
                $counts[$parent_id]++;
            }
        }

        return $counts;
    }

    /**
     * @param WP_Term|object $term
     * @return array<string, mixed>
     */
    private static function format_category($term, ?int $children_count = null): array
    {
        $term_id = is_object($term) && isset($term->term_id) ? (int) $term->term_id : 0;
        if ($term_id <= 0) {
            return array();
        }

        $thumb_id = (int) get_term_meta($term_id, 'thumbnail_id', true);
        $image_url = null;
        if ($thumb_id > 0) {
            $raw = wp_get_attachment_image_url($thumb_id, 'woocommerce_thumbnail');
            if ($raw) {
                $image_url = Lexi_Merch::normalize_image_url((string) $raw);
            }
        }
        if (null === $image_url && function_exists('wc_placeholder_img_src')) {
            $placeholder = wc_placeholder_img_src('woocommerce_thumbnail');
            if ($placeholder) {
                $image_url = Lexi_Merch::normalize_image_url((string) $placeholder);
            }
        }

        return array(
            'id' => $term_id,
            'name' => isset($term->name) ? self::normalize_text($term->name) : '',
            'slug' => isset($term->slug) ? (string) $term->slug : '',
            'description' => isset($term->description)
                ? self::normalize_text(wp_strip_all_tags((string) $term->description))
                : '',
            'count' => isset($term->count) ? (int) $term->count : 0,
            'parent' => isset($term->parent) ? (int) $term->parent : 0,
            'children_count' => null !== $children_count ? max(0, $children_count) : self::count_child_categories($term_id),
            'image' => $image_url,
            'image_url' => $image_url,
            'sort_order' => Lexi_Merch::get_category_sort_order($term_id),
        );
    }

    private static function normalize_text($value): string
    {
        if (class_exists('Lexi_Text')) {
            return Lexi_Text::normalize($value);
        }

        return (string) $value;
    }

    private static function count_child_categories(int $term_id): int
    {
        $children = get_terms(array(
            'taxonomy' => 'product_cat',
            'hide_empty' => false,
            'fields' => 'ids',
            'parent' => $term_id,
        ));

        if (is_wp_error($children) || !is_array($children)) {
            return 0;
        }

        return count($children);
    }
}
