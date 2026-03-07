<?php
/**
 * Email helpers: ensure WooCommerce emails fire for API-created orders.
 *
 * @package Lexi_API
 */

defined('ABSPATH') || exit;

class Lexi_Emails
{
    public const OPTION_MANAGEMENT_EMAILS = 'lexi_management_emails';
    public const OPTION_ACCOUNTING_EMAILS = 'lexi_accounting_emails';
    private const ORDER_NOTIFIED_META_KEY = '_lexi_internal_mail_sent';

    /**
     * Register hooks.
     */
    public static function init(): void
    {
        // Ensure our custom status triggers emails like processing/on-hold.
        add_filter('woocommerce_email_actions', array(__CLASS__, 'register_email_actions'));

        // Send internal recipients a full order payload once when order enters
        // an actionable state.
        add_action(
            'woocommerce_order_status_changed',
            array(__CLASS__, 'maybe_send_internal_order_email'),
            20,
            4
        );

        // Fallback for storefront checkout flows.
        add_action(
            'woocommerce_checkout_order_processed',
            array(__CLASS__, 'send_internal_order_email_after_checkout'),
            20,
            1
        );

        // Capture wp_mail failures for diagnostics.
        add_action('wp_mail_failed', array(__CLASS__, 'on_wp_mail_failed'));
    }

    /**
     * Log wp_mail failures for debugging.
     *
     * @param WP_Error $error The mail error.
     */
    public static function on_wp_mail_failed($error): void
    {
        if ($error instanceof WP_Error) {
            self::log('wp_mail FAILED: ' . $error->get_error_message());
            $data = $error->get_error_data();
            if (!empty($data)) {
                self::log('wp_mail error data: ' . wp_json_encode($data));
            }
        }
    }

    /**
     * Add custom status transitions to WooCommerce email actions so admin
     * "New Order" emails are triggered for pending-verification orders too.
     *
     * @param array $actions Existing email action hooks.
     * @return array
     */
    public static function register_email_actions(array $actions): array
    {
        $actions[] = 'woocommerce_order_status_pending_to_pending-verification';
        $actions[] = 'woocommerce_order_status_pending-verification_to_processing';
        $actions[] = 'woocommerce_order_status_pending-verification_to_completed';
        $actions[] = 'woocommerce_order_status_pending-verification_to_cancelled';
        return $actions;
    }

    /**
     * Trigger the WooCommerce "New Order" admin email for a given order.
     *
     * Uses the WC_Emails class to properly send to all configured recipients
     * from WooCommerce → Settings → Emails → New Order.
     *
     * @param int $order_id WooCommerce order ID.
     */
    public static function trigger_new_order_email(int $order_id): void
    {
        // Ensure WC Emails are loaded.
        if (!class_exists('WC_Emails')) {
            WC()->mailer();
        }

        $emails = WC()->mailer()->get_emails();

        if (isset($emails['WC_Email_New_Order'])) {
            $emails['WC_Email_New_Order']->trigger($order_id);
        }
    }

    /**
     * Trigger customer "Order On-Hold" or "Processing" email.
     *
     * @param int    $order_id Order ID.
     * @param string $status   New status.
     */
    public static function trigger_customer_email(int $order_id, string $status): void
    {
        if (!class_exists('WC_Emails')) {
            WC()->mailer();
        }

        $emails = WC()->mailer()->get_emails();

        $map = array(
            'processing' => 'WC_Email_Customer_Processing_Order',
            'on-hold' => 'WC_Email_Customer_On_Hold_Order',
            'completed' => 'WC_Email_Customer_Completed_Order',
        );

        if (isset($map[$status], $emails[$map[$status]])) {
            $emails[$map[$status]]->trigger($order_id);
        }
    }

    /**
     * Send internal order email notification once when order status changes.
     *
     * @param int      $order_id   Order ID.
     * @param string   $old_status Previous status slug.
     * @param string   $new_status New status slug.
     * @param WC_Order $order      Order object.
     */
    public static function maybe_send_internal_order_email(
        int $order_id,
        string $old_status,
        string $new_status,
        $order
    ): void {
        self::log("Hook triggered: Order #$order_id changed from $old_status to $new_status");

        if (!($order instanceof WC_Order)) {
            $order = wc_get_order($order_id);
        }
        if (!($order instanceof WC_Order)) {
            self::log("Order object invalid for ID $order_id");
            return;
        }

        if (self::was_internal_mail_sent($order)) {
            self::log("Email already sent for Order #$order_id (meta key present)");
            return;
        }

        $allowed = array('pending', 'on-hold', 'pending-verification', 'processing', 'completed');
        if (!in_array($new_status, $allowed, true)) {
            self::log("Status $new_status not in allowed list");
            return;
        }

        if (self::send_internal_order_email($order)) {
            self::log("Email sent successfully for Order #$order_id");
            $order->update_meta_data(self::ORDER_NOTIFIED_META_KEY, current_time('mysql'));
            $order->save();
        } else {
            self::log("Email FAILED for Order #$order_id");
        }
    }

