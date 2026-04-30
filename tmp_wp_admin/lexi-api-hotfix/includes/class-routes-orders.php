<?php
/**
 * Order routes: lookup, tracking, invoice access and ShamCash proof upload.
 *
 * @package Lexi_API
 */

defined('ABSPATH') || exit;

class Lexi_Routes_Orders
{
    private const MY_ORDERS_SCAN_LIMIT = 250;

    /**
     * Register order routes.
     */
    public static function register(): void
    {
        $ns = LEXI_API_NAMESPACE;

        // NOTE: Legacy phone-based tracking endpoints were intentionally removed.
        // Keeping them registered would violate guest privacy and enable order enumeration.

        register_rest_route($ns, '/my-orders', array(
            'methods' => WP_REST_Server::READABLE,
            'callback' => array(__CLASS__, 'my_orders'),
            'permission_callback' => array('Lexi_Security', 'customer_access'),
            'args' => array(
                'page' => array('default' => 1, 'sanitize_callback' => 'absint'),
                'per_page' => array('default' => 20, 'sanitize_callback' => 'absint'),
                'payment_method' => array('default' => '', 'sanitize_callback' => 'sanitize_text_field'),
            ),
        ));

        register_rest_route($ns, '/my-orders/(?P<id>\d+)', array(
            'methods' => WP_REST_Server::READABLE,
            'callback' => array(__CLASS__, 'my_order_details'),
            'permission_callback' => array('Lexi_Security', 'customer_access'),
            'args' => array(
                'id' => array('required' => true, 'sanitize_callback' => 'absint'),
            ),
        ));

        register_rest_route($ns, '/track-order', array(
            'methods' => WP_REST_Server::CREATABLE,
            'callback' => array(__CLASS__, 'track_order_by_number'),
            'permission_callback' => array('Lexi_Security', 'public_access'),
        ));

        register_rest_route($ns, '/orders/(?P<id>\d+)/invoice', array(
            'methods' => WP_REST_Server::READABLE,
            'callback' => array(__CLASS__, 'get_invoice'),
            'permission_callback' => array('Lexi_Security', 'public_access'),
            'args' => array(
                'id' => array('required' => true, 'sanitize_callback' => 'absint'),
                'type' => array('default' => '', 'sanitize_callback' => 'sanitize_text_field'),
                'phone' => array('default' => '', 'sanitize_callback' => 'sanitize_text_field'),
            ),
        ));

        register_rest_route($ns, '/payments/shamcash/proof', array(
            'methods' => WP_REST_Server::CREATABLE,
            'callback' => array(__CLASS__, 'upload_proof'),
            'permission_callback' => array('Lexi_Security', 'public_access'),
        ));

        register_rest_route($ns, '/invoices/render', array(
            'methods' => WP_REST_Server::READABLE,
            'callback' => array(__CLASS__, 'render_invoice'),
            'permission_callback' => array('Lexi_Security', 'public_access'),
        ));

        register_rest_route($ns, '/invoices/verify', array(
            'methods' => WP_REST_Server::READABLE,
            'callback' => array(__CLASS__, 'verify_invoice'),
            'permission_callback' => array('Lexi_Security', 'public_access'),
            'args' => array(
                'order_id' => array('required' => true, 'sanitize_callback' => 'absint'),
                'sig' => array('required' => true, 'sanitize_callback' => 'sanitize_text_field'),
            ),
        ));

        register_rest_route($ns, '/invoices/qr', array(
            'methods' => WP_REST_Server::READABLE,
            'callback' => array(__CLASS__, 'render_invoice_qr'),
            'permission_callback' => array('Lexi_Security', 'public_access'),
            'args' => array(
                'data' => array('required' => true, 'sanitize_callback' => 'sanitize_text_field'),
                'size' => array('default' => 220, 'sanitize_callback' => 'absint'),
            ),
        ));

        register_rest_route($ns, '/orders/(?P<id>\d+)/attach-device', array(
            'methods' => WP_REST_Server::CREATABLE,
            'callback' => array(__CLASS__, 'attach_device_to_order'),
            'permission_callback' => array('Lexi_Security', 'public_access'),
            'args' => array(
                'id' => array('required' => true, 'sanitize_callback' => 'absint'),
                'device_id' => array('required' => true, 'sanitize_callback' => 'sanitize_text_field'),
                'attach_token' => array('required' => false, 'sanitize_callback' => 'sanitize_text_field'),
                'phone' => array('required' => false, 'sanitize_callback' => 'sanitize_text_field'),
            ),
        ));
    }

    /**
     * GET /invoices/qr
     * Returns a PNG image.
     */
    public static function render_invoice_qr(WP_REST_Request $request): WP_REST_Response
    {
        $data = (string) $request->get_param('data');
        $size = max(120, min(600, (int) $request->get_param('size')));

        // The QR content is a URL. Keep it short and safe.
        $payload = rawurldecode($data);
        if ('' === trim($payload) || strlen($payload) > 500) {
            return new WP_REST_Response(null, 422);
        }

        $cache_key = 'lexi_inv_qr_' . md5($payload . '|' . $size);
        $png = get_transient($cache_key);
        if (!is_string($png) || '' === $png) {
            $png = self::generate_invoice_qr_png($payload, $size);
            if ('' !== $png) {
                set_transient($cache_key, $png, DAY_IN_SECONDS);
            }
        }

        if ('' === $png) {
            $html = self::build_invoice_qr_placeholder_svg($size);
            $response = new WP_REST_Response(null, 200);
            $response->header('Content-Type', 'image/svg+xml; charset=utf-8');
            $response->set_data($html);
            return $response;
        }

        $response = new WP_REST_Response(null, 200);
        $response->header('Content-Type', 'image/png');
        $response->header('Cache-Control', 'public, max-age=86400');
        $response->set_data($png);

        add_filter('rest_pre_serve_request', function ($served, $result) use ($png) {
            if ($result instanceof WP_REST_Response && $result->get_data() === $png) {
                echo $png; // phpcs:ignore WordPress.Security.EscapeOutput.OutputNotEscaped
                return true;
            }
            return $served;
        }, 10, 2);

        return $response;
    }

    /**
     * Generate a QR PNG using local support when available, with remote fallback.
     */
    private static function generate_invoice_qr_png(string $payload, int $size): string
    {
        // If phpqrcode is available in the environment, prefer local generation.
        if (class_exists('QRcode') && is_callable(array('QRcode', 'png'))) {
            ob_start();
            QRcode::png($payload, null, 'M', max(2, (int) floor($size / 42)), 1);
            $local_png = ob_get_clean();
            if (is_string($local_png) && '' !== $local_png) {
                return $local_png;
            }
        }

        // Fallback: fetch a QR image from an external renderer (can be disabled via filter).
        $allow_remote = (bool) apply_filters('lexi_invoice_qr_allow_remote', true, $payload, $size);
        if (!$allow_remote) {
            return '';
        }

        $remote_url = add_query_arg(
            array(
                'text' => $payload,
                'size' => (string) $size,
                'ecLevel' => 'M',
                'margin' => '2',
                'format' => 'png',
            ),
            'https://quickchart.io/qr'
        );

        $remote = wp_remote_get($remote_url, array(
            'timeout' => 8,
            'redirection' => 2,
            'sslverify' => true,
            'headers' => array(
                'Accept' => 'image/png',
            ),
        ));
        if (is_wp_error($remote)) {
            return '';
        }
        if (200 !== (int) wp_remote_retrieve_response_code($remote)) {
            return '';
        }

        $body = wp_remote_retrieve_body($remote);
        if (!is_string($body) || strlen($body) < 12) {
            return '';
        }

        $png_sig = "\x89PNG\r\n\x1a\n";
        if (0 !== strpos($body, $png_sig)) {
            return '';
        }

        return $body;
    }

    /**
     * SVG placeholder used only when QR rendering is unavailable.
     */
    private static function build_invoice_qr_placeholder_svg(int $size): string
    {
        return '<svg xmlns="http://www.w3.org/2000/svg" width="' . (int) $size . '" height="' . (int) $size . '">'
            . '<rect width="100%" height="100%" fill="#ffffff"/>'
            . '<rect x="8" y="8" width="' . ((int) $size - 16) . '" height="' . ((int) $size - 16) . '" rx="10" ry="10" fill="none" stroke="#d1d5db" stroke-width="2"/>'
            . '<text x="50%" y="48%" dominant-baseline="middle" text-anchor="middle" font-size="16" fill="#111827">QR</text>'
            . '<text x="50%" y="62%" dominant-baseline="middle" text-anchor="middle" font-size="11" fill="#6b7280">Unavailable</text>'
            . '</svg>';
    }

