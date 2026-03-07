<?php
/**
 * Delivery agent REST routes.
 *
 * @package Lexi_API
 */

defined('ABSPATH') || exit;

class Lexi_Routes_Delivery
{
    private const META_AVAILABLE = '_lexi_delivery_available';
    private const META_ASSIGNED_AGENT = '_lexi_delivery_agent_id';
    private const META_ASSIGNED_AT = '_lexi_delivery_assigned_at';
    private const META_ASSIGNED_BY = '_lexi_delivery_assigned_by';
    private const META_DELIVERY_STATE = '_lexi_delivery_state';
    private const META_ASSIGNMENT_STATE = '_lexi_courier_assignment_state';
    private const META_ASSIGNMENT_EXPIRES_AT = '_lexi_courier_assignment_expires_at';
    private const META_ASSIGNMENT_TTL = '_lexi_courier_assignment_ttl_seconds';
    private const META_ASSIGNMENT_DECIDED_BY = '_lexi_courier_assignment_decided_by';
    private const META_ASSIGNMENT_DECIDED_AT = '_lexi_courier_assignment_decided_at';
    private const META_ASSIGNMENT_DECISION = '_lexi_courier_assignment_decision';
    private const META_ASSIGNMENT_ACCEPT_LOCK = '_lexi_courier_assignment_accept_lock';

    private const META_COD_EXPECTED = '_lexi_cod_expected_amount';
    private const META_COD_COLLECTED_AMOUNT = '_lexi_cod_collected_amount';
    private const META_COD_COLLECTED_AT = '_lexi_cod_collected_at';
    private const META_COD_COLLECTED_BY = '_lexi_cod_collected_by';
    private const META_COD_STATUS = '_lexi_cod_collected_status';
    private const META_COD_LEDGER = '_lexi_cod_ledger';
    private const META_COD_OVERRIDE_APPROVED = '_lexi_cod_override_approved';
    private const META_COD_OVERRIDE_REASON = '_lexi_cod_override_reason';
    private const META_COD_OVERRIDE_BY = '_lexi_cod_override_by';
    private const META_COD_OVERRIDE_AT = '_lexi_cod_override_at';
    private const COD_TOLERANCE_DEFAULT = 0.01;

    /**
     * Register delivery routes.
     */
    public static function register(): void
    {
        $ns = LEXI_API_NAMESPACE;

        register_rest_route($ns, '/delivery/me', array(
            'methods' => WP_REST_Server::READABLE,
            'callback' => array(__CLASS__, 'get_me'),
            'permission_callback' => array('Lexi_Security', 'delivery_access'),
        ));

        register_rest_route($ns, '/delivery/availability', array(
            array(
                'methods' => WP_REST_Server::READABLE,
                'callback' => array(__CLASS__, 'get_availability'),
                'permission_callback' => array('Lexi_Security', 'delivery_access'),
            ),
            array(
                'methods' => WP_REST_Server::EDITABLE,
                'callback' => array(__CLASS__, 'set_availability'),
                'permission_callback' => array('Lexi_Security', 'delivery_access'),
            ),
        ));

        register_rest_route($ns, '/courier/location', array(
            'methods' => WP_REST_Server::CREATABLE,
            'callback' => array(__CLASS__, 'post_courier_location'),
            'permission_callback' => array('Lexi_Security', 'delivery_access'),
        ));

        register_rest_route($ns, '/delivery/orders', array(
            'methods' => WP_REST_Server::READABLE,
            'callback' => array(__CLASS__, 'get_orders'),
            'permission_callback' => array('Lexi_Security', 'delivery_access'),
            'args' => array(
                'status' => array('default' => '', 'sanitize_callback' => 'sanitize_text_field'),
                'page' => array('default' => 1, 'sanitize_callback' => 'absint'),
                'per_page' => array('default' => 20, 'sanitize_callback' => 'absint'),
            ),
        ));

        register_rest_route($ns, '/delivery/orders/(?P<id>\d+)', array(
            'methods' => WP_REST_Server::READABLE,
            'callback' => array(__CLASS__, 'get_order'),
            'permission_callback' => array('Lexi_Security', 'delivery_access'),
            'args' => array(
                'id' => array('required' => true, 'sanitize_callback' => 'absint'),
            ),
        ));

        register_rest_route($ns, '/delivery/orders/(?P<id>\d+)/status', array(
            'methods' => WP_REST_Server::EDITABLE,
            'callback' => array(__CLASS__, 'update_order_status'),
            'permission_callback' => array('Lexi_Security', 'delivery_access'),
            'args' => array(
                'id' => array('required' => true, 'sanitize_callback' => 'absint'),
            ),
        ));

        register_rest_route($ns, '/delivery/orders/(?P<id>\d+)/collect-cod', array(
            'methods' => WP_REST_Server::CREATABLE,
            'callback' => array(__CLASS__, 'collect_cod'),
            'permission_callback' => array('Lexi_Security', 'delivery_access'),
            'args' => array(
                'id' => array('required' => true, 'sanitize_callback' => 'absint'),
            ),
        ));

        register_rest_route($ns, '/courier/assignments/(?P<id>\d+)/accept', array(
            'methods' => WP_REST_Server::CREATABLE,
            'callback' => array(__CLASS__, 'accept_assignment'),
            'permission_callback' => array('Lexi_Security', 'delivery_access'),
            'args' => array(
                'id' => array('required' => true, 'sanitize_callback' => 'absint'),
            ),
        ));

        register_rest_route($ns, '/courier/assignments/(?P<id>\d+)/decline', array(
            'methods' => WP_REST_Server::CREATABLE,
            'callback' => array(__CLASS__, 'decline_assignment'),
            'permission_callback' => array('Lexi_Security', 'delivery_access'),
            'args' => array(
                'id' => array('required' => true, 'sanitize_callback' => 'absint'),
            ),
        ));

        register_rest_route($ns, '/courier/assignments/(?P<id>\d+)/cancel', array(
            'methods' => WP_REST_Server::CREATABLE,
            'callback' => array(__CLASS__, 'cancel_assignment'),
            'permission_callback' => array('Lexi_Security', 'delivery_access'),
            'args' => array(
                'id' => array('required' => true, 'sanitize_callback' => 'absint'),
            ),
        ));
    }

    /**
     * GET /delivery/me
     */
    public static function get_me(WP_REST_Request $request): WP_REST_Response
    {
        $user = wp_get_current_user();
        $user_id = (int) $user->ID;
        $is_available = self::is_available($user_id);
        $has_recent_location = class_exists('Lexi_Courier_Locations')
            ? Lexi_Courier_Locations::has_recent_ping($user_id)
            : true;
        $stale_after_minutes = class_exists('Lexi_Courier_Locations')
            ? Lexi_Courier_Locations::stale_after_minutes()
            : null;

        return Lexi_Security::success(array(
            'id' => $user_id,
            'user_login' => (string) $user->user_login,
            'email' => (string) $user->user_email,
            'display_name' => (string) $user->display_name,
            'roles' => array_values((array) $user->roles),
            'is_delivery_agent' => true,
            'is_available' => $is_available,
            'location_required' => class_exists('Lexi_Courier_Locations'),
            'location_stale_after_minutes' => $stale_after_minutes,
            'has_recent_location' => $has_recent_location,
        ));
    }

