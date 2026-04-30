<?php
/**
 * Public invoice verification page (/invoice/verify/<token>) and settings.
 *
 * @package Lexi_API
 */

defined('ABSPATH') || exit;

class Lexi_Invoice_Verify
{
    private const META_TOKEN = '_invoice_verify_token';
    private const META_CREATED_AT = '_invoice_verify_created_at';

    public static function init(): void
    {
        add_action('init', array(__CLASS__, 'register_rewrite_rules'), 8);
        add_filter('query_vars', array(__CLASS__, 'register_query_vars'));
        add_action('template_redirect', array(__CLASS__, 'handle_template_redirect'), 0);

        add_action('admin_menu', array(__CLASS__, 'register_settings_page'));
        add_action('admin_init', array(__CLASS__, 'register_settings'));
    }

    public static function register_rewrite_rules(): void
    {
        add_rewrite_rule(
            '^invoice/verify/([^/]+)/?$',
            'index.php?lexi_invoice_verify_token=$matches[1]',
            'top'
        );
    }

    /**
     * @param array<int,string> $vars
     * @return array<int,string>
     */
    public static function register_query_vars(array $vars): array
    {
        $vars[] = 'lexi_invoice_verify_token';
        return $vars;
    }

    public static function handle_template_redirect(): void
    {
        $token = get_query_var('lexi_invoice_verify_token');
        $token = is_string($token) ? trim($token) : '';
        if ('' === $token) {
            return;
        }

        $enabled = (int) get_option('lexi_invoice_verify_enabled', 1) === 1;
        if (!$enabled) {
            self::render_error_page('خدمة التحقق من الفاتورة غير مفعلة حالياً.', 404);
        }

        $order = self::get_order_by_token($token);
        if (!($order instanceof WC_Order)) {
            self::render_error_page('الفاتورة غير موجودة أو منتهية الصلاحية.', 404);
        }

        if (self::is_token_expired($order)) {
            self::render_error_page('الفاتورة غير موجودة أو منتهية الصلاحية.', 404);
        }

        self::audit_visit($order);

        $html = self::render_verification_page($order);

        status_header(200);
        header('Content-Type: text/html; charset=utf-8');
        header('X-Robots-Tag: noindex, nofollow', true);
        header('Cache-Control: no-store, no-cache, must-revalidate, max-age=0');
        header('Pragma: no-cache');
        echo $html; // phpcs:ignore WordPress.Security.EscapeOutput.OutputNotEscaped
        exit;
    }

    public static function ensure_token(WC_Order $order): string
    {
        $token = trim((string) $order->get_meta(self::META_TOKEN));
        if ('' !== $token) {
            return $token;
        }

        $token = self::generate_token();
        $order->update_meta_data(self::META_TOKEN, $token);
        $order->update_meta_data(self::META_CREATED_AT, gmdate('c'));
        $order->add_order_note('تم إنشاء رمز تحقق للفاتورة الإلكترونية.');
        $order->save();

        if (class_exists('Lexi_Delivery_Audit')) {
            Lexi_Delivery_Audit::log(
                'invoice_token_generated',
                (int) $order->get_id(),
                null,
                null,
                'success',
                'Invoice verify token generated'
            );
        }

        return $token;
    }

    public static function get_public_verify_url(WC_Order $order): string
    {
        $token = self::ensure_token($order);
        $path = '/invoice/verify/' . rawurlencode($token);
        return home_url($path);
    }

    private static function generate_token(): string
    {
        try {
            $bytes = random_bytes(32);
            $token = rtrim(strtr(base64_encode($bytes), '+/', '-_'), '=');
            return $token;
        } catch (Throwable $e) {
            // Fallback.
            return wp_generate_password(64, false, false);
        }
    }

    private static function is_token_expired(WC_Order $order): bool
    {
        $days = (int) get_option('lexi_invoice_verify_exp_days', 180);
        if ($days <= 0) {
            return false;
        }

        $created_at = trim((string) $order->get_meta(self::META_CREATED_AT));
        if ('' === $created_at) {
            // If missing timestamp, treat as not expired to avoid breaking old invoices.
            return false;
        }

        $ts = strtotime($created_at);
        if (!$ts) {
            return false;
        }

        return (time() - $ts) > ($days * DAY_IN_SECONDS);
    }