    /**
     * GET /my-orders
     */
    public static function my_orders(WP_REST_Request $request): WP_REST_Response
    {
        $user_id = get_current_user_id();
        if ($user_id <= 0) {
            return Lexi_Security::error('rest_forbidden', 'بيانات الدخول غير صحيحة.', 401);
        }

        $page = max(1, absint($request->get_param('page')));
        $per_page = absint($request->get_param('per_page'));
        if ($per_page <= 0) {
            $per_page = 20;
        }
        if ($per_page > 50) {
            $per_page = 50;
        }

        $payment_method_filter = self::normalize_payment_method_filter(
            (string) $request->get_param('payment_method')
        );
        $scan_limit = max(self::MY_ORDERS_SCAN_LIMIT, ($page * $per_page * 3));
        $all_orders = self::collect_customer_visible_orders(
            $user_id,
            $scan_limit,
            $payment_method_filter
        );
        $offset = ($page - 1) * $per_page;
        $orders = array_slice($all_orders, $offset, $per_page);
        $items = array();
        foreach ($orders as $order) {
            if (!($order instanceof WC_Order)) {
                continue;
            }
            $items[] = self::format_my_orders_list_item($order);
        }

        // Keep the response shape stable for existing app builds.
        return Lexi_Security::success(array(
            'page' => $page,
            'per_page' => $per_page,
            'items' => $items,
        ));
    }

    /**
     * GET /my-orders/{id}
     */
    public static function my_order_details(WP_REST_Request $request): WP_REST_Response
    {
        $user_id = get_current_user_id();
        if ($user_id <= 0) {
            return Lexi_Security::error('rest_forbidden', 'بيانات الدخول غير صحيحة.', 401);
        }

        $order_id = absint($request->get_param('id'));
        if ($order_id <= 0) {
            return Lexi_Security::error('invalid_order_id', 'رقم الطلب غير صالح.', 422);
        }

        $order = wc_get_order($order_id);
        if (!$order) {
            return Lexi_Security::error('order_not_found', 'الطلب غير موجود.', 404);
        }

        if (!self::user_owns_order($order, $user_id)) {
            // Don't leak whether it exists.
            return Lexi_Security::error('order_not_found', 'الطلب غير موجود.', 404);
        }

        return Lexi_Security::success(self::format_my_order_details($order));
    }

    /**
     * POST /track-order
     * Guest-only: order-number lookup with strict rate limiting and masked fields.
     */
    public static function track_order_by_number(WP_REST_Request $request): WP_REST_Response
    {
        $rate = self::enforce_track_rate_limit($request);
        if ($rate instanceof WP_REST_Response) {
            return $rate;
        }

        $body = $request->get_json_params();
        if (!is_array($body)) {
            $body = $request->get_body_params();
        }
        if (!is_array($body)) {
            $body = array();
        }

        $raw_order_id = (string) ($body['order_id'] ?? $request->get_param('order_id') ?? '');
        $raw_order_number = (string) ($body['order_number'] ?? $request->get_param('order_number') ?? '');
        $normalized_order_id = 0;
        if ('' !== trim($raw_order_id)) {
            $id_digits = preg_replace('/\D+/', '', $raw_order_id);
            if (is_string($id_digits) && '' !== $id_digits) {
                $normalized_order_id = absint($id_digits);
            }
        }
        if ($normalized_order_id <= 0) {
            $normalized_order_id = self::resolve_order_id_from_order_number($raw_order_number);
        }
        if ($normalized_order_id <= 0) {
            self::record_track_attempt($request, false);
            return Lexi_Security::error('order_not_found', 'الطلب غير موجود.', 404);
        }

        $order = wc_get_order($normalized_order_id);
        if (!$order) {
            self::record_track_attempt($request, false);
            return Lexi_Security::error('order_not_found', 'الطلب غير موجود.', 404);
        }

        // Optional verifier support (does not return extra PII; only used to reduce false positives).
        $verifier = trim((string) ($body['verifier'] ?? $request->get_param('verifier') ?? ''));
        if ('' !== $verifier) {
            $is_ok = self::verify_guest_order_verifier($order, $verifier);
            if (!$is_ok) {
                self::record_track_attempt($request, false);
                return Lexi_Security::error('order_not_found', 'الطلب غير موجود.', 404);
            }
        }

        self::record_track_attempt($request, true);
        return Lexi_Security::success(self::format_guest_track_order($order));
    }

    /**
     * POST /orders/{id}/attach-device
     */
    public static function attach_device_to_order(WP_REST_Request $request): WP_REST_Response
    {
        $order_id = (int) $request->get_param('id');
        $body = $request->get_json_params();
        if (!is_array($body)) {
            $body = $request->get_body_params();
        }
        if (!is_array($body)) {
            $body = array();
        }
        $device_id = trim(sanitize_text_field((string) ($body['device_id'] ?? $request->get_param('device_id') ?? '')));
        $attach_token = trim(sanitize_text_field((string) ($body['attach_token'] ?? $request->get_param('attach_token') ?? '')));
        $phone = Lexi_Security::sanitize_phone((string) ($body['phone'] ?? $request->get_param('phone') ?? ''));

        if ($order_id <= 0) {
            return Lexi_Security::error('invalid_order_id', 'رقم الطلب غير صالح.', 422);
        }

        $rate = self::enforce_attach_device_rate_limit($request, $order_id);
        if ($rate instanceof WP_REST_Response) {
            self::record_attach_device_abuse($request, $order_id, 'rate_limited');
            return $rate;
        }

        $order = wc_get_order($order_id);
        if (!$order) {
            return Lexi_Security::error('order_not_found', 'الطلب غير موجود.', 404);
        }

        if ('' === $device_id) {
            self::record_attach_device_abuse($request, $order_id, 'missing_device_id');
            return Lexi_Security::error('missing_device_id', 'معرف الجهاز مطلوب.', 422);
        }

        $authorized_by_token = false;
        if ('' !== $attach_token) {
            $authorized_by_token = self::verify_attach_token($order, $attach_token);
        }
        $authorized_by_phone = '' !== $phone && self::is_phone_match($order, $phone);

        if (!$authorized_by_token && !$authorized_by_phone) {
            self::record_attach_device_abuse(
                $request,
                $order_id,
                '' !== $attach_token ? 'invalid_attach_token_or_phone' : 'missing_attach_verifier'
            );
            return Lexi_Security::error(
                'attach_verification_failed',
                'Order ownership verification failed.',
                403
            );
        }

        // Check if device ID is already attached to avoid redundant updates
        $existing = $order->get_meta('_lexi_device_id');
        if ($existing !== $device_id) {
            $order->update_meta_data('_lexi_device_id', $device_id);
        }
        $order->update_meta_data('_lexi_device_attached_at', current_time('mysql'));
        self::invalidate_attach_token($order);
        $order->save();

        return Lexi_Security::success(array(
            'order_id' => $order_id,
            'device_id' => $device_id,
            'verified_with' => $authorized_by_token ? 'attach_token' : 'phone',
            'message' => 'تم ربط الجهاز بالطلب بنجاح.',
        ));
    }

    /**
     * POST /orders/lookup
     */
    public static function lookup_order(WP_REST_Request $request): WP_REST_Response
    {
        return Lexi_Security::error('endpoint_disabled', 'تم إيقاف هذه الخدمة. يرجى تتبع الطلب عبر رقم الطلب فقط.', 410);
    }

    /**
     * POST /orders/by-phone
     */
    public static function get_orders_by_phone(WP_REST_Request $request): WP_REST_Response
    {
        return Lexi_Security::error('endpoint_disabled', 'تم إيقاف هذه الخدمة. يرجى تتبع الطلب عبر رقم الطلب فقط.', 410);
    }

    /**
     * POST /orders/track
     */
    public static function track_order(WP_REST_Request $request): WP_REST_Response
    {
        return Lexi_Security::error('endpoint_disabled', 'تم إيقاف هذه الخدمة. يرجى تتبع الطلب عبر رقم الطلب فقط.', 410);
    }