    /**
     * Fallback hook after storefront checkout completion.
     *
     * @param int $order_id WooCommerce order ID.
     */
    public static function send_internal_order_email_after_checkout(int $order_id): void
    {
        $order = wc_get_order($order_id);
        if (!($order instanceof WC_Order)) {
            return;
        }

        if (self::was_internal_mail_sent($order)) {
            return;
        }

        if (self::send_internal_order_email($order)) {
            $order->update_meta_data(self::ORDER_NOTIFIED_META_KEY, current_time('mysql'));
            $order->save();
        }
    }

    /**
     * Get notification settings.
     *
     * @return array{management_emails: string[], accounting_emails: string[]}
     */
    public static function get_notification_settings(): array
    {
        return array(
            'management_emails' => self::sanitize_email_list(get_option(self::OPTION_MANAGEMENT_EMAILS, array())),
            'accounting_emails' => self::sanitize_email_list(get_option(self::OPTION_ACCOUNTING_EMAILS, array())),
        );
    }

    /**
     * Save notification settings.
     *
     * @param mixed $management Raw management email list.
     * @param mixed $accounting Raw accounting email list.
     * @return array{management_emails: string[], accounting_emails: string[]}
     */
    public static function save_notification_settings($management, $accounting): array
    {
        $settings = array(
            'management_emails' => self::sanitize_email_list($management),
            'accounting_emails' => self::sanitize_email_list($accounting),
        );

        update_option(self::OPTION_MANAGEMENT_EMAILS, $settings['management_emails']);
        update_option(self::OPTION_ACCOUNTING_EMAILS, $settings['accounting_emails']);

        return $settings;
    }