    /**
     * POST /courier/location
     */
    public static function post_courier_location(WP_REST_Request $request): WP_REST_Response
    {
        if (!class_exists('Lexi_Courier_Locations')) {
            return Lexi_Security::error('location_service_unavailable', 'خدمة الموقع غير متاحة حالياً.', 500);
        }

        $body = (array) $request->get_json_params();
        $lat = isset($body['lat']) && is_numeric($body['lat']) ? (float) $body['lat'] : null;
        $lng = isset($body['lng']) && is_numeric($body['lng']) ? (float) $body['lng'] : null;
        if (null === $lat || null === $lng) {
            return Lexi_Security::error('invalid_location', 'إحداثيات الموقع مطلوبة.', 422);
        }
        if ($lat < -90 || $lat > 90 || $lng < -180 || $lng > 180) {
            return Lexi_Security::error('invalid_location_range', 'إحداثيات الموقع غير صالحة.', 422);
        }

        $accuracy = isset($body['accuracy']) && is_numeric($body['accuracy']) ? (float) $body['accuracy'] : null;
        $heading = isset($body['heading']) && is_numeric($body['heading']) ? (float) $body['heading'] : null;
        $speed = isset($body['speed']) && is_numeric($body['speed']) ? (float) $body['speed'] : null;
        $device_id = sanitize_text_field((string) ($body['device_id'] ?? ''));

        $courier_id = (int) get_current_user_id();
        $saved = Lexi_Courier_Locations::upsert(
            $courier_id,
            $lat,
            $lng,
            $accuracy,
            $heading,
            $speed,
            $device_id
        );
        if (!$saved) {
            return Lexi_Security::error('location_save_failed', 'تعذر حفظ موقع المندوب.', 500);
        }

        if (class_exists('Lexi_Order_Events')) {
            Lexi_Order_Events::log(
                null,
                'location_ping',
                'courier',
                $courier_id,
                array(
                    'lat' => $lat,
                    'lng' => $lng,
                    'accuracy_m' => $accuracy,
                    'device_id' => $device_id,
                ),
                $courier_id
            );
        }

        $destination = self::format_coordinate($lat) . ',' . self::format_coordinate($lng);
        $maps_navigate_url = 'https://www.google.com/maps/dir/?api=1&destination=' .
            rawurlencode($destination) .
            '&travelmode=driving';

        return Lexi_Security::success(array(
            'courier_id' => $courier_id,
            'lat' => $lat,
            'lng' => $lng,
            'accuracy_m' => $accuracy,
            'heading' => $heading,
            'speed_mps' => $speed,
            'updated_at' => current_time('mysql', true),
            'maps_navigate_url' => $maps_navigate_url,
        ));
    }

    /**
     * GET /delivery/availability
     */
    public static function get_availability(WP_REST_Request $request): WP_REST_Response
    {
        $user_id = get_current_user_id();
        return Lexi_Security::success(array(
            'user_id' => (int) $user_id,
            'is_available' => self::is_available((int) $user_id),
        ));
    }

    /**
     * PATCH /delivery/availability
     */
    public static function set_availability(WP_REST_Request $request): WP_REST_Response
    {
        $body = (array) $request->get_json_params();
        $is_available = self::coerce_bool($body['is_available'] ?? true);
        $user_id = (int) get_current_user_id();

        update_user_meta($user_id, self::META_AVAILABLE, $is_available ? '1' : '0');

        return Lexi_Security::success(array(
            'message' => $is_available ? 'تم تحويل الحالة إلى متاح.' : 'تم تحويل الحالة إلى غير متاح.',
            'user_id' => $user_id,
            'is_available' => $is_available,
        ));
    }

    /**
     * GET /delivery/orders
     */
    public static function get_orders(WP_REST_Request $request): WP_REST_Response
    {
        $user_id = (int) get_current_user_id();
        $location_guard = self::guard_recent_courier_location($user_id);
        if ($location_guard instanceof WP_REST_Response) {
            return $location_guard;
        }

        $status = self::normalize_status((string) $request->get_param('status'));
        $page = max(1, (int) $request->get_param('page'));
        $per_page = min(100, max(1, (int) $request->get_param('per_page')));

        $args = array(
            'limit' => $per_page,
            'offset' => ($page - 1) * $per_page,
            'orderby' => 'date',
            'order' => 'DESC',
            'meta_query' => array(
                array(
                    'key' => self::META_ASSIGNED_AGENT,
                    'value' => (string) $user_id,
                    'compare' => '=',
                ),
            ),
        );

        if ('' !== $status && 'all' !== $status) {
            $args['status'] = $status;
        }

        $orders = wc_get_orders($args);
        $total_args = $args;
        $total_args['limit'] = -1;
        $total_args['offset'] = 0;
        $total_args['return'] = 'ids';
        $total = count((array) wc_get_orders($total_args));

        $items = array();
        foreach ($orders as $order) {
            if (!($order instanceof WC_Order)) {
                continue;
            }

            $payload = Lexi_Routes_Orders::format_order($order, true);
            $payload['delivery_assignment'] = self::build_assignment_payload($order);
            $payload['cod'] = self::build_cod_payload($order);
            $items[] = $payload;
        }

        return Lexi_Security::success(array(
            'items' => $items,
            'page' => $page,
            'per_page' => $per_page,
            'total' => (int) $total,
            'total_pages' => max(1, (int) ceil($total / $per_page)),
            'is_available' => self::is_available($user_id),
        ));
    }

    /**
     * GET /delivery/orders/{id}
     */
    public static function get_order(WP_REST_Request $request): WP_REST_Response
    {
        $order = wc_get_order((int) $request->get_param('id'));
        if (!$order) {
            return Lexi_Security::error('order_not_found', 'الطلب غير موجود.', 404);
        }

        $user_id = (int) get_current_user_id();
        if (!self::is_order_assigned_to((int) $order->get_id(), $user_id)) {
            return Lexi_Security::error('forbidden', 'هذا الطلب غير مسند لك.', 403);
        }

        $payload = Lexi_Routes_Orders::format_order($order, true);
        $payload['delivery_assignment'] = self::build_assignment_payload($order);
        $payload['cod'] = self::build_cod_payload($order);

        return Lexi_Security::success($payload);
    }