    private static function format_my_orders_list_item(WC_Order $order): array
    {
        $created = $order->get_date_created() ? $order->get_date_created()->date('c') : null;
        $status = self::normalize_public_status((string) $order->get_status());

        $shipping_method = '';
        $methods = $order->get_shipping_methods();
        if (is_array($methods) && !empty($methods)) {
            $first = reset($methods);
            if ($first instanceof WC_Order_Item_Shipping) {
                $shipping_method = (string) $first->get_name();
            }
        }

        $payment_method = Lexi_Order_Flow::resolve_order_payment_method($order);

        return array(
            'id' => (int) $order->get_id(),
            'order_number' => (string) $order->get_order_number(),
            'status' => $status,
            'status_label_ar' => self::status_label_ar($status),
            'date_created' => $created,
            'total' => (float) $order->get_total(),
            'item_count' => (int) $order->get_item_count(),
            'payment_method' => $payment_method,
            'shipping_method' => $shipping_method,
        );
    }

    private static function format_my_order_details(WC_Order $order): array
    {
        $base = self::format_order($order, true);

        $status = self::normalize_public_status((string) $order->get_status());

        $shipping_method = '';
        $methods = $order->get_shipping_methods();
        if (is_array($methods) && !empty($methods)) {
            $first = reset($methods);
            if ($first instanceof WC_Order_Item_Shipping) {
                $shipping_method = (string) $first->get_name();
            }
        }

        $coupons = array();
        foreach ($order->get_coupon_codes() as $code) {
            $trimmed = trim((string) $code);
            if ('' !== $trimmed) {
                $coupons[] = $trimmed;
            }
        }

        $transaction_id = trim((string) $order->get_transaction_id());
        if ('' === $transaction_id) {
            $transaction_id = trim((string) $order->get_meta('_transaction_id'));
        }

        $tracking_code = trim((string) $order->get_meta('_lexi_tracking_code'));
        if ('' === $tracking_code) {
            $tracking_code = trim((string) $order->get_meta('_tracking_number'));
        }

        $tracking_url = trim((string) $order->get_meta('_lexi_tracking_url'));
        if ('' === $tracking_url) {
            $tracking_url = trim((string) $order->get_meta('_tracking_url'));
        }

        $base['status_timeline'] = Lexi_Notifications::get_timeline($order);
        $base['shipping_method'] = $shipping_method;
        $base['payment_status'] = (string) $order->get_status();
        $base['transaction_reference'] = '' !== $transaction_id ? $transaction_id : null;
        $base['coupon_codes'] = $coupons;
        $base['discount_total'] = (float) $order->get_discount_total();
        $base['discount_tax'] = (float) $order->get_discount_tax();
        $base['shipping_tax'] = (float) $order->get_shipping_tax();
        $base['cart_tax'] = (float) $order->get_cart_tax();
        $base['total_tax'] = (float) $order->get_total_tax();
        $base['tracking'] = ('' !== $tracking_code || '' !== $tracking_url) ? array(
            'code' => '' !== $tracking_code ? $tracking_code : null,
            'url' => '' !== $tracking_url ? $tracking_url : null,
        ) : null;

        // Normalize status to public status.
        $base['status'] = $status;
        $base['status_label_ar'] = self::status_label_ar($status);

        return $base;
    }

    private static function format_guest_track_order(WC_Order $order): array
    {
        $status = self::normalize_public_status((string) $order->get_status());

        $items = array();
        foreach ($order->get_items() as $item) {
            $qty = (int) $item->get_quantity();
            $subtotal = (float) $item->get_subtotal();
            $items[] = array(
                'name' => Lexi_Order_Flow::format_order_item_name($item),
                'qty' => $qty,
                'total' => (float) $item->get_total(),
                'price' => $qty > 0 ? (float) round($subtotal / $qty, 2) : 0.0,
            );
        }

        $shipping_method = '';
        $methods = $order->get_shipping_methods();
        if (is_array($methods) && !empty($methods)) {
            $first = reset($methods);
            if ($first instanceof WC_Order_Item_Shipping) {
                $shipping_method = (string) $first->get_name();
            }
        }

        $email = trim((string) $order->get_billing_email());
        $phone = trim((string) $order->get_billing_phone());

        return array(
            'order_number' => (string) $order->get_order_number(),
            'status' => $status,
            'status_label_ar' => self::status_label_ar($status),
            'status_timeline' => Lexi_Notifications::get_timeline($order),
            'items' => $items,
            'totals' => array(
                'subtotal' => (float) $order->get_subtotal(),
                'shipping' => (float) $order->get_shipping_total(),
                'tax' => (float) $order->get_total_tax(),
                'discount' => (float) $order->get_discount_total(),
                'total' => (float) $order->get_total(),
            ),
            'shipping' => array(
                'method' => $shipping_method,
                'city' => (string) $order->get_shipping_city(),
                'state' => (string) $order->get_shipping_state(),
            ),
            'masked' => array(
                'email' => self::mask_email($email),
                'phone' => self::mask_phone($phone),
                'shipping_city' => (string) $order->get_shipping_city(),
                'shipping_state' => (string) $order->get_shipping_state(),
            ),
        );
    }

    /**
     * Collect orders visible to the current customer.
     *
     * Includes linked orders and legacy guest orders that match customer
     * email/phone to avoid hiding historical purchases after login.
     *
     * @return array<int, WC_Order>
     */
    private static function collect_customer_visible_orders(
        int $user_id,
        int $scan_limit = self::MY_ORDERS_SCAN_LIMIT,
        string $payment_method_filter = ''
    ): array
    {
        $user = get_userdata($user_id);
        if (!($user instanceof WP_User)) {
            return array();
        }

        $base_args = array(
            'limit' => max(50, $scan_limit),
            'orderby' => 'date',
            'order' => 'DESC',
            'return' => 'objects',
            'status' => self::customer_visible_statuses(),
        );

        $orders_by_id = array();
        $push_order = function ($candidate) use (&$orders_by_id, $user_id, $user, $payment_method_filter): void {
            if (!($candidate instanceof WC_Order)) {
                return;
            }

            if (!self::user_owns_order($candidate, $user_id, $user)) {
                return;
            }

            if (!self::order_matches_payment_method_filter($candidate, $payment_method_filter)) {
                return;
            }

            $orders_by_id[(int) $candidate->get_id()] = $candidate;
        };

        $linked_orders = wc_get_orders(array_merge($base_args, array('customer_id' => $user_id)));
        foreach ((array) $linked_orders as $candidate) {
            $push_order($candidate);
        }

        $email = strtolower(trim((string) $user->user_email));
        if ('' !== $email) {
            $email_orders = wc_get_orders(array_merge($base_args, array('customer' => $email)));
            foreach ((array) $email_orders as $candidate) {
                $push_order($candidate);
            }
        }

        $user_phone = self::current_user_phone($user_id);
        if ('' !== $user_phone) {
            $guest_orders = wc_get_orders(array_merge($base_args, array('customer_id' => 0)));
            foreach ((array) $guest_orders as $candidate) {
                if (!($candidate instanceof WC_Order)) {
                    continue;
                }

                if (!self::is_phone_match($candidate, $user_phone)) {
                    continue;
                }

                $push_order($candidate);
            }
        }

        $orders = array_values($orders_by_id);
        usort($orders, static function (WC_Order $left, WC_Order $right): int {
            return self::order_created_timestamp($right) <=> self::order_created_timestamp($left);
        });

        return $orders;
    }

    private static function order_created_timestamp(WC_Order $order): int
    {
        $created = $order->get_date_created();
        return $created ? (int) $created->getTimestamp() : 0;
    }

    /**
     * Ownership check that supports both linked and legacy guest orders.
     */
    private static function user_owns_order(WC_Order $order, int $user_id, ?WP_User $user = null): bool
    {
        if ($user_id <= 0) {
            return false;
        }

        if ((int) $order->get_customer_id() === $user_id) {
            return true;
        }

        if (!($user instanceof WP_User)) {
            $candidate = get_userdata($user_id);
            if (!($candidate instanceof WP_User)) {
                return false;
            }
            $user = $candidate;
        }

        $user_email = strtolower(trim((string) $user->user_email));
        if ('' !== $user_email) {
            $order_email = strtolower(trim((string) $order->get_billing_email()));
            if ('' !== $order_email && $order_email === $user_email) {
                return true;
            }
        }

        $user_phone = self::current_user_phone($user_id);
        if ('' !== $user_phone && self::is_phone_match($order, $user_phone)) {
            return true;
        }

        return false;
    }

