<?php
/**
 * Order routes: lookup, tracking, invoice access and ShamCash proof upload.
 *
 * @package Lexi_API
 */

defined('ABSPATH') || exit;

class Lexi_Routes_Orders
{
    /**
     * Register order routes.
     */
    public static function register(): void
    {
        $ns = LEXI_API_NAMESPACE;

        register_rest_route($ns, '/orders/lookup', array(
            array(
                'methods' => WP_REST_Server::CREATABLE,
                'callback' => array(__CLASS__, 'lookup_order'),
                'permission_callback' => array('Lexi_Security', 'public_access'),
            ),
            array(
                'methods' => WP_REST_Server::READABLE,
                'callback' => array(__CLASS__, 'lookup_order'),
                'permission_callback' => array('Lexi_Security', 'public_access'),
            ),
        ));

        register_rest_route($ns, '/orders/by-phone', array(
            array(
                'methods' => WP_REST_Server::CREATABLE,
                'callback' => array(__CLASS__, 'get_orders_by_phone'),
                'permission_callback' => array('Lexi_Security', 'public_access'),
            ),
            array(
                'methods' => WP_REST_Server::READABLE,
                'callback' => array(__CLASS__, 'get_orders_by_phone'),
                'permission_callback' => array('Lexi_Security', 'public_access'),
            ),
        ));

        register_rest_route($ns, '/orders/track', array(
            array(
                'methods' => WP_REST_Server::CREATABLE,
                'callback' => array(__CLASS__, 'track_order'),
                'permission_callback' => array('Lexi_Security', 'public_access'),
            ),
            array(
                'methods' => WP_REST_Server::READABLE,
                'callback' => array(__CLASS__, 'track_order'),
                'permission_callback' => array('Lexi_Security', 'public_access'),
            ),
        ));

        register_rest_route($ns, '/orders/(?P<id>\d+)/invoice', array(
            'methods' => WP_REST_Server::READABLE,
            'callback' => array(__CLASS__, 'get_invoice'),
            'permission_callback' => array('Lexi_Security', 'public_access'),
            'args' => array(
                'id' => array('required' => true, 'sanitize_callback' => 'absint'),
                'type' => array('default' => '', 'sanitize_callback' => 'sanitize_text_field'),
                'phone' => array('default' => '', 'sanitize_callback' => 'sanitize_text_field'),
            ),
        ));

        register_rest_route($ns, '/payments/shamcash/proof', array(
            'methods' => WP_REST_Server::CREATABLE,
            'callback' => array(__CLASS__, 'upload_proof'),
            'permission_callback' => array('Lexi_Security', 'public_access'),
        ));

        register_rest_route($ns, '/invoices/render', array(
            'methods' => WP_REST_Server::READABLE,
            'callback' => array(__CLASS__, 'render_invoice'),
            'permission_callback' => array('Lexi_Security', 'public_access'),
        ));

        register_rest_route($ns, '/invoices/verify', array(
            'methods' => WP_REST_Server::READABLE,
            'callback' => array(__CLASS__, 'verify_invoice'),
            'permission_callback' => array('Lexi_Security', 'public_access'),
            'args' => array(
                'order_id' => array('required' => true, 'sanitize_callback' => 'absint'),
                'sig' => array('required' => true, 'sanitize_callback' => 'sanitize_text_field'),
            ),
        ));

        register_rest_route($ns, '/orders/(?P<id>\d+)/attach-device', array(
            'methods' => WP_REST_Server::CREATABLE,
            'callback' => array(__CLASS__, 'attach_device_to_order'),
            'permission_callback' => array('Lexi_Security', 'public_access'),
            'args' => array(
                'id' => array('required' => true, 'sanitize_callback' => 'absint'),
                'device_id' => array('required' => true, 'sanitize_callback' => 'sanitize_text_field'),
            ),
        ));
    }