    /**
     * PATCH /delivery/orders/{id}/status
     */
    public static function update_order_status(WP_REST_Request $request): WP_REST_Response
    {
        $order = wc_get_order((int) $request->get_param('id'));
        if (!$order) {
            return Lexi_Security::error('order_not_found', 'الطلب غير موجود.', 404);
        }

        $user_id = (int) get_current_user_id();
        if (!self::is_order_assigned_to((int) $order->get_id(), $user_id)) {
            return Lexi_Security::error('forbidden', 'هذا الطلب غير مسند لك.', 403);
        }

        $body = (array) $request->get_json_params();
        $status = self::normalize_status((string) ($body['status'] ?? ''));
        $note = sanitize_textarea_field((string) ($body['note'] ?? ''));
        $customer_event_type = '';
        $customer_event_title = '';
        $customer_event_body = '';

        if ('' === $status) {
            return Lexi_Security::error('missing_status', 'حالة الطلب الجديدة مطلوبة.', 422);
        }

        if ('out-for-delivery' === $status || 'out_for_delivery' === $status) {
            $order->update_meta_data(self::META_DELIVERY_STATE, 'out_for_delivery');
            $order->set_status(Lexi_Order_Flow::STATUS_OUT_FOR_DELIVERY, 'تم تحديث الحالة بواسطة المندوب: خرج للتسليم.');
            if ('' !== trim($note)) {
                $order->add_order_note('ملاحظة المندوب: ' . $note, 0, true);
            }
            $order->save();

            if (class_exists('Lexi_Order_Events')) {
                Lexi_Order_Events::log(
                    (int) $order->get_id(),
                    'out_for_delivery',
                    'courier',
                    $user_id,
                    array('note' => $note),
                    $user_id
                );
            }
            $customer_event_type = 'order_assigned';
            $customer_event_title = 'Your order is out for delivery';
            $customer_event_body = sprintf(
                'Order #%s is now on the way.',
                (string) $order->get_order_number()
            );
        } elseif ('completed' === $status || 'delivered' === $status) {
            if (self::is_cod_order($order) && !self::is_cod_settled($order)) {
                return Lexi_Security::error(
                    'cod_not_confirmed',
                    'لا يمكن تأكيد التسليم قبل تحصيل مبلغ الدفع عند الاستلام.',
                    422
                );
            }

            $order->set_status('completed', 'تم تسليم الطلب بواسطة المندوب.');
            if ('' !== trim($note)) {
                $order->add_order_note('ملاحظة المندوب: ' . $note, 0, true);
            }
            $order->save();

            if (class_exists('Lexi_Order_Events')) {
                Lexi_Order_Events::log(
                    (int) $order->get_id(),
                    'delivered',
                    'courier',
                    $user_id,
                    array('note' => $note),
                    $user_id
                );
            }
            $customer_event_type = 'order_delivered';
            $customer_event_title = 'Order delivered';
            $customer_event_body = sprintf(
                'Order #%s has been delivered successfully.',
                (string) $order->get_order_number()
            );
        } elseif (in_array($status, array('processing', 'cancelled', 'failed'), true)) {
            $order->set_status($status, 'تحديث حالة الطلب بواسطة المندوب.');
            if ('' !== trim($note)) {
                $order->add_order_note('ملاحظة المندوب: ' . $note, 0, true);
            }
            $order->save();

            if (class_exists('Lexi_Order_Events')) {
                $event_type = 'status_changed';
                if ('failed' === $status) {
                    $event_type = 'failed_delivery';
                } elseif ('cancelled' === $status) {
                    $event_type = 'returned';
                }

                Lexi_Order_Events::log(
                    (int) $order->get_id(),
                    $event_type,
                    'courier',
                    $user_id,
                    array(
                        'status' => $status,
                        'note' => $note,
                    ),
                    $user_id
                );
            }
        } else {
            return Lexi_Security::error('invalid_status', 'حالة الطلب غير صالحة.', 422);
        }

        if ($customer_event_type !== '') {
            self::notify_customer_status_update(
                $order,
                $customer_event_type,
                $customer_event_title,
                $customer_event_body
            );
        }

        $payload = Lexi_Routes_Orders::format_order($order, true);
        $payload['delivery_assignment'] = self::build_assignment_payload($order);
        $payload['cod'] = self::build_cod_payload($order);

        return Lexi_Security::success(array(
            'message' => 'تم تحديث حالة الطلب.',
            'order' => $payload,
        ));
    }

    /**
     * POST /delivery/orders/{id}/collect-cod
     */
    public static function collect_cod(WP_REST_Request $request): WP_REST_Response
    {
        $order = wc_get_order((int) $request->get_param('id'));
        if (!$order) {
            return Lexi_Security::error('order_not_found', 'الطلب غير موجود.', 404);
        }

        $user_id = (int) get_current_user_id();
        if (!self::is_order_assigned_to((int) $order->get_id(), $user_id)) {
            return Lexi_Security::error('forbidden', 'هذا الطلب غير مسند لك.', 403);
        }

        if (!self::is_cod_order($order)) {
            return Lexi_Security::error('not_cod', 'لا يوجد مبلغ تحصيل لهذا الطلب.', 422);
        }

        if (self::is_cod_settled($order)) {
            $payload = Lexi_Routes_Orders::format_order($order, true);
            $payload['delivery_assignment'] = self::build_assignment_payload($order);
            $payload['cod'] = self::build_cod_payload($order);
            return Lexi_Security::success(array(
                'message' => 'تم تأكيد التحصيل مسبقاً.',
                'new_status' => (string) $order->get_status(),
                'locked' => true,
                'order' => $payload,
            ));
        }

        if (!self::cod_rate_limit_allows($user_id, (int) $order->get_id())) {
            self::audit_cod_attempt($order, $user_id, 'fail', array('reason' => 'rate_limited'));
            return Lexi_Security::error('rate_limited', 'تم تجاوز عدد المحاولات. حاول لاحقاً.', 429);
        }

        $body = (array) $request->get_json_params();
        $note = sanitize_textarea_field((string) ($body['note'] ?? ''));
        $reference = sanitize_text_field((string) ($body['reference'] ?? ''));
        $currency = strtoupper(trim((string) ($body['currency'] ?? $order->get_currency())));

        $raw_amount = (string) ($body['collected_amount'] ?? '');
        $received = self::normalize_decimal($raw_amount);
        if ('' === $received) {
            self::audit_cod_attempt($order, $user_id, 'fail', array('reason' => 'missing_amount'));
            return Lexi_Security::error('missing_amount', 'يرجى إدخال مبلغ التحصيل.', 422);
        }

        $expected = self::expected_cod_amount($order);
        $expected_float = self::decimal_to_float($expected);
        $received_float = self::decimal_to_float($received);
        if ($received_float <= 0.0) {
            self::audit_cod_attempt($order, $user_id, 'fail', array('reason' => 'invalid_amount'));
            return Lexi_Security::error('invalid_amount', 'قيمة التحصيل يجب أن تكون أكبر من صفر.', 422);
        }

        $ledger = self::get_cod_ledger($order);
        $collected_before = self::cod_ledger_total($ledger);
        $collected_after = round($collected_before + $received_float, 2);
        $tolerance = self::cod_tolerance();

        if ($collected_after > ($expected_float + $tolerance)) {
            self::audit_cod_attempt($order, $user_id, 'fail', array(
                'expected' => $expected,
                'collected_before' => self::format_decimal($collected_before),
                'received' => $received,
                'collected_after' => self::format_decimal($collected_after),
                'currency' => $currency,
            ));
            return Lexi_Security::error(
                'amount_mismatch_requires_override',
                'المبلغ يتجاوز المطلوب. يلزم اعتماد إداري للتجاوز.',
                400,
                array(
                    'expected' => $expected,
                    'received' => $received,
                    'collected_before' => self::format_decimal($collected_before),
                    'collected_after' => self::format_decimal($collected_after),
                    'currency' => $currency,
                    'can_override' => true,
                )
            );
        }

        $remaining = max(0.0, round($expected_float - $collected_after, 2));
        $is_partial = $remaining > $tolerance;

        $ledger = self::append_cod_ledger_entry(
            $order,
            array(
                'amount' => $received,
                'method' => 'cash',
                'collected_by' => $user_id,
                'collected_at' => gmdate('c'),
                'reference' => $reference,
                'notes' => $note,
                'kind' => $is_partial ? 'partial' : 'collected',
                'expected_amount' => $expected,
                'running_collected' => self::format_decimal($collected_after),
                'remaining_amount' => self::format_decimal($remaining),
            )
        );

        $order->update_meta_data(self::META_COD_EXPECTED, $expected);
        $order->update_meta_data(self::META_COD_COLLECTED_AMOUNT, self::format_decimal($collected_after));
        $order->update_meta_data(self::META_COD_COLLECTED_AT, gmdate('c'));
        $order->update_meta_data(self::META_COD_COLLECTED_BY, $user_id);
        $order->update_meta_data(self::META_COD_STATUS, $is_partial ? 'partial' : 'confirmed');

        $order->add_order_note(
            sprintf(
                'تم تحصيل الدفع عند الاستلام بواسطة المندوب (ID:%d). المبلغ: %s %s',
                $user_id,
                $received,
                $currency
            )
        );
        if ('' !== trim($note)) {
            $order->add_order_note('ملاحظة المندوب: ' . $note, 0, true);
        }

        if ($is_partial) {
            $order->set_status(
                Lexi_Order_Flow::STATUS_DELIVERED_UNPAID,
                'تم تسليم الطلب مع تحصيل جزئي للدفع عند الاستلام.'
            );
            $order->save();

            self::audit_cod_attempt($order, $user_id, 'partial', array(
                'expected' => $expected,
                'received' => $received,
                'collected_total' => self::format_decimal($collected_after),
                'remaining' => self::format_decimal($remaining),
                'currency' => $currency,
            ));

            if (class_exists('Lexi_Order_Events')) {
                Lexi_Order_Events::log(
                    (int) $order->get_id(),
                    'cod_partial',
                    'courier',
                    $user_id,
                    array(
                        'expected' => $expected,
                        'received' => $received,
                        'collected_total' => self::format_decimal($collected_after),
                        'remaining' => self::format_decimal($remaining),
                        'currency' => $currency,
                        'reference' => $reference,
                    ),
                    $user_id
                );
            }

            $payload = Lexi_Routes_Orders::format_order($order, true);
            $payload['delivery_assignment'] = self::build_assignment_payload($order);
            $payload['cod'] = self::build_cod_payload($order);

            return Lexi_Security::success(array(
                'message' => 'تم تسجيل تحصيل جزئي للدفع عند الاستلام.',
                'new_status' => (string) $order->get_status(),
                'locked' => false,
                'order' => $payload,
            ));
        }

        $order->set_status('completed', 'تم تسليم الطلب وتأكيد التحصيل بواسطة المندوب.');
        $order->save();

        self::notify_customer_status_update(
            $order,
            'order_delivered',
            'Order delivered',
            sprintf('Order #%s has been delivered and COD was confirmed.', (string) $order->get_order_number())
        );

        self::audit_cod_attempt($order, $user_id, 'success', array(
            'expected' => $expected,
            'received' => $received,
            'collected_total' => self::format_decimal($collected_after),
            'currency' => $currency,
        ));

        if (class_exists('Lexi_Order_Events')) {
            Lexi_Order_Events::log(
                (int) $order->get_id(),
                'cod_collected',
                'courier',
                $user_id,
                array(
                    'expected' => $expected,
                    'received' => $received,
                    'collected_total' => self::format_decimal($collected_after),
                    'currency' => $currency,
                    'reference' => $reference,
                ),
                $user_id,
                $received_float
            );
        }

        $payload = Lexi_Routes_Orders::format_order($order, true);
        $payload['delivery_assignment'] = self::build_assignment_payload($order);
        $payload['cod'] = self::build_cod_payload($order);

        return Lexi_Security::success(array(
            'message' => 'تم تأكيد التحصيل وتحديث حالة الطلب.',
            'new_status' => (string) $order->get_status(),
            'locked' => true,
            'order' => $payload,
        ));
    }