    private static function current_user_phone(int $user_id): string
    {
        $phone = Lexi_Security::sanitize_phone((string) get_user_meta($user_id, 'billing_phone', true));
        if ('' === $phone) {
            $phone = Lexi_Security::sanitize_phone((string) get_user_meta($user_id, 'phone', true));
        }

        return $phone;
    }

    private static function resolve_order_id_from_order_number(string $raw): int
    {
        $trimmed = trim($raw);
        if ('' === $trimmed) {
            return 0;
        }

        // Keep only digits, supports inputs like "#12345".
        $digits = preg_replace('/\D+/', '', $trimmed);
        if (!is_string($digits) || '' === $digits) {
            return 0;
        }

        // Keep sane length limits while allowing legacy short IDs/order numbers.
        if (strlen($digits) < 1 || strlen($digits) > 18) {
            return 0;
        }

        $candidate_id = absint($digits);
        if ($candidate_id <= 0) {
            return 0;
        }

        // 1) Direct ID lookup (most stores).
        $order = wc_get_order($candidate_id);
        if ($order instanceof WC_Order) {
            $display = (string) $order->get_order_number();
            $display_digits = preg_replace('/\D+/', '', $display);
            if (is_string($display_digits) && $display_digits === $digits) {
                return (int) $order->get_id();
            }
        }

        // 2) Sequential order number plugins: try matching common meta keys.
        global $wpdb;
        $meta_keys = array(
            '_order_number',
            '_order_number_formatted',
            '_alg_wc_custom_order_number',
            '_wc_seq_order_number',
            '_wc_seq_order_number_formatted',
            '_yith_pos_order_number',
        );

        $placeholders = implode(',', array_fill(0, count($meta_keys), '%s'));
        $sql = "SELECT post_id FROM {$wpdb->postmeta} WHERE meta_key IN ($placeholders) AND meta_value = %s ORDER BY post_id DESC LIMIT 1";
        $prepared = $wpdb->prepare($sql, array_merge($meta_keys, array($digits)));
        $found = (int) $wpdb->get_var($prepared);
        if ($found > 0) {
            $found_order = wc_get_order($found);
            if ($found_order instanceof WC_Order) {
                return (int) $found_order->get_id();
            }
        }

        // 3) Last resort: search for formatted order numbers (with prefix) by LIKE.
        // We keep this very narrow and digits-only to reduce enumeration surface.
        $sql2 = "SELECT post_id FROM {$wpdb->postmeta} WHERE meta_key IN ($placeholders) AND meta_value LIKE %s ORDER BY post_id DESC LIMIT 1";
        $prepared2 = $wpdb->prepare($sql2, array_merge($meta_keys, array('%' . $wpdb->esc_like($digits) . '%')));
        $found2 = (int) $wpdb->get_var($prepared2);
        if ($found2 > 0) {
            $found_order2 = wc_get_order($found2);
            if ($found_order2 instanceof WC_Order) {
                return (int) $found_order2->get_id();
            }
        }

        return 0;
    }

    private static function get_client_ip(): string
    {
        $keys = array('HTTP_CF_CONNECTING_IP', 'HTTP_X_FORWARDED_FOR', 'REMOTE_ADDR');
        foreach ($keys as $key) {
            if (!isset($_SERVER[$key])) {
                continue;
            }
            $raw = (string) $_SERVER[$key];
            if ('' === trim($raw)) {
                continue;
            }
            $parts = explode(',', $raw);
            $ip = trim((string) ($parts[0] ?? ''));
            if ('' !== $ip) {
                return $ip;
            }
        }
        return 'unknown';
    }

    private static function get_device_id(WP_REST_Request $request): string
    {
        $device = trim((string) $request->get_header('device-id'));
        if ('' === $device) {
            $device = trim((string) $request->get_header('Device-Id'));
        }
        // Prevent huge keys.
        if (strlen($device) > 64) {
            $device = substr($device, 0, 64);
        }
        return $device;
    }

    private static function enforce_track_rate_limit(WP_REST_Request $request)
    {
        $ip = self::get_client_ip();
        $device = self::get_device_id($request);
        $identity = $ip . '|' . $device;
        $key = 'lexi_track_order_rl_' . substr(hash('sha256', $identity), 0, 32);

        $window_seconds = 10 * 60;
        $limit = 10;
        $now = time();

        $data = get_transient($key);
        if (!is_array($data)) {
            $data = array(
                'count' => 0,
                'first_ts' => $now,
                'blocked_until' => 0,
                'misses' => 0,
            );
        }

        $blocked_until = absint($data['blocked_until'] ?? 0);
        if ($blocked_until > $now) {
            $retry = $blocked_until - $now;
            $response = Lexi_Security::error('rate_limited', 'تم تجاوز عدد المحاولات. حاول لاحقاً.', 429);
            $response->header('Retry-After', (string) $retry);
            return $response;
        }

        $first_ts = absint($data['first_ts'] ?? $now);
        if (($now - $first_ts) > $window_seconds) {
            $data['count'] = 0;
            $data['first_ts'] = $now;
            $data['blocked_until'] = 0;
            $data['misses'] = 0;
        }

        $data['count'] = absint($data['count'] ?? 0) + 1;

        if ($data['count'] > $limit) {
            // Exponential-ish backoff.
            $over = $data['count'] - $limit;
            $backoff = min(3600, (int) pow(2, min(10, $over)));
            $data['blocked_until'] = $now + $backoff;
            set_transient($key, $data, $window_seconds);

            $response = Lexi_Security::error('rate_limited', 'تم تجاوز عدد المحاولات. حاول لاحقاً.', 429);
            $response->header('Retry-After', (string) $backoff);
            return $response;
        }

        set_transient($key, $data, $window_seconds);
        return true;
    }

    private static function record_track_attempt(WP_REST_Request $request, bool $hit): void
    {
        $ip = self::get_client_ip();
        $device = self::get_device_id($request);
        $identity = $ip . '|' . $device;
        $key = 'lexi_track_order_miss_' . substr(hash('sha256', $identity), 0, 32);

        $data = get_transient($key);
        if (!is_array($data)) {
            $data = array('misses' => 0);
        }

        if (!$hit) {
            $data['misses'] = absint($data['misses'] ?? 0) + 1;
            set_transient($key, $data, 10 * 60);
            if ($data['misses'] >= 5) {
                error_log('[Lexi_API][SECURITY] Suspicious track-order misses: ip=' . $ip . ' device=' . $device . ' misses=' . $data['misses']);
            }
        }
    }

    private static function enforce_attach_device_rate_limit(WP_REST_Request $request, int $order_id)
    {
        $ip = self::get_client_ip();
        $device = self::get_device_id($request);
        $identity = $ip . '|' . $device . '|' . $order_id;
        $key = 'lexi_attach_device_rl_' . substr(hash('sha256', $identity), 0, 32);

        $window_seconds = 10 * MINUTE_IN_SECONDS;
        $limit = 8;
        $now = time();

        $data = get_transient($key);
        if (!is_array($data)) {
            $data = array(
                'count' => 0,
                'first_ts' => $now,
                'blocked_until' => 0,
            );
        }

        $blocked_until = absint($data['blocked_until'] ?? 0);
        if ($blocked_until > $now) {
            $retry = $blocked_until - $now;
            $response = Lexi_Security::error('rate_limited', 'تم تجاوز عدد المحاولات. حاول لاحقاً.', 429);
            $response->header('Retry-After', (string) $retry);
            return $response;
        }

        $first_ts = absint($data['first_ts'] ?? $now);
        if (($now - $first_ts) > $window_seconds) {
            $data['count'] = 0;
            $data['first_ts'] = $now;
            $data['blocked_until'] = 0;
        }

        $data['count'] = absint($data['count'] ?? 0) + 1;
        if ($data['count'] > $limit) {
            $over = $data['count'] - $limit;
            $backoff = min(3600, (int) pow(2, min(10, $over)));
            $data['blocked_until'] = $now + $backoff;
            set_transient($key, $data, $window_seconds);

            $response = Lexi_Security::error('rate_limited', 'تم تجاوز عدد المحاولات. حاول لاحقاً.', 429);
            $response->header('Retry-After', (string) $backoff);
            return $response;
        }

        set_transient($key, $data, $window_seconds);
        return true;
    }

