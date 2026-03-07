<?php
/**
 * REST routes for customer/admin notifications and Firebase push tools.
 *
 * @package Lexi_API
 */

defined('ABSPATH') || exit;

class Lexi_Routes_Notifications
{
    /**
     * Register all notification routes.
     */
    public static function register(): void
    {
        $ns = LEXI_API_NAMESPACE;

        register_rest_route($ns, '/notifications', array(
            'methods' => WP_REST_Server::READABLE,
            'callback' => array(__CLASS__, 'get_notifications'),
            'permission_callback' => array(__CLASS__, 'notifications_permission'),
            'args' => array(
                'audience' => array(
                    'required' => true,
                    'validate_callback' => static function ($value) {
                        return in_array($value, array('admin', 'customer'), true);
                    },
                    'sanitize_callback' => 'sanitize_text_field',
                ),
                'page' => array(
                    'default' => 1,
                    'sanitize_callback' => 'absint',
                ),
                'per_page' => array(
                    'default' => 20,
                    'sanitize_callback' => 'absint',
                ),
                'device_id' => array(
                    'default' => '',
                    'sanitize_callback' => 'sanitize_text_field',
                ),
            ),
        ));

        register_rest_route($ns, '/notifications/mark-read', array(
            'methods' => WP_REST_Server::CREATABLE,
            'callback' => array(__CLASS__, 'mark_read'),
            'permission_callback' => array(__CLASS__, 'notifications_permission'),
            'args' => array(
                'ids' => array(
                    'required' => true,
                    'validate_callback' => static function ($value) {
                        return is_array($value) && !empty($value);
                    },
                ),
                'audience' => array(
                    'required' => true,
                    'validate_callback' => static function ($value) {
                        return in_array($value, array('admin', 'customer'), true);
                    },
                    'sanitize_callback' => 'sanitize_text_field',
                ),
                'device_id' => array(
                    'default' => '',
                    'sanitize_callback' => 'sanitize_text_field',
                ),
            ),
        ));

        register_rest_route($ns, '/notifications/mark-all-read', array(
            'methods' => WP_REST_Server::CREATABLE,
            'callback' => array(__CLASS__, 'mark_all_read'),
            'permission_callback' => array(__CLASS__, 'notifications_permission'),
            'args' => array(
                'audience' => array(
                    'required' => true,
                    'validate_callback' => static function ($value) {
                        return in_array($value, array('admin', 'customer'), true);
                    },
                    'sanitize_callback' => 'sanitize_text_field',
                ),
                'device_id' => array(
                    'default' => '',
                    'sanitize_callback' => 'sanitize_text_field',
                ),
            ),
        ));

        register_rest_route($ns, '/notifications/unread-count', array(
            'methods' => WP_REST_Server::READABLE,
            'callback' => array(__CLASS__, 'get_unread_count'),
            'permission_callback' => array(__CLASS__, 'notifications_permission'),
            'args' => array(
                'audience' => array(
                    'required' => true,
                    'validate_callback' => static function ($value) {
                        return in_array($value, array('admin', 'customer'), true);
                    },
                    'sanitize_callback' => 'sanitize_text_field',
                ),
                'device_id' => array(
                    'default' => '',
                    'sanitize_callback' => 'sanitize_text_field',
                ),
            ),
        ));

        register_rest_route($ns, '/notifications/register-token', array(
            'methods' => WP_REST_Server::CREATABLE,
            'callback' => array(__CLASS__, 'register_device_token'),
            'permission_callback' => array('Lexi_Security', 'public_access'),
        ));

        register_rest_route($ns, '/devices/register', array(
            'methods' => WP_REST_Server::CREATABLE,
            'callback' => array(__CLASS__, 'register_device_token'),
            'permission_callback' => array('Lexi_Security', 'public_access'),
        ));

        register_rest_route($ns, '/admin/orders/(?P<id>\d+)/decision', array(
            'methods' => WP_REST_Server::CREATABLE,
            'callback' => array(__CLASS__, 'admin_order_decision'),
            'permission_callback' => array(__CLASS__, 'admin_permission'),
            'args' => array(
                'id' => array(
                    'required' => true,
                    'validate_callback' => static function ($value) {
                        return is_numeric($value) && (int) $value > 0;
                    },
                    'sanitize_callback' => 'absint',
                ),
                'decision' => array(
                    'required' => true,
                    'validate_callback' => static function ($value) {
                        return in_array($value, array('approve', 'reject'), true);
                    },
                    'sanitize_callback' => 'sanitize_text_field',
                ),
                'note' => array(
                    'default' => '',
                    'sanitize_callback' => 'sanitize_textarea_field',
                ),
            ),
        ));

        register_rest_route($ns, '/admin/notifications/send', array(
            'methods' => WP_REST_Server::CREATABLE,
            'callback' => array(__CLASS__, 'admin_send_notification'),
            'permission_callback' => array(__CLASS__, 'admin_permission'),
        ));

        register_rest_route($ns, '/admin/notify/user', array(
            'methods' => WP_REST_Server::CREATABLE,
            'callback' => array(__CLASS__, 'admin_notify_user'),
            'permission_callback' => array(__CLASS__, 'admin_permission'),
        ));

        register_rest_route($ns, '/admin/notify/courier', array(
            'methods' => WP_REST_Server::CREATABLE,
            'callback' => array(__CLASS__, 'admin_notify_courier'),
            'permission_callback' => array(__CLASS__, 'admin_permission'),
        ));

        register_rest_route($ns, '/admin/notify/order', array(
            'methods' => WP_REST_Server::CREATABLE,
            'callback' => array(__CLASS__, 'admin_notify_order'),
            'permission_callback' => array(__CLASS__, 'admin_permission'),
        ));

        register_rest_route($ns, '/admin/notifications/firebase-settings', array(
            array(
                'methods' => WP_REST_Server::READABLE,
                'callback' => array(__CLASS__, 'admin_get_firebase_settings'),
                'permission_callback' => array(__CLASS__, 'admin_permission'),
            ),
            array(
                'methods' => WP_REST_Server::EDITABLE,
                'callback' => array(__CLASS__, 'admin_update_firebase_settings'),
                'permission_callback' => array(__CLASS__, 'admin_permission'),
            ),
        ));

        register_rest_route($ns, '/admin/notifications/campaigns', array(
            'methods' => WP_REST_Server::READABLE,
            'callback' => array(__CLASS__, 'admin_list_campaigns'),
            'permission_callback' => array(__CLASS__, 'admin_permission'),
            'args' => array(
                'page' => array(
                    'default' => 1,
                    'sanitize_callback' => 'absint',
                ),
                'per_page' => array(
                    'default' => 20,
                    'sanitize_callback' => 'absint',
                ),
            ),
        ));
    }