    private static function get_order_by_token(string $token): ?WC_Order
    {
        $token = trim($token);
        if ('' === $token) {
            return null;
        }

        $orders = wc_get_orders(array(
            'limit' => 1,
            'orderby' => 'date',
            'order' => 'DESC',
            'meta_query' => array(
                array(
                    'key' => self::META_TOKEN,
                    'value' => $token,
                    'compare' => '=',
                ),
            ),
        ));

        foreach ($orders as $order) {
            if ($order instanceof WC_Order) {
                return $order;
            }
        }

        return null;
    }

    private static function audit_visit(WC_Order $order): void
    {
        if (!class_exists('Lexi_Delivery_Audit')) {
            return;
        }

        $ip = '';
        if (!empty($_SERVER['REMOTE_ADDR'])) {
            $ip = sanitize_text_field(wp_unslash((string) $_SERVER['REMOTE_ADDR']));
        }

        Lexi_Delivery_Audit::log(
            'invoice_verify_visit',
            (int) $order->get_id(),
            null,
            null,
            'info',
            'Invoice verify page visited',
            array('ip' => $ip)
        );
    }

    private static function render_error_page(string $message, int $status = 404): void
    {
        status_header($status);
        header('Content-Type: text/html; charset=utf-8');
        header('X-Robots-Tag: noindex, nofollow', true);
        header('Cache-Control: no-store, no-cache, must-revalidate, max-age=0');
        header('Pragma: no-cache');

        $title = 'تعذر التحقق';
        echo self::render_shell($title, "<p style='margin:0;color:#dc2626;font-weight:700;'>" . esc_html($message) . "</p>"); // phpcs:ignore WordPress.Security.EscapeOutput.OutputNotEscaped
        exit;
    }