    /**
     * POST /orders/{id}/attach-device
     */
    public static function attach_device_to_order(WP_REST_Request $request): WP_REST_Response
    {
        $order_id = (int) $request->get_param('id');
        $body = (array) $request->get_json_params();
        $device_id = trim(sanitize_text_field((string) ($body['device_id'] ?? '')));

        if ($order_id <= 0) {
            return Lexi_Security::error('invalid_order_id', 'رقم الطلب غير صالح.', 422);
        }

        $order = wc_get_order($order_id);
        if (!$order) {
            return Lexi_Security::error('order_not_found', 'الطلب غير موجود.', 404);
        }

        if ('' === $device_id) {
             return Lexi_Security::error('missing_device_id', 'معرف الجهاز مطلوب.', 422);
        }

        // Check if device ID is already attached to avoid redundant updates
        $existing = $order->get_meta('_lexi_device_id');
        if ($existing !== $device_id) {
            $order->update_meta_data('_lexi_device_id', $device_id);
            $order->save();
        }

        return Lexi_Security::success(array(
            'order_id' => $order_id,
            'device_id' => $device_id,
            'message' => 'تم ربط الجهاز بالطلب بنجاح.',
        ));
    }

    /**
     * POST /orders/lookup
     */
    public static function lookup_order(WP_REST_Request $request): WP_REST_Response
    {
        $body = (array) $request->get_json_params();
        $phone = Lexi_Security::sanitize_phone((string) ($body['phone'] ?? $request->get_param('phone') ?? ''));
        $order_id = self::resolve_order_id($body);
        if ($order_id <= 0) {
            $order_id = absint((int) $request->get_param('order_id'));
        }

        if ('' === $phone) {
            return Lexi_Security::error('missing_phone', 'رقم الهاتف مطلوب.', 422);
        }

        if ($order_id <= 0) {
            return self::get_orders_by_phone($request);
        }

        $order = wc_get_order($order_id);
        if (!$order) {
            return Lexi_Security::error('order_not_found', 'الطلب غير موجود.', 404);
        }

        if (!self::is_phone_match($order, $phone)) {
            return Lexi_Security::error('phone_mismatch', 'بيانات الطلب غير صحيحة.', 403);
        }

        return Lexi_Security::success(self::format_order($order));
    }

    /**
     * POST /orders/by-phone
     */
    public static function get_orders_by_phone(WP_REST_Request $request): WP_REST_Response
    {
        $body = (array) $request->get_json_params();
        $phone = Lexi_Security::sanitize_phone((string) ($body['phone'] ?? $request->get_param('phone') ?? ''));

        if ('' === $phone) {
            return Lexi_Security::error('missing_phone', 'رقم الهاتف مطلوب.', 422);
        }

        $orders = wc_get_orders(array(
            'limit' => -1,
            'orderby' => 'date',
            'order' => 'DESC',
            'return' => 'objects',
        ));

        $items = array();
        foreach ($orders as $order) {
            if (!($order instanceof WC_Order)) {
                continue;
            }
            if (!self::is_phone_match($order, $phone)) {
                continue;
            }
            $items[] = self::format_order($order);
        }

        $incomplete_items = array_values(array_filter($items, function ($item) {
            $status = is_array($item) ? (string) ($item['status'] ?? '') : '';
            return self::is_incomplete_status($status);
        }));

        return Lexi_Security::success(array(
            'phone' => $phone,
            'total' => count($items),
            'incomplete_count' => count($incomplete_items),
            'items' => $items,
            'incomplete_items' => $incomplete_items,
        ));
    }

    /**
     * POST /orders/track
     */
    public static function track_order(WP_REST_Request $request): WP_REST_Response
    {
        $body = (array) $request->get_json_params();
        $order_id = absint($body['order_id'] ?? $request->get_param('order_id') ?? 0);
        $phone = Lexi_Security::sanitize_phone((string) ($body['phone'] ?? $request->get_param('phone') ?? ''));

        if ($order_id <= 0 || '' === $phone) {
            return Lexi_Security::error('missing_fields', 'رقم الطلب ورقم الهاتف مطلوبان.', 422);
        }

        $order = wc_get_order($order_id);
        if (!$order) {
            return Lexi_Security::error('order_not_found', 'الطلب غير موجود.', 404);
        }

        if (!self::is_phone_match($order, $phone)) {
            return Lexi_Security::error('phone_mismatch', 'بيانات الطلب غير صحيحة.', 403);
        }

        $status = self::normalize_public_status((string) $order->get_status());
        $decision = strtolower(trim((string) $order->get_meta('_lexi_decision')));
        if ('' === $decision) {
            if (in_array($status, array('processing', 'completed'), true)) {
                $decision = 'approved';
            } elseif (in_array($status, array('cancelled', 'failed'), true)) {
                $decision = 'rejected';
            } else {
                $decision = 'pending';
            }
        }

        return Lexi_Security::success(array(
            'order_id' => (int) $order->get_id(),
            'order_number' => (string) $order->get_order_number(),
            'status' => $status,
            'status_label_ar' => self::status_label_ar($status),
            'last_decision' => $decision,
            'admin_note_ar' => (string) $order->get_meta('_lexi_admin_note_ar'),
            'timeline' => Lexi_Notifications::get_timeline($order),
            'inbox' => Lexi_Notifications::get_customer_inbox($order),
        ));
    }