    /**
     * Permission callback for notifications.
     *
     * @return bool|WP_Error
     */
    public static function notifications_permission(WP_REST_Request $request)
    {
        $audience = (string) $request->get_param('audience');
        $device_id = (string) $request->get_param('device_id');

        if ($audience === 'admin') {
            $user_id = get_current_user_id();
            if ($user_id <= 0) {
                return new WP_Error(
                    'rest_forbidden',
                    'يجب تسجيل الدخول للوصول إلى إشعارات الإدارة.',
                    array('status' => 401)
                );
            }
            if (!user_can($user_id, 'manage_woocommerce')) {
                return new WP_Error(
                    'rest_forbidden',
                    'ليس لديك صلاحية للوصول إلى إشعارات الإدارة.',
                    array('status' => 403)
                );
            }
            return true;
        }

        if (get_current_user_id() > 0) {
            return true;
        }

        if (trim($device_id) === '') {
            return new WP_Error(
                'rest_forbidden',
                'يجب توفير معرف الجهاز للوصول إلى الإشعارات.',
                array('status' => 401)
            );
        }

        return true;
    }

    /**
     * Permission callback for admin actions.
     *
     * @return bool|WP_Error
     */
    public static function admin_permission()
    {
        $user_id = get_current_user_id();
        if ($user_id <= 0) {
            return new WP_Error(
                'rest_forbidden',
                'يجب تسجيل الدخول.',
                array('status' => 401)
            );
        }

        if (!user_can($user_id, 'manage_woocommerce')) {
            return new WP_Error(
                'rest_forbidden',
                'ليس لديك صلاحية لتنفيذ هذا الإجراء.',
                array('status' => 403)
            );
        }

        return true;
    }