    private static function render_verification_page(WC_Order $order): string
    {
        $status = (string) $order->get_status();
        $status_label = (string) wc_get_order_status_name($status);
        $delivered = in_array($status, array('completed'), true);

        $order_number = (string) $order->get_order_number();
        $created = $order->get_date_created();
        $order_date = $created ? $created->date_i18n('Y-m-d H:i') : '--';

        $total = (string) wc_format_decimal($order->get_total(), 2);
        $shipping = (string) wc_format_decimal($order->get_shipping_total(), 2);
        $subtotal = (string) wc_format_decimal($order->get_subtotal(), 2);

        $payment_title = (string) $order->get_payment_method_title();

        $show_items = (int) get_option('lexi_invoice_verify_show_items', 1) === 1;
        $name_mode = (string) get_option('lexi_invoice_verify_customer_name', 'masked');
        $phone_mode = (string) get_option('lexi_invoice_verify_customer_phone', 'masked');
        $show_courier_name = (int) get_option('lexi_invoice_verify_show_courier_name', 1) === 1;
        $show_courier_phone = (int) get_option('lexi_invoice_verify_show_courier_phone', 0) === 1;

        $customer_name = trim((string) $order->get_billing_first_name() . ' ' . (string) $order->get_billing_last_name());
        $customer_phone = trim((string) $order->get_billing_phone());

        $customer_name = self::mask_name($customer_name, $name_mode);
        $customer_phone = self::mask_phone($customer_phone, $phone_mode);

        $cod_expected = (string) wc_format_decimal($order->get_total(), 2);
        $cod_status = strtolower(trim((string) $order->get_meta('_lexi_cod_collected_status')));
        $cod_collected_amount = trim((string) $order->get_meta('_lexi_cod_collected_amount'));
        $cod_collected_at = trim((string) $order->get_meta('_lexi_cod_collected_at'));

        $cod_collected_amount = '' !== $cod_collected_amount ? (string) wc_format_decimal($cod_collected_amount, 2) : '';

        $courier_id = (int) $order->get_meta('_lexi_delivery_agent_id');
        $courier = $courier_id > 0 ? get_user_by('id', $courier_id) : null;
        $courier_name = ($courier instanceof WP_User) ? (string) $courier->display_name : '';
        $courier_phone = ($courier instanceof WP_User)
            ? (string) get_user_meta((int) $courier->ID, 'billing_phone', true)
            : '';

        $courier_phone = self::mask_phone($courier_phone, $show_courier_phone ? 'masked' : 'off');

        $items_html = '';
        if ($show_items) {
            foreach ($order->get_items() as $item) {
                $qty = (int) $item->get_quantity();
                $line_total = (string) wc_format_decimal($item->get_total(), 2);
                $name = Lexi_Order_Flow::format_order_item_name($item);
                $items_html .= '<div class="item"><span>' . esc_html($name) . '</span><strong>' . esc_html($qty . ' × ' . $line_total . ' SYP') . '</strong></div>';
            }
            if ('' === $items_html) {
                $items_html = '<div class="muted">لا توجد عناصر.</div>';
            }
        }

        $badge = $delivered ? "<div class='badge ok'>تم التسليم</div>" : "<div class='badge warn'>لم يتم التسليم بعد</div>";

        $courier_block = '';
        if ($show_courier_name && '' !== $courier_name) {
            $courier_block .= "<div class='row'><span>مندوب التوصيل</span><strong>" . esc_html($courier_name) . "</strong></div>";
            if ($show_courier_phone && '' !== $courier_phone) {
                $courier_block .= "<div class='row'><span>هاتف المندوب</span><strong>" . esc_html($courier_phone) . "</strong></div>";
            }
        }

        $cod_block = "<div class='row'><span>المبلغ المطلوب (COD)</span><strong>" . esc_html($cod_expected) . " SYP</strong></div>";
        if ('confirmed' === $cod_status && '' !== $cod_collected_amount) {
            $cod_block .= "<div class='row'><span>المبلغ المحصّل</span><strong>" . esc_html($cod_collected_amount) . " SYP</strong></div>";
            if ('' !== $cod_collected_at) {
                $cod_block .= "<div class='row'><span>تاريخ التحصيل</span><strong>" . esc_html($cod_collected_at) . "</strong></div>";
            }
        } else {
            $cod_block .= "<div class='row'><span>حالة التحصيل</span><strong>غير مؤكدة</strong></div>";
        }

        $content = "
            {$badge}
            <div class='card'>
                <div class='row'><span>رقم الطلب</span><strong>#" . esc_html($order_number) . "</strong></div>
                <div class='row'><span>الحالة</span><strong>" . esc_html($status_label) . "</strong></div>
                <div class='row'><span>تاريخ الطلب</span><strong>" . esc_html($order_date) . "</strong></div>
                <div class='row'><span>طريقة الدفع</span><strong>" . esc_html($payment_title) . "</strong></div>
            </div>

            <div class='card'>
                <div class='row'><span>العميل</span><strong>" . esc_html($customer_name) . "</strong></div>
                <div class='row'><span>الهاتف</span><strong>" . esc_html($customer_phone) . "</strong></div>
            </div>

            <div class='card'>
                <div class='row'><span>المجموع الفرعي</span><strong>" . esc_html($subtotal) . " SYP</strong></div>
                <div class='row'><span>الشحن</span><strong>" . esc_html($shipping) . " SYP</strong></div>
                <div class='row grand'><span>الإجمالي</span><strong>" . esc_html($total) . " SYP</strong></div>
            </div>

            <div class='card'>
                {$cod_block}
                {$courier_block}
            </div>
        ";

        if ($show_items) {
            $content .= "<div class='card'><div class='h'>المنتجات</div>{$items_html}</div>";
        }

        return self::render_shell('التحقق من الفاتورة', $content);
    }