    /**
     * GET /orders/{id}/invoice
     */
    public static function get_invoice(WP_REST_Request $request): WP_REST_Response
    {
        $order_id = (int) $request->get_param('id');
        $phone = Lexi_Security::sanitize_phone((string) $request->get_param('phone'));
        $requested_type = sanitize_text_field((string) $request->get_param('type'));

        $order = wc_get_order($order_id);
        if (!$order) {
            return Lexi_Security::error('order_not_found', 'الطلب غير موجود.', 404);
        }

        $type = in_array($requested_type, array('provisional', 'final'), true)
            ? $requested_type
            : Lexi_Invoices::resolve_type($order);

        if (!current_user_can('manage_woocommerce')) {
            if ('' !== $phone) {
                if (!self::is_phone_match($order, $phone)) {
                    return Lexi_Security::error('phone_mismatch', 'بيانات الطلب غير صحيحة.', 403);
                }
            } else {
                if ('final' === $type) {
                    return Lexi_Security::error('phone_required', 'رقم الهاتف مطلوب للوصول إلى الفاتورة النهائية.', 422);
                }
                $type = 'provisional';
            }
        }

        if ('final' === $type && !in_array($order->get_status(), array('processing', 'completed'), true)) {
            return Lexi_Security::error('invoice_not_ready', 'الفاتورة النهائية غير متاحة حالياً.', 403);
        }

        $url = Lexi_Invoices::get_signed_url($order_id, $type);

        return Lexi_Security::success(array(
            'invoice_url' => $url,
            'url' => $url,
            'invoice_type' => $type,
            'verification_url' => Lexi_Invoices::get_verification_url($order),
        ));
    }