    /**
     * GET /notifications
     */
    public static function get_notifications(WP_REST_Request $request): WP_REST_Response
    {
        $audience = (string) $request->get_param('audience');
        $page = max(1, (int) $request->get_param('page'));
        $per_page = min(60, max(1, (int) $request->get_param('per_page')));
        $device_id = (string) $request->get_param('device_id');
        $user_id = get_current_user_id();

        $result = Lexi_Notifications::get_notifications(
            $audience,
            $user_id > 0 ? $user_id : null,
            trim($device_id) !== '' ? $device_id : null,
            $page,
            $per_page
        );

        return new WP_REST_Response(array(
            'success' => true,
            'data' => $result['items'],
            'meta' => array(
                'page' => $page,
                'per_page' => $per_page,
                'total' => (int) ($result['total'] ?? 0),
                'unread_count' => (int) ($result['unread_count'] ?? 0),
            ),
        ));
    }

    /**
     * POST /notifications/mark-read
     */
    public static function mark_read(WP_REST_Request $request): WP_REST_Response
    {
        $ids = array_map('intval', (array) $request->get_param('ids'));
        $audience = (string) $request->get_param('audience');
        $device_id = (string) $request->get_param('device_id');
        $user_id = get_current_user_id();

        $updated = Lexi_Notifications::mark_read(
            $ids,
            $audience,
            $user_id > 0 ? $user_id : null,
            trim($device_id) !== '' ? $device_id : null
        );

        return Lexi_Security::success(array(
            'updated_count' => (int) $updated,
            'message' => sprintf('تم تحديث %d إشعار.', (int) $updated),
        ));
    }

    /**
     * POST /notifications/mark-all-read
     */
    public static function mark_all_read(WP_REST_Request $request): WP_REST_Response
    {
        $audience = (string) $request->get_param('audience');
        $device_id = (string) $request->get_param('device_id');
        $user_id = get_current_user_id();

        $updated = Lexi_Notifications::mark_all_read(
            $audience,
            $user_id > 0 ? $user_id : null,
            trim($device_id) !== '' ? $device_id : null
        );

        return Lexi_Security::success(array(
            'updated_count' => (int) $updated,
            'message' => sprintf('تم تحديث %d إشعار.', (int) $updated),
        ));
    }

    /**
     * GET /notifications/unread-count
     */
    public static function get_unread_count(WP_REST_Request $request): WP_REST_Response
    {
        $audience = (string) $request->get_param('audience');
        $device_id = (string) $request->get_param('device_id');
        $user_id = get_current_user_id();

        $count = Lexi_Notifications::get_unread_count(
            $audience,
            $user_id > 0 ? $user_id : null,
            trim($device_id) !== '' ? $device_id : null
        );

        return Lexi_Security::success(array('unread_count' => (int) $count));
    }

    /**
     * POST /notifications/register-token
     */
    public static function register_device_token(WP_REST_Request $request): WP_REST_Response
    {
        $body = (array) $request->get_json_params();
        if (empty($body)) {
            $body = (array) $request->get_params();
        }

        $device_id = sanitize_text_field((string) ($body['device_id'] ?? ''));
        if ($device_id === '') {
            $device_id = sanitize_text_field((string) ($body['guest_id'] ?? ''));
        }
        if ($device_id === '') {
            $device_id = sanitize_text_field((string) $request->get_header('Device-Id'));
        }

        $token = (string) ($body['fcm_token'] ?? $body['token'] ?? '');
        $current_user_id = get_current_user_id();
        $incoming_role = sanitize_text_field((string) ($body['role'] ?? ''));

        if ($current_user_id <= 0 && $device_id === '') {
            return Lexi_Security::error(
                'missing_device_id',
                'Device ID (or guest_id) is required for guest token registration.',
                422
            );
        }

        $resolved_user_id = $current_user_id > 0 ? $current_user_id : 0;
        $resolved_role = $resolved_user_id > 0
            ? self::resolve_user_role($resolved_user_id, $incoming_role)
            : ($incoming_role !== '' ? strtolower($incoming_role) : 'guest');

        $result = Lexi_Push::register_token(array(
            'fcm_token' => $token,
            'device_id' => $device_id,
            'platform' => (string) ($body['platform'] ?? ''),
            'app_version' => (string) ($body['app_version'] ?? ''),
            'user_id' => $resolved_user_id > 0 ? $resolved_user_id : null,
            'role' => $resolved_role,
            'guest_id' => (string) ($body['guest_id'] ?? ''),
        ));

        if (empty($result['success'])) {
            return Lexi_Security::error(
                (string) ($result['code'] ?? 'register_token_failed'),
                (string) ($result['message'] ?? 'تعذّر تسجيل رمز الإشعارات.'),
                422
            );
        }

        return Lexi_Security::success(array(
            'message' => 'تم تسجيل جهاز الإشعارات بنجاح.',
            'token' => array(
                'id' => (int) ($result['id'] ?? 0),
                'user_id' => $result['user_id'] ?? null,
                'role' => (string) ($result['role'] ?? $resolved_role),
                'device_id' => $result['device_id'] ?? null,
                'platform' => (string) ($result['platform'] ?? 'unknown'),
            ),
        ));
    }