    /**
     * POST /courier/assignments/{id}/accept
     */
    public static function accept_assignment(WP_REST_Request $request): WP_REST_Response
    {
        $order = wc_get_order((int) $request->get_param('id'));
        if (!$order) {
            return Lexi_Security::error('order_not_found', 'Order not found.', 404);
        }

        $courier_id = (int) get_current_user_id();
        $order_id = (int) $order->get_id();

        if (!self::is_assignment_action_allowed($order)) {
            return Lexi_Security::error('invalid_order_state', 'Order cannot be handled in the current state.', 422);
        }

        $assignment_guard = self::guard_assignment_access($order, $courier_id);
        if ($assignment_guard instanceof WP_REST_Response) {
            return $assignment_guard;
        }

        $expired_guard = self::guard_assignment_ttl($order);
        if ($expired_guard instanceof WP_REST_Response) {
            return $expired_guard;
        }

        $accepted_by = (int) get_post_meta($order_id, self::META_ASSIGNMENT_ACCEPT_LOCK, true);
        if ($accepted_by > 0 && $accepted_by !== $courier_id) {
            return Lexi_Security::error('already_taken', 'Assignment is already accepted by another courier.', 409);
        }
        if ($accepted_by === $courier_id) {
            return self::assignment_action_success($order, 'Assignment was already accepted by you.', true);
        }

        $lock_added = add_post_meta($order_id, self::META_ASSIGNMENT_ACCEPT_LOCK, (string) $courier_id, true);
        if (!$lock_added) {
            $accepted_by_after = (int) get_post_meta($order_id, self::META_ASSIGNMENT_ACCEPT_LOCK, true);
            if ($accepted_by_after !== $courier_id) {
                return Lexi_Security::error('already_taken', 'Assignment is already accepted by another courier.', 409);
            }
            return self::assignment_action_success($order, 'Assignment was already accepted by you.', true);
        }

        $order->update_meta_data(self::META_ASSIGNED_AGENT, $courier_id);
        if ('' === trim((string) $order->get_meta(self::META_ASSIGNED_AT))) {
            $order->update_meta_data(self::META_ASSIGNED_AT, gmdate('c'));
        }
        $order->update_meta_data(self::META_DELIVERY_STATE, 'accepted');
        $order->update_meta_data(self::META_ASSIGNMENT_STATE, 'accepted');
        $order->update_meta_data(self::META_ASSIGNMENT_DECISION, 'accepted');
        $order->update_meta_data(self::META_ASSIGNMENT_DECIDED_BY, $courier_id);
        $order->update_meta_data(self::META_ASSIGNMENT_DECIDED_AT, gmdate('c'));

        $current_status = self::normalize_status((string) $order->get_status());
        if (in_array($current_status, array('pending', 'on-hold', 'pending-verification', 'pending-verificat'), true)) {
            $order->set_status('processing', 'Courier accepted assignment.');
        }

        $order->add_order_note('Courier accepted assignment.');
        $order->save();

        if (class_exists('Lexi_Delivery_Audit')) {
            Lexi_Delivery_Audit::log(
                'assignment_accepted',
                $order_id,
                $courier_id,
                null,
                'success',
                'Courier accepted assignment'
            );
        }

        if (class_exists('Lexi_Order_Events')) {
            Lexi_Order_Events::log(
                $order_id,
                'accepted',
                'courier',
                $courier_id,
                array(
                    'assignment_state' => 'accepted',
                ),
                $courier_id
            );
        }

        $courier_user = get_user_by('id', $courier_id);
        $courier_phone = (string) get_user_meta($courier_id, 'billing_phone', true);
        $courier_name = $courier_user instanceof WP_User ? $courier_user->display_name : 'المندوب';
        
        $customer_msg = sprintf(
            'تم شحن طلبك رقم #%s مع المندوب %s. رقم التواصل: %s',
            (string) $order->get_order_number(),
            (string) $courier_name,
            $courier_phone !== '' ? $courier_phone : 'غير متوفر'
        );

        self::notify_customer_status_update(
            $order,
            'order_accepted_by_courier',
            'تم شحن طلبك',
            $customer_msg
        );

        return self::assignment_action_success($order, 'Assignment accepted successfully.');
    }

