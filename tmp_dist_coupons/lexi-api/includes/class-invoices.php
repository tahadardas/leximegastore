<?php
/**
 * Invoice generation: branded Arabic HTML invoices with signed URLs.
 *
 * @package Lexi_API
 */

defined('ABSPATH') || exit;

class Lexi_Invoices
{

    /**
     * Generate a signed URL for an order invoice.
     *
     * @param int    $order_id Order ID.
     * @param string $type     "provisional" or "final".
     * @return string Signed URL valid for 1 hour.
     */
    public static function get_signed_url(int $order_id, string $type = 'provisional'): string
    {
        $base_url = rest_url(LEXI_API_NAMESPACE . '/invoices/render');
        $base_url = add_query_arg(
            array(
                'order_id' => $order_id,
                'type' => $type,
            ),
            $base_url
        );

        return Lexi_Security::generate_signed_url($base_url);
    }

    /**
     * Generate a permanent verification URL for an order invoice.
     *
     * @param WC_Order $order WooCommerce order.
     * @return string Signed verification URL.
     */
    public static function get_verification_url(WC_Order $order): string
    {
        $base_url = rest_url(LEXI_API_NAMESPACE . '/invoices/verify');
        return add_query_arg(
            array(
                'order_id' => (int) $order->get_id(),
                'sig' => self::build_verification_signature($order),
            ),
            $base_url
        );
    }

    /**
     * Validate invoice verification signature.
     *
     * @param WC_Order $order WooCommerce order.
     * @param string   $sig   Signature from request.
     * @return bool
     */
    public static function verify_signature(WC_Order $order, string $sig): bool
    {
        $expected = self::build_verification_signature($order);
        return '' !== trim($sig) && hash_equals($expected, $sig);
    }

    /**
     * Build the stable HMAC used in invoice verification links.
     *
     * @param WC_Order $order WooCommerce order.
     * @return string
     */
    private static function build_verification_signature(WC_Order $order): string
    {
        $created = $order->get_date_created();
        $timestamp = $created ? (string) $created->getTimestamp() : '0';

        $payload = implode('|', array(
            'lexi_invoice_verify',
            (string) $order->get_id(),
            (string) $order->get_order_key(),
            (string) wc_format_decimal($order->get_total(), 2),
            $timestamp,
        ));

        return hash_hmac('sha256', $payload, wp_salt('auth'));
    }

    /**
     * Determine which invoice type an order is eligible for.
     *
     * @param WC_Order $order WooCommerce order.
     * @return string "final" or "provisional".
     */
    public static function resolve_type(WC_Order $order): string
    {
        $final_statuses = array('processing', 'completed');
        if (in_array($order->get_status(), $final_statuses, true)) {
            return 'final';
        }
        return 'provisional';
    }