    /**
     * GET /admin/notifications/firebase-settings
     */
    public static function admin_get_firebase_settings(WP_REST_Request $request): WP_REST_Response
    {
        return Lexi_Security::success(Lexi_Push::get_settings(true));
    }

    /**
     * PATCH /admin/notifications/firebase-settings
     */
    public static function admin_update_firebase_settings(WP_REST_Request $request): WP_REST_Response
    {
        $body = (array) $request->get_json_params();
        $settings = Lexi_Push::save_settings($body);

        return Lexi_Security::success(array_merge(
            array('message' => 'تم حفظ إعدادات Firebase بنجاح.'),
            $settings
        ));
    }

    /**
     * GET /admin/notifications/campaigns
     */
    public static function admin_list_campaigns(WP_REST_Request $request): WP_REST_Response
    {
        $page = max(1, (int) $request->get_param('page'));
        $per_page = min(100, max(1, (int) $request->get_param('per_page')));

        return Lexi_Security::success(Lexi_Push::list_campaigns($page, $per_page));
    }

    /**
     * POST /admin/orders/{id}/decision
     */
    public static function admin_order_decision(WP_REST_Request $request)
    {
        $order_id = (int) $request->get_param('id');
        $decision = strtolower(trim((string) $request->get_param('decision')));
        $note = sanitize_textarea_field((string) $request->get_param('note'));

        $order = wc_get_order($order_id);
        if (!$order) {
            return new WP_Error('order_not_found', 'Order not found.', array('status' => 404));
        }

        if (!in_array($decision, array('approve', 'reject'), true)) {
            return Lexi_Security::error('invalid_decision', 'Decision is invalid.', 422);
        }

        $is_shamcash = class_exists('Lexi_Order_Flow')
            ? Lexi_Order_Flow::is_shamcash_order($order)
            : false;

        if ($is_shamcash) {
            $proof_url = trim((string) $order->get_meta('_lexi_shamcash_proof_url'));
            if ('' === $proof_url) {
                $proof_url = trim((string) $order->get_meta('_lexi_payment_proof_url'));
            }

            if ('approve' === $decision) {
                if ('' === $proof_url) {
                    return Lexi_Security::error('no_proof', 'Cannot approve ShamCash order without proof.', 422);
                }

                $new_status = 'processing';
                $message = 'Order approved successfully.';
                $order->set_status($new_status, 'ShamCash proof approved.');
                $order->update_meta_data('_lexi_decision', 'approved');
                $order->update_meta_data('_lexi_shamcash_verified_at', current_time('mysql'));
                $order->update_meta_data('_lexi_shamcash_verified_by', (int) get_current_user_id());
            } else {
                $new_status = 'failed';
                $message = 'Order rejected.';
                $order->set_status($new_status, 'ShamCash proof rejected.');
                $order->update_meta_data('_lexi_decision', 'rejected');
            }

            $order->update_meta_data('_lexi_admin_note_ar', $note);
            $order->update_meta_data('_lexi_decision_at', current_time('mysql'));
            $order->save();

            if (class_exists('Lexi_Order_Events')) {
                Lexi_Order_Events::log(
                    $order_id,
                    'approve' === $decision ? 'shamcash_decision_approved' : 'shamcash_decision_rejected',
                    'admin',
                    (int) get_current_user_id(),
                    array(
                        'note_ar' => $note,
                        'proof_url' => '' !== $proof_url ? $proof_url : null,
                    )
                );
            }

            if (class_exists('Lexi_Notifications')) {
                Lexi_Notifications::append_timeline(
                    $order,
                    'approve' === $decision ? 'approved' : 'rejected',
                    'approve' === $decision ? 'Order approved.' : 'Order rejected.'
                );
                Lexi_Notifications::notify_customer_decision(
                    $order,
                    'approve' === $decision ? 'approved' : 'rejected',
                    $note
                );
            }
        } else {
            $new_status = $decision === 'approve' ? 'processing' : 'cancelled';
            $message = $decision === 'approve'
                ? 'Order approved successfully.'
                : 'Order rejected.';

            $order->update_status($new_status, $note);
            if ($note !== '') {
                $order->update_meta_data('_lexi_admin_note', $note);
            }
            $order->save();

            if (class_exists('Lexi_Order_Events')) {
                Lexi_Order_Events::log(
                    $order_id,
                    'approve' === $decision ? 'order_decision_approved' : 'order_decision_rejected',
                    'admin',
                    (int) get_current_user_id(),
                    array(
                        'new_status' => $new_status,
                        'note' => $note,
                    )
                );
            }
        }

        return new WP_REST_Response(array(
            'success' => true,
            'message' => $message,
            'data' => array(
                'order_id' => $order_id,
                'decision' => $decision,
                'new_status' => $new_status,
            ),
        ));
    }