    /**
     * POST /courier/assignments/{id}/decline
     */
    public static function decline_assignment(WP_REST_Request $request): WP_REST_Response
    {
        $order = wc_get_order((int) $request->get_param('id'));
        if (!$order) {
            return Lexi_Security::error('order_not_found', 'Order not found.', 404);
        }

        $courier_id = (int) get_current_user_id();
        $order_id = (int) $order->get_id();

        if (!self::is_assignment_action_allowed($order)) {
            return Lexi_Security::error('invalid_order_state', 'Order cannot be handled in the current state.', 422);
        }

        $assignment_guard = self::guard_assignment_access($order, $courier_id);
        if ($assignment_guard instanceof WP_REST_Response) {
            return $assignment_guard;
        }

        $expired_guard = self::guard_assignment_ttl($order);
        if ($expired_guard instanceof WP_REST_Response) {
            return $expired_guard;
        }

        $accepted_by = (int) get_post_meta($order_id, self::META_ASSIGNMENT_ACCEPT_LOCK, true);
        if ($accepted_by > 0 && $accepted_by !== $courier_id) {
            return Lexi_Security::error('already_taken', 'Assignment is already accepted by another courier.', 409);
        }
        if ($accepted_by === $courier_id) {
            return Lexi_Security::error('already_accepted', 'Assignment already accepted by you.', 409);
        }

        $decision = strtolower(trim((string) $order->get_meta(self::META_ASSIGNMENT_DECISION)));
        $decided_by = (int) $order->get_meta(self::META_ASSIGNMENT_DECIDED_BY);
        if ($decision === 'declined' && $decided_by === $courier_id) {
            return self::assignment_action_success($order, 'Assignment was already declined by you.', true);
        }

        $assigned_agent = (int) $order->get_meta(self::META_ASSIGNED_AGENT);
        if ($assigned_agent === $courier_id) {
            $order->delete_meta_data(self::META_ASSIGNED_AGENT);
            $order->delete_meta_data(self::META_ASSIGNED_AT);
        }

        $order->update_meta_data(self::META_DELIVERY_STATE, 'declined');
        $order->update_meta_data(self::META_ASSIGNMENT_STATE, 'declined');
        $order->update_meta_data(self::META_ASSIGNMENT_DECISION, 'declined');
        $order->update_meta_data(self::META_ASSIGNMENT_DECIDED_BY, $courier_id);
        $order->update_meta_data(self::META_ASSIGNMENT_DECIDED_AT, gmdate('c'));
        $order->add_order_note('Courier declined assignment.');
        $order->save();

        if (class_exists('Lexi_Delivery_Audit')) {
            Lexi_Delivery_Audit::log(
                'assignment_declined',
                $order_id,
                $courier_id,
                null,
                'success',
                'Courier declined assignment'
            );
        }

        if (class_exists('Lexi_Order_Events')) {
            Lexi_Order_Events::log(
                $order_id,
                'rejected',
                'courier',
                $courier_id,
                array(
                    'assignment_state' => 'declined',
                ),
                $courier_id
            );
        }

        return self::assignment_action_success($order, 'Assignment declined successfully.', false, true);
    }

    /**
     * POST /courier/assignments/{id}/cancel
     */
    public static function cancel_assignment(WP_REST_Request $request): WP_REST_Response
    {
        $order = wc_get_order((int) $request->get_param('id'));
        if (!$order) {
            return Lexi_Security::error('order_not_found', 'Order not found.', 404);
        }

        $courier_id = (int) get_current_user_id();
        $order_id = (int) $order->get_id();

        if (!self::is_assignment_action_allowed($order)) {
            return Lexi_Security::error('invalid_order_state', 'Order cannot be handled in the current state.', 422);
        }

        $assignment_guard = self::guard_assignment_access($order, $courier_id);
        if ($assignment_guard instanceof WP_REST_Response) {
            // Already belonging to someone else or completely unassigned, but let's be careful.
            $assigned_agent = (int) $order->get_meta(self::META_ASSIGNED_AGENT);
            if ($assigned_agent !== $courier_id && $assigned_agent > 0) {
                 return $assignment_guard;
            }
        }

        $accepted_by = (int) $order->get_meta(self::META_ASSIGNMENT_ACCEPT_LOCK);
        if ($accepted_by > 0 && $accepted_by !== $courier_id) {
            return Lexi_Security::error('already_taken', 'Assignment is already accepted by another courier.', 409);
        }

        $order->delete_meta_data(self::META_ASSIGNED_AGENT);
        $order->delete_meta_data(self::META_ASSIGNED_AT);
        $order->delete_meta_data(self::META_ASSIGNMENT_ACCEPT_LOCK);

        $order->update_meta_data(self::META_DELIVERY_STATE, 'cancelled_by_agent');
        $order->update_meta_data(self::META_ASSIGNMENT_STATE, 'cancelled_by_agent');
        $order->update_meta_data(self::META_ASSIGNMENT_DECISION, 'cancelled');
        $order->update_meta_data(self::META_ASSIGNMENT_DECIDED_BY, $courier_id);
        $order->update_meta_data(self::META_ASSIGNMENT_DECIDED_AT, gmdate('c'));
        $order->add_order_note('Courier cancelled assignment after assignment/acceptance.');
        $order->save();

        if (class_exists('Lexi_Delivery_Audit')) {
            Lexi_Delivery_Audit::log(
                'assignment_cancelled',
                $order_id,
                $courier_id,
                null,
                'success',
                'Courier cancelled assignment'
            );
        }

        if (class_exists('Lexi_Order_Events')) {
            Lexi_Order_Events::log(
                $order_id,
                'driver_cancelled',
                'courier',
                $courier_id,
                array(
                    'assignment_state' => 'cancelled_by_agent',
                ),
                $courier_id
            );
        }

        if (class_exists('Lexi_Push')) {
            $user = get_userdata($courier_id);
            $courier_name = $user ? $user->display_name : 'مندوب';
            Lexi_Push::send_push_for_target(array(
                'target' => 'admin',
                'audience' => 'manager',
                'title_ar' => 'إلغاء إسناد طلب',
                'body_ar' => sprintf('قام المندوب %s بإلغاء إسناد الطلب #%s', $courier_name, $order->get_order_number()),
                'type' => 'delivery_cancelled',
            ));
        }

        return self::assignment_action_success($order, 'Assignment cancelled successfully.', false, true);
    }

    private static function is_assignment_action_allowed(WC_Order $order): bool
    {
        $status = self::normalize_status((string) $order->get_status());
        return in_array(
            $status,
            array('pending', 'on-hold', 'processing', 'pending-verification', 'pending-verificat'),
            true
        );
    }

    private static function guard_assignment_access(WC_Order $order, int $courier_id): ?WP_REST_Response
    {
        $assigned_agent = (int) $order->get_meta(self::META_ASSIGNED_AGENT);
        if ($assigned_agent <= 0) {
            return Lexi_Security::error('assignment_not_assigned', 'Assignment is no longer active.', 409);
        }

        if ($assigned_agent !== $courier_id) {
            return Lexi_Security::error('assignment_for_other_courier', 'Assignment belongs to another courier.', 409);
        }

        return null;
    }

    private static function guard_assignment_ttl(WC_Order $order): ?WP_REST_Response
    {
        if (!self::is_assignment_expired($order)) {
            return null;
        }

        self::mark_assignment_missed($order);
        return Lexi_Security::error(
            'assignment_expired',
            'Assignment response window expired.',
            410,
            array('state' => 'ready_for_assignment')
        );
    }