    /**
     * Render an Arabic HTML invoice.
     *
     * @param int    $order_id Order ID.
     * @param string $type     Invoice type.
     * @return string HTML content.
     */
    public static function render_html(int $order_id, string $type): string
    {
        $order = wc_get_order($order_id);

        if (!$order) {
            return '<p>الطلب غير موجود.</p>';
        }

        $is_final = 'final' === $type;
        $title = $is_final ? 'فاتورة نهائية' : 'فاتورة مبدئية';
        $badge_color = $is_final ? '#16a34a' : '#f59e0b';
        $date = $order->get_date_created() ? $order->get_date_created()->date_i18n('Y-m-d H:i') : '';

        $items_html = '';
        foreach ($order->get_items() as $item) {
            $product = $item->get_product();
            $qty = $item->get_quantity();
            $subtotal = $item->get_subtotal();
            $name = $item->get_name();
            $sku = $product ? $product->get_sku() : '';
            $unit_price = $qty > 0 ? round($subtotal / $qty, 2) : 0;

            $items_html .= "<tr>
				<td style='padding:8px;border-bottom:1px solid #e5e7eb;'>{$name}</td>
				<td style='padding:8px;border-bottom:1px solid #e5e7eb;text-align:center;'>" . esc_html($sku) . "</td>
				<td style='padding:8px;border-bottom:1px solid #e5e7eb;text-align:center;'>{$qty}</td>
				<td style='padding:8px;border-bottom:1px solid #e5e7eb;text-align:left;'>{$unit_price} SYP</td>
				<td style='padding:8px;border-bottom:1px solid #e5e7eb;text-align:left;'>{$subtotal} SYP</td>
			</tr>";
        }

        $subtotal = $order->get_subtotal();
        $shipping = $order->get_shipping_total();
        $total = $order->get_total();
        $order_number = $order->get_order_number();
        $status_label = wc_get_order_status_name($order->get_status());
        $payment_label = $order->get_payment_method_title();

        // Billing info.
        $billing_name = $order->get_billing_first_name() . ' ' . $order->get_billing_last_name();
        $billing_phone = $order->get_billing_phone();
        $billing_addr = $order->get_billing_address_1() . ', ' . $order->get_billing_city();

        $store_name = get_bloginfo('name');

        $html = "<!DOCTYPE html>
<html dir='rtl' lang='ar'>
<head>
	<meta charset='UTF-8'>
	<meta name='viewport' content='width=device-width, initial-scale=1.0'>
	<title>{$title} - #{$order_number}</title>
	<style>
		* { margin: 0; padding: 0; box-sizing: border-box; }
		body { font-family: 'Segoe UI', Tahoma, Arial, sans-serif; background: #f3f4f6; color: #1f2937; direction: rtl; }
		.invoice { max-width: 800px; margin: 20px auto; background: #fff; border-radius: 12px; overflow: hidden; box-shadow: 0 4px 24px rgba(0,0,0,0.08); }
		.header { background: linear-gradient(135deg, #1e293b 0%, #334155 100%); color: #fff; padding: 32px; display: flex; justify-content: space-between; align-items: center; }
		.header h1 { font-size: 24px; }
		.badge { display: inline-block; padding: 4px 16px; border-radius: 20px; font-size: 13px; font-weight: 600; color: #fff; background: {$badge_color}; }
		.meta { padding: 24px 32px; background: #f8fafc; border-bottom: 1px solid #e5e7eb; display: grid; grid-template-columns: 1fr 1fr; gap: 16px; }
		.meta-item label { font-size: 12px; color: #64748b; display: block; margin-bottom: 4px; }
		.meta-item span { font-size: 14px; font-weight: 600; }
		table { width: 100%; border-collapse: collapse; }
		thead { background: #f8fafc; }
		th { padding: 10px 8px; text-align: right; font-size: 13px; color: #64748b; border-bottom: 2px solid #e5e7eb; }
		.totals { padding: 24px 32px; }
		.total-row { display: flex; justify-content: space-between; padding: 6px 0; font-size: 14px; }
		.total-row.grand { font-size: 18px; font-weight: 700; border-top: 2px solid #1e293b; padding-top: 12px; margin-top: 8px; }
		.footer { padding: 20px 32px; background: #f8fafc; text-align: center; font-size: 12px; color: #94a3b8; border-top: 1px solid #e5e7eb; }
		@media print { body { background: #fff; } .invoice { box-shadow: none; margin: 0; } }
	</style>
</head>
<body>
	<div class='invoice'>
		<div class='header'>
			<div>
				<h1>" . esc_html($store_name) . "</h1>
				<p style='margin-top:4px;opacity:0.8;font-size:14px;'>{$title}</p>
			</div>
			<div style='text-align:left;'>
				<div class='badge'>{$title}</div>
				<p style='margin-top:8px;font-size:14px;opacity:0.8;'>#{$order_number}</p>
			</div>
		</div>

		<div class='meta'>
			<div class='meta-item'><label>العميل</label><span>" . esc_html($billing_name) . "</span></div>
			<div class='meta-item'><label>الهاتف</label><span>" . esc_html($billing_phone) . "</span></div>
			<div class='meta-item'><label>العنوان</label><span>" . esc_html($billing_addr) . "</span></div>
			<div class='meta-item'><label>التاريخ</label><span>{$date}</span></div>
			<div class='meta-item'><label>الحالة</label><span>{$status_label}</span></div>
			<div class='meta-item'><label>طريقة الدفع</label><span>" . esc_html($payment_label) . "</span></div>
		</div>

		<div style='padding:24px 32px;'>
			<table>
				<thead>
					<tr>
						<th style='text-align:right;'>المنتج</th>
						<th style='text-align:center;'>SKU</th>
						<th style='text-align:center;'>الكمية</th>
						<th style='text-align:left;'>سعر الوحدة</th>
						<th style='text-align:left;'>الإجمالي</th>
					</tr>
				</thead>
				<tbody>
					{$items_html}
				</tbody>
			</table>
		</div>

		<div class='totals'>
			<div class='total-row'><span>المجموع الفرعي</span><span>{$subtotal} SYP</span></div>
			<div class='total-row'><span>الشحن</span><span>{$shipping} SYP</span></div>
			<div class='total-row grand'><span>الإجمالي</span><span>{$total} SYP</span></div>
		</div>

		<div class='footer'>
			<p>{$title} — " . esc_html($store_name) . " — {$date}</p>
			<p style='margin-top:4px;'>هذه الفاتورة تم إنشاؤها إلكترونياً ولا تحتاج إلى توقيع.</p>
		</div>
	</div>
</body>
</html>";

        return $html;
    }
}
