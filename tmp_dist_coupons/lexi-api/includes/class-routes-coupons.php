<?php
/**
 * Coupon REST routes.
 *
 * @package Lexi_API
 */

defined('ABSPATH') || exit;

class Lexi_Routes_Coupons
{
    private const LOG_SOURCE = 'lexi-api-coupons';

    /**
     * Register routes.
     */
    public static function register(): void
    {
        $ns = LEXI_API_NAMESPACE;

        register_rest_route($ns, '/coupons/validate', array(
            'methods' => WP_REST_Server::CREATABLE,
            'callback' => array(__CLASS__, 'validate_coupon'),
            'permission_callback' => array('Lexi_Security', 'public_access'),
            'args' => array(
                'code' => array('required' => true, 'sanitize_callback' => 'sanitize_text_field'),
                'cart_total' => array('required' => true, 'sanitize_callback' => array(__CLASS__, 'sanitize_decimal')),
                'items' => array('required' => false),
            ),
        ));

        register_rest_route($ns, '/admin/coupons', array(
            array(
                'methods' => WP_REST_Server::READABLE,
                'callback' => array(__CLASS__, 'list_coupons'),
                'permission_callback' => array('Lexi_Security', 'admin_access'),
            ),
            array(
                'methods' => WP_REST_Server::CREATABLE,
                'callback' => array(__CLASS__, 'create_coupon'),
                'permission_callback' => array('Lexi_Security', 'admin_access'),
                'args' => array(
                    'code' => array('required' => true, 'sanitize_callback' => 'sanitize_text_field'),
                    'discount_type' => array('required' => true, 'sanitize_callback' => 'sanitize_text_field'),
                    'amount' => array('required' => true, 'sanitize_callback' => array(__CLASS__, 'sanitize_decimal')),
                ),
            ),
        ));

        register_rest_route($ns, '/admin/coupons/(?P<id>\d+)', array(
            array(
                'methods' => WP_REST_Server::EDITABLE,
                'callback' => array(__CLASS__, 'update_coupon'),
                'permission_callback' => array('Lexi_Security', 'admin_access'),
            ),
            array(
                'methods' => WP_REST_Server::DELETABLE,
                'callback' => array(__CLASS__, 'delete_coupon'),
                'permission_callback' => array('Lexi_Security', 'admin_access'),
            ),
        ));
    }

