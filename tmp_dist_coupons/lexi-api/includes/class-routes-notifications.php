<?php
/**
 * REST routes for notifications.
 *
 * @package Lexi_API
 */

defined('ABSPATH') || exit;

/**
 * Lexi Routes - Notifications
 */
class Lexi_Routes_Notifications
{
    /**
     * Register all notification routes.
     */
    public static function register(): void
    {
        // Fetch notifications
        register_rest_route('lexi/v1', '/notifications', [
            'methods' => 'GET',
            'callback' => [__CLASS__, 'get_notifications'],
            'permission_callback' => [__CLASS__, 'notifications_permission'],
            'args' => [
                'audience' => [
                    'required' => true,
                    'validate_callback' => function ($v) {
                        return in_array($v, ['admin', 'customer'], true);
                    },
                    'sanitize_callback' => 'sanitize_text_field',
                ],
                'page' => [
                    'default' => 1,
                    'sanitize_callback' => 'absint',
                ],
                'per_page' => [
                    'default' => 20,
                    'sanitize_callback' => 'absint',
                ],
                'device_id' => [
                    'default' => '',
                    'sanitize_callback' => 'sanitize_text_field',
                ],
            ],
        ]);

        // Mark as read
        register_rest_route('lexi/v1', '/notifications/mark-read', [
            'methods' => 'POST',
            'callback' => [__CLASS__, 'mark_read'],
            'permission_callback' => [__CLASS__, 'notifications_permission'],
            'args' => [
                'ids' => [
                    'required' => true,
                    'validate_callback' => function ($v) {
                        return is_array($v) && !empty($v);
                    },
                ],
                'audience' => [
                    'required' => true,
                    'validate_callback' => function ($v) {
                        return in_array($v, ['admin', 'customer'], true);
                    },
                    'sanitize_callback' => 'sanitize_text_field',
                ],
                'device_id' => [
                    'default' => '',
                    'sanitize_callback' => 'sanitize_text_field',
                ],
            ],
        ]);

        // Mark all as read
        register_rest_route('lexi/v1', '/notifications/mark-all-read', [
            'methods' => 'POST',
            'callback' => [__CLASS__, 'mark_all_read'],
            'permission_callback' => [__CLASS__, 'notifications_permission'],
            'args' => [
                'audience' => [
                    'required' => true,
                    'validate_callback' => function ($v) {
                        return in_array($v, ['admin', 'customer'], true);
                    },
                    'sanitize_callback' => 'sanitize_text_field',
                ],
                'device_id' => [
                    'default' => '',
                    'sanitize_callback' => 'sanitize_text_field',
                ],
            ],
        ]);

        // Unread count
        register_rest_route('lexi/v1', '/notifications/unread-count', [
            'methods' => 'GET',
            'callback' => [__CLASS__, 'get_unread_count'],
            'permission_callback' => [__CLASS__, 'notifications_permission'],
            'args' => [
                'audience' => [
                    'required' => true,
                    'validate_callback' => function ($v) {
                        return in_array($v, ['admin', 'customer'], true);
                    },
                    'sanitize_callback' => 'sanitize_text_field',
                ],
                'device_id' => [
                    'default' => '',
                    'sanitize_callback' => 'sanitize_text_field',
                ],
            ],
        ]);

        // Admin: Approve/Reject order
        register_rest_route('lexi/v1', '/admin/orders/(?P<id>\d+)/decision', [
            'methods' => 'POST',
            'callback' => [__CLASS__, 'admin_order_decision'],
            'permission_callback' => [__CLASS__, 'admin_permission'],
            'args' => [
                'id' => [
                    'required' => true,
                    'validate_callback' => function ($v) {
                        return is_numeric($v) && (int) $v > 0;
                    },
                    'sanitize_callback' => 'absint',
                ],
                'decision' => [
                    'required' => true,
                    'validate_callback' => function ($v) {
                        return in_array($v, ['approve', 'reject'], true);
                    },
                    'sanitize_callback' => 'sanitize_text_field',
                ],
                'note' => [
                    'default' => '',
                    'sanitize_callback' => 'sanitize_textarea_field',
                ],
            ],
        ]);

        // Admin: Send manual notification
        register_rest_route('lexi/v1', '/admin/notifications/send', [
            'methods' => 'POST',
            'callback' => [__CLASS__, 'admin_send_notification'],
            'permission_callback' => [__CLASS__, 'admin_permission'],
            'args' => [
                'target' => [
                    'required' => true,
                    'validate_callback' => function ($v) {
                        return in_array($v, ['broadcast', 'all_admins', 'specific_user', 'specific_device'], true);
                    },
                    'sanitize_callback' => 'sanitize_text_field',
                ],
                'title_ar' => [
                    'required' => true,
                    'sanitize_callback' => 'sanitize_text_field',
                ],
                'body_ar' => [
                    'required' => true,
                    'sanitize_callback' => 'sanitize_textarea_field',
                ],
                'user_id' => [
                    'sanitize_callback' => 'absint',
                ],
                'device_id' => [
                    'sanitize_callback' => 'sanitize_text_field',
                ],
                'type' => [
                    'default' => 'manual',
                    'sanitize_callback' => 'sanitize_text_field',
                ],
            ],
        ]);
    }