    private static function record_attach_device_abuse(WP_REST_Request $request, int $order_id, string $reason): void
    {
        $ip = self::get_client_ip();
        $device = self::get_device_id($request);
        $identity = $ip . '|' . $device . '|' . $order_id;
        $key = 'lexi_attach_device_abuse_' . substr(hash('sha256', $identity), 0, 32);

        $data = get_transient($key);
        if (!is_array($data)) {
            $data = array('count' => 0);
        }

        $data['count'] = absint($data['count'] ?? 0) + 1;
        set_transient($key, $data, 15 * MINUTE_IN_SECONDS);

        if ($data['count'] >= 3) {
            error_log(
                '[Lexi_API][SECURITY] attach-device abuse: reason=' . $reason .
                    ' order=' . $order_id .
                    ' ip=' . $ip .
                    ' device=' . $device .
                    ' count=' . $data['count']
            );
        }
    }

    private static function verify_attach_token(WC_Order $order, string $attach_token): bool
    {
        $token = trim($attach_token);
        if ('' === $token) {
            return false;
        }

        $stored_hash = trim((string) $order->get_meta('_lexi_attach_token_hash'));
        $expires_at = absint($order->get_meta('_lexi_attach_token_expires'));
        if ('' === $stored_hash || $expires_at <= 0 || time() > $expires_at) {
            return false;
        }

        $candidate = hash_hmac('sha256', $token, wp_salt('auth'));
        return hash_equals($stored_hash, $candidate);
    }

    private static function invalidate_attach_token(WC_Order $order): void
    {
        $order->delete_meta_data('_lexi_attach_token_hash');
        $order->delete_meta_data('_lexi_attach_token_expires');
        $order->delete_meta_data('_lexi_attach_token_issued_at');
    }

    private static function verify_guest_order_verifier(WC_Order $order, string $verifier): bool
    {
        $v = trim($verifier);
        if ('' === $v) {
            return true;
        }

        // If verifier looks like email, compare billing email.
        if (false !== strpos($v, '@')) {
            $email = strtolower(trim((string) $order->get_billing_email()));
            return '' !== $email && strtolower($v) === $email;
        }

        // Otherwise interpret as last4 phone.
        $digits = preg_replace('/\D+/', '', $v);
        if (!is_string($digits) || strlen($digits) < 4) {
            return false;
        }
        $last4 = substr($digits, -4);

        $phone = Lexi_Security::sanitize_phone((string) $order->get_billing_phone());
        if (strlen($phone) < 4) {
            return false;
        }
        return substr($phone, -4) === $last4;
    }

    private static function mask_email(string $email): ?string
    {
        $trimmed = trim($email);
        if ('' === $trimmed) {
            return null;
        }
        $parts = explode('@', $trimmed);
        if (count($parts) !== 2) {
            return null;
        }
        $name = $parts[0];
        $domain = $parts[1];
        if (strlen($name) <= 2) {
            return substr($name, 0, 1) . '***@' . $domain;
        }
        return substr($name, 0, 2) . '***@' . $domain;
    }

    private static function mask_phone(string $phone): ?string
    {
        $normalized = Lexi_Security::sanitize_phone($phone);
        if ('' === $normalized) {
            return null;
        }
        $len = strlen($normalized);
        if ($len <= 4) {
            return '****';
        }
        $last2 = substr($normalized, -2);
        return str_repeat('*', max(0, $len - 2)) . $last2;
    }

    /**
     * GET /orders/{id}/invoice
     */
    public static function get_invoice(WP_REST_Request $request): WP_REST_Response
    {
        $order_id = (int) $request->get_param('id');
        $phone = Lexi_Security::sanitize_phone((string) $request->get_param('phone'));
        $requested_type = sanitize_text_field((string) $request->get_param('type'));

        $order = wc_get_order($order_id);
        if (!$order) {
            return Lexi_Security::error('order_not_found', 'الطلب غير موجود.', 404);
        }

        $type = in_array($requested_type, array('provisional', 'final'), true)
            ? $requested_type
            : Lexi_Invoices::resolve_type($order);

        // Access rules:
        // - Admins can access any invoice.
        // - Logged-in customers can access invoices for THEIR orders only, without a phone.
        // - Guests require a phone match for any access.
        $is_admin = current_user_can('manage_woocommerce');
        if (!$is_admin) {
            $user_id = get_current_user_id();
            $is_customer_owner = $user_id > 0 && self::user_owns_order($order, $user_id);

            if (!$is_customer_owner) {
                if ('' === $phone) {
                    return Lexi_Security::error('phone_required', 'رقم الهاتف مطلوب للوصول إلى الفاتورة.', 422);
                }
                if (!self::is_phone_match($order, $phone)) {
                    return Lexi_Security::error('phone_mismatch', 'بيانات الطلب غير صحيحة.', 403);
                }
            }
        }

        if ('final' === $type && !in_array($order->get_status(), array('processing', 'completed'), true)) {
            return Lexi_Security::error('invoice_not_ready', 'الفاتورة النهائية غير متاحة حالياً.', 403);
        }

        $url = Lexi_Invoices::get_signed_url($order_id, $type);

        return Lexi_Security::success(array(
            'invoice_url' => $url,
            'url' => $url,
            'invoice_type' => $type,
            'verification_url' => Lexi_Invoices::get_verification_url($order),
            'order' => self::format_order($order, false),
        ));
    }