    /**
     * POST /payments/shamcash/proof
     */
    public static function upload_proof(WP_REST_Request $request): WP_REST_Response
    {
        $order_id = absint($request->get_param('order_id'));
        $phone = Lexi_Security::sanitize_phone((string) $request->get_param('phone'));
        $note = sanitize_textarea_field((string) $request->get_param('note'));

        if ($order_id <= 0 || '' === $phone) {
            return Lexi_Security::error('missing_fields', 'رقم الطلب ورقم الهاتف مطلوبان.', 422);
        }

        $order = wc_get_order($order_id);
        if (!$order) {
            return Lexi_Security::error('order_not_found', 'الطلب غير موجود.', 404);
        }

        if (!self::is_phone_match($order, $phone)) {
            return Lexi_Security::error('phone_mismatch', 'بيانات الطلب غير صحيحة.', 403);
        }

        $saved_method = strtolower(trim((string) $order->get_meta('_lexi_payment_method')));
        if ('' === $saved_method) {
            $saved_method = strtolower(trim((string) $order->get_payment_method()));
        }
        $saved_method = str_replace('-', '_', $saved_method);
        if (!in_array($saved_method, array('sham_cash', 'shamcash'), true)) {
            return Lexi_Security::error('invalid_payment_method', 'هذا الطلب لا يقبل رفع إيصال شام كاش.', 422);
        }

        $status = strtolower((string) $order->get_status());
        if (0 === strpos($status, 'wc-')) {
            $status = substr($status, 3);
        }
        $status = str_replace('_', '-', $status);
        if (!in_array($status, array('pending-verification', 'pending-verificat', 'on-hold', 'pending'), true)) {
            return Lexi_Security::error('invalid_status', 'هذا الطلب لا يحتاج إلى إثبات دفع.', 422);
        }

        $files = $request->get_file_params();
        if (empty($files['proof_image'])) {
            return Lexi_Security::error('no_file', 'يرجى رفع صورة إثبات الدفع.', 422);
        }

        $file = $files['proof_image'];
        $allowed_types = array('image/jpeg', 'image/png', 'image/webp', 'image/gif');
        if (!in_array((string) $file['type'], $allowed_types, true)) {
            return Lexi_Security::error('invalid_file_type', 'نوع الملف غير مسموح.', 422);
        }
        if ((int) $file['size'] > 5 * 1024 * 1024) {
            return Lexi_Security::error('file_too_large', 'حجم الملف كبير جداً. الحد الأقصى 5 ميغا.', 422);
        }

        require_once ABSPATH . 'wp-admin/includes/image.php';
        require_once ABSPATH . 'wp-admin/includes/file.php';
        require_once ABSPATH . 'wp-admin/includes/media.php';

        $upload = wp_handle_upload($file, array('test_form' => false));
        if (isset($upload['error'])) {
            return Lexi_Security::error('upload_failed', 'تعذر رفع صورة الإيصال حالياً.', 500);
        }

        $attachment = array(
            'post_mime_type' => $upload['type'],
            'post_title' => sprintf('إثبات دفع - طلب #%d', $order_id),
            'post_content' => '',
            'post_status' => 'inherit',
        );

        $attach_id = wp_insert_attachment($attachment, $upload['file'], $order_id);
        if (is_wp_error($attach_id)) {
            return Lexi_Security::error('attach_failed', 'تعذر حفظ صورة الإيصال.', 500);
        }

        $metadata = wp_generate_attachment_metadata($attach_id, $upload['file']);
        wp_update_attachment_metadata($attach_id, $metadata);

        $uploaded_at = (string) current_time('mysql');
        $proof_url = (string) $upload['url'];

        $order->update_meta_data('_lexi_shamcash_proof_attachment_id', (int) $attach_id);
        $order->update_meta_data('_lexi_shamcash_proof_url', $proof_url);
        $order->update_meta_data('_lexi_shamcash_proof_uploaded_at', $uploaded_at);
        if ('' !== $note) {
            $order->update_meta_data('_lexi_shamcash_proof_note', $note);
        }

        // Backward compatibility keys.
        $order->update_meta_data('_lexi_payment_proof_id', (int) $attach_id);
        $order->update_meta_data('_lexi_payment_proof_url', $proof_url);
        $order->update_meta_data('_lexi_payment_proof_date', $uploaded_at);
        if ('' !== $note) {
            $order->update_meta_data('_lexi_payment_proof_note', $note);
        }

        // Keep internal status short and stable in Woo.
        if ('on-hold' !== $status) {
            $order->set_status('on-hold', 'تم رفع إيصال شام كاش وبانتظار التحقق.');
        }
        $order->update_meta_data('_lexi_decision', 'pending');
        $order->add_order_note('تم إرسال إيصال شام كاش وبانتظار مراجعة الإدارة.');
        $order->save();

        Lexi_Notifications::append_timeline(
            $order,
            'proof_uploaded',
            'تم إرسال الإيصال وبانتظار التحقق.'
        );
        Lexi_Notifications::notify_admin_shamcash_proof_uploaded($order, $proof_url);

        return Lexi_Security::success(array(
            'status' => 'pending-verification',
            'message_ar' => 'تم إرسال الإيصال وبانتظار التحقق',
            'payment_proof' => array(
                'attachment_id' => (int) $attach_id,
                'image_url' => $proof_url,
                'uploaded_at' => $uploaded_at,
            ),
        ), 201);
    }

    /**
     * GET /invoices/render
     */
    public static function render_invoice(WP_REST_Request $request): WP_REST_Response
    {
        $verify = Lexi_Security::verify_signed_request($request);
        if ($verify instanceof WP_REST_Response) {
            return $verify;
        }

        $order_id = absint($request->get_param('order_id'));
        $type = sanitize_text_field((string) $request->get_param('type'));
        if (!in_array($type, array('provisional', 'final'), true)) {
            $type = 'provisional';
        }

        $html = Lexi_Invoices::render_html($order_id, $type);
        return self::html_response($html);
    }

    /**
     * GET /invoices/verify
     */
    public static function verify_invoice(WP_REST_Request $request): WP_REST_Response
    {
        $order_id = absint($request->get_param('order_id'));
        $sig = sanitize_text_field((string) $request->get_param('sig'));

        if (!$order_id || '' === trim($sig)) {
            return self::html_response(
                self::render_verification_html(false, null, 'رابط التحقق غير صالح.'),
                403
            );
        }

        $order = wc_get_order($order_id);
        if (!$order) {
            return self::html_response(
                self::render_verification_html(false, null, 'الفاتورة غير موجودة.'),
                404
            );
        }

        if (!Lexi_Invoices::verify_signature($order, $sig)) {
            return self::html_response(
                self::render_verification_html(false, null, 'فشل التحقق من توقيع الفاتورة.'),
                403
            );
        }

        return self::html_response(self::render_verification_html(true, $order));
    }