    /**
     * POST /admin/notifications/send
     */
    public static function admin_send_notification(WP_REST_Request $request)
    {
        $body = (array) $request->get_json_params();
        if (empty($body)) {
            $body = (array) $request->get_params();
        }

        $target = sanitize_text_field((string) ($body['target'] ?? 'broadcast'));
        $title_ar = self::normalize_text((string) ($body['title_ar'] ?? ''));
        $body_ar = self::normalize_text((string) ($body['body_ar'] ?? ''));
        $user_id = absint((int) ($body['user_id'] ?? 0));
        $device_id = sanitize_text_field((string) ($body['device_id'] ?? ''));
        $type = sanitize_text_field((string) ($body['type'] ?? 'manual'));
        $audience = sanitize_text_field((string) ($body['audience'] ?? 'customer'));
        $image_url = esc_url_raw((string) ($body['image_url'] ?? ''));
        $deep_link = trim((string) ($body['deep_link'] ?? ''));
        $open_mode = self::normalize_open_mode((string) ($body['open_mode'] ?? 'in_app'));
        $send_push = self::to_bool($body['send_push'] ?? true);

        if (!in_array($target, array('broadcast', 'all_admins', 'specific_user', 'specific_device'), true)) {
            return Lexi_Security::error('invalid_target', 'الهدف غير صالح.', 422);
        }

        if ($title_ar === '' || $body_ar === '') {
            return Lexi_Security::error('invalid_payload', 'العنوان والنص مطلوبان.', 422);
        }

        if ($target === 'all_admins') {
            $audience = 'admin';
        }
        if (!in_array($audience, array('admin', 'customer'), true)) {
            $audience = 'customer';
        }

        if ($target === 'specific_user' && $user_id <= 0) {
            return Lexi_Security::error('missing_user_id', 'معرف المستخدم مطلوب لهذا النوع من الإرسال.', 422);
        }
        if ($target === 'specific_device' && trim($device_id) === '') {
            return Lexi_Security::error('missing_device_id', 'معرف الجهاز مطلوب لهذا النوع من الإرسال.', 422);
        }

        $notification_data = array_filter(array(
            'deep_link' => $deep_link,
            'open_mode' => $open_mode,
            'image_url' => $image_url,
            'source' => 'admin_campaign',
            'type' => $type,
        ), static function ($value) {
            return is_string($value) ? trim($value) !== '' : !empty($value);
        });

        $stored_count = 0;
        if ($audience === 'admin') {
            if ($target === 'specific_user') {
                Lexi_Notifications::notify_customer(
                    $user_id,
                    null,
                    $type,
                    $title_ar,
                    $body_ar,
                    null,
                    $notification_data
                );
                $stored_count = 1;
            } else {
                Lexi_Notifications::notify_admins($type, $title_ar, $body_ar, null, $notification_data);
                $stored_count = self::count_admin_users();
            }
        } else {
            switch ($target) {
                case 'broadcast':
                    $stored_count = Lexi_Notifications::broadcast_customer(
                        $type,
                        $title_ar,
                        $body_ar,
                        $notification_data
                    );
                    break;

                case 'specific_user':
                    Lexi_Notifications::notify_customer(
                        $user_id,
                        null,
                        $type,
                        $title_ar,
                        $body_ar,
                        null,
                        $notification_data
                    );
                    $stored_count = 1;
                    break;

                case 'specific_device':
                    Lexi_Notifications::notify_customer(
                        null,
                        $device_id,
                        $type,
                        $title_ar,
                        $body_ar,
                        null,
                        $notification_data
                    );
                    $stored_count = 1;
                    break;

                case 'all_admins':
                    Lexi_Notifications::notify_admins($type, $title_ar, $body_ar, null, $notification_data);
                    $stored_count = self::count_admin_users();
                    break;
            }
        }

        $push_result = array(
            'targeted_count' => 0,
            'push_success' => 0,
            'push_failed' => 0,
            'provider_status' => 'disabled_by_request',
            'provider_error' => '',
        );

        if ($send_push) {
            $push_result = Lexi_Push::send_push_for_target(array(
                'target' => $target,
                'audience' => $audience,
                'title_ar' => $title_ar,
                'body_ar' => $body_ar,
                'type' => $type,
                'image_url' => $image_url,
                'deep_link' => $deep_link,
                'open_mode' => $open_mode,
                'user_id' => $user_id,
                'device_id' => $device_id,
            ));
        } else {
            $push_result['targeted_count'] = count(
                Lexi_Push::collect_tokens_for_target($target, $audience, $user_id, $device_id)
            );
        }

        $campaign_id = Lexi_Push::save_campaign(array(
            'created_by' => get_current_user_id(),
            'target' => $target,
            'audience' => $audience,
            'type' => $type,
            'title_ar' => $title_ar,
            'body_ar' => $body_ar,
            'image_url' => $image_url,
            'deep_link' => $deep_link,
            'open_mode' => $open_mode,
            'targeted_count' => (int) ($push_result['targeted_count'] ?? 0),
            'stored_count' => (int) $stored_count,
            'push_success' => (int) ($push_result['push_success'] ?? 0),
            'push_failed' => (int) ($push_result['push_failed'] ?? 0),
            'provider_status' => (string) ($push_result['provider_status'] ?? 'none'),
            'provider_error' => (string) ($push_result['provider_error'] ?? ''),
            'meta' => array(
                'send_push' => $send_push,
            ),
        ));

        return Lexi_Security::success(array(
            'message' => 'تم إرسال الإشعار بنجاح.',
            'campaign' => array(
                'id' => $campaign_id,
                'target' => $target,
                'audience' => $audience,
                'type' => $type,
                'title_ar' => $title_ar,
                'body_ar' => $body_ar,
                'image_url' => $image_url,
                'deep_link' => $deep_link,
                'open_mode' => $open_mode,
                'stored_count' => (int) $stored_count,
                'targeted_count' => (int) ($push_result['targeted_count'] ?? 0),
                'push_success' => (int) ($push_result['push_success'] ?? 0),
                'push_failed' => (int) ($push_result['push_failed'] ?? 0),
                'provider_status' => (string) ($push_result['provider_status'] ?? 'none'),
                'provider_error' => (string) ($push_result['provider_error'] ?? ''),
            ),
        ));
    }