    /**
     * POST /coupons/validate
     */
    public static function validate_coupon(WP_REST_Request $request): WP_REST_Response
    {
        $trace_id = self::new_trace_id();
        self::log_route_start('/coupons/validate', $request, $trace_id);

        $dependency_error = self::ensure_woocommerce_dependency($trace_id);
        if (null !== $dependency_error) {
            return $dependency_error;
        }

        try {
            $code = strtolower(trim((string) $request->get_param('code')));
            $cart_total = self::sanitize_decimal($request->get_param('cart_total'));
            $items = self::normalize_items($request->get_param('items'));

            if ('' === $code) {
                return Lexi_Security::error(
                    'invalid_coupon',
                    'يرجى إدخال رمز القسيمة.',
                    422,
                    array('trace_id' => $trace_id)
                );
            }

            $coupon_id = function_exists('wc_get_coupon_id_by_code')
                ? (int) wc_get_coupon_id_by_code($code)
                : 0;
            $coupon = $coupon_id > 0 ? new WC_Coupon($coupon_id) : new WC_Coupon($code);

            if (!$coupon->get_id()) {
                return Lexi_Security::error(
                    'invalid_coupon',
                    'الكوبون غير موجود.',
                    404,
                    array('trace_id' => $trace_id)
                );
            }

            if ('publish' !== get_post_status($coupon->get_id())) {
                return Lexi_Security::error(
                    'invalid_coupon',
                    'الكوبون غير متاح حالياً.',
                    422,
                    array('trace_id' => $trace_id)
                );
            }

            $expires = $coupon->get_date_expires();
            if ($expires && $expires->getTimestamp() < current_time('timestamp')) {
                return Lexi_Security::error(
                    'coupon_expired',
                    'انتهت صلاحية هذا الكوبون.',
                    422,
                    array('trace_id' => $trace_id)
                );
            }

            $usage_limit = (int) $coupon->get_usage_limit();
            if ($usage_limit > 0 && (int) $coupon->get_usage_count() >= $usage_limit) {
                return Lexi_Security::error(
                    'coupon_usage_limit',
                    'تم تجاوز الحد المسموح لاستخدام هذا الكوبون.',
                    422,
                    array('trace_id' => $trace_id)
                );
            }

            $per_user_limit = (int) $coupon->get_usage_limit_per_user();
            if ($per_user_limit > 0 && is_user_logged_in() && method_exists($coupon, 'get_usage_count_for_user')) {
                $usage_for_user = (int) $coupon->get_usage_count_for_user(get_current_user_id());
                if ($usage_for_user >= $per_user_limit) {
                    return Lexi_Security::error(
                        'coupon_user_limit',
                        'تم استهلاك عدد مرات استخدام الكوبون لهذا الحساب.',
                        422,
                        array('trace_id' => $trace_id)
                    );
                }
            }

            $minimum_amount = self::sanitize_decimal($coupon->get_minimum_amount());
            if ($minimum_amount > 0 && $cart_total < $minimum_amount) {
                return Lexi_Security::error(
                    'min_spend',
                    sprintf('الحد الأدنى لاستخدام هذا الكوبون هو %s.', wc_format_decimal($minimum_amount, 2)),
                    422,
                    array('trace_id' => $trace_id)
                );
            }

            $maximum_amount = self::sanitize_decimal($coupon->get_maximum_amount());
            if ($maximum_amount > 0 && $cart_total > $maximum_amount) {
                return Lexi_Security::error(
                    'max_spend',
                    sprintf('الحد الأقصى لاستخدام هذا الكوبون هو %s.', wc_format_decimal($maximum_amount, 2)),
                    422,
                    array('trace_id' => $trace_id)
                );
            }

            if (!self::coupon_matches_cart($coupon, $items)) {
                return Lexi_Security::error(
                    'coupon_not_applicable',
                    'هذا الكوبون لا ينطبق على المنتجات الموجودة في السلة.',
                    422,
                    array('trace_id' => $trace_id)
                );
            }

            $discount_amount = self::calculate_discount_amount($coupon, $cart_total, $items);
            if ($discount_amount <= 0) {
                return Lexi_Security::error(
                    'coupon_no_discount',
                    'هذا الكوبون لا يضيف خصماً على السلة الحالية.',
                    422,
                    array('trace_id' => $trace_id)
                );
            }

            if ($discount_amount > $cart_total) {
                $discount_amount = $cart_total;
            }

            $payload = array(
                'code' => (string) $coupon->get_code(),
                'valid' => true,
                'discount_amount' => (float) wc_format_decimal($discount_amount, 2),
                'discount_type' => (string) $coupon->get_discount_type(),
                'amount' => (float) wc_format_decimal(self::sanitize_decimal($coupon->get_amount()), 2),
                'cart_total' => (float) wc_format_decimal($cart_total, 2),
                'final_total' => (float) wc_format_decimal(max(0.0, $cart_total - $discount_amount), 2),
                'currency' => function_exists('get_woocommerce_currency')
                    ? (string) get_woocommerce_currency()
                    : 'SYP',
                'message' => 'تم تطبيق الكوبون بنجاح.',
                'description' => self::normalize_optional_text($coupon->get_description()),
                'trace_id' => $trace_id,
            );

            self::log_route_success('/coupons/validate', $trace_id, array(
                'code' => $coupon->get_code(),
                'cart_total' => $cart_total,
                'discount_type' => $coupon->get_discount_type(),
                'discount_amount' => $discount_amount,
                'items_count' => count($items),
            ));

            return Lexi_Security::success($payload);
        } catch (Throwable $e) {
            self::log_route_error('/coupons/validate', $trace_id, $e);
            return Lexi_Security::error(
                'coupon_validate_failed',
                'تعذر التحقق من القسيمة حالياً. حاول مرة أخرى.',
                500,
                array('trace_id' => $trace_id)
            );
        }
    }

    /**
     * GET /admin/coupons
     */
    public static function list_coupons(WP_REST_Request $request): WP_REST_Response
    {
        $trace_id = self::new_trace_id();
        self::log_route_start('/admin/coupons', $request, $trace_id);

        $dependency_error = self::ensure_woocommerce_dependency($trace_id);
        if (null !== $dependency_error) {
            return $dependency_error;
        }

        $args = array(
            'post_type' => 'shop_coupon',
            'post_status' => 'publish',
            'posts_per_page' => -1,
            'orderby' => 'date',
            'order' => 'DESC',
        );

        $posts = get_posts($args);
        $coupons = array();

        foreach ($posts as $post) {
            $coupon = new WC_Coupon($post->ID);
            if ($coupon->get_id()) {
                $coupons[] = self::format_coupon($coupon);
            }
        }

        self::log_route_success('/admin/coupons', $trace_id, array('count' => count($coupons)));
        return Lexi_Security::success($coupons);
    }

