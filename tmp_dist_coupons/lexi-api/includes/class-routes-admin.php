<?php
/**
 * Admin REST routes: dashboard, orders, shipping cities, ShamCash verification.
 *
 * @package Lexi_API
 */

defined('ABSPATH') || exit;

class Lexi_Routes_Admin
{
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

        register_rest_route($ns, '/admin/orders/(?P<id>\d+)/notify', array(
            'methods' => WP_REST_Server::CREATABLE,
            'callback' => array(__CLASS__, 'notify_order_customer'),
            'permission_callback' => array('Lexi_Security', 'admin_access'),
            'args' => array(
                'id' => array('required' => true, 'sanitize_callback' => 'absint'),
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
            'methods' => WP_REST_Server::READABLE,
            'callback' => array(__CLASS__, 'get_email_diagnostics'),
            'permission_callback' => array('Lexi_Security', 'admin_access'),
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
        $page = max(1, (int) $request->get_param('page'));
        $per_page = min(100, max(1, (int) $request->get_param('per_page')));

        $args = array(
            'limit' => $per_page,
            'offset' => ($page - 1) * $per_page,
            'orderby' => 'date',
            'order' => 'DESC',
        );
        if ('' !== $status && 'all' !== $status) {
            if ('pending-verification' === $status) {
                $args['status'] = array('pending-verification', 'pending-verificat', 'on-hold');
            } else {
                $args['status'] = $status;
            }
        }

        $orders = wc_get_orders($args);
        $total_args = $args;
        $total_args['limit'] = -1;
        $total_args['offset'] = 0;
        $total_args['return'] = 'ids';
        $total = count(wc_get_orders($total_args));

        $items = array();
        foreach ($orders as $order) {
            if ($order instanceof WC_Order) {
                $items[] = Lexi_Routes_Orders::format_order($order, true);
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

        return Lexi_Security::success(Lexi_Routes_Orders::format_order($order, true));
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

        $new_status = self::normalize_status((string) ($body['status'] ?? ''));
        $note = sanitize_textarea_field((string) ($body['note'] ?? ''));

        if ('' === $new_status) {
            return Lexi_Security::error('missing_status', 'حالة الطلب الجديدة مطلوبة.', 422);
        }

        $valid_statuses = wc_get_order_statuses();
        if (!isset($valid_statuses['wc-' . $new_status])) {
            return Lexi_Security::error('invalid_status', 'حالة الطلب غير صالحة.', 422);
        }

        $old_status = $order->get_status();
        $order->set_status($new_status, 'تحديث من لوحة التحكم.');
        if ('' !== $note) {
            $order->add_order_note($note, 0, true);
        }
        $order->save();

        return Lexi_Security::success(array(
            'order_id' => (int) $order->get_id(),
            'old_status' => $old_status,
            'new_status' => $new_status,
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
        $order->save();

        Lexi_Notifications::append_timeline($order, 'approved', 'تم قبول طلبك.');
        Lexi_Notifications::notify_customer_decision($order, 'approved', $note_ar);

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

        $order->set_status('cancelled', 'تم رفض إيصال شام كاش.');
        $order->add_order_note('تم رفض الطلب. ملاحظة الإدارة: ' . $note_ar, 0, true);
        $order->update_meta_data('_lexi_decision', 'rejected');
        $order->update_meta_data('_lexi_admin_note_ar', $note_ar);
        $order->update_meta_data('_lexi_decision_at', current_time('mysql'));
        $order->save();

        Lexi_Notifications::append_timeline($order, 'rejected', 'تم رفض طلبك.');
        Lexi_Notifications::notify_customer_decision($order, 'rejected', $note_ar);

        return Lexi_Security::success(array(
            'id' => (int) $order->get_id(),
            'status' => 'cancelled',
            'status_label_ar' => 'ملغي',
            'message' => 'تم رفض طلبك',
        ));
    }

    private static function is_shamcash_order(WC_Order $order): bool
    {
        $method = strtolower(trim((string) $order->get_meta('_lexi_payment_method')));
        if ('' === $method) {
            $method = strtolower(trim((string) $order->get_payment_method()));
        }
        $method = str_replace('-', '_', $method);
        return in_array($method, array('sham_cash', 'shamcash'), true);
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

        $orders = wc_get_orders(array(
            'status' => array('pending-verification', 'pending-verificat', 'on-hold', 'pending'),
            'limit' => -1,
            'orderby' => 'date',
            'order' => 'DESC',
            'return' => 'objects',
        ));

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
            if ('' === $proof_url) {
                continue;
            }

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
                    'has_proof' => true,
                    'image_url' => $proof_url,
                    'thumbnail_url' => $proof_url,
                    'uploaded_at' => $proof_uploaded_at,
                    'note' => $proof_note,
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