    /**
     * POST /admin/notify/user
     */
    public static function admin_notify_user(WP_REST_Request $request): WP_REST_Response
    {
        $body = self::request_body($request);
        $user_id = absint((int) ($body['user_id'] ?? 0));
        $title = self::normalize_text((string) ($body['title'] ?? $body['title_ar'] ?? ''));
        $message = self::normalize_text((string) ($body['body'] ?? $body['body_ar'] ?? ''));
        $data = self::normalize_data_map($body['data'] ?? array());
        $type = sanitize_text_field((string) ($body['type'] ?? ($data['type'] ?? 'manual')));
        $open_mode = self::normalize_open_mode((string) ($body['open_mode'] ?? ($data['open_mode'] ?? 'in_app')));
        $deep_link = trim((string) ($body['deep_link'] ?? ($data['deep_link'] ?? '')));
        $priority = sanitize_text_field((string) ($body['priority'] ?? 'normal'));

        if ($user_id <= 0) {
            return Lexi_Security::error('missing_user_id', 'User ID is required.', 422);
        }
        if ($title === '' || $message === '') {
            return Lexi_Security::error('invalid_payload', 'Title and body are required.', 422);
        }

        $audience = sanitize_text_field((string) ($body['audience'] ?? 'customer'));
        if (!in_array($audience, array('customer', 'courier', 'admin'), true)) {
            $audience = 'customer';
        }

        $push_result = Lexi_Push::send_push_for_target(array(
            'target' => 'specific_user',
            'audience' => $audience,
            'user_id' => $user_id,
            'title_ar' => $title,
            'body_ar' => $message,
            'type' => $type,
            'open_mode' => $open_mode,
            'deep_link' => $deep_link,
            'priority' => $priority,
            'extra_data' => $data,
        ));

        return Lexi_Security::success(array(
            'message' => 'User notification dispatched.',
            'result' => $push_result,
        ));
    }