    /**
     * POST /admin/coupons
     */
    public static function create_coupon(WP_REST_Request $request): WP_REST_Response
    {
        $trace_id = self::new_trace_id();
        self::log_route_start('/admin/coupons#create', $request, $trace_id);

        $dependency_error = self::ensure_woocommerce_dependency($trace_id);
        if (null !== $dependency_error) {
            return $dependency_error;
        }

        $code = strtolower(trim((string) $request->get_param('code')));
        if ('' === $code) {
            return Lexi_Security::error('invalid_coupon', 'رمز الكوبون مطلوب.', 422, array('trace_id' => $trace_id));
        }

        $existing = new WC_Coupon($code);
        if ($existing->get_id()) {
            return Lexi_Security::error('coupon_exists', 'كوبون بهذا الرمز موجود بالفعل.', 409, array('trace_id' => $trace_id));
        }

        $coupon = new WC_Coupon();
        $coupon->set_code($code);
        self::apply_coupon_data($coupon, $request);
        $coupon->save();

        self::log_route_success('/admin/coupons#create', $trace_id, array('coupon_id' => $coupon->get_id()));
        return Lexi_Security::success(self::format_coupon($coupon));
    }

    /**
     * PUT/PATCH /admin/coupons/<id>
     */
    public static function update_coupon(WP_REST_Request $request): WP_REST_Response
    {
        $trace_id = self::new_trace_id();
        self::log_route_start('/admin/coupons/{id}#update', $request, $trace_id);

        $dependency_error = self::ensure_woocommerce_dependency($trace_id);
        if (null !== $dependency_error) {
            return $dependency_error;
        }

        $id = (int) $request->get_param('id');
        $coupon = new WC_Coupon($id);

        if (!$coupon->get_id()) {
            return Lexi_Security::error('not_found', 'الكوبون غير موجود.', 404, array('trace_id' => $trace_id));
        }

        $code = $request->get_param('code');
        if ($code !== null) {
            $coupon->set_code(strtolower(trim(sanitize_text_field((string) $code))));
        }

        self::apply_coupon_data($coupon, $request);
        $coupon->save();

        self::log_route_success('/admin/coupons/{id}#update', $trace_id, array('coupon_id' => $coupon->get_id()));
        return Lexi_Security::success(self::format_coupon($coupon));
    }

    /**
     * DELETE /admin/coupons/<id>
     */
    public static function delete_coupon(WP_REST_Request $request): WP_REST_Response
    {
        $trace_id = self::new_trace_id();
        self::log_route_start('/admin/coupons/{id}#delete', $request, $trace_id);

        $dependency_error = self::ensure_woocommerce_dependency($trace_id);
        if (null !== $dependency_error) {
            return $dependency_error;
        }

        $id = (int) $request->get_param('id');
        $coupon = new WC_Coupon($id);

        if (!$coupon->get_id()) {
            return Lexi_Security::error('not_found', 'الكوبون غير موجود.', 404, array('trace_id' => $trace_id));
        }

        $coupon->delete(true);

        self::log_route_success('/admin/coupons/{id}#delete', $trace_id, array('coupon_id' => $id));
        return Lexi_Security::success(array('deleted' => true));
    }

    /**
     * Apply request params to a WC_Coupon object.
     */
    private static function apply_coupon_data(WC_Coupon $coupon, WP_REST_Request $request): void
    {
        $discount_type = $request->get_param('discount_type');
        if ($discount_type !== null) {
            $type = sanitize_text_field((string) $discount_type);
            if (!in_array($type, array('percent', 'fixed_cart', 'fixed_product'), true)) {
                $type = 'fixed_cart';
            }
            $coupon->set_discount_type($type);
        }

        $amount = $request->get_param('amount');
        if ($amount !== null) {
            $coupon->set_amount((string) wc_format_decimal(self::sanitize_decimal($amount), 2));
        }

        $description = $request->get_param('description');
        if ($description !== null) {
            $coupon->set_description(sanitize_textarea_field((string) $description));
        }

        $usage_limit = $request->get_param('usage_limit');
        if ($usage_limit !== null) {
            $coupon->set_usage_limit(max(0, absint($usage_limit)));
        }

        $minimum_amount = $request->get_param('minimum_amount');
        if ($minimum_amount !== null) {
            $coupon->set_minimum_amount((string) wc_format_decimal(self::sanitize_decimal($minimum_amount), 2));
        }

        $maximum_amount = $request->get_param('maximum_amount');
        if ($maximum_amount !== null) {
            $coupon->set_maximum_amount((string) wc_format_decimal(self::sanitize_decimal($maximum_amount), 2));
        }

        $individual_use = $request->get_param('individual_use');
        if ($individual_use !== null) {
            $coupon->set_individual_use(rest_sanitize_boolean($individual_use));
        }

        $exclude_sale_items = $request->get_param('exclude_sale_items');
        if ($exclude_sale_items !== null) {
            $coupon->set_exclude_sale_items(rest_sanitize_boolean($exclude_sale_items));
        }

        $date_expires = $request->get_param('date_expires');
        if ($date_expires !== null) {
            $raw = trim((string) $date_expires);
            if ('' === $raw) {
                $coupon->set_date_expires(null);
            } else {
                $timestamp = strtotime($raw);
                if (false !== $timestamp) {
                    $coupon->set_date_expires($timestamp);
                }
            }
        }
    }