    private static function is_assignment_expired(WC_Order $order): bool
    {
        $expires_at = trim((string) $order->get_meta(self::META_ASSIGNMENT_EXPIRES_AT));
        if ($expires_at === '') {
            return false;
        }

        $timestamp = strtotime($expires_at);
        if ($timestamp === false || $timestamp <= 0) {
            return false;
        }

        return time() > $timestamp;
    }

    private static function mark_assignment_missed(WC_Order $order): void
    {
        $order_id = (int) $order->get_id();
        $expired_courier_id = (int) $order->get_meta(self::META_ASSIGNED_AGENT);
        $order->update_meta_data(self::META_ASSIGNMENT_STATE, 'expired');
        $order->update_meta_data(self::META_ASSIGNMENT_DECISION, 'expired');
        $order->update_meta_data(self::META_ASSIGNMENT_DECIDED_AT, gmdate('c'));
        $order->delete_meta_data(self::META_ASSIGNED_AGENT);
        $order->delete_meta_data(self::META_ASSIGNED_AT);
        $order->update_meta_data(self::META_DELIVERY_STATE, 'ready_for_assignment');
        $order->delete_meta_data(self::META_ASSIGNMENT_EXPIRES_AT);
        $order->delete_meta_data(self::META_ASSIGNMENT_TTL);
        delete_post_meta($order_id, self::META_ASSIGNMENT_ACCEPT_LOCK);
        $order->add_order_note('Courier assignment window expired.');
        $order->save();

        if (class_exists('Lexi_Delivery_Audit')) {
            Lexi_Delivery_Audit::log(
                'assignment_expired',
                $order_id,
                $expired_courier_id > 0 ? $expired_courier_id : null,
                null,
                'warning',
                'Assignment TTL expired'
            );
        }

        if (class_exists('Lexi_Order_Events')) {
            Lexi_Order_Events::log(
                $order_id,
                'assignment_expired',
                'system',
                null,
                array(
                    'previous_courier_id' => $expired_courier_id > 0 ? $expired_courier_id : null,
                    'reason' => 'assignment_expired',
                )
            );
        }

        if (class_exists('Lexi_Push')) {
            Lexi_Push::send_push_for_target(array(
                'target' => 'all_admins',
                'audience' => 'admin',
                'type' => 'assignment_expired',
                'title_ar' => 'انتهاء مهلة الإسناد',
                'body_ar' => sprintf('انتهت مهلة إسناد الطلب #%s وأصبح جاهزاً لإعادة الإسناد.', (string) $order->get_order_number()),
                'open_mode' => 'in_app',
            ));
        }
    }

    /**
     * Expire stale courier assignments and make orders re-assignable.
     */
    public static function expire_stale_assignments(int $limit = 200): int
    {
        $limit = min(500, max(1, $limit));
        $orders = wc_get_orders(array(
            'limit' => $limit,
            'orderby' => 'date',
            'order' => 'ASC',
            'status' => array(
                'pending',
                'on-hold',
                'processing',
                Lexi_Order_Flow::STATUS_PENDING_VERIFICATION,
                Lexi_Order_Flow::STATUS_PENDING_VERIFICATION_LEGACY,
                Lexi_Order_Flow::STATUS_OUT_FOR_DELIVERY,
            ),
            'meta_query' => array(
                array(
                    'key' => self::META_ASSIGNMENT_EXPIRES_AT,
                    'compare' => 'EXISTS',
                ),
            ),
        ));

        $expired_count = 0;
        foreach ($orders as $order) {
            if (!$order instanceof WC_Order) {
                continue;
            }
            if (!self::is_assignment_expired($order)) {
                continue;
            }

            $state = strtolower(trim((string) $order->get_meta(self::META_ASSIGNMENT_STATE)));
            $decision = strtolower(trim((string) $order->get_meta(self::META_ASSIGNMENT_DECISION)));
            $accepted_by = (int) get_post_meta((int) $order->get_id(), self::META_ASSIGNMENT_ACCEPT_LOCK, true);

            if ($accepted_by > 0 || $state === 'accepted' || $decision === 'accepted') {
                continue;
            }
            if (!in_array($state, array('', 'pending', 'assigned'), true) && $decision !== 'pending') {
                continue;
            }

            self::mark_assignment_missed($order);
            $expired_count++;
        }

        return $expired_count;
    }

    private static function assignment_action_success(
        WC_Order $order,
        string $message,
        bool $idempotent = false,
        bool $reassignable = false
    ): WP_REST_Response {
        $payload = Lexi_Routes_Orders::format_order($order, true);
        $payload['delivery_assignment'] = self::build_assignment_payload($order);
        $payload['cod'] = self::build_cod_payload($order);

        return Lexi_Security::success(array(
            'message' => $message,
            'idempotent' => $idempotent,
            'reassignable' => $reassignable,
            'order' => $payload,
        ));
    }

    private static function notify_customer_status_update(
        WC_Order $order,
        string $type,
        string $title_ar,
        string $body_ar
    ): void {
        $user_id = (int) $order->get_user_id();
        $device_id = trim((string) $order->get_meta('_lexi_device_id'));

        Lexi_Notifications::notify_customer(
            $user_id > 0 ? $user_id : null,
            $device_id !== '' ? $device_id : null,
            $type,
            $title_ar,
            $body_ar,
            (int) $order->get_id(),
            array(
                'type' => $type,
                'order_id' => (int) $order->get_id(),
                'order_number' => (string) $order->get_order_number(),
                'deep_link' => '/orders/status?order_number=' . rawurlencode((string) $order->get_order_number()),
                'open_mode' => 'in_app',
            )
        );

        if (!class_exists('Lexi_Push')) {
            return;
        }

        $target = '';
        if ($user_id > 0) {
            $target = 'specific_user';
        } elseif ($device_id !== '') {
            $target = 'specific_device';
        }
        if ($target === '') {
            return;
        }

        Lexi_Push::send_push_for_target(array(
            'target' => $target,
            'audience' => 'customer',
            'user_id' => $user_id,
            'device_id' => $device_id,
            'type' => $type,
            'title_ar' => $title_ar,
            'body_ar' => $body_ar,
            'open_mode' => 'in_app',
            'deep_link' => '/orders/status?order_number=' . rawurlencode((string) $order->get_order_number()),
            'android_channel_id' => 'customer_default',
            'priority' => 'normal',
        ));
    }
    public static function is_cod_order_public(WC_Order $order): bool
    {
        return self::is_cod_order($order);
    }

    private static function is_cod_order(WC_Order $order): bool
    {
        return Lexi_Order_Flow::is_cod_order($order);
    }

    private static function is_cod_confirmed(WC_Order $order): bool
    {
        return 'confirmed' === strtolower(trim((string) $order->get_meta(self::META_COD_STATUS)));
    }

    private static function is_cod_overridden(WC_Order $order): bool
    {
        return (string) $order->get_meta(self::META_COD_OVERRIDE_APPROVED) === '1';
    }

    private static function is_cod_settled(WC_Order $order): bool
    {
        return self::is_cod_confirmed($order) || self::is_cod_overridden($order);
    }

    private static function expected_cod_amount(WC_Order $order): string
    {
        $total = (string) $order->get_total();
        $expected = self::normalize_decimal($total);
        if ('' === $expected) {
            $expected = '0.00';
        }
        return $expected;
    }