    /**
     * Send a full order summary email to management/accounting recipients.
     *
     * @param WC_Order $order Order object.
     * @return bool True when email was sent.
     */
    public static function send_internal_order_email(WC_Order $order): bool
    {
        $settings = self::get_notification_settings();
        $recipients = array_values(array_unique(array_merge(
            $settings['management_emails'],
            $settings['accounting_emails']
        )));

        self::log("Management Emails: " . json_encode($settings['management_emails']));
        self::log("Accounting Emails: " . json_encode($settings['accounting_emails']));
        self::log("Merged Recipients: " . json_encode($recipients));

        if (empty($recipients)) {
            self::log("No recipients found, aborting.");
            return false;
        }

        $to = implode(',', $recipients);
        $order_number = $order->get_order_number();
        $status_label = wc_get_order_status_name($order->get_status());
        $created = $order->get_date_created();
        $created_label = $created ? $created->date_i18n('Y-m-d H:i') : current_time('mysql');
        $subject = sprintf('طلب جديد #%s - %s', $order_number, get_bloginfo('name'));

        $billing_name = trim($order->get_billing_first_name() . ' ' . $order->get_billing_last_name());
        $billing_phone = (string) $order->get_billing_phone();
        $billing_email = (string) $order->get_billing_email();
        $billing_address = trim((string) $order->get_billing_address_1() . ' - ' . (string) $order->get_billing_city());

        $items_html = '';
        foreach ($order->get_items() as $item) {
            if (!($item instanceof WC_Order_Item_Product)) {
                continue;
            }

            $qty = (int) $item->get_quantity();
            $line_total = (float) $item->get_total();
            $unit = $qty > 0 ? ($line_total / $qty) : 0;

            $items_html .= sprintf(
                '<tr>
                    <td style="padding:8px;border:1px solid #e5e7eb;">%s</td>
                    <td style="padding:8px;border:1px solid #e5e7eb;text-align:center;">%d</td>
                    <td style="padding:8px;border:1px solid #e5e7eb;text-align:left;">%s SYP</td>
                    <td style="padding:8px;border:1px solid #e5e7eb;text-align:left;">%s SYP</td>
                </tr>',
                esc_html($item->get_name()),
                $qty,
                esc_html(wc_format_decimal($unit, 2)),
                esc_html(wc_format_decimal($line_total, 2))
            );
        }

        if ('' === $items_html) {
            $items_html = '<tr><td colspan="4" style="padding:8px;border:1px solid #e5e7eb;">لا توجد عناصر ضمن الطلب.</td></tr>';
        }

        $payment_method = (string) $order->get_payment_method_title();
        $shipping_total = (float) $order->get_shipping_total();
        $subtotal = (float) $order->get_subtotal();
        $total = (float) $order->get_total();
        $customer_note = trim((string) $order->get_customer_note());

        $body = sprintf(
            '<div dir="rtl" style="font-family:Tahoma,Arial,sans-serif;line-height:1.8;color:#111827;">
                <h2 style="margin:0 0 8px;">طلب جديد #%s</h2>
                <p style="margin:0 0 14px;"><strong>التاريخ:</strong> %s</p>
                <p style="margin:0 0 6px;"><strong>الحالة:</strong> %s</p>
                <p style="margin:0 0 6px;"><strong>الدفع:</strong> %s</p>
                <hr style="border:none;border-top:1px solid #e5e7eb;margin:14px 0;">
                <h3 style="margin:0 0 8px;">بيانات العميل</h3>
                <p style="margin:0 0 4px;"><strong>الاسم:</strong> %s</p>
                <p style="margin:0 0 4px;"><strong>الهاتف:</strong> %s</p>
                <p style="margin:0 0 4px;"><strong>البريد:</strong> %s</p>
                <p style="margin:0 0 10px;"><strong>العنوان:</strong> %s</p>
                %s
                <h3 style="margin:14px 0 8px;">تفاصيل المنتجات</h3>
                <table style="width:100%%;border-collapse:collapse;">
                    <thead>
                        <tr>
                            <th style="padding:8px;border:1px solid #e5e7eb;text-align:right;background:#f9fafb;">المنتج</th>
                            <th style="padding:8px;border:1px solid #e5e7eb;text-align:center;background:#f9fafb;">الكمية</th>
                            <th style="padding:8px;border:1px solid #e5e7eb;text-align:left;background:#f9fafb;">سعر الوحدة</th>
                            <th style="padding:8px;border:1px solid #e5e7eb;text-align:left;background:#f9fafb;">الإجمالي</th>
                        </tr>
                    </thead>
                    <tbody>%s</tbody>
                </table>
                <p style="margin:12px 0 0;"><strong>المجموع الفرعي:</strong> %s SYP</p>
                <p style="margin:4px 0 0;"><strong>الشحن:</strong> %s SYP</p>
                <p style="margin:4px 0 0;font-size:16px;"><strong>الإجمالي النهائي:</strong> %s SYP</p>
            </div>',
            esc_html($order_number),
            esc_html($created_label),
            esc_html($status_label),
            esc_html($payment_method),
            esc_html($billing_name),
            esc_html($billing_phone),
            esc_html($billing_email),
            esc_html($billing_address),
            '' !== $customer_note
            ? '<p style="margin:0 0 10px;"><strong>ملاحظة العميل:</strong> ' . nl2br(esc_html($customer_note)) . '</p>'
            : '',
            $items_html,
            esc_html(wc_format_decimal($subtotal, 2)),
            esc_html(wc_format_decimal($shipping_total, 2)),
            esc_html(wc_format_decimal($total, 2))
        );

        $headers = array('Content-Type: text/html; charset=UTF-8');
        return (bool) wp_mail($to, $subject, $body, $headers);
    }

    /**
     * Convert mixed email list input to unique valid emails.
     *
     * @param mixed $raw Raw value from request or options.
     * @return string[]
     */
    private static function sanitize_email_list($raw): array
    {
        $items = array();
        if (is_string($raw)) {
            $items = preg_split('/[\s,;]+/', $raw) ?: array();
        } elseif (is_array($raw)) {
            $items = $raw;
        }

        $clean = array();
        foreach ($items as $item) {
            $email = sanitize_email((string) $item);
            if ('' !== $email && is_email($email)) {
                $clean[] = strtolower($email);
            }
        }

        return array_values(array_unique($clean));
    }

    /**
     * Check whether internal order email has already been sent.
     */
    private static function was_internal_mail_sent(WC_Order $order): bool
    {
        return '' !== trim((string) $order->get_meta(self::ORDER_NOTIFIED_META_KEY));
    }

