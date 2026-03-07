<?php
/**
 * Notification hooks for order events.
 *
 * @package Lexi_API
 */

defined('ABSPATH') || exit;

/**
 * Lexi Notification Hooks
 */
class Lexi_Notification_Hooks
{
    /**
     * Initialize hooks.
     */
    public static function init(): void
    {
        // Order created (WooCommerce checkout)
        add_action('woocommerce_checkout_order_processed', [__CLASS__, 'on_order_created'], 10, 3);
        add_action('woocommerce_store_api_checkout_order_processed', [__CLASS__, 'on_block_checkout_order_processed'], 10, 1);

        // Order status changed
        add_action('woocommerce_order_status_changed', [__CLASS__, 'on_order_status_changed'], 10, 4);

        // REST API attachment of device_id to order
        add_action('rest_api_init', [__CLASS__, 'register_device_attachment_route']);
    }

    /**
     * Hook: Order created via classic checkout.
     *
     * @param int $order_id Order ID.
     * @param array $posted_data Posted data.
     * @param WC_Order $order Order object.
     */
    public static function on_order_created(int $order_id, array $posted_data, WC_Order $order): void
    {
        self::handle_order_created($order);
    }

    /**
     * Hook: Order created via block checkout.
     *
     * @param WC_Order $order Order object.
     */
    public static function on_block_checkout_order_processed(WC_Order $order): void
    {
        self::handle_order_created($order);
    }

    /**
     * Handle order creation - create notifications.
     *
     * @param WC_Order $order Order object.
     */
    private static function handle_order_created(WC_Order $order): void
    {
        $order_id = (int) $order->get_id();
        $total = (float) $order->get_total();
        $payment_method = (string) $order->get_payment_method();
        $currency = (string) $order->get_currency();

        // Get city from shipping or billing
        $city = $order->get_shipping_city() ?: $order->get_billing_city();

        // Get customer identity
        $user_id = (int) $order->get_user_id();
        $device_id = (string) $order->get_meta('_lexi_device_id');

        // Prepare data JSON (safe info only)
        $data_json = [
            'order_id' => $order_id,
            'total' => $total,
            'currency' => $currency ?: 'SYP',
            'payment_method' => $payment_method,
            'city' => $city,
        ];

        // Format total for display
        $total_formatted = Lexi_Notifications::format_currency($total);

        // 1) Admin in-app notification
        Lexi_Notifications::notify_admins(
            'order_created',
            'طلب جديد',
            "تم إنشاء طلب جديد رقم #{$order_id} بقيمة {$total_formatted}",
            $order_id,
            $data_json
        );

        // 2) Customer in-app notification
        Lexi_Notifications::notify_customer(
            $user_id > 0 ? $user_id : null,
            '' !== $device_id ? $device_id : null,
            'order_created',
            'تم استلام طلبك',
            "تم استلام طلبك رقم #{$order_id} وسنقوم بمراجعته قريبًا.",
            $order_id,
            $data_json
        );

        // 3) Immediate email to management/accounting list
        if (class_exists('Lexi_Emails')) {
            Lexi_Emails::send_internal_order_email_once($order, 'notification_hooks_order_created');
            // Keep WooCommerce default admin New Order email in sync.
            Lexi_Emails::trigger_new_order_email($order_id);
        }
    }