    private static function normalize_decimal(string $raw): string
    {
        $raw = trim((string) $raw);
        if ('' === $raw) {
            return '';
        }

        // Normalize separators and strip non-numeric symbols.
        $raw = str_replace(array(' ', '\u{00A0}'), '', $raw);
        $raw = preg_replace('/[^0-9\.,\-]/', '', $raw);
        if (!is_string($raw) || '' === trim($raw)) {
            return '';
        }

        // Use WooCommerce decimal formatting (string-safe, avoids float rounding bugs).
        $decimals = function_exists('wc_get_price_decimals') ? (int) wc_get_price_decimals() : 2;
        $formatted = function_exists('wc_format_decimal')
            ? (string) wc_format_decimal($raw, $decimals)
            : (string) number_format((float) $raw, $decimals, '.', '');

        $formatted = trim($formatted);
        if ('' === $formatted || '-' === $formatted) {
            return '';
        }
        if (strpos($formatted, '-') === 0) {
            return '';
        }
        return $formatted;
    }

    private static function decimal_equals(string $expected, string $received): bool
    {
        return self::normalize_decimal($expected) === self::normalize_decimal($received);
    }

    private static function cod_tolerance(): float
    {
        $raw = get_option('lexi_cod_tolerance', self::COD_TOLERANCE_DEFAULT);
        $value = is_numeric($raw) ? (float) $raw : self::COD_TOLERANCE_DEFAULT;

        return max(0.0, min(5.0, $value));
    }

    private static function decimal_to_float(string $value): float
    {
        $normalized = self::normalize_decimal($value);
        return $normalized === '' ? 0.0 : (float) $normalized;
    }

    private static function format_decimal(float $value): string
    {
        $decimals = function_exists('wc_get_price_decimals') ? (int) wc_get_price_decimals() : 2;
        return (string) number_format($value, $decimals, '.', '');
    }

    private static function cod_rate_limit_allows(int $courier_id, int $order_id): bool
    {
        if ($courier_id <= 0 || $order_id <= 0) {
            return false;
        }

        $key = 'lexi_cod_attempts_' . $courier_id . '_' . $order_id;
        $raw = get_transient($key);
        $count = is_numeric($raw) ? (int) $raw : 0;

        // Allow up to 20 attempts / 10 minutes per order per courier.
        if ($count >= 20) {
            return false;
        }

        set_transient($key, (string) ($count + 1), 10 * MINUTE_IN_SECONDS);
        return true;
    }

    /**
     * @return array<int,array<string,mixed>>
     */
    private static function get_cod_ledger(WC_Order $order): array
    {
        $raw = $order->get_meta(self::META_COD_LEDGER, true);
        if (!is_array($raw)) {
            return array();
        }

        return array_values(
            array_filter(
                $raw,
                static function ($entry): bool {
                    return is_array($entry);
                }
            )
        );
    }

    /**
     * @param array<int,array<string,mixed>> $ledger
     */
    private static function cod_ledger_total(array $ledger): float
    {
        $sum = 0.0;
        foreach ($ledger as $entry) {
            $amount = self::decimal_to_float((string) ($entry['amount'] ?? ''));
            if ($amount > 0) {
                $sum += $amount;
            }
        }

        return round($sum, 2);
    }

    /**
     * @param array<string,mixed> $entry
     * @return array<int,array<string,mixed>>
     */
    private static function append_cod_ledger_entry(WC_Order $order, array $entry): array
    {
        $ledger = self::get_cod_ledger($order);
        $entry['amount'] = self::normalize_decimal((string) ($entry['amount'] ?? '0'));
        $entry['collected_at'] = (string) ($entry['collected_at'] ?? gmdate('c'));
        $entry['collected_by'] = isset($entry['collected_by']) ? (int) $entry['collected_by'] : null;
        $entry['method'] = sanitize_key((string) ($entry['method'] ?? 'cash'));
        $entry['kind'] = sanitize_key((string) ($entry['kind'] ?? 'collected'));
        $entry['reference'] = sanitize_text_field((string) ($entry['reference'] ?? ''));
        $entry['notes'] = sanitize_textarea_field((string) ($entry['notes'] ?? ''));

        $ledger[] = $entry;
        if (count($ledger) > 100) {
            $ledger = array_slice($ledger, -100);
        }

        $order->update_meta_data(self::META_COD_LEDGER, $ledger);
        return $ledger;
    }

    /**
     * Apply admin COD override and force-close the order.
     *
     * @return array<string,mixed>|WP_REST_Response
     */
    public static function apply_cod_override(
        WC_Order $order,
        string $final_amount,
        int $admin_id,
        string $reason
    ) {
        if (!self::is_cod_order($order)) {
            return Lexi_Security::error('not_cod', 'هذا الطلب ليس COD.', 422);
        }

        $expected = self::expected_cod_amount($order);
        $expected_float = self::decimal_to_float($expected);
        $resolved_amount = self::normalize_decimal($final_amount);
        if ($resolved_amount === '') {
            $resolved_amount = $expected;
        }

        $resolved_float = self::decimal_to_float($resolved_amount);
        if ($resolved_float <= 0.0) {
            return Lexi_Security::error('invalid_final_amount', 'قيمة التحصيل النهائية غير صالحة.', 422);
        }

        self::append_cod_ledger_entry(
            $order,
            array(
                'amount' => self::format_decimal($resolved_float),
                'method' => 'admin_override',
                'collected_by' => $admin_id,
                'collected_at' => gmdate('c'),
                'reference' => '',
                'notes' => $reason,
                'kind' => 'override',
                'expected_amount' => $expected,
                'running_collected' => self::format_decimal($resolved_float),
                'remaining_amount' => self::format_decimal(max(0.0, round($expected_float - $resolved_float, 2))),
            )
        );

        $order->update_meta_data(self::META_COD_EXPECTED, $expected);
        $order->update_meta_data(self::META_COD_COLLECTED_AMOUNT, self::format_decimal($resolved_float));
        $order->update_meta_data(self::META_COD_COLLECTED_AT, gmdate('c'));
        $order->update_meta_data(self::META_COD_COLLECTED_BY, $admin_id);
        $order->update_meta_data(self::META_COD_STATUS, 'override');
        $order->update_meta_data(self::META_COD_OVERRIDE_APPROVED, '1');
        $order->update_meta_data(self::META_COD_OVERRIDE_REASON, $reason);
        $order->update_meta_data(self::META_COD_OVERRIDE_BY, $admin_id);
        $order->update_meta_data(self::META_COD_OVERRIDE_AT, gmdate('c'));
        $order->add_order_note(
            sprintf(
                'Admin COD override approved by user #%d. Final collected amount: %s. Reason: %s',
                $admin_id,
                self::format_decimal($resolved_float),
                $reason
            )
        );
        $order->set_status('completed', 'Admin approved COD mismatch override.');
        $order->save();

        self::audit_cod_attempt($order, $admin_id, 'override', array(
            'expected' => $expected,
            'final_amount' => self::format_decimal($resolved_float),
            'reason' => $reason,
        ));

        if (class_exists('Lexi_Order_Events')) {
            Lexi_Order_Events::log(
                (int) $order->get_id(),
                'cod_override',
                'admin',
                $admin_id,
                array(
                    'expected' => $expected,
                    'final_amount' => self::format_decimal($resolved_float),
                    'reason' => $reason,
                )
            );
        }

        $payload = Lexi_Routes_Orders::format_order($order, true);
        $payload['delivery_assignment'] = self::build_assignment_payload($order);
        $payload['cod'] = self::build_cod_payload($order);

        return array(
            'message' => 'تم اعتماد التجاوز وإغلاق الطلب بنجاح.',
            'new_status' => (string) $order->get_status(),
            'locked' => true,
            'order' => $payload,
        );
    }