    /**
     * POST /payments/shamcash/proof
     */
    public static function upload_proof(WP_REST_Request $request): WP_REST_Response
    {
        $order_id = absint($request->get_param('order_id'));
        $phone = Lexi_Security::sanitize_phone((string) $request->get_param('phone'));
        $note = sanitize_textarea_field((string) $request->get_param('note'));

        if ($order_id <= 0 || '' === $phone) {
            return Lexi_Security::error('missing_fields', 'رقم الطلب ورقم الهاتف مطلوبان.', 422);
        }

        $order = wc_get_order($order_id);
        if (!$order) {
            return Lexi_Security::error('order_not_found', 'الطلب غير موجود.', 404);
        }

        if (function_exists('wc_get_logger')) {
            wc_get_logger()->info(
                sprintf(
                    '[ORDERS] shamcash proof upload requested order_id=%d current_status=%s payment_method=%s',
                    $order_id,
                    (string) $order->get_status(),
                    (string) $order->get_payment_method()
                ),
                array('source' => 'lexi-api')
            );
        }

        if (!self::is_phone_match($order, $phone)) {
            return Lexi_Security::error('phone_mismatch', 'بيانات الطلب غير صحيحة.', 403);
        }

        if (!Lexi_Order_Flow::is_shamcash_order($order)) {
            return Lexi_Security::error('invalid_payment_method', 'هذا الطلب لا يقبل رفع إيصال شام كاش.', 422);
        }

        $status = strtolower((string) $order->get_status());
        if (0 === strpos($status, 'wc-')) {
            $status = substr($status, 3);
        }
        $status = str_replace('_', '-', $status);
        if (!in_array(
            $status,
            array(
                Lexi_Order_Flow::STATUS_PENDING_VERIFICATION,
                Lexi_Order_Flow::STATUS_PENDING_VERIFICATION_LEGACY,
                'on-hold',
                'pending',
            ),
            true
        )) {
            return Lexi_Security::error('invalid_status', 'هذا الطلب لا يحتاج إلى إثبات دفع.', 422);
        }

        $files = $request->get_file_params();
        if (empty($files['proof_image'])) {
            return Lexi_Security::error('no_file', 'يرجى رفع صورة إثبات الدفع.', 422);
        }

        $file = $files['proof_image'];
        $allowed_types = array('image/jpeg', 'image/png', 'image/webp', 'image/gif');
        if (!in_array((string) $file['type'], $allowed_types, true)) {
            return Lexi_Security::error('invalid_file_type', 'نوع الملف غير مسموح.', 422);
        }
        if ((int) $file['size'] > 5 * 1024 * 1024) {
            return Lexi_Security::error('file_too_large', 'حجم الملف كبير جداً. الحد الأقصى 5 ميغا.', 422);
        }

        require_once ABSPATH . 'wp-admin/includes/image.php';
        require_once ABSPATH . 'wp-admin/includes/file.php';
        require_once ABSPATH . 'wp-admin/includes/media.php';

        $upload = wp_handle_upload($file, array('test_form' => false));
        if (isset($upload['error'])) {
            return Lexi_Security::error('upload_failed', 'تعذر رفع صورة الإيصال حالياً.', 500);
        }

        $attachment = array(
            'post_mime_type' => $upload['type'],
            'post_title' => sprintf('إثبات دفع - طلب #%d', $order_id),
            'post_content' => '',
            'post_status' => 'inherit',
        );

        $attach_id = wp_insert_attachment($attachment, $upload['file'], $order_id);
        if (is_wp_error($attach_id)) {
            return Lexi_Security::error('attach_failed', 'تعذر حفظ صورة الإيصال.', 500);
        }

        $metadata = wp_generate_attachment_metadata($attach_id, $upload['file']);
        wp_update_attachment_metadata($attach_id, $metadata);

        $uploaded_at = (string) current_time('mysql');
        $proof_url = (string) $upload['url'];

        $order->update_meta_data('_lexi_shamcash_proof_attachment_id', (int) $attach_id);
        $order->update_meta_data('_lexi_shamcash_proof_url', $proof_url);
        $order->update_meta_data('_lexi_shamcash_proof_uploaded_at', $uploaded_at);
        if ('' !== $note) {
            $order->update_meta_data('_lexi_shamcash_proof_note', $note);
        }

        // Backward compatibility keys.
        $order->update_meta_data('_lexi_payment_proof_id', (int) $attach_id);
        $order->update_meta_data('_lexi_payment_proof_url', $proof_url);
        $order->update_meta_data('_lexi_payment_proof_date', $uploaded_at);
        if ('' !== $note) {
            $order->update_meta_data('_lexi_payment_proof_note', $note);
        }

        if (Lexi_Order_Flow::pending_verification_storage_status() !== $status) {
            $order->set_status(
                Lexi_Order_Flow::pending_verification_storage_status(),
                'تم رفع إيصال شام كاش وبانتظار التحقق.'
            );
        }
        $order->update_meta_data('_lexi_decision', 'pending');
        $order->add_order_note('تم إرسال إيصال شام كاش وبانتظار مراجعة الإدارة.');
        $order->save();
        self::log_order_state($order, 'shamcash_proof_uploaded');

        if (class_exists('Lexi_Order_Events')) {
            Lexi_Order_Events::log(
                (int) $order->get_id(),
                'shamcash_proof_uploaded',
                'customer',
                (int) $order->get_user_id() ?: null,
                array(
                    'proof_url' => $proof_url,
                    'note' => $note,
                )
            );
        }

        Lexi_Notifications::append_timeline(
            $order,
            'proof_uploaded',
            'تم إرسال الإيصال وبانتظار التحقق.'
        );
        Lexi_Notifications::notify_admin_shamcash_proof_uploaded($order, $proof_url);

        return Lexi_Security::success(array(
            'status' => 'pending-verification',
            'message_ar' => 'تم إرسال الإيصال وبانتظار التحقق',
            'payment_proof' => array(
                'attachment_id' => (int) $attach_id,
                'image_url' => $proof_url,
                'uploaded_at' => $uploaded_at,
            ),
        ), 201);
    }

    /**
     * GET /invoices/render
     */
    public static function render_invoice(WP_REST_Request $request): WP_REST_Response
    {
        $verify = Lexi_Security::verify_signed_request($request);
        if ($verify instanceof WP_REST_Response) {
            return $verify;
        }

        $order_id = absint($request->get_param('order_id'));
        $type = sanitize_text_field((string) $request->get_param('type'));
        if (!in_array($type, array('provisional', 'final'), true)) {
            $type = 'provisional';
        }

        $html = Lexi_Invoices::render_html($order_id, $type);
        return self::html_response($html);
    }

    /**
     * GET /invoices/verify
     */
    public static function verify_invoice(WP_REST_Request $request): WP_REST_Response
    {
        $order_id = absint($request->get_param('order_id'));
        $sig = sanitize_text_field((string) $request->get_param('sig'));

        if (!$order_id || '' === trim($sig)) {
            return self::html_response(
                self::render_verification_html(false, null, 'رابط التحقق غير صالح.')
            );
        }

        $order = wc_get_order($order_id);
        if (!$order) {
            return self::html_response(
                self::render_verification_html(false, null, 'الفاتورة غير موجودة.')
            );
        }

        if (!Lexi_Invoices::verify_signature($order, $sig)) {
            return self::html_response(
                self::render_verification_html(false, null, 'فشل التحقق من توقيع الفاتورة.')
            );
        }

        return self::html_response(self::render_verification_html(true, $order));
    }

    /**
     * Return an HTML response from REST callback.
     */
    private static function html_response(string $html, int $status = 200): WP_REST_Response
    {
        $response = new WP_REST_Response(null, $status);
        $response->header('Content-Type', 'text/html; charset=utf-8');
        $response->set_data($html);

        add_filter('rest_pre_serve_request', function ($served, $result) use ($html, $status) {
            if ($result->get_data() === $html) {
                status_header($status);
                header('Content-Type: text/html; charset=utf-8');
                echo $html; // phpcs:ignore WordPress.Security.EscapeOutput.OutputNotEscaped
                return true;
            }
            return $served;
        }, 10, 2);

        return $response;
    }