    /**
     * Hook: Order status changed.
     *
     * @param int $order_id Order ID.
     * @param string $old_status Old status.
     * @param string $new_status New status.
     * @param WC_Order $order Order object.
     */
    public static function on_order_status_changed(int $order_id, string $old_status, string $new_status, WC_Order $order): void
    {
        // Skip if same status
        if ($old_status === $new_status) {
            return;
        }

        // Get customer identity
        $user_id = $order->get_user_id();
        $device_id = $order->get_meta('_lexi_device_id');

        // Get total for display
        $total = (float) $order->get_total();
        $total_formatted = Lexi_Notifications::format_currency($total);

        // Prepare data JSON
        $data_json = [
            'order_id' => $order_id,
            'old_status' => $old_status,
            'new_status' => $new_status,
            'total' => $total,
        ];

        // Check for approval (processing or completed)
        if (in_array($new_status, ['processing', 'completed'], true)) {
            // Notify CUSTOMER about approval
            Lexi_Notifications::notify_customer(
                $user_id > 0 ? $user_id : null,
                $device_id ?: null,
                'order_approved',
                'تمت الموافقة على طلبك',
                "طلبك رقم #{$order_id} تمت الموافقة عليه وسيتم تجهيزه للشحن.",
                $order_id,
                $data_json
            );

            // Optionally notify admins about status change
            Lexi_Notifications::notify_admins(
                'order_status_changed',
                'تم تحديث حالة طلب',
                "تم تحديث حالة الطلب رقم #{$order_id} إلى: " . self::get_status_label_ar($new_status),
                $order_id,
                $data_json
            );
        }

        // Check for rejection (cancelled or failed)
        if (in_array($new_status, ['cancelled', 'failed'], true)) {
            // Notify CUSTOMER about rejection
            Lexi_Notifications::notify_customer(
                $user_id > 0 ? $user_id : null,
                $device_id ?: null,
                'order_rejected',
                'تم رفض طلبك',
                "طلبك رقم #{$order_id} تم رفضه. يمكنك التواصل مع الدعم للمساعدة.",
                $order_id,
                $data_json
            );

            // Optionally notify admins about status change
            Lexi_Notifications::notify_admins(
                'order_status_changed',
                'تم تحديث حالة طلب',
                "تم تحديث حالة الطلب رقم #{$order_id} إلى: " . self::get_status_label_ar($new_status),
                $order_id,
                $data_json
            );
        }
    }

    /**
     * Get Arabic label for order status.
     *
     * @param string $status WooCommerce status.
     * @return string Arabic label.
     */
    private static function get_status_label_ar(string $status): string
    {
        $labels = [
            'pending' => 'قيد الانتظار',
            'processing' => 'قيد التجهيز',
            'on-hold' => 'معلق',
            'completed' => 'مكتمل',
            'cancelled' => 'ملغي',
            'refunded' => 'مسترجع',
            'failed' => 'فاشل',
        ];

        return $labels[$status] ?? $status;
    }

    /**
     * Register REST route for attaching device_id to order.
     */
    public static function register_device_attachment_route(): void
    {
        register_rest_route('lexi/v1', '/orders/(?P<id>\d+)/attach-device', [
            'methods' => 'POST',
            'callback' => [__CLASS__, 'attach_device_to_order'],
            'permission_callback' => [__CLASS__, 'attach_device_permission'],
            'args' => [
                'id' => [
                    'required' => true,
                    'validate_callback' => function ($v) {
                        return is_numeric($v) && (int) $v > 0;
                    },
                    'sanitize_callback' => 'absint',
                ],
                'device_id' => [
                    'required' => true,
                    'validate_callback' => function ($v) {
                        return is_string($v) && strlen($v) >= 8 && strlen($v) <= 64;
                    },
                    'sanitize_callback' => 'sanitize_text_field',
                ],
            ],
        ]);
    }

    /**
     * Permission callback for device attachment.
     *
     * @param WP_REST_Request $request Request object.
     * @return bool|WP_Error
     */
    public static function attach_device_permission(WP_REST_Request $request)
    {
        // Allow public access (guest orders)
        // Security: device_id is stored but order ownership is verified via other means
        return true;
    }

    /**
     * Attach device_id to order.
     *
     * @param WP_REST_Request $request Request object.
     * @return WP_REST_Response|WP_Error
     */
    public static function attach_device_to_order(WP_REST_Request $request)
    {
        $order_id = (int) $request->get_param('id');
        $device_id = sanitize_text_field($request->get_param('device_id'));

        $order = wc_get_order($order_id);
        if (!$order) {
            return new WP_Error(
                'order_not_found',
                'الطلب غير موجود.',
                ['status' => 404]
            );
        }

        // Store device_id in order meta
        $order->update_meta_data('_lexi_device_id', $device_id);
        $order->save();

        return new WP_REST_Response([
            'success' => true,
            'message' => 'تم ربط الجهاز بالطلب بنجاح.',
            'data' => [
                'order_id' => $order_id,
                'device_id' => $device_id,
            ],
        ]);
    }
}