    /**
     * POST /admin/notify/courier
     */
    public static function admin_notify_courier(WP_REST_Request $request): WP_REST_Response
    {
        $body = self::request_body($request);
        $courier_id = absint((int) ($body['courier_id'] ?? 0));
        $title = self::normalize_text((string) ($body['title'] ?? $body['title_ar'] ?? ''));
        $message = self::normalize_text((string) ($body['body'] ?? $body['body_ar'] ?? ''));
        $data = self::normalize_data_map($body['data'] ?? array());
        $type = sanitize_text_field((string) ($body['type'] ?? ($data['type'] ?? 'courier_manual')));
        $open_mode = self::normalize_open_mode((string) ($body['open_mode'] ?? ($data['open_mode'] ?? 'in_app')));
        $deep_link = trim((string) ($body['deep_link'] ?? ($data['deep_link'] ?? '')));

        if ($courier_id <= 0) {
            return Lexi_Security::error('missing_courier_id', 'Courier ID is required.', 422);
        }
        if ($title === '' || $message === '') {
            return Lexi_Security::error('invalid_payload', 'Title and body are required.', 422);
        }

        $courier = get_user_by('id', $courier_id);
        if (!($courier instanceof WP_User) || !self::is_delivery_agent($courier)) {
            return Lexi_Security::error('invalid_courier', 'Courier not found or not a delivery agent.', 422);
        }

        $push_result = Lexi_Push::send_push_for_target(array(
            'target' => 'specific_user',
            'audience' => 'courier',
            'user_id' => $courier_id,
            'title_ar' => $title,
            'body_ar' => $message,
            'type' => $type,
            'open_mode' => $open_mode,
            'deep_link' => $deep_link,
            'priority' => 'high',
            'extra_data' => $data,
        ));

        return Lexi_Security::success(array(
            'message' => 'Courier notification dispatched.',
            'result' => $push_result,
        ));
    }