    /**
     * Render invoice verification page.
     */
    private static function render_verification_html(bool $is_valid, ?WC_Order $order = null, string $message = ''): string
    {
        $title = $is_valid ? 'تم التحقق من الفاتورة' : 'تعذر التحقق من الفاتورة';
        $status_text = $is_valid ? 'فاتورة صحيحة ومعتمدة' : ($message ?: 'تعذر التحقق من الفاتورة.');
        $accent = $is_valid ? '#16a34a' : '#dc2626';
        $icon = $is_valid ? '✓' : '!';
        $helper_text = $is_valid
            ? 'يمكنك اعتماد هذه الصفحة كمرجع رسمي للتحقق من الفاتورة.'
            : 'تأكد من نسخ رابط التحقق كاملاً، أو اطلب رابطاً جديداً من المتجر.';
        $site_name = esc_html((string) get_bloginfo('name'));
        $orders_url = esc_url(home_url('/my-account/orders/'));
        $order_block = '';

        if ($is_valid && $order instanceof WC_Order) {
            $created = $order->get_date_created();
            $date = $created ? $created->date_i18n('Y-m-d H:i') : '--';
            $status = self::status_label_ar((string) $order->get_status());
            $payment = trim((string) $order->get_payment_method_title());
            if ('' === $payment) {
                $payment = 'غير محدد';
            }
            $total = number_format((float) $order->get_total(), 2, '.', ',') . ' SYP';

            $order_block = sprintf(
                "<div class='section-title'>ملخص الطلب</div>
                <div class='details'>
                    <div class='row'><span>رقم الطلب</span><strong>#%s</strong></div>
                    <div class='row'><span>الحالة</span><strong>%s</strong></div>
                    <div class='row'><span>طريقة الدفع</span><strong>%s</strong></div>
                    <div class='row'><span>الإجمالي</span><strong>%s</strong></div>
                    <div class='row'><span>تاريخ الإصدار</span><strong>%s</strong></div>
                </div>",
                esc_html((string) $order->get_order_number()),
                esc_html((string) $status),
                esc_html((string) $payment),
                esc_html((string) $total),
                esc_html((string) $date)
            );
        }

        return "<!DOCTYPE html>
<html dir='rtl' lang='ar'>
<head>
    <meta charset='UTF-8'>
    <meta name='viewport' content='width=device-width, initial-scale=1.0'>
    <title>{$title}</title>
    <style>
        * { box-sizing: border-box; }
        body {
            margin: 0;
            min-height: 100vh;
            background: radial-gradient(circle at top right, #f0f7ff 0%, #eef2f7 45%, #f8fafc 100%);
            font-family: 'Cairo', 'Segoe UI', Tahoma, Arial, sans-serif;
            color: #0f172a;
            direction: rtl;
        }
        .wrap {
            max-width: 760px;
            margin: 24px auto;
            background: #ffffff;
            border: 1px solid #e2e8f0;
            border-radius: 22px;
            overflow: hidden;
            box-shadow: 0 20px 48px rgba(15, 23, 42, 0.12);
        }
        .hero {
            padding: 24px 26px;
            background: linear-gradient(135deg, #0b1324 0%, #17223a 60%, #243b5a 100%);
            color: #fff;
        }
        .hero-top {
            display: flex;
            justify-content: space-between;
            align-items: center;
            gap: 14px;
            flex-wrap: wrap;
        }
        .site {
            font-size: 23px;
            font-weight: 800;
            letter-spacing: 0.1px;
        }
        .badge {
            display: inline-flex;
            align-items: center;
            gap: 8px;
            padding: 7px 14px;
            border-radius: 999px;
            font-size: 13px;
            font-weight: 700;
            color: #fff;
            background: {$accent};
        }
        .icon {
            width: 22px;
            height: 22px;
            border-radius: 999px;
            display: inline-grid;
            place-items: center;
            border: 1px solid rgba(255,255,255,.38);
            background: rgba(255,255,255,.16);
            font-size: 14px;
            font-weight: 900;
            line-height: 1;
        }
        .hero-title {
            margin: 14px 0 0;
            font-size: 27px;
            line-height: 1.35;
            font-weight: 800;
        }
        .hero-sub {
            margin: 8px 0 0;
            font-size: 14px;
            color: rgba(255, 255, 255, 0.9);
            line-height: 1.8;
        }
        .body {
            padding: 24px 26px;
        }
        .section-title {
            margin: 0 0 10px;
            color: #334155;
            font-size: 14px;
            font-weight: 700;
        }
        .details {
            border: 1px solid #e2e8f0;
            border-radius: 14px;
            overflow: hidden;
            background: #ffffff;
        }
        .row {
            display: flex;
            justify-content: space-between;
            align-items: center;
            gap: 12px;
            padding: 11px 14px;
            border-bottom: 1px solid #eef2f7;
            font-size: 14px;
        }
        .row:last-child {
            border-bottom: 0;
        }
        .row span {
            color: #64748b;
        }
        .row strong {
            color: #0f172a;
            font-weight: 800;
        }
        .actions {
            margin-top: 14px;
            display: flex;
            gap: 10px;
            flex-wrap: wrap;
        }
        .btn {
            display: inline-block;
            text-decoration: none;
            font-size: 13px;
            font-weight: 700;
            border-radius: 10px;
            padding: 10px 14px;
            transition: 0.2s ease;
        }
        .btn-primary {
            background: #0f172a;
            color: #fff;
        }
        .btn-secondary {
            background: #f8fafc;
            color: #0f172a;
            border: 1px solid #dbe3ef;
        }
        .foot {
            border-top: 1px solid #e2e8f0;
            background: #f8fafc;
            color: #64748b;
            font-size: 12px;
            padding: 14px 26px;
        }
        @media (max-width: 640px) {
            .wrap {
                margin: 12px;
                border-radius: 16px;
            }
            .hero, .body, .foot {
                padding: 16px;
            }
            .hero-title {
                font-size: 22px;
            }
        }
    </style>
</head>
<body>
    <div class='wrap'>
        <header class='hero'>
            <div class='hero-top'>
                <div class='site'>{$site_name}</div>
                <span class='badge'><span class='icon'>{$icon}</span>{$title}</span>
            </div>
            <h1 class='hero-title'>{$status_text}</h1>
            <p class='hero-sub'>{$helper_text}</p>
        </header>
        <main class='body'>
            {$order_block}
        </main>
        <footer class='foot'>
            تم إنشاء صفحة التحقق بتاريخ " . esc_html((string) wp_date('Y-m-d H:i')) . " — {$site_name}
        </footer>
    </div>
</body>
</html>";
    }

    /**
     * Format order payload used by app and admin screens.
     */
    public static function format_order(WC_Order $order, bool $include_private_location = false): array
    {
        $items = array();
        foreach ($order->get_items() as $item) {
            $product = $item->get_product();
            $qty = (int) $item->get_quantity();
            $subtotal = (float) $item->get_subtotal();
            $total = (float) $item->get_total();
            $discount = max(0.0, $subtotal - $total);

            // Fetch unit and pieces details if available
            $unit_type = '';
            $pieces_count = 0;
            if ($product) {
                $unit_type = trim((string) $product->get_meta('_unit_type'));
                $pieces_count = (float) $product->get_meta('_pieces_count');
                if ($pieces_count <= 0) {
                    $pieces_count = (float) $product->get_meta('_pieces_per_carton');
                }
            }
            // Fallback to item meta in case it was stored there
            if ('' === $unit_type) {
                $unit_type = trim((string) $item->get_meta('_unit_type'));
            }
            if ($pieces_count <= 0) {
                $pieces_count = (float) $item->get_meta('_pieces_count');
            }

            $items[] = array(
                'product_id' => (int) $item->get_product_id(),
                'name' => Lexi_Order_Flow::format_order_item_name($item),
                'sku' => $product ? (string) $product->get_sku() : '',
                'unit_type' => $unit_type,
                'pieces_count' => $pieces_count,
                'qty' => $qty,
                'unit_price' => $qty > 0 ? (float) round($subtotal / $qty, 2) : 0.0,
                'price' => $qty > 0 ? (float) round($subtotal / $qty, 2) : 0.0, // kept for backward compatibility
                'discount' => $discount,
                'subtotal' => $subtotal,
                'line_total' => $total,
                'total' => $total, // kept for backward compatibility
                'image' => $product ? (string) wp_get_attachment_image_url($product->get_image_id(), 'woocommerce_thumbnail') : '',
            );
        }

        $created = $order->get_date_created() ? $order->get_date_created()->date('c') : null;
        $payment_method = Lexi_Order_Flow::resolve_order_payment_method($order);

        $proof_url = trim((string) $order->get_meta('_lexi_shamcash_proof_url'));
        if ('' === $proof_url) {
            $proof_url = trim((string) $order->get_meta('_lexi_payment_proof_url'));
        }
        $proof_uploaded_at = trim((string) $order->get_meta('_lexi_shamcash_proof_uploaded_at'));
        if ('' === $proof_uploaded_at) {
            $proof_uploaded_at = trim((string) $order->get_meta('_lexi_payment_proof_date'));
        }
        $proof_note = trim((string) $order->get_meta('_lexi_shamcash_proof_note'));
        if ('' === $proof_note) {
            $proof_note = trim((string) $order->get_meta('_lexi_payment_proof_note'));
        }
        $proof_attachment_id = (int) $order->get_meta('_lexi_shamcash_proof_attachment_id');
        if ($proof_attachment_id <= 0) {
            $proof_attachment_id = (int) $order->get_meta('_lexi_payment_proof_id');
        }
        $has_proof = '' !== $proof_url;
        $delivery_location = $include_private_location ? self::read_delivery_location($order) : null;

        $public_status = self::normalize_public_status((string) $order->get_status());

        return array(
            'id' => (int) $order->get_id(),
            'order_number' => (string) $order->get_order_number(),
            'status' => $public_status,
            'status_label_ar' => self::status_label_ar($public_status),
            'total' => (float) $order->get_total(), // backward compatibility
            'subtotal' => (float) $order->get_subtotal(),
            'shipping_cost' => (float) $order->get_shipping_total(), // backward compatibility
            'shipping_total' => (float) $order->get_shipping_total(),
            'discount_total' => (float) $order->get_discount_total(),
            'tax' => (float) $order->get_total_tax(),
            'final_total' => (float) $order->get_total(),
            'amount_to_collect' => (float) $order->get_total(), // App can override with COD if necessary
            'currency' => (string) $order->get_currency(),
            'payment_method' => $payment_method,
            'date' => $created,
            'date_created' => $created,
            'billing' => array(
                'first_name' => (string) $order->get_billing_first_name(),
                'last_name' => (string) $order->get_billing_last_name(),
                'phone' => (string) $order->get_billing_phone(),
                'email' => (string) $order->get_billing_email(),
                'address_1' => (string) $order->get_billing_address_1(),
                'city' => (string) $order->get_billing_city(),
            ),
            'items' => $items,
            'line_items' => $items,
            'customer_note' => (string) $order->get_customer_note(),
            'invoice_verification_url' => Lexi_Invoices::get_verification_url($order),
            'decision' => (string) $order->get_meta('_lexi_decision'),
            'delivery_location' => $delivery_location,
            'proof' => array(
                'has_proof' => $has_proof,
                'image_url' => $has_proof ? $proof_url : null,
                'uploaded_at' => $has_proof ? $proof_uploaded_at : null,
                'note' => $has_proof ? $proof_note : null,
            ),
            'payment_proof' => $has_proof ? array(
                'order_id' => (string) $order->get_id(),
                'image_url' => $proof_url,
                'attachment_id' => $proof_attachment_id,
                'uploaded_at' => $proof_uploaded_at,
                'status' => 'pending',
            ) : null,
        );
    }

    /**
     * @return array<string,mixed>|null
     */
    private static function read_delivery_location(WC_Order $order): ?array
    {
        $lat = self::meta_float_or_null($order->get_meta('_lexi_delivery_lat'));
        $lng = self::meta_float_or_null($order->get_meta('_lexi_delivery_lng'));
        $accuracy = self::meta_float_or_null($order->get_meta('_lexi_delivery_accuracy'));
        $full_address = trim((string) $order->get_meta('_lexi_delivery_full_address'));
        $city = trim((string) $order->get_meta('_lexi_delivery_city'));
        $area = trim((string) $order->get_meta('_lexi_delivery_area'));
        $street = trim((string) $order->get_meta('_lexi_delivery_street'));
        $building = trim((string) $order->get_meta('_lexi_delivery_building'));
        $notes = trim((string) $order->get_meta('_lexi_delivery_notes'));
        $captured_at = trim((string) $order->get_meta('_lexi_delivery_captured_at'));
        $maps_open_url = trim((string) $order->get_meta('_lexi_maps_open_url'));
        $maps_navigate_url = trim((string) $order->get_meta('_lexi_maps_navigate_url'));

        if ('' === $full_address) {
            $full_address = trim((string) $order->get_billing_address_1());
        }
        if ('' === $city) {
            $city = trim((string) $order->get_billing_city());
        }

        if ('' === $maps_open_url && null !== $lat && null !== $lng) {
            $destination = self::format_coordinate($lat) . ',' . self::format_coordinate($lng);
            $maps_open_url = 'https://www.google.com/maps/search/?api=1&query=' . $destination;
        }
        if ('' === $maps_navigate_url && null !== $lat && null !== $lng) {
            $destination = self::format_coordinate($lat) . ',' . self::format_coordinate($lng);
            $maps_navigate_url = 'https://www.google.com/maps/dir/?api=1&destination=' . $destination . '&travelmode=driving';
        }
        if ('' === $maps_open_url && '' !== $full_address) {
            $maps_open_url = 'https://www.google.com/maps/search/?api=1&query=' . rawurlencode($full_address);
        }
        if ('' === $maps_navigate_url && '' !== $full_address) {
            $maps_navigate_url = 'https://www.google.com/maps/dir/?api=1&destination=' . rawurlencode($full_address) . '&travelmode=driving';
        }

        $has_any_delivery_data =
            null !== $lat ||
            null !== $lng ||
            '' !== $full_address ||
            '' !== $city ||
            '' !== $area ||
            '' !== $street ||
            '' !== $building ||
            '' !== $notes ||
            '' !== $maps_open_url ||
            '' !== $maps_navigate_url;

        if (!$has_any_delivery_data) {
            return null;
        }

        return array(
            'lat' => $lat,
            'lng' => $lng,
            'accuracy_meters' => $accuracy,
            'full_address' => $full_address,
            'city' => $city,
            'area' => $area,
            'street' => $street,
            'building' => $building,
            'notes' => $notes,
            'captured_at' => $captured_at,
            'maps_open_url' => $maps_open_url,
            'maps_navigate_url' => $maps_navigate_url,
        );
    }

    private static function meta_float_or_null($raw): ?float
    {
        $value = trim((string) $raw);
        if ('' === $value || !is_numeric($value)) {
            return null;
        }

        return (float) $value;
    }

    private static function format_coordinate(float $value): string
    {
        return rtrim(rtrim(sprintf('%.6F', $value), '0'), '.');
    }

    /**
     * Resolve order ID from order_id or order_number.
     */
    private static function resolve_order_id(array $body): int
    {
        $order_id = absint($body['order_id'] ?? 0);
        if ($order_id > 0) {
            return $order_id;
        }

        $order_number_raw = isset($body['order_number']) ? (string) $body['order_number'] : '';
        if ('' === trim($order_number_raw)) {
            return 0;
        }

        $digits = preg_replace('/\D+/', '', $order_number_raw);
        if ('' === $digits) {
            return 0;
        }

        return absint($digits);
    }

    private static function is_phone_match(WC_Order $order, string $phone): bool
    {
        $saved = Lexi_Security::sanitize_phone((string) $order->get_meta('_lexi_phone'));
        if ('' === $saved) {
            $saved = Lexi_Security::sanitize_phone((string) $order->get_billing_phone());
        }
        return $saved === $phone;
    }

    /**
     * @return array<int,string>
     */
    private static function customer_visible_statuses(): array
    {
        return array(
            'pending',
            'processing',
            'on-hold',
            'completed',
            'cancelled',
            'failed',
            'refunded',
            Lexi_Order_Flow::STATUS_PENDING_VERIFICATION,
            Lexi_Order_Flow::STATUS_PENDING_VERIFICATION_LEGACY,
            Lexi_Order_Flow::STATUS_OUT_FOR_DELIVERY,
            Lexi_Order_Flow::STATUS_DELIVERED_UNPAID,
        );
    }

    private static function normalize_payment_method_filter(string $raw): string
    {
        $method = Lexi_Order_Flow::normalize_payment_method($raw);
        if (in_array(
            $method,
            array(Lexi_Order_Flow::PAYMENT_METHOD_COD, Lexi_Order_Flow::PAYMENT_METHOD_SHAMCASH),
            true
        )) {
            return $method;
        }

        return '';
    }

    private static function order_matches_payment_method_filter(WC_Order $order, string $filter): bool
    {
        if ('' === $filter) {
            return true;
        }

        return Lexi_Order_Flow::resolve_order_payment_method($order) === $filter;
    }

    private static function is_incomplete_status(string $status): bool
    {
        $status = self::normalize_public_status($status);
        if ('' === $status) {
            return true;
        }
        return !in_array($status, array('completed', 'cancelled', 'failed', 'refunded'), true);
    }

    private static function status_label_ar(string $status): string
    {
        $status = self::normalize_public_status($status);
        if ('pending-verification' === $status) {
            return 'بانتظار التحقق من الدفع';
        }
        $labels = array(
            'pending' => 'قيد الانتظار',
            'processing' => 'قيد المعالجة',
            'on-hold' => 'معلّق',
            'completed' => 'مكتمل',
            'cancelled' => 'ملغي',
            'failed' => 'فاشل',
            'refunded' => 'مسترجع',
            'pending-verification' => 'بانتظار التحقق',
            'out-for-delivery' => 'خرج للتسليم',
            'delivered-unpaid' => 'تم التسليم - غير مسدد',
        );
        return $labels[$status] ?? $status;
    }

    /**
     * Normalize raw Woo status into public API status.
     *
     * Handles legacy truncated custom status (pending-verificat) caused by
     * post_status length limit.
     */
    private static function normalize_public_status(string $status): string
    {
        return Lexi_Order_Flow::normalize_public_status($status);
    }

    private static function log_order_state(WC_Order $order, string $stage): void
    {
        if (!function_exists('wc_get_logger')) {
            return;
        }

        $order_id = (int) $order->get_id();
        $post = $order_id > 0 ? get_post($order_id) : null;
        wc_get_logger()->info(
            sprintf(
                '[ORDERS] %s order_id=%d order_number=%s wc_status=%s post_status=%s post_type=%s payment_method=%s lexi_payment_method=%s',
                $stage,
                $order_id,
                (string) $order->get_order_number(),
                (string) $order->get_status(),
                $post ? (string) $post->post_status : 'n/a',
                $post ? (string) $post->post_type : 'n/a',
                (string) $order->get_payment_method(),
                (string) $order->get_meta('_lexi_payment_method')
            ),
            array('source' => 'lexi-api')
        );
    }
}
