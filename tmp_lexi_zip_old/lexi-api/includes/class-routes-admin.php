<?php
/**
 * Admin REST routes: dashboard, orders, shipping cities, ShamCash verification.
 *
 * @package Lexi_API
 */

defined('ABSPATH') || exit;

class Lexi_Routes_Admin
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
    private const ASSIGNMENT_TTL_DEFAULT_SECONDS = 90;
    private const ASSIGNMENT_TTL_MIN_SECONDS = 30;
    private const ASSIGNMENT_TTL_MAX_SECONDS = 600;

    /**
     * Register admin routes.
     */
    public static function register(): void
    {
        $ns = LEXI_API_NAMESPACE;

        register_rest_route($ns, '/admin/dashboard', array(
            'methods' => WP_REST_Server::READABLE,
            'callback' => array(__CLASS__, 'get_dashboard'),
            'permission_callback' => array('Lexi_Security', 'admin_access'),
        ));

        register_rest_route($ns, '/admin/orders', array(
            'methods' => WP_REST_Server::READABLE,
            'callback' => array(__CLASS__, 'get_orders'),
            'permission_callback' => array('Lexi_Security', 'admin_access'),
            'args' => array(
                'status' => array('default' => '', 'sanitize_callback' => 'sanitize_text_field'),
                'payment_method' => array('default' => '', 'sanitize_callback' => 'sanitize_text_field'),
                'page' => array('default' => 1, 'sanitize_callback' => 'absint'),
                'per_page' => array('default' => 20, 'sanitize_callback' => 'absint'),
            ),
        ));

        register_rest_route($ns, '/admin/orders/(?P<id>\d+)', array(
            array(
                'methods' => WP_REST_Server::READABLE,
                'callback' => array(__CLASS__, 'get_order'),
                'permission_callback' => array('Lexi_Security', 'admin_access'),
                'args' => array(
                    'id' => array('required' => true, 'sanitize_callback' => 'absint'),
                ),
            ),
            array(
                'methods' => WP_REST_Server::EDITABLE,
                'callback' => array(__CLASS__, 'update_order'),
                'permission_callback' => array('Lexi_Security', 'admin_access'),
                'args' => array(
                    'id' => array('required' => true, 'sanitize_callback' => 'absint'),
                ),
            ),
        ));

        register_rest_route($ns, '/admin/orders/(?P<id>\d+)/events', array(
            'methods' => WP_REST_Server::READABLE,
            'callback' => array(__CLASS__, 'get_order_events'),
            'permission_callback' => array('Lexi_Security', 'admin_access'),
            'args' => array(
                'id' => array('required' => true, 'sanitize_callback' => 'absint'),
                'limit' => array('default' => 80, 'sanitize_callback' => 'absint'),
            ),
        ));

        register_rest_route($ns, '/admin/orders/(?P<id>\d+)/cod/override', array(
            'methods' => WP_REST_Server::CREATABLE,
            'callback' => array(__CLASS__, 'cod_override'),
            'permission_callback' => array('Lexi_Security', 'admin_access'),
            'args' => array(
                'id' => array('required' => true, 'sanitize_callback' => 'absint'),
            ),
        ));

        register_rest_route($ns, '/admin/orders/(?P<id>\d+)/notify', array(
            'methods' => WP_REST_Server::CREATABLE,
            'callback' => array(__CLASS__, 'notify_order_customer'),
            'permission_callback' => array('Lexi_Security', 'admin_access'),
            'args' => array(
                'id' => array('required' => true, 'sanitize_callback' => 'absint'),
            ),
        ));

        register_rest_route($ns, '/admin/orders/(?P<id>\d+)/assign-courier', array(
            array(
                'methods' => WP_REST_Server::READABLE,
                'callback' => array(__CLASS__, 'get_order_courier_assignment'),
                'permission_callback' => array('Lexi_Security', 'admin_access'),
                'args' => array(
                    'id' => array('required' => true, 'sanitize_callback' => 'absint'),
                ),
            ),
            array(
                'methods' => WP_REST_Server::EDITABLE,
                'callback' => array(__CLASS__, 'assign_order_courier'),
                'permission_callback' => array('Lexi_Security', 'admin_access'),
                'args' => array(
                    'id' => array('required' => true, 'sanitize_callback' => 'absint'),
                ),
            ),
        ));

        register_rest_route($ns, '/admin/couriers', array(
            'methods' => WP_REST_Server::READABLE,
            'callback' => array(__CLASS__, 'get_couriers'),
            'permission_callback' => array('Lexi_Security', 'admin_access'),
        ));

        register_rest_route($ns, '/admin/couriers/(?P<id>\d+)/location', array(
            'methods' => WP_REST_Server::READABLE,
            'callback' => array(__CLASS__, 'get_courier_location'),
            'permission_callback' => array('Lexi_Security', 'admin_access'),
            'args' => array(
                'id' => array('required' => true, 'sanitize_callback' => 'absint'),
            ),
        ));

        register_rest_route($ns, '/admin/couriers/report', array(
            'methods' => WP_REST_Server::READABLE,
            'callback' => array(__CLASS__, 'get_couriers_report'),
            'permission_callback' => array('Lexi_Security', 'admin_access'),
            'args' => array(
                'date' => array('default' => '', 'sanitize_callback' => 'sanitize_text_field'),
                'from' => array('default' => '', 'sanitize_callback' => 'sanitize_text_field'),
                'to' => array('default' => '', 'sanitize_callback' => 'sanitize_text_field'),
                'courier_id' => array('default' => 0, 'sanitize_callback' => 'absint'),
                'available_only' => array('default' => 0, 'sanitize_callback' => 'absint'),
                'search' => array('default' => '', 'sanitize_callback' => 'sanitize_text_field'),
                'include_details' => array('default' => 1, 'sanitize_callback' => 'absint'),
                'details_limit' => array('default' => 50, 'sanitize_callback' => 'absint'),
            ),
        ));

        register_rest_route($ns, '/admin/shipping/cities', array(
            array(
                'methods' => WP_REST_Server::READABLE,
                'callback' => array(__CLASS__, 'list_cities'),
                'permission_callback' => array('Lexi_Security', 'admin_access'),
            ),
            array(
                'methods' => WP_REST_Server::CREATABLE,
                'callback' => array(__CLASS__, 'create_city'),
                'permission_callback' => array('Lexi_Security', 'admin_access'),
            ),
        ));

        register_rest_route($ns, '/admin/shipping/cities/(?P<id>\d+)', array(
            array(
                'methods' => WP_REST_Server::EDITABLE,
                'callback' => array(__CLASS__, 'update_city'),
                'permission_callback' => array('Lexi_Security', 'admin_access'),
                'args' => array(
                    'id' => array('required' => true, 'sanitize_callback' => 'absint'),
                ),
            ),
            array(
                'methods' => WP_REST_Server::DELETABLE,
                'callback' => array(__CLASS__, 'delete_city'),
                'permission_callback' => array('Lexi_Security', 'admin_access'),
                'args' => array(
                    'id' => array('required' => true, 'sanitize_callback' => 'absint'),
                ),
            ),
        ));

        register_rest_route($ns, '/admin/me', array(
            'methods' => WP_REST_Server::READABLE,
            'callback' => array(__CLASS__, 'get_current_user'),
            'permission_callback' => array('Lexi_Security', 'admin_access'),
        ));

        register_rest_route($ns, '/admin/delivery-audit', array(
            'methods' => WP_REST_Server::READABLE,
            'callback' => array(__CLASS__, 'get_delivery_audit'),
            'permission_callback' => array('Lexi_Security', 'admin_access'),
            'args' => array(
                'order_id' => array('default' => 0, 'sanitize_callback' => 'absint'),
                'courier_id' => array('default' => 0, 'sanitize_callback' => 'absint'),
                'event_type' => array('default' => '', 'sanitize_callback' => 'sanitize_text_field'),
                'page' => array('default' => 1, 'sanitize_callback' => 'absint'),
                'per_page' => array('default' => 50, 'sanitize_callback' => 'absint'),
            ),
        ));

        register_rest_route($ns, '/admin/notification-settings', array(
            array(
                'methods' => WP_REST_Server::READABLE,
                'callback' => array(__CLASS__, 'get_notification_settings'),
                'permission_callback' => array('Lexi_Security', 'admin_access'),
            ),
            array(
                'methods' => WP_REST_Server::EDITABLE,
                'callback' => array(__CLASS__, 'update_notification_settings'),
                'permission_callback' => array('Lexi_Security', 'admin_access'),
            ),
        ));

        register_rest_route($ns, '/admin/email-diagnostics', array(
            array(
                'methods' => WP_REST_Server::READABLE,
                'callback' => array(__CLASS__, 'get_email_diagnostics'),
                'permission_callback' => array('Lexi_Security', 'admin_access'),
            ),
            array(
                'methods' => WP_REST_Server::CREATABLE,
                'callback' => array(__CLASS__, 'send_test_email'),
                'permission_callback' => array('Lexi_Security', 'admin_access'),
            ),
        ));

        register_rest_route($ns, '/admin/shamcash/pending', array(
            'methods' => WP_REST_Server::READABLE,
            'callback' => array(__CLASS__, 'get_pending_shamcash_orders'),
            'permission_callback' => array('Lexi_Security', 'admin_access'),
            'args' => array(
                'page' => array('default' => 1, 'sanitize_callback' => 'absint'),
                'per_page' => array('default' => 20, 'sanitize_callback' => 'absint'),
            ),
        ));

        register_rest_route($ns, '/admin/shamcash/orders/(?P<id>\d+)', array(
            'methods' => WP_REST_Server::EDITABLE,
            'callback' => array(__CLASS__, 'patch_shamcash_order'),
            'permission_callback' => array('Lexi_Security', 'admin_access'),
            'args' => array(
                'id' => array('required' => true, 'sanitize_callback' => 'absint'),
            ),
        ));

        register_rest_route($ns, '/admin/debug/order/(?P<id>\d+)', array(
            'methods' => WP_REST_Server::READABLE,
            'callback' => array(__CLASS__, 'debug_order'),
            'permission_callback' => array('Lexi_Security', 'admin_access'),
            'args' => array(
                'id' => array('required' => true, 'sanitize_callback' => 'absint'),
            ),
        ));
    }

    /**
     * GET /admin/delivery-audit
     */
    public static function get_delivery_audit(WP_REST_Request $request): WP_REST_Response
    {
        if (!class_exists('Lexi_Delivery_Audit')) {
            return Lexi_Security::error('not_available', 'سجل التتبع غير متاح.', 500);
        }

        $page = max(1, (int) $request->get_param('page'));
        $per_page = min(200, max(1, (int) $request->get_param('per_page')));

        $filters = array();
        $order_id = (int) $request->get_param('order_id');
        $courier_id = (int) $request->get_param('courier_id');
        $event_type = trim((string) $request->get_param('event_type'));

        if ($order_id > 0) {
            $filters['order_id'] = $order_id;
        }
        if ($courier_id > 0) {
            $filters['courier_id'] = $courier_id;
        }
        if ('' !== $event_type) {
            $filters['event_type'] = $event_type;
        }

        $items = Lexi_Delivery_Audit::list($filters, $page, $per_page);

        return Lexi_Security::success(array(
            'items' => $items,
            'page' => $page,
            'per_page' => $per_page,
        ));
    }

    /**
     * GET /admin/me
     */
    public static function get_current_user(WP_REST_Request $request): WP_REST_Response
    {
        $user = wp_get_current_user();

        return Lexi_Security::success(array(
            'id' => (int) $user->ID,
            'user_login' => (string) $user->user_login,
            'email' => (string) $user->user_email,
            'display_name' => (string) $user->display_name,
            'roles' => array_values((array) $user->roles),
            'is_admin' => current_user_can('administrator') || current_user_can('manage_woocommerce'),
        ));
    }

    /**
     * GET /admin/notification-settings
     */
    public static function get_notification_settings(WP_REST_Request $request): WP_REST_Response
    {
        return Lexi_Security::success(Lexi_Emails::get_notification_settings());
    }

    /**
     * PATCH /admin/notification-settings
     */
    public static function update_notification_settings(WP_REST_Request $request): WP_REST_Response
    {
        $body = (array) $request->get_json_params();
        $management = $body['management_emails'] ?? array();
        $accounting = $body['accounting_emails'] ?? array();

        $settings = Lexi_Emails::save_notification_settings($management, $accounting);

        return Lexi_Security::success(array(
            'message' => 'تم حفظ إعدادات الإشعارات.',
            'management_emails' => $settings['management_emails'],
            'accounting_emails' => $settings['accounting_emails'],
        ));
    }

    /**
     * GET /admin/email-diagnostics
     */
    public static function get_email_diagnostics(WP_REST_Request $request): WP_REST_Response
    {
        return Lexi_Security::success(Lexi_Emails::get_diagnostics());
    }

    /**
     * POST /admin/email-diagnostics
     * Send a test email to configured recipients.
     */
    public static function send_test_email(WP_REST_Request $request): WP_REST_Response
    {
        $body = (array) $request->get_json_params();
        $result = Lexi_Emails::send_test_email(array(
            'actor_user_id' => get_current_user_id(),
            'source' => 'admin_email_diagnostics',
            'note' => isset($body['note']) ? sanitize_text_field((string) $body['note']) : '',
        ));

        if (!($result['sent'] ?? false)) {
            return Lexi_Security::error(
                'email_send_failed',
                trim((string) ($result['error_message'] ?? '')) !== ''
                    ? trim((string) ($result['error_message'] ?? ''))
                    : 'فشل إرسال بريد الاختبار. تحقق من إعدادات SMTP وسجل التشخيص.',
                (string) ($result['error_code'] ?? '') === 'no_recipients' ? 422 : 502,
                $result
            );
        }

        return Lexi_Security::success(array(
            'message' => 'تم إرسال بريد الاختبار بنجاح.',
            'recipients' => $result['recipients'] ?? array(),
            'subject' => (string) ($result['subject'] ?? ''),
        ));
    }

    /**
     * GET /admin/dashboard
     */
    public static function get_dashboard(WP_REST_Request $request): WP_REST_Response
    {
        $today_start = gmdate('Y-m-d 00:00:00');
        $today_end = gmdate('Y-m-d 23:59:59');

        $today_orders = wc_get_orders(array(
            'limit' => -1,
            'date_created' => $today_start . '...' . $today_end,
            'return' => 'ids',
        ));

        $today_sales = 0.0;
        foreach ($today_orders as $order_id) {
            $order = wc_get_order($order_id);
            if ($order) {
                $today_sales += (float) $order->get_total();
            }
        }

        $pending_verification = wc_get_orders(array(
            'limit' => -1,
            'status' => array('pending-verification', 'pending-verificat', 'on-hold'),
            'return' => 'ids',
        ));

        $processing = wc_get_orders(array(
            'limit' => -1,
            'status' => 'processing',
            'return' => 'ids',
        ));

        $all_orders = wc_get_orders(array(
            'limit' => -1,
            'return' => 'ids',
        ));

        return Lexi_Security::success(array(
            'today_sales' => round($today_sales, 2),
            'today_orders_count' => (int) count($today_orders),
            'total_orders_count' => (int) count($all_orders),
            'pending_verification_count' => (int) count($pending_verification),
            'processing_count' => (int) count($processing),
        ));
    }

    /**
     * GET /admin/orders
     */
    public static function get_orders(WP_REST_Request $request): WP_REST_Response
    {
        $status = self::normalize_status((string) $request->get_param('status'));
        $payment_method = self::normalize_payment_method_filter(
            (string) $request->get_param('payment_method')
        );
        $page = max(1, (int) $request->get_param('page'));
        $per_page = min(100, max(1, (int) $request->get_param('per_page')));

        $args = array(
            'limit' => $per_page,
            'offset' => ($page - 1) * $per_page,
            'orderby' => 'date',
            'order' => 'DESC',
        );
        if ('' !== $status && 'all' !== $status) {
            if (in_array($status, array('pending-verification', 'pending-verificat', 'on-hold'), true)) {
                $args['status'] = array('pending-verification', 'pending-verificat', 'on-hold');
            } else {
                $args['status'] = $status;
            }
        }
        self::apply_payment_method_filter($args, $payment_method);

        $orders = wc_get_orders($args);
        $total_args = $args;
        $total_args['limit'] = -1;
        $total_args['offset'] = 0;
        $total_args['return'] = 'ids';
        $total = count(wc_get_orders($total_args));

        $items = array();
        foreach ($orders as $order) {
            if ($order instanceof WC_Order) {
                $payload = Lexi_Routes_Orders::format_order($order, true);
                $payload['delivery_assignment'] = self::order_assignment_payload($order);
                $items[] = $payload;
            }
        }

        return Lexi_Security::success(array(
            'items' => $items,
            'page' => $page,
            'per_page' => $per_page,
            'total' => (int) $total,
            'total_pages' => max(1, (int) ceil($total / $per_page)),
        ));
    }

    /**
     * GET /admin/orders/{id}
     */
    public static function get_order(WP_REST_Request $request): WP_REST_Response
    {
        $order = wc_get_order((int) $request->get_param('id'));
        if (!$order) {
            return Lexi_Security::error('order_not_found', 'الطلب غير موجود.', 404);
        }

        $payload = Lexi_Routes_Orders::format_order($order, true);
        $payload['delivery_assignment'] = self::order_assignment_payload($order);
        return Lexi_Security::success($payload);
    }

    /**
     * GET /admin/orders/{id}/events
     */
    public static function get_order_events(WP_REST_Request $request): WP_REST_Response
    {
        $order_id = (int) $request->get_param('id');
        $limit = min(300, max(1, (int) $request->get_param('limit')));

        $order = wc_get_order($order_id);
        if (!$order) {
            return Lexi_Security::error('order_not_found', 'الطلب غير موجود.', 404);
        }

        if (!class_exists('Lexi_Order_Events')) {
            return Lexi_Security::success(array('items' => array()));
        }

        return Lexi_Security::success(array(
            'order_id' => $order_id,
            'items' => Lexi_Order_Events::list_by_order($order_id, $limit),
        ));
    }

    /**
     * PATCH /admin/orders/{id}
     *
     * Supports:
     * - status update
     * - legacy actions: approve_shamcash / reject_shamcash
     */
    public static function update_order(WP_REST_Request $request): WP_REST_Response
    {
        $order = wc_get_order((int) $request->get_param('id'));
        if (!$order) {
            return Lexi_Security::error('order_not_found', 'الطلب غير موجود.', 404);
        }

        $body = (array) $request->get_json_params();
        $action = strtolower(trim((string) ($body['action'] ?? '')));
        $note_ar = sanitize_textarea_field((string) ($body['note_ar'] ?? ''));

        if (in_array($action, array('approve_shamcash', 'approve'), true)) {
            return self::handle_approve_shamcash($order, $note_ar);
        }
        if (in_array($action, array('reject_shamcash', 'reject'), true)) {
            return self::handle_reject_shamcash($order, $note_ar);
        }
        if (in_array($action, array('cod_override', 'override_cod'), true)) {
            return self::cod_override($request);
        }

        $new_status = self::normalize_status((string) ($body['status'] ?? ''));
        $note = sanitize_textarea_field((string) ($body['note'] ?? ''));

        if ('' === $new_status) {
            return Lexi_Security::error('missing_status', 'حالة الطلب الجديدة مطلوبة.', 422);
        }

        $new_status_for_write = $new_status;
        if (Lexi_Order_Flow::STATUS_PENDING_VERIFICATION === $new_status_for_write) {
            $new_status_for_write = Lexi_Order_Flow::pending_verification_storage_status();
        }

        $valid_statuses = wc_get_order_statuses();
        if (!isset($valid_statuses['wc-' . $new_status_for_write]) && !isset($valid_statuses['wc-' . $new_status])) {
            return Lexi_Security::error('invalid_status', 'حالة الطلب غير صالحة.', 422);
        }

        $old_status = $order->get_status();
        $order->set_status($new_status_for_write, 'تحديث من لوحة التحكم.');
        if ('' !== $note) {
            $order->add_order_note($note, 0, true);
        }
        $order->save();

        if (class_exists('Lexi_Order_Events')) {
            Lexi_Order_Events::log(
                (int) $order->get_id(),
                'admin_status_updated',
                'admin',
                (int) get_current_user_id(),
                array(
                    'old_status' => $old_status,
                    'new_status' => self::normalize_status((string) $order->get_status()),
                    'note' => $note,
                )
            );
        }

        return Lexi_Security::success(array(
            'order_id' => (int) $order->get_id(),
            'old_status' => $old_status,
            'new_status' => self::normalize_status((string) $order->get_status()),
            'message' => 'تم تحديث حالة الطلب بنجاح.',
        ));
    }

    /**
     * PATCH /admin/shamcash/orders/{id}
     *
     * Body:
     * - action: approve|reject
     * - note_ar: required
     */
    public static function patch_shamcash_order(WP_REST_Request $request): WP_REST_Response
    {
        $order = wc_get_order((int) $request->get_param('id'));
        if (!$order) {
            return Lexi_Security::error('order_not_found', 'الطلب غير موجود.', 404);
        }

        $body = (array) $request->get_json_params();
        $action = strtolower(trim((string) ($body['action'] ?? '')));
        $note_ar = sanitize_textarea_field((string) ($body['note_ar'] ?? ''));

        if (!in_array($action, array('approve', 'reject'), true)) {
            return Lexi_Security::error('invalid_action', 'الإجراء غير صالح.', 422);
        }
        if (strlen(trim($note_ar)) < 2) {
            return Lexi_Security::error('note_required', 'يرجى كتابة ملاحظة واضحة.', 422);
        }

        if ('approve' === $action) {
            return self::handle_approve_shamcash($order, $note_ar);
        }
        return self::handle_reject_shamcash($order, $note_ar);
    }

    private static function handle_approve_shamcash(WC_Order $order, string $note_ar): WP_REST_Response
    {
        if (!self::is_shamcash_order($order)) {
            return Lexi_Security::error('invalid_payment_method', 'هذا الطلب ليس شام كاش.', 422);
        }

        $proof_url = trim((string) $order->get_meta('_lexi_shamcash_proof_url'));
        if ('' === $proof_url) {
            $proof_url = trim((string) $order->get_meta('_lexi_payment_proof_url'));
        }
        if ('' === $proof_url) {
            return Lexi_Security::error('no_proof', 'لا يمكن قبول الطلب بدون إيصال دفع.', 422);
        }

        $order->set_status('processing', 'تم قبول إيصال شام كاش.');
        $order->add_order_note('تم قبول الطلب. ملاحظة الإدارة: ' . $note_ar, 0, true);
        $order->update_meta_data('_lexi_decision', 'approved');
        $order->update_meta_data('_lexi_admin_note_ar', $note_ar);
        $order->update_meta_data('_lexi_decision_at', current_time('mysql'));
        $order->update_meta_data('_lexi_shamcash_verified_at', current_time('mysql'));
        $order->update_meta_data('_lexi_shamcash_verified_by', (int) get_current_user_id());
        $order->save();

        if (class_exists('Lexi_Order_Events')) {
            Lexi_Order_Events::log(
                (int) $order->get_id(),
                'shamcash_decision_approved',
                'admin',
                (int) get_current_user_id(),
                array(
                    'note_ar' => $note_ar,
                    'proof_url' => $proof_url,
                )
            );
        }

        Lexi_Notifications::append_timeline($order, 'approved', 'تم قبول طلبك.');
        Lexi_Notifications::notify_customer_decision($order, 'approved', $note_ar);
        self::notify_customer_assignment_update(
            $order,
            'order_approved',
            'Order approved',
            sprintf('Order #%s was approved and is being prepared.', (string) $order->get_order_number())
        );

        return Lexi_Security::success(array(
            'id' => (int) $order->get_id(),
            'status' => 'processing',
            'status_label_ar' => 'قيد المعالجة',
            'message' => 'تم قبول طلبك',
        ));
    }

    private static function handle_reject_shamcash(WC_Order $order, string $note_ar): WP_REST_Response
    {
        if (!self::is_shamcash_order($order)) {
            return Lexi_Security::error('invalid_payment_method', 'هذا الطلب ليس شام كاش.', 422);
        }

        if (strlen(trim($note_ar)) < 2) {
            return Lexi_Security::error('note_required', 'يرجى كتابة سبب الرفض.', 422);
        }

        $order->set_status('failed', 'تم رفض إيصال شام كاش.');
        $order->add_order_note('تم رفض الطلب. ملاحظة الإدارة: ' . $note_ar, 0, true);
        $order->update_meta_data('_lexi_decision', 'rejected');
        $order->update_meta_data('_lexi_admin_note_ar', $note_ar);
        $order->update_meta_data('_lexi_decision_at', current_time('mysql'));
        $order->save();

        if (class_exists('Lexi_Order_Events')) {
            Lexi_Order_Events::log(
                (int) $order->get_id(),
                'shamcash_decision_rejected',
                'admin',
                (int) get_current_user_id(),
                array(
                    'note_ar' => $note_ar,
                )
            );
        }

        Lexi_Notifications::append_timeline($order, 'rejected', 'تم رفض طلبك.');
        Lexi_Notifications::notify_customer_decision($order, 'rejected', $note_ar);

        return Lexi_Security::success(array(
            'id' => (int) $order->get_id(),
            'status' => 'failed',
            'status_label_ar' => 'فاشل',
            'message' => 'تم رفض طلبك',
        ));
    }

    private static function is_shamcash_order(WC_Order $order): bool
    {
        return Lexi_Order_Flow::is_shamcash_order($order);
    }

    /**
     * POST /admin/orders/{id}/cod/override
     */
    public static function cod_override(WP_REST_Request $request): WP_REST_Response
    {
        $order = wc_get_order((int) $request->get_param('id'));
        if (!$order) {
            return Lexi_Security::error('order_not_found', 'الطلب غير موجود.', 404);
        }

        $body = (array) $request->get_json_params();
        $reason = sanitize_textarea_field((string) ($body['reason'] ?? $body['note'] ?? ''));
        if (strlen(trim($reason)) < 3) {
            return Lexi_Security::error('reason_required', 'يجب إدخال سبب واضح لاعتماد التجاوز.', 422);
        }

        $final_amount = isset($body['final_amount'])
            ? (string) $body['final_amount']
            : '';

        if (!class_exists('Lexi_Routes_Delivery') || !method_exists('Lexi_Routes_Delivery', 'apply_cod_override')) {
            return Lexi_Security::error('override_unavailable', 'خدمة اعتماد تحصيل COD غير متاحة حالياً.', 500);
        }

        $result = Lexi_Routes_Delivery::apply_cod_override(
            $order,
            $final_amount,
            (int) get_current_user_id(),
            $reason
        );
        if ($result instanceof WP_REST_Response) {
            return $result;
        }

        return Lexi_Security::success($result);
    }

    /**
     * POST /admin/orders/{id}/notify
     */
    public static function notify_order_customer(WP_REST_Request $request): WP_REST_Response
    {
        $order = wc_get_order((int) $request->get_param('id'));
        if (!$order) {
            return Lexi_Security::error('order_not_found', 'الطلب غير موجود.', 404);
        }

        $body = (array) $request->get_json_params();
        $subject = sanitize_text_field((string) ($body['subject'] ?? ''));
        $message = trim(wp_strip_all_tags((string) ($body['message'] ?? '')));
        $as_customer_note = self::coerce_bool($body['as_customer_note'] ?? false);

        if ('' === $message) {
            return Lexi_Security::error('missing_message', 'محتوى الرسالة مطلوب.', 422);
        }

        $customer_email = sanitize_email((string) $order->get_billing_email());
        if ('' === $customer_email) {
            return Lexi_Security::error('missing_customer_email', 'لا يوجد بريد إلكتروني للعميل.', 422);
        }

        if ('' === $subject) {
            $subject = sprintf('تحديث بخصوص طلبك #%s', $order->get_order_number());
        }

        $full_name = trim($order->get_billing_first_name() . ' ' . $order->get_billing_last_name());
        $status_name = wc_get_order_status_name($order->get_status());
        $email_body = sprintf(
            '<div dir="rtl" style="font-family:Tahoma,Arial,sans-serif;line-height:1.8;">
                <p>مرحباً %s،</p>
                <p>%s</p>
                <p><strong>رقم الطلب:</strong> #%s</p>
                <p><strong>الحالة الحالية:</strong> %s</p>
            </div>',
            esc_html($full_name ?: 'عميلنا العزيز'),
            nl2br(esc_html($message)),
            esc_html($order->get_order_number()),
            esc_html($status_name)
        );

        $headers = array('Content-Type: text/html; charset=UTF-8');
        if (class_exists('Lexi_Text')) {
            $subject = Lexi_Text::normalize($subject);
            $email_body = Lexi_Text::normalize($email_body);
        }
        $sent = wp_mail($customer_email, $subject, $email_body, $headers);
        if (!$sent) {
            return Lexi_Security::error('mail_send_failed', 'تعذر إرسال الرسالة حالياً.', 500);
        }

        $order->add_order_note('تم إرسال رسالة للعميل: ' . $subject, 0, true);
        if (1 === $as_customer_note) {
            $order->add_order_note($message, 1, true);
        }
        $order->save();

        return Lexi_Security::success(array(
            'order_id' => (int) $order->get_id(),
            'message' => 'تم إرسال الرسالة بنجاح.',
        ));
    }

    /**
     * GET /admin/couriers
     */
    public static function get_couriers(WP_REST_Request $request): WP_REST_Response
    {
        $available_only = self::coerce_bool($request->get_param('available_only'));
        $search = strtolower(trim((string) $request->get_param('search')));

        $items = self::collect_couriers($available_only === 1, $search);

        return Lexi_Security::success(array(
            'items' => $items,
            'total' => count($items),
            'available_only' => (bool) $available_only,
        ));
    }

    /**
     * GET /admin/couriers/{id}/location
     */
    public static function get_courier_location(WP_REST_Request $request): WP_REST_Response
    {
        if (!class_exists('Lexi_Courier_Locations')) {
            return Lexi_Security::error('location_service_unavailable', 'خدمة موقع المندوب غير متاحة حالياً.', 500);
        }

        $courier_id = (int) $request->get_param('id');
        $courier = get_user_by('id', $courier_id);
        if (!($courier instanceof WP_User) || !self::user_is_delivery_agent($courier)) {
            return Lexi_Security::error('courier_not_found', 'المندوب غير موجود.', 404);
        }

        $location = Lexi_Courier_Locations::get($courier_id);
        if (!is_array($location)) {
            return Lexi_Security::error('location_not_found', 'لا يوجد موقع مسجل لهذا المندوب بعد.', 404);
        }

        $lat = (float) ($location['lat'] ?? 0.0);
        $lng = (float) ($location['lng'] ?? 0.0);
        $updated_at_utc = trim((string) ($location['updated_at'] ?? ''));
        $updated_ts = $updated_at_utc !== '' ? strtotime($updated_at_utc . ' UTC') : false;
        $age_minutes = $updated_ts !== false
            ? max(0, (int) floor((time() - $updated_ts) / 60))
            : null;
        $stale_after_minutes = Lexi_Courier_Locations::stale_after_minutes();
        $is_outdated = null !== $age_minutes ? $age_minutes > $stale_after_minutes : true;

        $destination = self::format_coordinate($lat) . ',' . self::format_coordinate($lng);
        $maps_navigate_url = 'https://www.google.com/maps/dir/?api=1&destination=' .
            rawurlencode($destination) .
            '&travelmode=driving';
        $maps_open_url = 'https://www.google.com/maps/search/?api=1&query=' . rawurlencode($destination);

        return Lexi_Security::success(array(
            'courier_id' => $courier_id,
            'lat' => $lat,
            'lng' => $lng,
            'accuracy_m' => isset($location['accuracy_m']) ? (float) $location['accuracy_m'] : null,
            'heading' => isset($location['heading']) ? (float) $location['heading'] : null,
            'speed_mps' => isset($location['speed_mps']) ? (float) $location['speed_mps'] : null,
            'updated_at' => $updated_at_utc,
            'updated_at_local' => $updated_at_utc !== '' ? self::to_site_datetime_string($updated_at_utc) : '',
            'age_minutes' => $age_minutes,
            'is_outdated' => $is_outdated,
            'stale_after_minutes' => $stale_after_minutes,
            'maps_navigate_url' => $maps_navigate_url,
            'maps_open_url' => $maps_open_url,
        ));
    }

    /**
     * GET /admin/couriers/report
     */
    public static function get_couriers_report(WP_REST_Request $request): WP_REST_Response
    {
        $available_only = self::coerce_bool($request->get_param('available_only')) === 1;
        $search = strtolower(trim((string) $request->get_param('search')));
        $courier_id = (int) $request->get_param('courier_id');
        $include_details = self::coerce_bool($request->get_param('include_details')) === 1;
        $details_limit = min(200, max(1, (int) $request->get_param('details_limit')));

        $window = self::build_courier_report_window(
            (string) $request->get_param('date'),
            (string) $request->get_param('from'),
            (string) $request->get_param('to')
        );
        $couriers = self::collect_couriers($available_only, $search);
        if ($courier_id > 0) {
            $couriers = array_values(array_filter(
                $couriers,
                static function (array $item) use ($courier_id): bool {
                    return (int) ($item['id'] ?? 0) === $courier_id;
                }
            ));
        }

        $event_rows = self::list_courier_event_rows(
            (string) $window['start_utc_sql'],
            (string) $window['end_utc_sql'],
            $courier_id
        );

        $stats_by_courier = array();
        $assigned_timestamp_by_order = array();
        $order_number_cache = array();

        foreach ($event_rows as $row) {
            $current_courier_id = self::resolve_courier_id_from_event_row($row);
            if ($current_courier_id <= 0) {
                continue;
            }

            if (!isset($stats_by_courier[$current_courier_id])) {
                $stats_by_courier[$current_courier_id] = array(
                    'assigned_count' => 0,
                    'accepted_count' => 0,
                    'rejected_count' => 0,
                    'delivered_count' => 0,
                    'failed_count' => 0,
                    'cod_collected_sum' => 0.0,
                    'deliveries_with_duration_count' => 0,
                    'duration_total_minutes' => 0.0,
                    'details' => array(),
                );
            }

            $event_type = self::normalize_courier_report_event_type((string) ($row['event_type'] ?? ''));
            $order_id = (int) ($row['order_id'] ?? 0);
            $created_at_utc = trim((string) ($row['created_at'] ?? ''));
            $pair_key = ($current_courier_id > 0 && $order_id > 0)
                ? ((string) $current_courier_id . ':' . (string) $order_id)
                : '';

            if ($event_type === 'assigned') {
                $stats_by_courier[$current_courier_id]['assigned_count']++;
                if ($pair_key !== '' && $created_at_utc !== '') {
                    if (
                        !isset($assigned_timestamp_by_order[$pair_key]) ||
                        strcmp((string) $created_at_utc, (string) $assigned_timestamp_by_order[$pair_key]) < 0
                    ) {
                        $assigned_timestamp_by_order[$pair_key] = $created_at_utc;
                    }
                }
                continue;
            }

            if ($event_type === 'accepted') {
                $stats_by_courier[$current_courier_id]['accepted_count']++;
                continue;
            }

            if ($event_type === 'rejected') {
                $stats_by_courier[$current_courier_id]['rejected_count']++;
                continue;
            }

            if ($event_type === 'failed') {
                $stats_by_courier[$current_courier_id]['failed_count']++;
                continue;
            }

            if ($event_type === 'cod_collected') {
                $amount = isset($row['amount']) && is_numeric($row['amount'])
                    ? (float) $row['amount']
                    : 0.0;
                if ($amount > 0) {
                    $stats_by_courier[$current_courier_id]['cod_collected_sum'] += $amount;
                }
                continue;
            }

            if ($event_type !== 'delivered') {
                continue;
            }

            $stats_by_courier[$current_courier_id]['delivered_count']++;
            $assigned_at_utc = $pair_key !== '' && isset($assigned_timestamp_by_order[$pair_key])
                ? (string) $assigned_timestamp_by_order[$pair_key]
                : '';
            $duration_minutes = null;
            if ($assigned_at_utc !== '' && $created_at_utc !== '') {
                $assigned_ts = strtotime($assigned_at_utc . ' UTC');
                $delivered_ts = strtotime($created_at_utc . ' UTC');
                if ($assigned_ts !== false && $delivered_ts !== false && $delivered_ts >= $assigned_ts) {
                    $duration_minutes = ($delivered_ts - $assigned_ts) / 60;
                    $stats_by_courier[$current_courier_id]['deliveries_with_duration_count']++;
                    $stats_by_courier[$current_courier_id]['duration_total_minutes'] += $duration_minutes;
                }
            }

            if (
                $include_details &&
                count($stats_by_courier[$current_courier_id]['details']) < $details_limit
            ) {
                if (!isset($order_number_cache[$order_id])) {
                    $order = $order_id > 0 ? wc_get_order($order_id) : null;
                    $order_number_cache[$order_id] = $order instanceof WC_Order
                        ? (string) $order->get_order_number()
                        : (string) $order_id;
                }

                $stats_by_courier[$current_courier_id]['details'][] = array(
                    'order_id' => $order_id,
                    'order_number' => (string) ($order_number_cache[$order_id] ?? ''),
                    'started_at' => $assigned_at_utc !== '' ? self::to_site_datetime_string($assigned_at_utc) : '',
                    'started_at_utc' => $assigned_at_utc,
                    'delivered_at' => $created_at_utc !== '' ? self::to_site_datetime_string($created_at_utc) : '',
                    'delivered_at_utc' => $created_at_utc,
                    'duration_minutes' => null !== $duration_minutes
                        ? round($duration_minutes, 2)
                        : null,
                );
            }
        }

        $indexed_couriers = array();
        foreach ($couriers as $item) {
            $indexed_couriers[(int) ($item['id'] ?? 0)] = $item;
        }

        foreach ($stats_by_courier as $stats_courier_id => $_unused) {
            if (isset($indexed_couriers[$stats_courier_id])) {
                continue;
            }

            $user = get_user_by('id', $stats_courier_id);
            $indexed_couriers[$stats_courier_id] = array(
                'id' => $stats_courier_id,
                'display_name' => $user instanceof WP_User ? (string) $user->display_name : sprintf('Courier #%d', $stats_courier_id),
                'email' => $user instanceof WP_User ? (string) $user->user_email : '',
                'phone' => (string) get_user_meta($stats_courier_id, 'billing_phone', true),
                'is_available' => self::coerce_bool(get_user_meta($stats_courier_id, self::META_AVAILABLE, true)) === 1,
                'active_orders_count' => self::count_active_orders_for_courier($stats_courier_id),
            );
        }

        $items = array();
        $summary_active_assigned = 0;
        $summary_assigned = 0;
        $summary_accepted = 0;
        $summary_rejected = 0;
        $summary_delivered = 0;
        $summary_failed = 0;
        $summary_cod_collected = 0.0;
        $summary_duration_count = 0;
        $summary_duration_total = 0.0;

        foreach ($indexed_couriers as $item) {
            $item_courier_id = (int) ($item['id'] ?? 0);
            $stats = $stats_by_courier[$item_courier_id] ?? array(
                'assigned_count' => 0,
                'accepted_count' => 0,
                'rejected_count' => 0,
                'delivered_count' => 0,
                'failed_count' => 0,
                'cod_collected_sum' => 0.0,
                'deliveries_with_duration_count' => 0,
                'duration_total_minutes' => 0.0,
                'details' => array(),
            );

            $active_orders_count = (int) ($item['active_orders_count'] ?? 0);
            $assigned_count = (int) ($stats['assigned_count'] ?? 0);
            $accepted_count = (int) ($stats['accepted_count'] ?? 0);
            $rejected_count = (int) ($stats['rejected_count'] ?? 0);
            $delivered_count = (int) ($stats['delivered_count'] ?? 0);
            $failed_count = (int) ($stats['failed_count'] ?? 0);
            $cod_collected_sum = (float) ($stats['cod_collected_sum'] ?? 0.0);
            $deliveries_with_duration_count = (int) ($stats['deliveries_with_duration_count'] ?? 0);
            $duration_total_minutes = (float) ($stats['duration_total_minutes'] ?? 0.0);
            $avg_duration = $deliveries_with_duration_count > 0
                ? round($duration_total_minutes / $deliveries_with_duration_count, 2)
                : 0.0;

            $item['assigned_orders_count'] = $assigned_count;
            $item['assigned_count'] = $assigned_count;
            $item['accepted_count'] = $accepted_count;
            $item['rejected_count'] = $rejected_count;
            $item['delivered_count'] = $delivered_count;
            $item['failed_count'] = $failed_count;
            $item['cod_collected_sum'] = round($cod_collected_sum, 2);
            $item['avg_delivery_minutes'] = $avg_duration;
            $item['delivered_today_count'] = $delivered_count;
            $item['delivered_today_avg_minutes'] = $avg_duration;
            $item['delivered_today_total_minutes'] = round($duration_total_minutes, 2);
            $item['deliveries_today'] = $include_details
                ? array_values((array) ($stats['details'] ?? array()))
                : array();
            $items[] = $item;

            $summary_active_assigned += $active_orders_count;
            $summary_assigned += $assigned_count;
            $summary_accepted += $accepted_count;
            $summary_rejected += $rejected_count;
            $summary_delivered += $delivered_count;
            $summary_failed += $failed_count;
            $summary_cod_collected += $cod_collected_sum;
            $summary_duration_count += $deliveries_with_duration_count;
            $summary_duration_total += $duration_total_minutes;
        }

        usort(
            $items,
            static function (array $a, array $b): int {
                $delivered_diff = (int) ($b['delivered_count'] ?? 0) - (int) ($a['delivered_count'] ?? 0);
                if ($delivered_diff !== 0) {
                    return $delivered_diff;
                }
                $assigned_diff = (int) ($b['assigned_count'] ?? 0) - (int) ($a['assigned_count'] ?? 0);
                if ($assigned_diff !== 0) {
                    return $assigned_diff;
                }
                return strcmp((string) ($a['display_name'] ?? ''), (string) ($b['display_name'] ?? ''));
            }
        );

        return Lexi_Security::success(array(
            'date' => (string) $window['date_local'],
            'window' => array(
                'start_local' => (string) $window['start_local_sql'],
                'end_local' => (string) $window['end_local_sql'],
                'start_utc' => (string) $window['start_utc_sql'],
                'end_utc' => (string) $window['end_utc_sql'],
            ),
            'summary' => array(
                'couriers_count' => count($items),
                'active_assigned_orders_total' => $summary_active_assigned,
                'assigned_total' => $summary_assigned,
                'accepted_total' => $summary_accepted,
                'rejected_total' => $summary_rejected,
                'delivered_total' => $summary_delivered,
                'failed_total' => $summary_failed,
                'cod_collected_total' => round($summary_cod_collected, 2),
                'delivered_today_total' => $summary_delivered,
                'average_delivery_minutes' => $summary_duration_count > 0
                    ? round($summary_duration_total / $summary_duration_count, 2)
                    : 0.0,
            ),
            'items' => array_values($items),
        ));
    }

    /**
     * GET /admin/orders/{id}/assign-courier
     */
    public static function get_order_courier_assignment(WP_REST_Request $request): WP_REST_Response
    {
        $order = wc_get_order((int) $request->get_param('id'));
        if (!$order) {
            return Lexi_Security::error('order_not_found', 'الطلب غير موجود.', 404);
        }

        return Lexi_Security::success(array(
            'order_id' => (int) $order->get_id(),
            'order_number' => (string) $order->get_order_number(),
            'assignment' => self::order_assignment_payload($order),
            'available_couriers' => self::collect_couriers(true),
        ));
    }

    /**
     * PATCH /admin/orders/{id}/assign-courier
     */
    public static function assign_order_courier(WP_REST_Request $request): WP_REST_Response
    {
        $order = wc_get_order((int) $request->get_param('id'));
        if (!$order) {
            return Lexi_Security::error('order_not_found', 'الطلب غير موجود.', 404);
        }

        $body = (array) $request->get_json_params();
        $courier_id = absint((int) ($body['courier_id'] ?? $body['agent_id'] ?? 0));
        $unassign = self::coerce_bool($body['unassign'] ?? false) === 1 || $courier_id <= 0;
        $ttl_input = absint((int) ($body['ttl_seconds'] ?? self::ASSIGNMENT_TTL_DEFAULT_SECONDS));
        $ttl_seconds = $ttl_input > 0 ? $ttl_input : self::ASSIGNMENT_TTL_DEFAULT_SECONDS;
        $ttl_seconds = min(self::ASSIGNMENT_TTL_MAX_SECONDS, max(self::ASSIGNMENT_TTL_MIN_SECONDS, $ttl_seconds));
        $previous_courier_id = (int) $order->get_meta(self::META_ASSIGNED_AGENT);

        if ($unassign) {
            $had_assignment = (int) $order->get_meta(self::META_ASSIGNED_AGENT) > 0;
            $order_id = (int) $order->get_id();

            if (class_exists('Lexi_Delivery_Audit')) {
                Lexi_Delivery_Audit::log(
                    'assignment_removed',
                    $order_id,
                    $had_assignment ? (int) $order->get_meta(self::META_ASSIGNED_AGENT) : null,
                    (int) get_current_user_id(),
                    $had_assignment ? 'success' : 'info',
                    $had_assignment ? 'Unassigned courier' : 'No prior assignment'
                );
            }

            $order->delete_meta_data(self::META_ASSIGNED_AGENT);
            $order->delete_meta_data(self::META_ASSIGNED_AT);
            $order->delete_meta_data(self::META_ASSIGNED_BY);
            $order->delete_meta_data(self::META_DELIVERY_STATE);
            $order->delete_meta_data(self::META_ASSIGNMENT_STATE);
            $order->delete_meta_data(self::META_ASSIGNMENT_EXPIRES_AT);
            $order->delete_meta_data(self::META_ASSIGNMENT_TTL);
            $order->delete_meta_data(self::META_ASSIGNMENT_DECIDED_BY);
            $order->delete_meta_data(self::META_ASSIGNMENT_DECIDED_AT);
            $order->delete_meta_data(self::META_ASSIGNMENT_DECISION);
            delete_post_meta($order_id, self::META_ASSIGNMENT_ACCEPT_LOCK);
            $order->add_order_note('تم إلغاء إسناد الطلب من أي مندوب توصيل.');
            $order->save();

            if (class_exists('Lexi_Order_Events')) {
                Lexi_Order_Events::log(
                    $order_id,
                    'driver_unassigned',
                    'admin',
                    (int) get_current_user_id(),
                    array(
                        'previous_courier_id' => $previous_courier_id > 0 ? $previous_courier_id : null,
                    )
                );
            }

            $payload = Lexi_Routes_Orders::format_order($order, true);
            $payload['delivery_assignment'] = self::order_assignment_payload($order);

            return Lexi_Security::success(array(
                'message' => $had_assignment
                    ? 'تم إلغاء الإسناد بنجاح.'
                    : 'الطلب غير مسند مسبقاً.',
                'order' => $payload,
            ));
        }

        $courier_user = get_user_by('id', $courier_id);
        if (!($courier_user instanceof WP_User) || !self::user_is_delivery_agent($courier_user)) {
            return Lexi_Security::error('courier_not_found', 'المندوب غير موجود أو غير صالح.', 404);
        }

        $is_available = class_exists('Lexi_Routes_Delivery')
            ? Lexi_Routes_Delivery::is_available((int) $courier_user->ID)
            : self::coerce_bool(get_user_meta((int) $courier_user->ID, self::META_AVAILABLE, true)) === 1;
        if (!$is_available) {
            return Lexi_Security::error('courier_unavailable', 'المندوب غير متوفر حالياً.', 422);
        }

        $order->update_meta_data(self::META_ASSIGNED_AGENT, (int) $courier_user->ID);
        $order->update_meta_data(self::META_ASSIGNED_AT, gmdate('c'));
        $order->update_meta_data(self::META_ASSIGNED_BY, (int) get_current_user_id());
        $order->update_meta_data(self::META_DELIVERY_STATE, 'assigned');
        $order->update_meta_data(self::META_ASSIGNMENT_STATE, 'pending');
        $order->update_meta_data(self::META_ASSIGNMENT_TTL, $ttl_seconds);
        $order->update_meta_data(self::META_ASSIGNMENT_EXPIRES_AT, gmdate('c', time() + $ttl_seconds));
        $order->update_meta_data(self::META_ASSIGNMENT_DECISION, 'pending');
        $order->delete_meta_data(self::META_ASSIGNMENT_DECIDED_BY);
        $order->delete_meta_data(self::META_ASSIGNMENT_DECIDED_AT);
        delete_post_meta((int) $order->get_id(), self::META_ASSIGNMENT_ACCEPT_LOCK);

        $order->add_order_note(
            sprintf(
                'تم إسناد الطلب إلى مندوب التوصيل: %s (TTL: %d sec).',
                (string) $courier_user->display_name,
                $ttl_seconds
            )
        );
        $order->save();

        if (class_exists('Lexi_Delivery_Audit')) {
            Lexi_Delivery_Audit::log(
                'assignment_set',
                (int) $order->get_id(),
                (int) $courier_user->ID,
                (int) get_current_user_id(),
                'success',
                'Assigned courier'
            );
        }

        if (class_exists('Lexi_Order_Events')) {
            Lexi_Order_Events::log(
                (int) $order->get_id(),
                'assigned',
                'admin',
                (int) get_current_user_id(),
                array(
                    'assignment_action' => $previous_courier_id > 0 && $previous_courier_id !== (int) $courier_user->ID
                        ? 'reassigned'
                        : 'assigned',
                    'courier_id' => (int) $courier_user->ID,
                    'previous_courier_id' => $previous_courier_id > 0 ? $previous_courier_id : null,
                    'ttl_seconds' => $ttl_seconds,
                ),
                (int) $courier_user->ID
            );
        }

        self::send_courier_assignment_push($order, (int) $courier_user->ID, $ttl_seconds);
        
        $courier_phone = (string) get_user_meta((int) $courier_user->ID, 'billing_phone', true);
        $customer_msg = sprintf(
            'تم شحن طلبك رقم #%s مع المندوب %s. رقم التواصل: %s',
            (string) $order->get_order_number(),
            (string) $courier_user->display_name,
            $courier_phone !== '' ? $courier_phone : 'غير متوفر'
        );
        self::notify_customer_assignment_update(
            $order,
            'order_assigned',
            'تم شحن طلبك',
            $customer_msg
        );

        $payload = Lexi_Routes_Orders::format_order($order, true);
        $payload['delivery_assignment'] = self::order_assignment_payload($order);

        return Lexi_Security::success(array(
            'message' => 'تم إسناد الطلب بنجاح.',
            'assignment_ttl_seconds' => $ttl_seconds,
            'order' => $payload,
        ));
    }

    private static function send_courier_assignment_push(WC_Order $order, int $courier_id, int $ttl_seconds): void
    {
        if (!class_exists('Lexi_Push') || $courier_id <= 0) {
            return;
        }

        $payload = self::build_courier_assignment_payload($order, $ttl_seconds);
        $order_number = (string) $order->get_order_number();

        Lexi_Push::send_push_for_target(array(
            'target' => 'specific_user',
            'audience' => 'courier',
            'user_id' => $courier_id,
            'type' => 'courier_assignment',
            'title_ar' => sprintf('New delivery assignment #%s', $order_number),
            'body_ar' => sprintf(
                'Order #%s is waiting for your decision. Amount due: %s.',
                $order_number,
                (string) ($payload['amount_due'] ?? '--')
            ),
            'open_mode' => 'in_app',
            'deep_link' => (string) ($payload['deep_link'] ?? ''),
            'priority' => 'high',
            'data_only' => true,
            'ttl_seconds' => $ttl_seconds,
            'android_channel_id' => 'courier_assignment',
            'android_sound' => 'courier_assignment_ringtone',
            'android_category' => 'call',
            'android_visibility' => 'public',
            'android_full_screen_intent' => true,
            'extra_data' => $payload,
        ));
    }

    /**
     * Notify customer and send customer_default push for state changes.
     */
    private static function notify_customer_assignment_update(
        WC_Order $order,
        string $type,
        string $title,
        string $message
    ): void {
        $user_id = (int) $order->get_user_id();
        $device_id = trim((string) $order->get_meta('_lexi_device_id'));

        Lexi_Notifications::notify_customer(
            $user_id > 0 ? $user_id : null,
            $device_id !== '' ? $device_id : null,
            $type,
            $title,
            $message,
            (int) $order->get_id(),
            array(
                'type' => $type,
                'order_id' => (int) $order->get_id(),
                'order_number' => (string) $order->get_order_number(),
                'open_mode' => 'in_app',
                'deep_link' => '/orders/status?order_number=' . rawurlencode((string) $order->get_order_number()),
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
            'title_ar' => $title,
            'body_ar' => $message,
            'open_mode' => 'in_app',
            'deep_link' => '/orders/status?order_number=' . rawurlencode((string) $order->get_order_number()),
            'android_channel_id' => 'customer_default',
            'priority' => 'normal',
            'extra_data' => array(
                'type' => $type,
                'order_id' => (int) $order->get_id(),
                'order_number' => (string) $order->get_order_number(),
            ),
        ));
    }

    /**
     * @return array<string,string>
     */
    private static function build_courier_assignment_payload(WC_Order $order, int $ttl_seconds): array
    {
        $customer_name = trim($order->get_billing_first_name() . ' ' . $order->get_billing_last_name());
        if ($customer_name === '') {
            $customer_name = method_exists($order, 'get_formatted_billing_full_name')
                ? trim((string) $order->get_formatted_billing_full_name())
                : '';
        }
        if ($customer_name === '') {
            $customer_name = trim((string) $order->get_billing_company());
        }

        $address = self::order_address_for_assignment($order);
        $phone = trim((string) $order->get_billing_phone());
        $amount_due = trim((string) $order->get_total());
        if ($amount_due === '') {
            $amount_due = '0';
        }
        $currency = trim((string) $order->get_currency());
        if ($currency !== '') {
            $amount_due .= ' ' . $currency;
        }

        $deep_link = '/delivery/assignment-decision?order_id=' . rawurlencode((string) $order->get_id());

        return array(
            'type' => 'courier_assignment',
            'order_id' => (string) ((int) $order->get_id()),
            'amount_due' => $amount_due,
            'customer_name' => $customer_name,
            'address' => $address,
            'customer_phone' => $phone,
            'ttl_seconds' => (string) $ttl_seconds,
            'deep_link' => $deep_link,
        );
    }

    private static function order_address_for_assignment(WC_Order $order): string
    {
        $address = trim((string) $order->get_formatted_shipping_address());
        if ($address === '') {
            $address = trim((string) $order->get_formatted_billing_address());
        }
        $address = preg_replace('/\s+/', ' ', $address);
        return is_string($address) ? trim($address) : '';
    }

    /**
     * GET /admin/shipping/cities
     */
    public static function list_cities(WP_REST_Request $request): WP_REST_Response
    {
        $cities = Lexi_Shipping_Cities::get_all();

        $data = array_map(function ($city) {
            return array(
                'id' => (int) $city['id'],
                'name' => (string) $city['name'],
                'price' => (float) $city['price'],
                'is_active' => (bool) $city['is_active'],
                'sort_order' => (int) $city['sort_order'],
                'created_at' => (string) $city['created_at'],
                'updated_at' => (string) $city['updated_at'],
            );
        }, $cities);

        return Lexi_Security::success($data);
    }

    /**
     * POST /admin/shipping/cities
     */
    public static function create_city(WP_REST_Request $request): WP_REST_Response
    {
        $body = (array) $request->get_json_params();
        if (empty($body['name']) || !isset($body['price'])) {
            return Lexi_Security::error('missing_fields', 'اسم المدينة والسعر مطلوبان.', 422);
        }

        $payload = array(
            'name' => sanitize_text_field((string) $body['name']),
            'price' => (float) $body['price'],
            'is_active' => isset($body['is_active']) ? self::coerce_bool($body['is_active']) : 1,
            'sort_order' => isset($body['sort_order']) ? absint($body['sort_order']) : 0,
        );

        $id = Lexi_Shipping_Cities::create($payload);
        if (!$id) {
            return Lexi_Security::error('create_failed', 'تعذر إنشاء المدينة.', 500);
        }

        $city = Lexi_Shipping_Cities::get_by_id((int) $id);
        return Lexi_Security::success(array(
            'id' => (int) $city['id'],
            'name' => (string) $city['name'],
            'price' => (float) $city['price'],
            'is_active' => (bool) $city['is_active'],
            'sort_order' => (int) $city['sort_order'],
        ), 201);
    }

    /**
     * PATCH /admin/shipping/cities/{id}
     */
    public static function update_city(WP_REST_Request $request): WP_REST_Response
    {
        $id = (int) $request->get_param('id');
        $existing = Lexi_Shipping_Cities::get_by_id($id);
        if (!$existing) {
            return Lexi_Security::error('city_not_found', 'المدينة غير موجودة.', 404);
        }

        $body = (array) $request->get_json_params();
        $payload = array();

        if (isset($body['name'])) {
            $payload['name'] = sanitize_text_field((string) $body['name']);
        }
        if (isset($body['price'])) {
            $payload['price'] = (float) $body['price'];
        }
        if (isset($body['is_active'])) {
            $payload['is_active'] = self::coerce_bool($body['is_active']);
        }
        if (isset($body['sort_order'])) {
            $payload['sort_order'] = absint($body['sort_order']);
        }

        if (empty($payload)) {
            return Lexi_Security::error('missing_fields', 'لا يوجد حقول للتحديث.', 422);
        }
        if (!Lexi_Shipping_Cities::update($id, $payload)) {
            return Lexi_Security::error('update_failed', 'تعذر تحديث المدينة.', 500);
        }

        $city = Lexi_Shipping_Cities::get_by_id($id);
        return Lexi_Security::success(array(
            'id' => (int) $city['id'],
            'name' => (string) $city['name'],
            'price' => (float) $city['price'],
            'is_active' => (bool) $city['is_active'],
            'sort_order' => (int) $city['sort_order'],
        ));
    }

    /**
     * DELETE /admin/shipping/cities/{id}
     */
    public static function delete_city(WP_REST_Request $request): WP_REST_Response
    {
        $id = (int) $request->get_param('id');
        $existing = Lexi_Shipping_Cities::get_by_id($id);
        if (!$existing) {
            return Lexi_Security::error('city_not_found', 'المدينة غير موجودة.', 404);
        }
        if (!Lexi_Shipping_Cities::delete($id)) {
            return Lexi_Security::error('delete_failed', 'تعذر حذف المدينة.', 500);
        }

        return Lexi_Security::success(array('message' => 'تم حذف المدينة بنجاح.'));
    }

    /**
     * GET /admin/shamcash/pending
     */
    public static function get_pending_shamcash_orders(WP_REST_Request $request): WP_REST_Response
    {
        $page = max(1, (int) $request->get_param('page'));
        $per_page = min(100, max(1, (int) $request->get_param('per_page')));

        $args = array(
            'status' => array('pending-verification', 'pending-verificat', 'on-hold', 'pending', 'processing'),
            'limit' => -1,
            'orderby' => 'date',
            'order' => 'DESC',
            'return' => 'objects',
        );
        self::apply_payment_method_filter($args, Lexi_Order_Flow::PAYMENT_METHOD_SHAMCASH);
        $orders = wc_get_orders($args);

        $filtered = array();
        foreach ($orders as $order) {
            if (!($order instanceof WC_Order)) {
                continue;
            }
            if (!self::is_shamcash_order($order)) {
                continue;
            }
            $proof_url = trim((string) $order->get_meta('_lexi_shamcash_proof_url'));
            if ('' === $proof_url) {
                $proof_url = trim((string) $order->get_meta('_lexi_payment_proof_url'));
            }
            $has_proof = '' !== $proof_url;

            $proof_uploaded_at = trim((string) $order->get_meta('_lexi_shamcash_proof_uploaded_at'));
            if ('' === $proof_uploaded_at) {
                $proof_uploaded_at = trim((string) $order->get_meta('_lexi_payment_proof_date'));
            }
            $proof_note = trim((string) $order->get_meta('_lexi_shamcash_proof_note'));
            if ('' === $proof_note) {
                $proof_note = trim((string) $order->get_meta('_lexi_payment_proof_note'));
            }

            $filtered[] = array(
                'id' => (int) $order->get_id(),
                'order_number' => (string) $order->get_order_number(),
                'status' => self::normalize_status((string) $order->get_status()),
                'status_label_ar' => 'بانتظار التحقق',
                'total' => (float) $order->get_total(),
                'currency' => (string) $order->get_currency(),
                'customer_name' => trim($order->get_billing_first_name() . ' ' . $order->get_billing_last_name()),
                'customer_phone' => (string) $order->get_billing_phone(),
                'date_created' => $order->get_date_created()
                    ? (string) $order->get_date_created()->format('Y-m-d H:i:s')
                    : '',
                'proof' => array(
                    'has_proof' => $has_proof,
                    'image_url' => $has_proof ? $proof_url : null,
                    'thumbnail_url' => $has_proof ? $proof_url : null,
                    'uploaded_at' => $has_proof ? $proof_uploaded_at : null,
                    'note' => $has_proof ? $proof_note : null,
                ),
            );
        }

        $total = count($filtered);
        $offset = ($page - 1) * $per_page;
        $paged = array_slice($filtered, $offset, $per_page);

        return Lexi_Security::success(array(
            'orders' => array_values($paged),
            'total' => (int) $total,
            'page' => $page,
            'per_page' => $per_page,
            'total_pages' => max(1, (int) ceil($total / $per_page)),
        ));
    }

    /**
     * GET /admin/debug/order/{id}
     */
    public static function debug_order(WP_REST_Request $request): WP_REST_Response
    {
        $order_id = absint($request->get_param('id'));
        if ($order_id <= 0) {
            return Lexi_Security::error('invalid_order_id', 'رقم الطلب غير صالح.', 422);
        }

        $post = get_post($order_id);
        $order = wc_get_order($order_id);
        if (!($order instanceof WC_Order)) {
            return Lexi_Security::success(array(
                'exists' => false,
                'order_id' => $order_id,
                'post_type' => $post ? (string) $post->post_type : null,
                'post_status' => $post ? (string) $post->post_status : null,
                'created_at' => $post ? (string) $post->post_date : null,
            ));
        }

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
        $decision = trim((string) $order->get_meta('_lexi_decision'));
        $transaction_id = trim((string) $order->get_transaction_id());
        if ('' === $transaction_id) {
            $transaction_id = trim((string) $order->get_meta('_transaction_id'));
        }

        return Lexi_Security::success(array(
            'exists' => true,
            'order_id' => (int) $order->get_id(),
            'order_number' => (string) $order->get_order_number(),
            'post_type' => $post ? (string) $post->post_type : 'shop_order',
            'post_status' => $post ? (string) $post->post_status : null,
            'status' => self::normalize_status((string) $order->get_status()),
            'payment_method' => Lexi_Order_Flow::resolve_order_payment_method($order),
            'payment_method_raw' => (string) $order->get_payment_method(),
            'payment_method_meta' => (string) $order->get_meta('_lexi_payment_method'),
            'decision_meta' => '' !== $decision ? $decision : null,
            'proof_meta' => array(
                'url' => '' !== $proof_url ? $proof_url : null,
                'uploaded_at' => '' !== $proof_uploaded_at ? $proof_uploaded_at : null,
                'note' => '' !== $proof_note ? $proof_note : null,
                'attachment_id' => (int) $order->get_meta('_lexi_shamcash_proof_attachment_id') ?: null,
            ),
            'transaction_id' => '' !== $transaction_id ? $transaction_id : null,
            'created_at' => $order->get_date_created()
                ? (string) $order->get_date_created()->date('c')
                : ($post ? (string) $post->post_date : null),
        ));
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

    /**
     * @param array<string,mixed> $args
     */
    private static function apply_payment_method_filter(array &$args, string $payment_method): void
    {
        if ('' === $payment_method) {
            return;
        }

        $query_values = Lexi_Order_Flow::PAYMENT_METHOD_SHAMCASH === $payment_method
            ? Lexi_Order_Flow::shamcash_payment_ids()
            : array($payment_method);

        $args['meta_query'] = array(
            'relation' => 'OR',
            array(
                'key' => '_payment_method',
                'value' => $query_values,
                'compare' => 'IN',
            ),
            array(
                'key' => '_lexi_payment_method',
                'value' => $query_values,
                'compare' => 'IN',
            ),
        );
    }

    private static function normalize_status(string $status): string
    {
        $status = trim(strtolower($status));
        if ('' === $status) {
            return '';
        }
        $status = str_replace('_', '-', $status);
        if ('on-hold' === $status || 'pending-verificat' === $status) {
            return 'pending-verification';
        }
        return $status;
    }

    /**
     * @return array<string,mixed>
     */
    private static function order_assignment_payload(WC_Order $order): array
    {
        if (class_exists('Lexi_Routes_Delivery')) {
            return Lexi_Routes_Delivery::build_assignment_payload($order);
        }

        $agent_id = (int) $order->get_meta(self::META_ASSIGNED_AGENT);
        $assigned_at = trim((string) $order->get_meta(self::META_ASSIGNED_AT));
        $assigned_by = (int) $order->get_meta(self::META_ASSIGNED_BY);
        $delivery_state = trim((string) $order->get_meta(self::META_DELIVERY_STATE));
        $assignment_state = trim((string) $order->get_meta(self::META_ASSIGNMENT_STATE));
        $assignment_expires_at = trim((string) $order->get_meta(self::META_ASSIGNMENT_EXPIRES_AT));
        $assignment_ttl_seconds = (int) $order->get_meta(self::META_ASSIGNMENT_TTL);
        $assignment_decision = trim((string) $order->get_meta(self::META_ASSIGNMENT_DECISION));
        $assignment_decided_by = (int) $order->get_meta(self::META_ASSIGNMENT_DECIDED_BY);
        $assignment_decided_at = trim((string) $order->get_meta(self::META_ASSIGNMENT_DECIDED_AT));
        $assignment_accept_lock = (int) get_post_meta((int) $order->get_id(), self::META_ASSIGNMENT_ACCEPT_LOCK, true);

        return array(
            'agent_id' => $agent_id > 0 ? $agent_id : null,
            'agent' => null,
            'assigned_at' => $assigned_at,
            'assigned_by' => $assigned_by > 0 ? $assigned_by : null,
            'delivery_state' => $delivery_state,
            'assignment_state' => $assignment_state,
            'assignment_expires_at' => $assignment_expires_at,
            'assignment_ttl_seconds' => $assignment_ttl_seconds > 0 ? $assignment_ttl_seconds : null,
            'assignment_decision' => $assignment_decision,
            'assignment_decided_by' => $assignment_decided_by > 0 ? $assignment_decided_by : null,
            'assignment_decided_at' => $assignment_decided_at !== '' ? $assignment_decided_at : null,
            'assignment_accept_lock' => $assignment_accept_lock > 0 ? $assignment_accept_lock : null,
        );
    }

    /**
     * @return array<int,array<string,mixed>>
     */
    private static function collect_couriers(bool $available_only = false, string $search = ''): array
    {
        $users = get_users(array(
            'role' => 'delivery_agent',
            'orderby' => 'display_name',
            'order' => 'ASC',
            'number' => 500,
        ));

        $items = array();
        foreach ($users as $user) {
            if (!($user instanceof WP_User) || !self::user_is_delivery_agent($user)) {
                continue;
            }

            $courier = class_exists('Lexi_Routes_Delivery')
                ? Lexi_Routes_Delivery::map_courier((int) $user->ID)
                : null;
            if (!is_array($courier)) {
                $courier = array(
                    'id' => (int) $user->ID,
                    'display_name' => (string) $user->display_name,
                    'email' => (string) $user->user_email,
                    'phone' => (string) get_user_meta((int) $user->ID, 'billing_phone', true),
                    'is_available' => self::coerce_bool(get_user_meta((int) $user->ID, self::META_AVAILABLE, true)) === 1,
                );
            }

            $is_available = self::coerce_bool($courier['is_available'] ?? true) === 1;
            if ($available_only && !$is_available) {
                continue;
            }

            if ('' !== $search) {
                $haystack = strtolower(
                    trim(
                        (string) ($courier['display_name'] ?? '') . ' ' .
                        (string) ($courier['email'] ?? '') . ' ' .
                        (string) ($courier['phone'] ?? '')
                    )
                );
                if (false === strpos($haystack, $search)) {
                    continue;
                }
            }

            $courier['active_orders_count'] = self::count_active_orders_for_courier((int) $courier['id']);
            $items[] = $courier;
        }

        return array_values($items);
    }

    /**
     * @return array{date_local:string,start_local_sql:string,end_local_sql:string,start_utc_sql:string,end_utc_sql:string}
     */
    private static function build_courier_report_window(
        string $date_param,
        string $from_param = '',
        string $to_param = ''
    ): array {
        $site_tz = wp_timezone();
        $local_start = self::parse_report_datetime($from_param, $site_tz, false);
        $local_end = self::parse_report_datetime($to_param, $site_tz, true);

        if (!($local_start instanceof \DateTimeImmutable) && !($local_end instanceof \DateTimeImmutable)) {
            $trimmed_date = trim($date_param);
            if ($trimmed_date !== '' && preg_match('/^\d{4}-\d{2}-\d{2}$/', $trimmed_date) === 1) {
                $parsed = \DateTimeImmutable::createFromFormat('!Y-m-d', $trimmed_date, $site_tz);
                if ($parsed instanceof \DateTimeImmutable) {
                    $local_start = $parsed->setTime(0, 0, 0);
                    $local_end = $parsed->setTime(23, 59, 59);
                }
            }
        }

        if (!($local_start instanceof \DateTimeImmutable) && !($local_end instanceof \DateTimeImmutable)) {
            $today = new \DateTimeImmutable('now', $site_tz);
            $local_start = $today->setTime(0, 0, 0);
            $local_end = $today->setTime(23, 59, 59);
        } elseif ($local_start instanceof \DateTimeImmutable && !($local_end instanceof \DateTimeImmutable)) {
            $local_end = $local_start->setTime(23, 59, 59);
        } elseif (!($local_start instanceof \DateTimeImmutable) && $local_end instanceof \DateTimeImmutable) {
            $local_start = $local_end->setTime(0, 0, 0);
        }

        if ($local_end < $local_start) {
            $tmp = $local_start;
            $local_start = $local_end;
            $local_end = $tmp;
        }

        $utc_tz = new \DateTimeZone('UTC');
        $utc_start = $local_start->setTimezone($utc_tz);
        $utc_end = $local_end->setTimezone($utc_tz);

        return array(
            'date_local' => $local_start->format('Y-m-d'),
            'start_local_sql' => $local_start->format('Y-m-d H:i:s'),
            'end_local_sql' => $local_end->format('Y-m-d H:i:s'),
            'start_utc_sql' => $utc_start->format('Y-m-d H:i:s'),
            'end_utc_sql' => $utc_end->format('Y-m-d H:i:s'),
        );
    }

    private static function parse_report_datetime(
        string $raw,
        \DateTimeZone $site_tz,
        bool $as_end_of_day
    ): ?\DateTimeImmutable {
        $value = trim($raw);
        if ($value === '') {
            return null;
        }

        if (preg_match('/^\d{4}-\d{2}-\d{2}$/', $value) === 1) {
            $parsed = \DateTimeImmutable::createFromFormat('!Y-m-d', $value, $site_tz);
            if ($parsed instanceof \DateTimeImmutable) {
                return $as_end_of_day
                    ? $parsed->setTime(23, 59, 59)
                    : $parsed->setTime(0, 0, 0);
            }
        }

        $formats = array('Y-m-d H:i:s', 'Y-m-d H:i');
        foreach ($formats as $format) {
            $parsed = \DateTimeImmutable::createFromFormat($format, $value, $site_tz);
            if ($parsed instanceof \DateTimeImmutable) {
                return $parsed;
            }
        }

        try {
            return new \DateTimeImmutable($value, $site_tz);
        } catch (\Throwable $e) {
            return null;
        }
    }

    /**
     * @return array<int,array<string,mixed>>
     */
    private static function list_courier_event_rows(
        string $start_utc_sql,
        string $end_utc_sql,
        int $courier_id_filter = 0
    ): array {
        if (!class_exists('Lexi_Order_Events')) {
            return array();
        }

        global $wpdb;
        $table = Lexi_Order_Events::table_name();

        $tracked_event_types = array(
            'assigned',
            'driver_assigned',
            'driver_reassigned',
            'accepted',
            'driver_accepted',
            'rejected',
            'driver_rejected',
            'out_for_delivery',
            'delivered',
            'failed_delivery',
            'returned',
            'cod_collected',
        );
        $quoted_event_types = array();
        foreach ($tracked_event_types as $event_type) {
            $quoted_event_types[] = "'" . esc_sql(sanitize_key($event_type)) . "'";
        }
        $event_type_sql = implode(', ', $quoted_event_types);

        $where_courier = '';
        $params = array($start_utc_sql, $end_utc_sql);
        if ($courier_id_filter > 0) {
            $where_courier = ' AND (e.courier_id = %d OR (e.courier_id IS NULL AND e.actor_role = \'courier\' AND e.actor_id = %d))';
            $params[] = $courier_id_filter;
            $params[] = $courier_id_filter;
        }

        $sql = "
            SELECT
                e.id,
                e.order_id,
                e.courier_id,
                e.event_type,
                e.amount,
                e.actor_role,
                e.actor_id,
                e.payload_json,
                e.created_at
            FROM {$table} e
            WHERE e.created_at BETWEEN %s AND %s
              AND e.event_type IN ({$event_type_sql})
              {$where_courier}
            ORDER BY e.created_at ASC, e.id ASC
        ";

        $prepared = $wpdb->prepare($sql, $params);
        $rows = $wpdb->get_results($prepared, ARRAY_A);
        if (!is_array($rows)) {
            return array();
        }

        $items = array();
        foreach ($rows as $row) {
            $payload = array();
            $payload_raw = (string) ($row['payload_json'] ?? '');
            if ($payload_raw !== '') {
                $decoded = json_decode($payload_raw, true);
                if (is_array($decoded)) {
                    $payload = $decoded;
                }
            }

            $items[] = array(
                'id' => (int) ($row['id'] ?? 0),
                'order_id' => isset($row['order_id']) ? (int) $row['order_id'] : 0,
                'courier_id' => isset($row['courier_id']) ? (int) $row['courier_id'] : 0,
                'event_type' => (string) ($row['event_type'] ?? ''),
                'amount' => isset($row['amount']) && is_numeric($row['amount']) ? (float) $row['amount'] : null,
                'actor_role' => (string) ($row['actor_role'] ?? ''),
                'actor_id' => isset($row['actor_id']) ? (int) $row['actor_id'] : 0,
                'payload' => $payload,
                'created_at' => (string) ($row['created_at'] ?? ''),
            );
        }

        return $items;
    }

    /**
     * @param array<string,mixed> $row
     */
    private static function resolve_courier_id_from_event_row(array $row): int
    {
        $courier_id = isset($row['courier_id']) ? (int) $row['courier_id'] : 0;
        if ($courier_id > 0) {
            return $courier_id;
        }

        $actor_role = strtolower(trim((string) ($row['actor_role'] ?? '')));
        $actor_id = isset($row['actor_id']) ? (int) $row['actor_id'] : 0;
        if ($actor_role === 'courier' && $actor_id > 0) {
            return $actor_id;
        }

        $payload = isset($row['payload']) && is_array($row['payload']) ? $row['payload'] : array();
        $payload_courier = isset($payload['courier_id']) ? (int) $payload['courier_id'] : 0;
        return $payload_courier > 0 ? $payload_courier : 0;
    }

    private static function normalize_courier_report_event_type(string $event_type): string
    {
        $value = strtolower(trim($event_type));
        if (in_array($value, array('assigned', 'driver_assigned', 'driver_reassigned'), true)) {
            return 'assigned';
        }
        if (in_array($value, array('accepted', 'driver_accepted'), true)) {
            return 'accepted';
        }
        if (in_array($value, array('rejected', 'driver_rejected'), true)) {
            return 'rejected';
        }
        if (in_array($value, array('failed_delivery', 'returned'), true)) {
            return 'failed';
        }
        if ($value === 'delivered') {
            return 'delivered';
        }
        if ($value === 'cod_collected') {
            return 'cod_collected';
        }
        if ($value === 'out_for_delivery') {
            return 'out_for_delivery';
        }

        return $value;
    }

    private static function format_coordinate(float $value): string
    {
        return rtrim(rtrim(sprintf('%.6F', $value), '0'), '.');
    }

    private static function to_site_datetime_string(string $utc_mysql_datetime): string
    {
        $value = trim($utc_mysql_datetime);
        if ($value === '') {
            return '';
        }

        $local = get_date_from_gmt($value, 'Y-m-d H:i:s');
        return is_string($local) ? $local : '';
    }

    private static function user_is_delivery_agent(WP_User $user): bool
    {
        $roles = is_array($user->roles) ? $user->roles : array();
        return in_array('delivery_agent', $roles, true) || user_can($user, 'lexi_delivery_agent');
    }

    private static function count_active_orders_for_courier(int $courier_id): int
    {
        if ($courier_id <= 0) {
            return 0;
        }

        $order_ids = wc_get_orders(array(
            'limit' => -1,
            'return' => 'ids',
            'status' => array(
                'pending',
                'on-hold',
                'processing',
                'out-for-delivery',
                'delivered-unpaid',
                'pending-verification',
                'pending-verificat',
            ),
            'meta_query' => array(
                array(
                    'key' => self::META_ASSIGNED_AGENT,
                    'value' => (string) $courier_id,
                    'compare' => '=',
                ),
            ),
        ));

        return count((array) $order_ids);
    }

    private static function coerce_bool($value): int
    {
        if (is_bool($value)) {
            return $value ? 1 : 0;
        }
        if (is_numeric($value)) {
            return ((int) $value) === 0 ? 0 : 1;
        }
        $normalized = strtolower(trim((string) $value));
        return in_array($normalized, array('1', 'true', 'yes', 'on'), true) ? 1 : 0;
    }
}