    /**
     * POST /admin/notify/order
     */
    public static function admin_notify_order(WP_REST_Request $request): WP_REST_Response
    {
        $body = self::request_body($request);
        $order_id = absint((int) ($body['order_id'] ?? 0));
        $target = sanitize_text_field((string) ($body['target'] ?? 'customer'));
        $title = self::normalize_text((string) ($body['title'] ?? $body['title_ar'] ?? ''));
        $message = self::normalize_text((string) ($body['body'] ?? $body['body_ar'] ?? ''));
        $data = self::normalize_data_map($body['data'] ?? array());
        $type = sanitize_text_field((string) ($body['type'] ?? ($data['type'] ?? 'order_update')));
        $open_mode = self::normalize_open_mode((string) ($body['open_mode'] ?? ($data['open_mode'] ?? 'in_app')));
        $deep_link = trim((string) ($body['deep_link'] ?? ($data['deep_link'] ?? '')));

        if ($order_id <= 0) {
            return Lexi_Security::error('missing_order_id', 'Order ID is required.', 422);
        }
        if (!in_array($target, array('customer', 'courier', 'admin'), true)) {
            return Lexi_Security::error('invalid_target', 'Target must be one of: customer, courier, admin.', 422);
        }
        if ($title === '' || $message === '') {
            return Lexi_Security::error('invalid_payload', 'Title and body are required.', 422);
        }

        $order = wc_get_order($order_id);
        if (!$order) {
            return Lexi_Security::error('order_not_found', 'Order not found.', 404);
        }

        $payload = array(
            'title_ar' => $title,
            'body_ar' => $message,
            'type' => $type,
            'open_mode' => $open_mode,
            'deep_link' => $deep_link,
            'order_id' => $order_id,
            'extra_data' => array_merge(
                array('order_id' => (string) $order_id),
                $data
            ),
        );

        if ($target === 'admin') {
            $payload['target'] = 'all_admins';
            $payload['audience'] = 'admin';
        } elseif ($target === 'courier') {
            $courier_id = (int) $order->get_meta('_lexi_delivery_agent_id');
            if ($courier_id <= 0) {
                return Lexi_Security::error('courier_not_assigned', 'This order has no assigned courier.', 409);
            }
            $payload['target'] = 'specific_user';
            $payload['audience'] = 'courier';
            $payload['user_id'] = $courier_id;
            $payload['priority'] = 'high';
        } else {
            $customer_id = (int) $order->get_user_id();
            $order_device_id = trim((string) $order->get_meta('_lexi_device_id'));
            if ($customer_id > 0) {
                $payload['target'] = 'specific_user';
                $payload['audience'] = 'customer';
                $payload['user_id'] = $customer_id;
            } elseif ($order_device_id !== '') {
                $payload['target'] = 'specific_device';
                $payload['audience'] = 'customer';
                $payload['device_id'] = $order_device_id;
            } else {
                return Lexi_Security::error(
                    'customer_target_unavailable',
                    'Customer notification target is unavailable for this order.',
                    409
                );
            }
        }

        $push_result = Lexi_Push::send_push_for_target($payload);

        return Lexi_Security::success(array(
            'message' => 'Order notification dispatched.',
            'result' => $push_result,
        ));
    }

    /**
     * @return array<string,mixed>
     */
    private static function request_body(WP_REST_Request $request): array
    {
        $body = (array) $request->get_json_params();
        if (empty($body)) {
            $body = (array) $request->get_params();
        }
        return $body;
    }

    /**
     * @param mixed $value
     * @return array<string,mixed>
     */
    private static function normalize_data_map($value): array
    {
        if (is_array($value)) {
            return $value;
        }
        if (is_string($value)) {
            $decoded = json_decode($value, true);
            if (is_array($decoded)) {
                return $decoded;
            }
        }
        return array();
    }

    private static function resolve_user_role(int $user_id, string $fallback = ''): string
    {
        $fallback = strtolower(trim($fallback));
        if ($fallback !== '') {
            return $fallback;
        }

        $user = get_user_by('id', $user_id);
        if (!($user instanceof WP_User)) {
            return 'customer';
        }

        $roles = is_array($user->roles) ? $user->roles : array();
        if (empty($roles)) {
            return 'customer';
        }

        return sanitize_text_field((string) $roles[0]);
    }

    private static function is_delivery_agent(WP_User $user): bool
    {
        $roles = is_array($user->roles) ? $user->roles : array();
        return in_array('delivery_agent', $roles, true) || user_can($user, 'lexi_delivery_agent');
    }

    private static function normalize_open_mode(string $value): string
    {
        $mode = sanitize_text_field($value);
        if (!in_array($mode, array('in_app', 'external', 'product', 'category', 'deals'), true)) {
            return 'in_app';
        }
        return $mode;
    }

    private static function to_bool($value): bool
    {
        if (is_bool($value)) {
            return $value;
        }
        if (is_numeric($value)) {
            return (int) $value > 0;
        }
        $normalized = strtolower(trim((string) $value));
        return in_array($normalized, array('1', 'true', 'yes', 'on'), true);
    }

    private static function normalize_text($value): string
    {
        if (class_exists('Lexi_Text')) {
            return Lexi_Text::normalize($value);
        }
        return (string) $value;
    }

    private static function count_admin_users(): int
    {
        $ids = get_users(array(
            'role__in' => array('administrator', 'shop_manager'),
            'fields' => 'ids',
            'number' => 5000,
        ));

        return count((array) $ids);
    }
}
