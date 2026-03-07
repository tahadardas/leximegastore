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
    private const LAST_MAIL_ERROR_OPTION = 'lexi_last_mail_error';

    /**
     * Register hooks.
     */
    public static function init(): void
    {
        add_filter('wp_mail_charset', array(__CLASS__, 'force_mail_charset'));
        add_action('phpmailer_init', array(__CLASS__, 'configure_phpmailer_charset'));

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
     * Force UTF-8 for all WordPress emails generated while plugin is active.
     */
    public static function force_mail_charset(): string
    {
        return 'UTF-8';
    }

    /**
     * Ensure PHPMailer uses UTF-8-safe encoding for Arabic content.
     *
     * @param mixed $phpmailer PHPMailer instance.
     */
    public static function configure_phpmailer_charset($phpmailer): void
    {
        if (!is_object($phpmailer)) {
            return;
        }

        if (property_exists($phpmailer, 'CharSet')) {
            $phpmailer->CharSet = 'UTF-8';
        }

        if (property_exists($phpmailer, 'Encoding')) {
            $current = strtolower((string) $phpmailer->Encoding);
            if ('' === $current || '8bit' === $current) {
                $phpmailer->Encoding = 'base64';
            }
        }
    }

    /**
     * Log wp_mail failures for debugging.
     *
     * @param WP_Error $error The mail error.
     */
    public static function on_wp_mail_failed($error): void
    {
        if ($error instanceof WP_Error) {
            $message = (string) $error->get_error_message();
            self::log('wp_mail FAILED: ' . $message);
            $data = $error->get_error_data();
            if (!empty($data)) {
                self::log('wp_mail error data: ' . wp_json_encode($data));
            }
            self::remember_last_mail_error($message, $data);
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
        $actions[] = 'woocommerce_order_status_pending_to_pending-verificat';
        $actions[] = 'woocommerce_order_status_pending-verification_to_processing';
        $actions[] = 'woocommerce_order_status_pending-verificat_to_processing';
        $actions[] = 'woocommerce_order_status_pending-verification_to_completed';
        $actions[] = 'woocommerce_order_status_pending-verificat_to_completed';
        $actions[] = 'woocommerce_order_status_pending-verification_to_cancelled';
        $actions[] = 'woocommerce_order_status_pending-verificat_to_cancelled';
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

        $allowed = array('pending', 'on-hold', 'pending-verification', 'pending-verificat', 'processing', 'completed');
        if (!in_array($new_status, $allowed, true)) {
            self::log("Status $new_status not in allowed list");
            return;
        }

        self::send_internal_order_email_once($order, 'status_change:' . $old_status . '->' . $new_status);
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

        self::send_internal_order_email_once($order, 'checkout_processed');
    }

    /**
     * Send internal order email once (idempotent) and mark order meta.
     *
     * @param WC_Order $order Order object.
     * @param string   $reason Debug reason for logs.
     * @return bool True when email was sent.
     */
    public static function send_internal_order_email_once(WC_Order $order, string $reason = ''): bool
    {
        $order_id = (int) $order->get_id();
        if ($order_id <= 0) {
            self::log('Order ID invalid in send_internal_order_email_once');
            return false;
        }

        if (self::was_internal_mail_sent($order)) {
            self::log("Skip duplicate internal email for Order #$order_id | reason=$reason");
            return false;
        }

        $sent = self::send_internal_order_email($order);
        if ($sent) {
            self::log("Internal email sent for Order #$order_id | reason=$reason");
            $order->update_meta_data(self::ORDER_NOTIFIED_META_KEY, current_time('mysql'));
            $order->save();
        } else {
            self::log("Internal email FAILED for Order #$order_id | reason=$reason");
        }

        return $sent;
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
        $recipients = self::resolve_recipients($settings);

        self::log("Management Emails: " . json_encode($settings['management_emails']));
        self::log("Accounting Emails: " . json_encode($settings['accounting_emails']));
        self::log("Merged Recipients: " . json_encode($recipients));

        if (empty($recipients)) {
            self::log("No recipients found, aborting.");
            return false;
        }

        $to = $recipients;
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

        $result = self::dispatch_email($to, $subject, $body);
        self::log(
            'Order email result for order #' . $order_number . ': '
            . ($result['sent'] ? 'sent' : 'failed')
            . ' | recipients=' . wp_json_encode($recipients)
            . (empty($result['error_message']) ? '' : ' | error=' . $result['error_message'])
        );
        return (bool) ($result['sent'] ?? false);
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
        $recipients = self::resolve_recipients($settings);

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

        $to = $recipients;
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

        $result = self::dispatch_email($to, $subject, $body);
        if (!empty($result['sent'])) {
            self::log("New user email sent successfully for User #$user_id");
        } else {
            self::log(
                "New user email FAILED for User #$user_id"
                . (empty($result['error_message']) ? '' : ' | error=' . $result['error_message'])
            );
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
        $recipients = self::resolve_recipients($settings);

        // Check if mail() function is available.
        $mail_available = function_exists('mail');

        // Read last lines of debug log.
        $log_file = self::get_debug_log_file();
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
            'last_mail_error' => self::get_last_mail_error(),
            'debug_log_last_30_lines' => $log_lines,
        );
    }

    /**
     * Send a test email to configured management/accounting recipients.
     *
     * @param array<string, mixed> $context Optional context values.
     * @return array{sent: bool, recipients: array, subject: string}
     */
    public static function send_test_email(array $context = array()): array
    {
        $settings = self::get_notification_settings();
        $recipients = self::resolve_recipients($settings);

        $subject = sprintf('اختبار إشعارات Lexi - %s', get_bloginfo('name'));
        $body = sprintf(
            '<div dir="rtl" style="font-family:Tahoma,Arial,sans-serif;line-height:1.8;color:#111827;">
                <h2 style="margin:0 0 8px;">رسالة اختبار إشعارات الإدارة</h2>
                <p style="margin:0 0 6px;">تم إرسال هذه الرسالة للتأكد أن نظام البريد يعمل بشكل صحيح.</p>
                <p style="margin:0 0 6px;"><strong>الموقع:</strong> %s</p>
                <p style="margin:0 0 6px;"><strong>الوقت:</strong> %s</p>
                %s
            </div>',
            esc_html(get_bloginfo('name')),
            esc_html(current_time('mysql')),
            !empty($context)
                ? '<p style="margin:0 0 6px;"><strong>سياق:</strong> '
                    . esc_html(wp_json_encode($context, JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES))
                    . '</p>'
                : ''
        );

        if (empty($recipients)) {
            self::log('Test email skipped: no recipients configured.');
            return array(
                'sent' => false,
                'error_code' => 'no_recipients',
                'error_message' => 'لا توجد عناوين بريد صالحة ضمن إعدادات الإدارة والمحاسبة.',
                'recipients' => array(),
                'subject' => $subject,
            );
        }

        $result = self::dispatch_email($recipients, $subject, $body);
        self::log(
            'Test email result: '
            . (!empty($result['sent']) ? 'sent' : 'failed')
            . ' | recipients=' . wp_json_encode($recipients)
            . (empty($result['error_message']) ? '' : ' | error=' . $result['error_message'])
        );

        return array_merge(
            array(
                'recipients' => $recipients,
                'subject' => $subject,
            ),
            $result
        );
    }

    /**
     * @param array{management_emails?: array, accounting_emails?: array} $settings
     * @return string[]
     */
    private static function resolve_recipients(array $settings): array
    {
        $management = is_array($settings['management_emails'] ?? null)
            ? $settings['management_emails']
            : array();
        $accounting = is_array($settings['accounting_emails'] ?? null)
            ? $settings['accounting_emails']
            : array();

        $recipients = array_values(array_unique(array_merge($management, $accounting)));

        // Merge WooCommerce "New Order" recipients if configured.
        $wc_new_order = get_option('woocommerce_new_order_settings', array());
        if (is_array($wc_new_order) && !empty($wc_new_order['recipient'])) {
            $recipients = array_merge(
                $recipients,
                self::sanitize_email_list((string) $wc_new_order['recipient'])
            );
        }

        // Fallback to WordPress admin email if no recipients were configured.
        if (empty($recipients)) {
            $admin_email = sanitize_email((string) get_option('admin_email', ''));
            if ('' !== $admin_email && is_email($admin_email)) {
                $recipients[] = strtolower($admin_email);
            }
        }

        return array_values(array_unique(self::sanitize_email_list($recipients)));
    }

    /**
     * Send email with resilient headers and a plain-text fallback.
     *
     * @param array<int, string> $recipients
     * @return array{sent: bool, attempts: int, recipients: array<int, string>, error_code?: string, error_message?: string}
     */
    private static function dispatch_email(array $recipients, string $subject, string $html_body): array
    {
        $sanitized_recipients = self::sanitize_email_list($recipients);
        if (empty($sanitized_recipients)) {
            return array(
                'sent' => false,
                'attempts' => 0,
                'recipients' => array(),
                'error_code' => 'no_recipients',
                'error_message' => 'لا توجد عناوين بريد صالحة للإرسال.',
            );
        }

        $safe_subject = Lexi_Text::normalize($subject);
        $safe_html_body = Lexi_Text::normalize($html_body);

        $headers = self::build_default_headers(true);
        self::clear_last_mail_error();
        $sent = (bool) wp_mail($sanitized_recipients, $safe_subject, $safe_html_body, $headers);
        if ($sent) {
            return array(
                'sent' => true,
                'attempts' => 1,
                'recipients' => $sanitized_recipients,
            );
        }

        $first_error = self::get_last_mail_error();

        // Fallback: plain text can pass stricter SMTP relays.
        $plain_body = trim(
            wp_strip_all_tags(
                str_replace(array('<br>', '<br/>', '<br />'), "\n", $safe_html_body)
            )
        );
        if ('' === $plain_body) {
            $plain_body = $safe_subject;
        }
        $plain_body = Lexi_Text::normalize($plain_body);

        self::clear_last_mail_error();
        $sent_plain = (bool) wp_mail(
            $sanitized_recipients,
            $safe_subject,
            $plain_body,
            self::build_default_headers(false)
        );
        if ($sent_plain) {
            return array(
                'sent' => true,
                'attempts' => 2,
                'recipients' => $sanitized_recipients,
            );
        }

        $second_error = self::get_last_mail_error();
        $raw_error_message = '';
        if (!empty($second_error['message'])) {
            $raw_error_message = (string) $second_error['message'];
        } elseif (!empty($first_error['message'])) {
            $raw_error_message = (string) $first_error['message'];
        }
        $error_message = self::normalize_mail_error_message($raw_error_message);

        return array(
            'sent' => false,
            'attempts' => 2,
            'recipients' => $sanitized_recipients,
            'error_code' => self::is_auth_mail_error($raw_error_message)
                ? 'smtp_auth_failed'
                : 'mail_transport_failed',
            'error_message' => $error_message,
        );
    }

    /**
     * @return array<int, string>
     */
    private static function build_default_headers(bool $html = true): array
    {
        $headers = $html ? array('Content-Type: text/html; charset=UTF-8') : array();
        $headers[] = 'MIME-Version: 1.0';

        $from_email = sanitize_email((string) get_option('admin_email', ''));
        if ('' === $from_email || !is_email($from_email)) {
            $host = (string) wp_parse_url(home_url(), PHP_URL_HOST);
            $host = preg_replace('/^www\./i', '', $host);
            if (is_string($host) && '' !== $host) {
                $candidate = 'no-reply@' . $host;
                if (is_email($candidate)) {
                    $from_email = $candidate;
                }
            }
        }

        if ('' !== $from_email && is_email($from_email)) {
            $site_name = wp_specialchars_decode((string) get_bloginfo('name'), ENT_QUOTES);
            $headers[] = 'From: ' . $site_name . ' <' . $from_email . '>';
            $headers[] = 'Reply-To: ' . $from_email;
        }

        return $headers;
    }

    /**
     * @param mixed $data
     */
    private static function remember_last_mail_error(string $message, $data = null): void
    {
        $payload = array(
            'message' => sanitize_text_field($message),
            'data' => $data,
            'time' => current_time('mysql'),
        );
        update_option(self::LAST_MAIL_ERROR_OPTION, $payload, false);
    }

    private static function clear_last_mail_error(): void
    {
        delete_option(self::LAST_MAIL_ERROR_OPTION);
    }

    /**
     * @return array<string, mixed>
     */
    private static function get_last_mail_error(): array
    {
        $raw = get_option(self::LAST_MAIL_ERROR_OPTION, array());
        return is_array($raw) ? $raw : array();
    }

    private static function get_debug_log_file(): string
    {
        return WP_CONTENT_DIR . '/plugins/lexi-api/debug-mail.log';
    }

    private static function is_auth_mail_error(string $raw): bool
    {
        $lower = strtolower($raw);
        return false !== strpos($lower, 'missing required authentication credential')
            || false !== strpos($lower, 'invalid_grant')
            || false !== strpos($lower, 'unauthorized_client')
            || false !== strpos($lower, 'oauth')
            || false !== strpos($lower, 'invalid credentials')
            || false !== strpos($lower, 'unauthenticated');
    }

    private static function normalize_mail_error_message(string $raw): string
    {
        $raw = trim((string) $raw);
        if ('' === $raw) {
            return 'فشل الإرسال عبر مزود البريد. تحقق من إعدادات SMTP.';
        }

        $decoded = json_decode($raw, true);
        if (is_array($decoded)) {
            $candidate = '';
            if (!empty($decoded['error']) && is_array($decoded['error'])) {
                $candidate = (string) ($decoded['error']['message'] ?? '');
            }
            if ('' === $candidate) {
                $candidate = (string) ($decoded['message'] ?? '');
            }
            if ('' !== trim($candidate)) {
                $raw = trim($candidate);
            }
        }

        if (self::is_auth_mail_error($raw)) {
            return 'فشل التحقق من مزود البريد (SMTP/OAuth). أعد ربط حساب البريد في إعدادات SMTP ثم أعد المحاولة.';
        }

        $clean = sanitize_text_field($raw);
        if ('' === $clean) {
            return 'فشل الإرسال عبر مزود البريد. تحقق من إعدادات SMTP.';
        }
        if (strlen($clean) > 220) {
            return substr($clean, 0, 220) . '...';
        }

        return $clean;
    }

    private static function log($msg)
    {
        $file = self::get_debug_log_file();
        $timestamp = date('Y-m-d H:i:s');
        $line = '[' . $timestamp . '] ' . $msg . "\n";

        // Keep logging non-fatal in production.
        @file_put_contents($file, $line, FILE_APPEND);
        if (defined('WP_DEBUG_LOG') && WP_DEBUG_LOG) {
            error_log('[Lexi_Emails] ' . wp_strip_all_tags((string) $msg));
        }
    }
}