    /**
     * Format a WC_Coupon into a response array.
     */
    private static function format_coupon(WC_Coupon $coupon): array
    {
        $expires = $coupon->get_date_expires();
        return array(
            'id' => $coupon->get_id(),
            'code' => $coupon->get_code(),
            'discount_type' => $coupon->get_discount_type(),
            'amount' => (float) wc_format_decimal(self::sanitize_decimal($coupon->get_amount()), 2),
            'description' => self::normalize_optional_text($coupon->get_description()),
            'date_expires' => $expires ? $expires->date('Y-m-d') : null,
            'usage_limit' => $coupon->get_usage_limit() ?: null,
            'usage_count' => (int) $coupon->get_usage_count(),
            'minimum_amount' => (float) wc_format_decimal(self::sanitize_decimal($coupon->get_minimum_amount()), 2),
            'maximum_amount' => (float) wc_format_decimal(self::sanitize_decimal($coupon->get_maximum_amount()), 2),
            'individual_use' => (bool) $coupon->get_individual_use(),
            'exclude_sale_items' => (bool) $coupon->get_exclude_sale_items(),
        );
    }

    private static function calculate_discount_amount(WC_Coupon $coupon, float $cart_total, array $items): float
    {
        $type = (string) $coupon->get_discount_type();
        $amount = self::sanitize_decimal($coupon->get_amount());
        $eligible_subtotal = self::calculate_eligible_subtotal($coupon, $items);

        // If we cannot calculate item subtotal, keep compatibility with cart total.
        if ($eligible_subtotal <= 0) {
            $eligible_subtotal = $cart_total;
        }

        if ('percent' === $type) {
            return ($eligible_subtotal * $amount) / 100;
        }

        if ('fixed_product' === $type) {
            $discount = 0.0;
            foreach ($items as $item) {
                $product_id = (int) ($item['product_id'] ?? 0);
                $qty = max(1, (int) ($item['quantity'] ?? 1));
                if (self::is_coupon_valid_for_product($coupon, $product_id)) {
                    $discount += ($amount * $qty);
                }
            }
            return $discount;
        }

        // fixed_cart
        return min($amount, $eligible_subtotal);
    }

    private static function calculate_eligible_subtotal(WC_Coupon $coupon, array $items): float
    {
        $subtotal = 0.0;

        foreach ($items as $item) {
            $product_id = (int) ($item['product_id'] ?? 0);
            $qty = max(1, (int) ($item['quantity'] ?? 1));
            if ($product_id <= 0 || !self::is_coupon_valid_for_product($coupon, $product_id)) {
                continue;
            }

            $product = wc_get_product($product_id);
            if (!$product || !($product instanceof WC_Product)) {
                continue;
            }

            $price = 0.0;
            if (class_exists('Lexi_Merch') && method_exists('Lexi_Merch', 'resolve_product_prices')) {
                $prices = Lexi_Merch::resolve_product_prices($product);
                $price = self::sanitize_decimal($prices['price'] ?? 0);
            }

            if ($price <= 0) {
                $price = self::sanitize_decimal($product->get_price());
            }

            if ($price > 0) {
                $subtotal += ($price * $qty);
            }
        }

        return $subtotal;
    }

    private static function coupon_matches_cart(WC_Coupon $coupon, array $items): bool
    {
        $has_restrictions = !empty($coupon->get_product_ids())
            || !empty($coupon->get_excluded_product_ids())
            || !empty($coupon->get_product_categories())
            || !empty($coupon->get_excluded_product_categories())
            || (bool) $coupon->get_exclude_sale_items();

        if (!$has_restrictions) {
            return true;
        }

        foreach ($items as $item) {
            $product_id = (int) ($item['product_id'] ?? 0);
            if (self::is_coupon_valid_for_product($coupon, $product_id)) {
                return true;
            }
        }

        return false;
    }