    private static function build_cod_payload(WC_Order $order): array
    {
        $expected = self::expected_cod_amount($order);
        $status = strtolower(trim((string) $order->get_meta(self::META_COD_STATUS)));
        $collected_amount = trim((string) $order->get_meta(self::META_COD_COLLECTED_AMOUNT));
        $ledger = self::get_cod_ledger($order);
        $collected_total = self::cod_ledger_total($ledger);
        if ($collected_amount === '' && $collected_total > 0.0) {
            $collected_amount = self::format_decimal($collected_total);
        }
        $remaining = max(0.0, round(self::decimal_to_float($expected) - $collected_total, 2));

        return array(
            'is_cod' => self::is_cod_order($order),
            'expected_amount' => $expected,
            'currency' => (string) $order->get_currency(),
            'collected_status' => '' !== $status ? $status : 'pending',
            'collected_amount' => '' !== $collected_amount ? $collected_amount : null,
            'collected_total' => $collected_total > 0 ? self::format_decimal($collected_total) : null,
            'remaining_amount' => self::format_decimal($remaining),
            'collected_at' => trim((string) $order->get_meta(self::META_COD_COLLECTED_AT)),
            'collected_by' => (int) $order->get_meta(self::META_COD_COLLECTED_BY) > 0
                ? (int) $order->get_meta(self::META_COD_COLLECTED_BY)
                : null,
            'override_approved' => self::is_cod_overridden($order),
            'override_reason' => trim((string) $order->get_meta(self::META_COD_OVERRIDE_REASON)),
            'ledger' => $ledger,
            'locked' => self::is_cod_settled($order),
        );
    }

    private static function audit_cod_attempt(WC_Order $order, int $courier_id, string $status, array $meta = array()): void
    {
        if (!class_exists('Lexi_Delivery_Audit')) {
            return;
        }
        Lexi_Delivery_Audit::log(
            'cod_collect_attempt',
            (int) $order->get_id(),
            $courier_id,
            null,
            $status,
            'COD collect attempt',
            $meta
        );
    }

    /**
     * Build delivery assignment payload for an order.
     *
     * @return array<string,mixed>
     */
    public static function build_assignment_payload(WC_Order $order): array
    {
        $agent_id = (int) $order->get_meta(self::META_ASSIGNED_AGENT);
        $assigned_at = trim((string) $order->get_meta(self::META_ASSIGNED_AT));
        $assigned_by = (int) $order->get_meta(self::META_ASSIGNED_BY);
        $delivery_state = trim((string) $order->get_meta(self::META_DELIVERY_STATE));
        $assignment_state = trim((string) $order->get_meta(self::META_ASSIGNMENT_STATE));
        $expires_at = trim((string) $order->get_meta(self::META_ASSIGNMENT_EXPIRES_AT));
        $ttl_seconds = (int) $order->get_meta(self::META_ASSIGNMENT_TTL);
        $decision = trim((string) $order->get_meta(self::META_ASSIGNMENT_DECISION));
        $decided_by = (int) $order->get_meta(self::META_ASSIGNMENT_DECIDED_BY);
        $decided_at = trim((string) $order->get_meta(self::META_ASSIGNMENT_DECIDED_AT));
        $accepted_by = (int) get_post_meta((int) $order->get_id(), self::META_ASSIGNMENT_ACCEPT_LOCK, true);

        return array(
            'agent_id' => $agent_id > 0 ? $agent_id : null,
            'agent' => $agent_id > 0 ? self::map_courier((int) $agent_id) : null,
            'assigned_at' => $assigned_at,
            'assigned_by' => $assigned_by > 0 ? self::map_user_brief($assigned_by) : null,
            'delivery_state' => $delivery_state,
            'assignment_state' => $assignment_state,
            'assignment_expires_at' => $expires_at,
            'assignment_ttl_seconds' => $ttl_seconds > 0 ? $ttl_seconds : null,
            'assignment_decision' => $decision,
            'assignment_decided_by' => $decided_by > 0 ? $decided_by : null,
            'assignment_decided_at' => $decided_at !== '' ? $decided_at : null,
            'assignment_accept_lock' => $accepted_by > 0 ? $accepted_by : null,
            'assignment_is_expired' => self::is_assignment_expired($order),
        );
    }

    /**
     * @return array<string,mixed>|null
     */
    public static function map_courier(int $user_id): ?array
    {
        $user = get_user_by('id', $user_id);
        if (!$user) {
            return null;
        }

        $roles = is_array($user->roles) ? $user->roles : array();
        if (!in_array('delivery_agent', $roles, true)) {
            return null;
        }

        return array(
            'id' => (int) $user->ID,
            'display_name' => (string) $user->display_name,
            'email' => (string) $user->user_email,
            'phone' => (string) get_user_meta((int) $user->ID, 'billing_phone', true),
            'is_available' => self::is_available((int) $user->ID),
        );
    }

    /**
     * @return array<string,mixed>|null
     */
    private static function map_user_brief(int $user_id): ?array
    {
        $user = get_user_by('id', $user_id);
        if (!$user) {
            return null;
        }

        return array(
            'id' => (int) $user->ID,
            'display_name' => (string) $user->display_name,
            'email' => (string) $user->user_email,
        );
    }

    /**
     * Check whether order is assigned to current courier.
     */
    private static function is_order_assigned_to(int $order_id, int $courier_id): bool
    {
        $order = wc_get_order($order_id);
        if (!$order) {
            return false;
        }

        return (int) $order->get_meta(self::META_ASSIGNED_AGENT) === $courier_id;
    }

    /**
     * Courier availability helper.
     */
    public static function is_available(int $user_id): bool
    {
        $raw = get_user_meta($user_id, self::META_AVAILABLE, true);
        if ('' === (string) $raw) {
            return true;
        }

        return self::coerce_bool($raw);
    }

    private static function guard_recent_courier_location(int $courier_id): ?WP_REST_Response
    {
        if ($courier_id <= 0 || !class_exists('Lexi_Courier_Locations')) {
            return null;
        }

        $stale_after_minutes = Lexi_Courier_Locations::stale_after_minutes();
        if (Lexi_Courier_Locations::has_recent_ping($courier_id, $stale_after_minutes)) {
            return null;
        }

        $last = Lexi_Courier_Locations::get($courier_id);
        if (!is_array($last)) {
            return Lexi_Security::error(
                'courier_location_required',
                'يجب تفعيل الموقع وإرسال موقعك الحالي قبل عرض الطلبات.',
                428,
                array(
                    'required_within_minutes' => $stale_after_minutes,
                    'open_settings' => true,
                )
            );
        }

        return Lexi_Security::error(
            'courier_location_stale',
            'آخر تحديث لموقعك قديم. يرجى تحديث الموقع ثم إعادة المحاولة.',
            428,
            array(
                'required_within_minutes' => $stale_after_minutes,
                'last_updated_at' => (string) ($last['updated_at'] ?? ''),
                'open_settings' => true,
            )
        );
    }

    private static function format_coordinate(float $value): string
    {
        return rtrim(rtrim(sprintf('%.6F', $value), '0'), '.');
    }

    /**
     * Normalize status text.
     */
    private static function normalize_status(string $status): string
    {
        return str_replace('_', '-', strtolower(trim($status)));
    }

    /**
     * Normalize bool-like values.
     */
    private static function coerce_bool($value): bool
    {
        if (is_bool($value)) {
            return $value;
        }
        if (is_numeric($value)) {
            return ((int) $value) !== 0;
        }
        $normalized = strtolower(trim((string) $value));
        return in_array($normalized, array('1', 'true', 'yes', 'on'), true);
    }
}