    /**
     * Permission callback for notifications.
     *
     * @param WP_REST_Request $request Request object.
     * @return bool|WP_Error
     */
    public static function notifications_permission(WP_REST_Request $request)
    {
        $audience = $request->get_param('audience');
        $device_id = $request->get_param('device_id');

        // Admin audience requires JWT + admin capability
        if ($audience === 'admin') {
            $user_id = get_current_user_id();
            if (!$user_id) {
                return new WP_Error(
                    'rest_forbidden',
                    'يجب تسجيل الدخول للوصول إلى إشعارات الإدارة.',
                    ['status' => 401]
                );
            }
            if (!user_can($user_id, 'manage_woocommerce')) {
                return new WP_Error(
                    'rest_forbidden',
                    'ليس لديك صلاحية للوصول إلى إشعارات الإدارة.',
                    ['status' => 403]
                );
            }
            return true;
        }

        // Customer audience
        $user_id = get_current_user_id();
        if ($user_id) {
            // Logged-in customer
            return true;
        }

        // Guest customer - require device_id
        if (empty($device_id)) {
            return new WP_Error(
                'rest_forbidden',
                'يجب توفير معرف الجهاز للوصول إلى الإشعارات.',
                ['status' => 401]
            );
        }

        return true;
    }

    /**
     * Permission callback for admin actions.
     */
    public static function admin_permission()
    {
        $user_id = get_current_user_id();
        if (!$user_id) {
            return new WP_Error(
                'rest_forbidden',
                'يجب تسجيل الدخول.',
                ['status' => 401]
            );
        }
        if (!user_can($user_id, 'manage_woocommerce')) {
            return new WP_Error(
                'rest_forbidden',
                'ليس لديك صلاحية للقيام بهذا الإجراء.',
                ['status' => 403]
            );
        }
        return true;
    }

    /**
     * Get notifications.
     *
     * @param WP_REST_Request $request Request object.
     * @return WP_REST_Response
     */
    public static function get_notifications(WP_REST_Request $request): WP_REST_Response
    {
        $audience = $request->get_param('audience');
        $page = (int) $request->get_param('page');
        $per_page = min(60, max(1, (int) $request->get_param('per_page')));
        $device_id = $request->get_param('device_id');

        $user_id = get_current_user_id();

        $result = Lexi_Notifications::get_notifications(
            $audience,
            $user_id > 0 ? $user_id : null,
            $device_id ?: null,
            $page,
            $per_page
        );

        return new WP_REST_Response([
            'success' => true,
            'data' => $result['items'],
            'meta' => [
                'page' => $page,
                'per_page' => $per_page,
                'total' => $result['total'],
                'unread_count' => $result['unread_count'],
            ],
        ]);
    }

    /**
     * Mark notifications as read.
     *
     * @param WP_REST_Request $request Request object.
     * @return WP_REST_Response
     */
    public static function mark_read(WP_REST_Request $request): WP_REST_Response
    {
        $ids = array_map('intval', (array) $request->get_param('ids'));
        $audience = $request->get_param('audience');
        $device_id = $request->get_param('device_id');

        $user_id = get_current_user_id();

        $updated = Lexi_Notifications::mark_read(
            $ids,
            $audience,
            $user_id > 0 ? $user_id : null,
            $device_id ?: null
        );

        return new WP_REST_Response([
            'success' => true,
            'message' => "تم تحديث {$updated} إشعار.",
            'data' => [
                'updated_count' => $updated,
            ],
        ]);
    }