    private static function render_shell(string $title, string $body): string
    {
        $store = esc_html(get_bloginfo('name'));
        $title_safe = esc_html($title);

        return "<!doctype html>
<html lang='ar' dir='rtl'>
<head>
<meta charset='utf-8'>
<meta name='viewport' content='width=device-width, initial-scale=1'>
<title>{$title_safe}</title>
<style>
body{margin:0;background:#f3f4f6;font-family:Tahoma,Arial,sans-serif;color:#111827;}
.wrap{max-width:760px;margin:32px auto;padding:0 14px;}
.head{background:#111827;color:#fff;padding:18px 18px;border-radius:14px;}
.head h1{margin:0;font-size:18px;}
.card{background:#fff;border:1px solid #e5e7eb;border-radius:14px;padding:14px;margin-top:12px;}
.row{display:flex;justify-content:space-between;gap:12px;padding:8px 0;border-bottom:1px dashed #e5e7eb;}
.row:last-child{border-bottom:0;}
.row span{color:#6b7280;}
.row.grand strong{font-size:18px;}
.badge{display:inline-block;padding:6px 12px;border-radius:999px;font-weight:700;font-size:13px;}
.badge.ok{background:#16a34a;color:#fff;}
.badge.warn{background:#f59e0b;color:#111827;}
.item{display:flex;justify-content:space-between;gap:12px;padding:8px 0;border-bottom:1px solid #f3f4f6;}
.item:last-child{border-bottom:0;}
.muted{color:#6b7280;}
.h{font-weight:800;margin-bottom:6px;}
</style>
</head>
<body>
<div class='wrap'>
  <div class='head'><h1>{$store} — {$title_safe}</h1></div>
  {$body}
  <div class='card' style='color:#6b7280;font-size:12px;'>هذه الصفحة للتحقق من الفاتورة ولا يجب مشاركتها إلا عند الحاجة.</div>
</div>
</body>
</html>";
    }

    private static function mask_name(string $name, string $mode): string
    {
        $name = trim($name);
        if ('off' === $mode || '' === $name) {
            return '' === $name ? 'عميل' : $name;
        }
        if ('full' === $mode) {
            return $name;
        }

        // masked
        $parts = preg_split('/\s+/', $name);
        if (!is_array($parts) || empty($parts)) {
            return $name;
        }
        $first = (string) $parts[0];
        $last = (string) (count($parts) > 1 ? $parts[count($parts) - 1] : '');
        $last_initial = '' !== $last ? mb_substr($last, 0, 1) . '.' : '';
        return trim($first . ' ' . $last_initial);
    }

    private static function mask_phone(string $phone, string $mode): string
    {
        $phone = trim($phone);
        if ('off' === $mode || '' === $phone) {
            return '';
        }
        if ('full' === $mode) {
            return $phone;
        }

        // masked
        $digits = preg_replace('/\D+/', '', $phone);
        if (!is_string($digits) || '' === $digits) {
            return '****';
        }
        $last3 = strlen($digits) >= 3 ? substr($digits, -3) : $digits;
        return '+963****' . $last3;
    }

    public static function register_settings_page(): void
    {
        add_options_page(
            'Invoice Verification',
            'Invoice Verification',
            'manage_woocommerce',
            'lexi-invoice-verify',
            array(__CLASS__, 'render_settings_page')
        );
    }

    public static function register_settings(): void
    {
        register_setting('lexi_invoice_verify', 'lexi_invoice_verify_enabled');
        register_setting('lexi_invoice_verify', 'lexi_invoice_verify_exp_days');
        register_setting('lexi_invoice_verify', 'lexi_invoice_verify_customer_name');
        register_setting('lexi_invoice_verify', 'lexi_invoice_verify_customer_phone');
        register_setting('lexi_invoice_verify', 'lexi_invoice_verify_show_courier_name');
        register_setting('lexi_invoice_verify', 'lexi_invoice_verify_show_courier_phone');
        register_setting('lexi_invoice_verify', 'lexi_invoice_verify_show_items');

        add_settings_section('lexi_invoice_verify_main', 'Settings', '__return_null', 'lexi-invoice-verify');

        add_settings_field('lexi_invoice_verify_enabled', 'Enable', array(__CLASS__, 'field_enabled'), 'lexi-invoice-verify', 'lexi_invoice_verify_main');
        add_settings_field('lexi_invoice_verify_exp_days', 'Token expiry (days)', array(__CLASS__, 'field_exp_days'), 'lexi-invoice-verify', 'lexi_invoice_verify_main');
        add_settings_field('lexi_invoice_verify_customer_name', 'Customer name', array(__CLASS__, 'field_customer_name'), 'lexi-invoice-verify', 'lexi_invoice_verify_main');
        add_settings_field('lexi_invoice_verify_customer_phone', 'Customer phone', array(__CLASS__, 'field_customer_phone'), 'lexi-invoice-verify', 'lexi_invoice_verify_main');
        add_settings_field('lexi_invoice_verify_show_courier_name', 'Show courier name', array(__CLASS__, 'field_show_courier_name'), 'lexi-invoice-verify', 'lexi_invoice_verify_main');
        add_settings_field('lexi_invoice_verify_show_courier_phone', 'Show courier phone', array(__CLASS__, 'field_show_courier_phone'), 'lexi-invoice-verify', 'lexi_invoice_verify_main');
        add_settings_field('lexi_invoice_verify_show_items', 'Show items', array(__CLASS__, 'field_show_items'), 'lexi-invoice-verify', 'lexi_invoice_verify_main');
    }

    public static function render_settings_page(): void
    {
        echo '<div class="wrap"><h1>Invoice Verification</h1>';
        echo '<p>After changing rewrite-related settings, you may need to re-save Permalinks.</p>';
        echo '<form method="post" action="options.php">';
        settings_fields('lexi_invoice_verify');
        do_settings_sections('lexi-invoice-verify');
        submit_button();
        echo '</form></div>';
    }

    public static function field_enabled(): void
    {
        $val = (int) get_option('lexi_invoice_verify_enabled', 1);
        echo '<label><input type="checkbox" name="lexi_invoice_verify_enabled" value="1" ' . checked(1, $val, false) . '> Enabled</label>';
    }

    public static function field_exp_days(): void
    {
        $val = (int) get_option('lexi_invoice_verify_exp_days', 180);
        echo '<input type="number" min="0" name="lexi_invoice_verify_exp_days" value="' . esc_attr((string) $val) . '" /> <span class="description">0 = never</span>';
    }

    public static function field_customer_name(): void
    {
        $val = (string) get_option('lexi_invoice_verify_customer_name', 'masked');
        echo '<select name="lexi_invoice_verify_customer_name">';
        foreach (array('masked' => 'Masked', 'full' => 'Full', 'off' => 'Off') as $k => $label) {
            echo '<option value="' . esc_attr($k) . '" ' . selected($val, $k, false) . '>' . esc_html($label) . '</option>';
        }
        echo '</select>';
    }

    public static function field_customer_phone(): void
    {
        $val = (string) get_option('lexi_invoice_verify_customer_phone', 'masked');
        echo '<select name="lexi_invoice_verify_customer_phone">';
        foreach (array('masked' => 'Masked', 'full' => 'Full', 'off' => 'Off') as $k => $label) {
            echo '<option value="' . esc_attr($k) . '" ' . selected($val, $k, false) . '>' . esc_html($label) . '</option>';
        }
        echo '</select>';
    }

    public static function field_show_courier_name(): void
    {
        $val = (int) get_option('lexi_invoice_verify_show_courier_name', 1);
        echo '<label><input type="checkbox" name="lexi_invoice_verify_show_courier_name" value="1" ' . checked(1, $val, false) . '> Enabled</label>';
    }

    public static function field_show_courier_phone(): void
    {
        $val = (int) get_option('lexi_invoice_verify_show_courier_phone', 0);
        echo '<label><input type="checkbox" name="lexi_invoice_verify_show_courier_phone" value="1" ' . checked(1, $val, false) . '> Enabled</label>';
    }

    public static function field_show_items(): void
    {
        $val = (int) get_option('lexi_invoice_verify_show_items', 1);
        echo '<label><input type="checkbox" name="lexi_invoice_verify_show_items" value="1" ' . checked(1, $val, false) . '> Enabled</label>';
    }
}

// Bootstrap.
if (class_exists('Lexi_Invoice_Verify')) {
    Lexi_Invoice_Verify::init();
}