    /**
     * Send email to management/accounting when a new user registers.
     *
     * @param int $user_id The newly registered user ID.
     */
    public static function send_new_user_email(int $user_id): void
    {
        $settings = self::get_notification_settings();
        $recipients = array_values(array_unique(array_merge(
            $settings['management_emails'],
            $settings['accounting_emails']
        )));

        self::log("New user registration: User #$user_id");
        self::log("Recipients for new user email: " . json_encode($recipients));

        if (empty($recipients)) {
            self::log("No recipients found for new user email, aborting.");
            return;
        }

        $user = get_userdata($user_id);
        if (!$user) {
            self::log("Could not get user data for User #$user_id");
            return;
        }

        $display_name = trim($user->display_name);
        if ('' === $display_name) {
            $display_name = trim($user->first_name . ' ' . $user->last_name);
        }
        if ('' === $display_name) {
            $display_name = $user->user_login;
        }

        $email = (string) $user->user_email;
        $phone = get_user_meta($user_id, 'billing_phone', true);
        $registered = $user->user_registered;
        $site_name = get_bloginfo('name');

        $to = implode(',', $recipients);
        $subject = sprintf('مستخدم جديد: %s - %s', $display_name, $site_name);

        $body = sprintf(
            '<div dir="rtl" style="font-family:Tahoma,Arial,sans-serif;line-height:1.8;color:#111827;">
                <h2 style="margin:0 0 12px;">تسجيل مستخدم جديد</h2>
                <p style="margin:0 0 6px;"><strong>الاسم:</strong> %s</p>
                <p style="margin:0 0 6px;"><strong>البريد الإلكتروني:</strong> %s</p>
                <p style="margin:0 0 6px;"><strong>الهاتف:</strong> %s</p>
                <p style="margin:0 0 6px;"><strong>تاريخ التسجيل:</strong> %s</p>
                <hr style="border:none;border-top:1px solid #e5e7eb;margin:14px 0;">
                <p style="color:#6b7280;font-size:13px;">هذا إشعار تلقائي من %s</p>
            </div>',
            esc_html($display_name),
            esc_html($email),
            esc_html($phone ?: 'غير محدد'),
            esc_html($registered),
            esc_html($site_name)
        );

        $headers = array('Content-Type: text/html; charset=UTF-8');
        $sent = wp_mail($to, $subject, $body, $headers);

        if ($sent) {
            self::log("New user email sent successfully for User #$user_id");
        } else {
            self::log("New user email FAILED for User #$user_id");
        }
    }

    /**
     * Get email diagnostics info for troubleshooting.
     *
     * @return array Diagnostic data.
     */
    public static function get_diagnostics(): array
    {
        $settings = self::get_notification_settings();
        $recipients = array_values(array_unique(array_merge(
            $settings['management_emails'],
            $settings['accounting_emails']
        )));

        // Check if mail() function is available.
        $mail_available = function_exists('mail');

        // Read last lines of debug log.
        $log_file = WP_CONTENT_DIR . '/plugins/lexi-api/debug-mail.log';
        $log_lines = array();
        if (file_exists($log_file)) {
            $all_lines = file($log_file, FILE_IGNORE_NEW_LINES | FILE_SKIP_EMPTY_LINES);
            if (is_array($all_lines)) {
                $log_lines = array_slice($all_lines, -30);
            }
        }

        // Check SMTP plugin status.
        $smtp_plugins = array(
            'wp-mail-smtp/wp_mail_smtp.php' => 'WP Mail SMTP',
            'fluent-smtp/fluent-smtp.php' => 'FluentSMTP',
            'post-smtp/postman-smtp.php' => 'Post SMTP',
            'easy-wp-smtp/easy-wp-smtp.php' => 'Easy WP SMTP',
        );
        $active_smtp = array();
        $active_plugins = (array) get_option('active_plugins', array());
        foreach ($smtp_plugins as $plugin_file => $name) {
            if (in_array($plugin_file, $active_plugins, true)) {
                $active_smtp[] = $name;
            }
        }

        return array(
            'management_emails' => $settings['management_emails'],
            'accounting_emails' => $settings['accounting_emails'],
            'merged_recipients' => $recipients,
            'php_mail_available' => $mail_available,
            'smtp_plugin_active' => !empty($active_smtp),
            'smtp_plugins' => $active_smtp,
            'debug_log_last_30_lines' => $log_lines,
        );
    }

    private static function log($msg)
    {
        $file = WP_CONTENT_DIR . '/plugins/lexi-api/debug-mail.log';
        $timestamp = date('Y-m-d H:i:s');
        file_put_contents($file, "[$timestamp] $msg\n", FILE_APPEND);
    }
}