    private static function is_coupon_valid_for_product(WC_Coupon $coupon, int $product_id): bool
    {
        if ($product_id <= 0) {
            return false;
        }

        $product = wc_get_product($product_id);
        if (!$product || !($product instanceof WC_Product)) {
            return false;
        }

        $parent_id = (int) $product->get_parent_id();
        $candidate_ids = array_values(array_unique(array_filter(array(
            (int) $product->get_id(),
            $parent_id > 0 ? $parent_id : null,
        ))));

        $product_ids = array_map('intval', (array) $coupon->get_product_ids());
        if (!empty($product_ids) && empty(array_intersect($candidate_ids, $product_ids))) {
            return false;
        }

        $excluded_product_ids = array_map('intval', (array) $coupon->get_excluded_product_ids());
        if (!empty($excluded_product_ids) && !empty(array_intersect($candidate_ids, $excluded_product_ids))) {
            return false;
        }

        $category_ids = wp_get_post_terms($product->get_id(), 'product_cat', array('fields' => 'ids'));
        if (is_wp_error($category_ids) || !is_array($category_ids)) {
            $category_ids = array();
        }

        if ($parent_id > 0) {
            $parent_terms = wp_get_post_terms($parent_id, 'product_cat', array('fields' => 'ids'));
            if (!is_wp_error($parent_terms) && is_array($parent_terms)) {
                $category_ids = array_unique(array_merge($category_ids, $parent_terms));
            }
        }

        $product_categories = array_map('intval', $category_ids);

        $allowed_categories = array_map('intval', (array) $coupon->get_product_categories());
        if (!empty($allowed_categories) && empty(array_intersect($product_categories, $allowed_categories))) {
            return false;
        }

        $blocked_categories = array_map('intval', (array) $coupon->get_excluded_product_categories());
        if (!empty($blocked_categories) && !empty(array_intersect($product_categories, $blocked_categories))) {
            return false;
        }

        if ((bool) $coupon->get_exclude_sale_items() && $product->is_on_sale()) {
            return false;
        }

        return true;
    }

    /**
     * @param mixed $items
     * @return array<int, array<string, int>>
     */
    private static function normalize_items($items): array
    {
        if (!is_array($items)) {
            return array();
        }

        $normalized = array();
        foreach ($items as $item) {
            if (!is_array($item)) {
                continue;
            }

            $product_id = absint($item['variation_id'] ?? 0);
            if ($product_id <= 0) {
                $product_id = absint($item['product_id'] ?? 0);
            }

            if ($product_id <= 0) {
                continue;
            }

            $quantity = max(1, absint($item['quantity'] ?? $item['qty'] ?? 1));
            $normalized[] = array(
                'product_id' => $product_id,
                'quantity' => $quantity,
            );
        }

        return $normalized;
    }

    /**
     * @param mixed $value
     */
    public static function sanitize_decimal($value): float
    {
        if (is_numeric($value)) {
            return max(0, (float) $value);
        }

        $raw = trim((string) $value);
        if ('' === $raw) {
            return 0.0;
        }

        $normalized = preg_replace('/[^0-9,.\-]/', '', $raw);
        if (!is_string($normalized) || '' === $normalized) {
            return 0.0;
        }

        $has_comma = false !== strpos($normalized, ',');
        $has_dot = false !== strpos($normalized, '.');

        if ($has_comma && $has_dot) {
            // "1.234,56" => decimal is comma. "1,234.56" => decimal is dot.
            if (strrpos($normalized, ',') > strrpos($normalized, '.')) {
                $normalized = str_replace('.', '', $normalized);
                $normalized = str_replace(',', '.', $normalized);
            } else {
                $normalized = str_replace(',', '', $normalized);
            }
        } elseif ($has_comma) {
            // "15,500" (thousands) vs "10,5" (decimal comma).
            if (preg_match('/^\-?\d{1,3}(,\d{3})+$/', $normalized)) {
                $normalized = str_replace(',', '', $normalized);
            } else {
                $normalized = str_replace(',', '.', $normalized);
            }
        } elseif ($has_dot && preg_match('/^\-?\d{1,3}(\.\d{3})+$/', $normalized)) {
            $normalized = str_replace('.', '', $normalized);
        }

        if (!is_numeric($normalized)) {
            return 0.0;
        }

        return max(0, (float) $normalized);
    }

    private static function normalize_optional_text(string $value): ?string
    {
        $text = trim($value);
        return '' === $text ? null : $text;
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
            error_log('[lexi-api-coupons] ' . $message . ' | ' . wp_json_encode($context));
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
            'تعذر تنفيذ الطلب لأن WooCommerce غير مفعّل.',
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
}