    /**
     * Return an HTML response from REST callback.
     */
    private static function html_response(string $html, int $status = 200): WP_REST_Response
    {
        $response = new WP_REST_Response(null, $status);
        $response->header('Content-Type', 'text/html; charset=utf-8');
        $response->set_data($html);

        add_filter('rest_pre_serve_request', function ($served, $result) use ($html, $status) {
            if ($result->get_data() === $html) {
                status_header($status);
                header('Content-Type: text/html; charset=utf-8');
                echo $html; // phpcs:ignore WordPress.Security.EscapeOutput.OutputNotEscaped
                return true;
            }
            return $served;
        }, 10, 2);

        return $response;
    }

    /**
     * Render invoice verification page.
     */
    private static function render_verification_html(bool $is_valid, ?WC_Order $order = null, string $message = ''): string
    {
        $title = $is_valid ? 'تم التحقق من الفاتورة' : 'تعذر التحقق من الفاتورة';
        $status_text = $is_valid ? 'فاتورة صحيحة ومعتمدة' : ($message ?: 'تعذر التحقق من الفاتورة.');
        $accent = $is_valid ? '#16a34a' : '#dc2626';
        $order_block = '';

        if ($is_valid && $order instanceof WC_Order) {
            $created = $order->get_date_created();
            $date = $created ? $created->date_i18n('Y-m-d H:i') : '--';
            $order_block = sprintf(
                "<div class='details'>
                    <div class='row'><span>رقم الطلب</span><strong>#%s</strong></div>
                    <div class='row'><span>الحالة</span><strong>%s</strong></div>
                    <div class='row'><span>الإجمالي</span><strong>%s SYP</strong></div>
                    <div class='row'><span>التاريخ</span><strong>%s</strong></div>
                </div>",
                esc_html((string) $order->get_order_number()),
                esc_html((string) wc_get_order_status_name($order->get_status())),
                esc_html((string) wc_format_decimal($order->get_total(), 2)),
                esc_html((string) $date)
            );
        }

        return "<!DOCTYPE html>
<html dir='rtl' lang='ar'>
<head>
    <meta charset='UTF-8'>
    <meta name='viewport' content='width=device-width, initial-scale=1.0'>
    <title>{$title}</title>
    <style>
        * { box-sizing: border-box; }
        body { margin: 0; background: #f3f4f6; font-family: 'Segoe UI', Tahoma, Arial, sans-serif; color: #111827; direction: rtl; }
        .wrap { max-width: 620px; margin: 32px auto; background: #fff; border-radius: 14px; overflow: hidden; box-shadow: 0 8px 28px rgba(0,0,0,0.08); }
        .head { padding: 24px; background: #111827; color: #fff; border-bottom: 4px solid #f5e400; }
        .head h1 { margin: 0; font-size: 24px; }
        .body { padding: 24px; }
        .badge { display: inline-block; background: {$accent}; color: #fff; border-radius: 20px; padding: 6px 14px; font-size: 13px; font-weight: 700; margin-bottom: 14px; }
        .status { font-size: 18px; font-weight: 700; margin: 0 0 14px; color: {$accent}; }
        .details { border: 1px solid #e5e7eb; border-radius: 10px; padding: 14px; background: #fafafa; }
        .row { display: flex; justify-content: space-between; gap: 12px; padding: 8px 0; border-bottom: 1px dashed #e5e7eb; }
        .row:last-child { border-bottom: 0; }
        .row span { color: #6b7280; }
        .foot { padding: 16px 24px; color: #6b7280; font-size: 12px; border-top: 1px solid #e5e7eb; background: #fcfcfc; }
    </style>
</head>
<body>
    <div class='wrap'>
        <div class='head'>
            <h1>" . esc_html(get_bloginfo('name')) . "</h1>
        </div>
        <div class='body'>
            <div class='badge'>{$title}</div>
            <p class='status'>{$status_text}</p>
            {$order_block}
        </div>
        <div class='foot'>يمكنك حفظ هذه الصفحة كدليل تحقق من صحة الفاتورة.</div>
    </div>
</body>
</html>";
    }

    /**
     * Format order payload used by app and admin screens.
     */
    public static function format_order(WC_Order $order, bool $include_private_location = false): array
    {
        $items = array();
        foreach ($order->get_items() as $item) {
            $product = $item->get_product();
            $qty = (int) $item->get_quantity();
            $subtotal = (float) $item->get_subtotal();

            $items[] = array(
                'product_id' => (int) $item->get_product_id(),
                'name' => (string) $item->get_name(),
                'sku' => $product ? (string) $product->get_sku() : '',
                'qty' => $qty,
                'price' => $qty > 0 ? (float) round($subtotal / $qty, 2) : 0.0,
                'subtotal' => $subtotal,
                'total' => (float) $item->get_total(),
                'image' => $product ? (string) wp_get_attachment_image_url($product->get_image_id(), 'woocommerce_thumbnail') : '',
            );
        }

        $created = $order->get_date_created() ? $order->get_date_created()->date('c') : null;
        $payment_method = strtolower(trim((string) $order->get_meta('_lexi_payment_method')));
        if ('' === $payment_method) {
            $payment_method = strtolower(trim((string) $order->get_payment_method()));
        }
        $payment_method = str_replace('-', '_', $payment_method);
        if ('shamcash' === $payment_method) {
            $payment_method = 'sham_cash';
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
        $proof_attachment_id = (int) $order->get_meta('_lexi_shamcash_proof_attachment_id');
        if ($proof_attachment_id <= 0) {
            $proof_attachment_id = (int) $order->get_meta('_lexi_payment_proof_id');
        }
        $has_proof = '' !== $proof_url;
        $delivery_location = $include_private_location ? self::read_delivery_location($order) : null;

        $public_status = self::normalize_public_status((string) $order->get_status());

        return array(
            'id' => (int) $order->get_id(),
            'order_number' => (string) $order->get_order_number(),
            'status' => $public_status,
            'status_label_ar' => self::status_label_ar($public_status),
            'total' => (float) $order->get_total(),
            'subtotal' => (float) $order->get_subtotal(),
            'shipping_cost' => (float) $order->get_shipping_total(),
            'shipping_total' => (float) $order->get_shipping_total(),
            'payment_method' => $payment_method,
            'date' => $created,
            'date_created' => $created,
            'billing' => array(
                'first_name' => (string) $order->get_billing_first_name(),
                'last_name' => (string) $order->get_billing_last_name(),
                'phone' => (string) $order->get_billing_phone(),
                'email' => (string) $order->get_billing_email(),
                'address_1' => (string) $order->get_billing_address_1(),
                'city' => (string) $order->get_billing_city(),
            ),
            'items' => $items,
            'line_items' => $items,
            'customer_note' => (string) $order->get_customer_note(),
            'invoice_verification_url' => Lexi_Invoices::get_verification_url($order),
            'decision' => (string) $order->get_meta('_lexi_decision'),
            'delivery_location' => $delivery_location,
            'proof' => array(
                'has_proof' => $has_proof,
                'image_url' => $has_proof ? $proof_url : null,
                'uploaded_at' => $has_proof ? $proof_uploaded_at : null,
                'note' => $has_proof ? $proof_note : null,
            ),
            'payment_proof' => $has_proof ? array(
                'order_id' => (string) $order->get_id(),
                'image_url' => $proof_url,
                'attachment_id' => $proof_attachment_id,
                'uploaded_at' => $proof_uploaded_at,
                'status' => 'pending',
            ) : null,
        );
    }

    /**
     * @return array<string,mixed>|null
     */
    private static function read_delivery_location(WC_Order $order): ?array
    {
        $lat = self::meta_float_or_null($order->get_meta('_lexi_delivery_lat'));
        $lng = self::meta_float_or_null($order->get_meta('_lexi_delivery_lng'));
        $accuracy = self::meta_float_or_null($order->get_meta('_lexi_delivery_accuracy'));
        $full_address = trim((string) $order->get_meta('_lexi_delivery_full_address'));
        $city = trim((string) $order->get_meta('_lexi_delivery_city'));
        $area = trim((string) $order->get_meta('_lexi_delivery_area'));
        $street = trim((string) $order->get_meta('_lexi_delivery_street'));
        $building = trim((string) $order->get_meta('_lexi_delivery_building'));
        $notes = trim((string) $order->get_meta('_lexi_delivery_notes'));
        $captured_at = trim((string) $order->get_meta('_lexi_delivery_captured_at'));
        $maps_open_url = trim((string) $order->get_meta('_lexi_maps_open_url'));
        $maps_navigate_url = trim((string) $order->get_meta('_lexi_maps_navigate_url'));

        if ('' === $full_address) {
            $full_address = trim((string) $order->get_billing_address_1());
        }
        if ('' === $city) {
            $city = trim((string) $order->get_billing_city());
        }

        if ('' === $maps_open_url && null !== $lat && null !== $lng) {
            $destination = self::format_coordinate($lat) . ',' . self::format_coordinate($lng);
            $maps_open_url = 'https://www.google.com/maps/search/?api=1&query=' . $destination;
        }
        if ('' === $maps_navigate_url && null !== $lat && null !== $lng) {
            $destination = self::format_coordinate($lat) . ',' . self::format_coordinate($lng);
            $maps_navigate_url = 'https://www.google.com/maps/dir/?api=1&destination=' . $destination . '&travelmode=driving';
        }

        $has_any_delivery_data =
            null !== $lat ||
            null !== $lng ||
            '' !== $full_address ||
            '' !== $city ||
            '' !== $area ||
            '' !== $street ||
            '' !== $building ||
            '' !== $notes ||
            '' !== $maps_open_url ||
            '' !== $maps_navigate_url;

        if (!$has_any_delivery_data) {
            return null;
        }

        return array(
            'lat' => $lat,
            'lng' => $lng,
            'accuracy_meters' => $accuracy,
            'full_address' => $full_address,
            'city' => $city,
            'area' => $area,
            'street' => $street,
            'building' => $building,
            'notes' => $notes,
            'captured_at' => $captured_at,
            'maps_open_url' => $maps_open_url,
            'maps_navigate_url' => $maps_navigate_url,
        );
    }

    private static function meta_float_or_null($raw): ?float
    {
        $value = trim((string) $raw);
        if ('' === $value || !is_numeric($value)) {
            return null;
        }

        return (float) $value;
    }

    private static function format_coordinate(float $value): string
    {
        return rtrim(rtrim(sprintf('%.6F', $value), '0'), '.');
    }

    /**
     * Resolve order ID from order_id or order_number.
     */
    private static function resolve_order_id(array $body): int
    {
        $order_id = absint($body['order_id'] ?? 0);
        if ($order_id > 0) {
            return $order_id;
        }

        $order_number_raw = isset($body['order_number']) ? (string) $body['order_number'] : '';
        if ('' === trim($order_number_raw)) {
            return 0;
        }

        $digits = preg_replace('/\D+/', '', $order_number_raw);
        if ('' === $digits) {
            return 0;
        }

        return absint($digits);
    }

    private static function is_phone_match(WC_Order $order, string $phone): bool
    {
        $saved = Lexi_Security::sanitize_phone((string) $order->get_meta('_lexi_phone'));
        if ('' === $saved) {
            $saved = Lexi_Security::sanitize_phone((string) $order->get_billing_phone());
        }
        return $saved === $phone;
    }

    private static function is_incomplete_status(string $status): bool
    {
        $status = self::normalize_public_status($status);
        if ('' === $status) {
            return true;
        }
        return !in_array($status, array('completed', 'cancelled', 'failed', 'refunded'), true);
    }

    private static function status_label_ar(string $status): string
    {
        $status = self::normalize_public_status($status);
        $labels = array(
            'pending' => 'قيد الانتظار',
            'processing' => 'قيد المعالجة',
            'on-hold' => 'معلّق',
            'completed' => 'مكتمل',
            'cancelled' => 'ملغي',
            'failed' => 'فاشل',
            'refunded' => 'مسترجع',
            'pending-verification' => 'بانتظار التحقق',
        );
        return $labels[$status] ?? $status;
    }

    /**
     * Normalize raw Woo status into public API status.
     *
     * Handles legacy truncated custom status (pending-verificat) caused by
     * post_status length limit.
     */
    private static function normalize_public_status(string $status): string
    {
        $status = strtolower(trim($status));
        if (0 === strpos($status, 'wc-')) {
            $status = substr($status, 3);
        }
        $status = str_replace('_', '-', $status);

        if (in_array($status, array('pending-verification', 'pending-verificat', 'on-hold'), true)) {
            return 'pending-verification';
        }

        return $status;
    }
}