    /**
     * Mark all notifications as read.
     *
     * @param WP_REST_Request $request Request object.
     * @return WP_REST_Response
     */
    public static function mark_all_read(WP_REST_Request $request): WP_REST_Response
    {
        $audience = $request->get_param('audience');
        $device_id = $request->get_param('device_id');

        $user_id = get_current_user_id();

        $updated = Lexi_Notifications::mark_all_read(
            $audience,
            $user_id > 0 ? $user_id : null,
            $device_id ?: null
        );

        return new WP_REST_Response([
            'success' => true,
            'message' => "تم تحديث {$updated} إشعار.",
            'data' => [
                'updated_count' => $updated,
            ],
        ]);
    }

    /**
     * Get unread count.
     *
     * @param WP_REST_Request $request Request object.
     * @return WP_REST_Response
     */
    public static function get_unread_count(WP_REST_Request $request): WP_REST_Response
    {
        $audience = $request->get_param('audience');
        $device_id = $request->get_param('device_id');

        $user_id = get_current_user_id();

        $count = Lexi_Notifications::get_unread_count(
            $audience,
            $user_id > 0 ? $user_id : null,
            $device_id ?: null
        );

        return new WP_REST_Response([
            'success' => true,
            'data' => [
                'unread_count' => $count,
            ],
        ]);
    }

    /**
     * Admin: Approve or reject order.
     *
     * @param WP_REST_Request $request Request object.
     * @return WP_REST_Response|WP_Error
     */
    public static function admin_order_decision(WP_REST_Request $request)
    {
        $order_id = (int) $request->get_param('id');
        $decision = $request->get_param('decision');
        $note = $request->get_param('note');

        $order = wc_get_order($order_id);
        if (!$order) {
            return new WP_Error(
                'order_not_found',
                'الطلب غير موجود.',
                ['status' => 404]
            );
        }

        // Determine new status and response message
        $new_status = $decision === 'approve' ? 'processing' : 'cancelled';
        $message    = $decision === 'approve' ? 'تم قبول الطلب بنجاح.' : 'تم رفض الطلب.';

        // Update order status (this will trigger notification hooks)
        $order->update_status($new_status, $note);

        // Store admin note in meta
        if (!empty($note)) {
            $order->update_meta_data('_lexi_admin_note', $note);
            $order->save();
        }

        return new WP_REST_Response([
            'success' => true,
            'message' => $message,
            'data' => [
                'order_id' => $order_id,
                'decision' => $decision,
                'new_status' => $new_status,
            ],
        ]);
    }

    /**
     * Admin: Send manual notification to a target audience.
     *
     * @param WP_REST_Request $request Request object.
     * @return WP_REST_Response|WP_Error
     */
    public static function admin_send_notification(WP_REST_Request $request)
    {
        $target = $request->get_param('target');
        $title_ar = $request->get_param('title_ar');
        $body_ar = $request->get_param('body_ar');
        $user_id = $request->get_param('user_id');
        $device_id = $request->get_param('device_id');
        $type = $request->get_param('type');

        switch ($target) {
            case 'broadcast':
                // Send to all customers (this is a simple implementation)
                $count = Lexi_Notifications::broadcast_customer($type, $title_ar, $body_ar);
                break;

            case 'all_admins':
                Lexi_Notifications::notify_admins($type, $title_ar, $body_ar);
                $count = 1; // Arbitrary since it fanned out
                break;

            case 'specific_user':
                if (!$user_id) {
                    return new WP_Error('missing_user_id', 'يجب توفير معرف المستخدم.', ['status' => 400]);
                }
                Lexi_Notifications::notify_customer($user_id, null, $type, $title_ar, $body_ar);
                $count = 1;
                break;

            case 'specific_device':
                if (empty($device_id)) {
                    return new WP_Error('missing_device_id', 'يجب توفير معرف الجهاز.', ['status' => 400]);
                }
                Lexi_Notifications::notify_customer(null, $device_id, $type, $title_ar, $body_ar);
                $count = 1;
                break;

            default:
                return new WP_Error('invalid_target', 'هدف غير صالح.', ['status' => 400]);
        }

        return new WP_REST_Response([
            'success' => true,
            'message' => 'تم إرسال الإشعار بنجاح.',
            'data' => [
                'target' => $target,
                'count' => $count ?? 1,
            ],
        ]);
    }
}
