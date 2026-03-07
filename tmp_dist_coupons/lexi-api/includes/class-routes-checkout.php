<?php
/**
 * Checkout REST routes: create Woo orders from Flutter checkout wizard.
 *
 * @package Lexi_API
 */

defined('ABSPATH') || exit;

class Lexi_Routes_Checkout
{
    private const LOG_SOURCE = 'lexi-api';

    /**
     * Register checkout routes.
     */
    public static function register(): void
    {
        register_rest_route(LEXI_API_NAMESPACE, '/checkout/create-order', array(
            'methods' => WP_REST_Server::CREATABLE,
            'callback' => array(__CLASS__, 'create_order'),
            'permission_callback' => array('Lexi_Security', 'public_access'),
        ));

        // Backward-compatible route used by older app builds.
        register_rest_route(LEXI_API_NAMESPACE, '/checkout/guest', array(
            'methods' => WP_REST_Server::CREATABLE,
            'callback' => array(__CLASS__, 'guest_checkout'),
            'permission_callback' => array('Lexi_Security', 'public_access'),
        ));
    }

    /**
     * POST /checkout/create-order
     */
    public static function create_order(WP_REST_Request $request): WP_REST_Response
    {
        $body = (array) $request->get_json_params();
        return self::create_order_from_payload($body);
    }

    /**
     * POST /checkout/guest (legacy input adapter)
     */
    public static function guest_checkout(WP_REST_Request $request): WP_REST_Response
    {
        $legacy = (array) $request->get_json_params();
        $payload = self::map_legacy_payload($legacy);
        return self::create_order_from_payload($payload);
    }

    private static function create_order_from_payload(array $body): WP_REST_Response
    {
        $customer = isset($body['customer']) && is_array($body['customer']) ? $body['customer'] : array();
        $address = isset($body['address']) && is_array($body['address']) ? $body['address'] : array();
        $delivery_location_input = isset($body['delivery_location']) && is_array($body['delivery_location'])
            ? $body['delivery_location']
            : array();
        $items = isset($body['items']) && is_array($body['items']) ? $body['items'] : array();

        $name = sanitize_text_field((string) ($customer['name'] ?? ''));
        $phone = Lexi_Security::sanitize_phone((string) ($customer['phone'] ?? ''));
        $email = sanitize_email((string) ($customer['email'] ?? ''));
        $city_id = absint($address['city_id'] ?? 0);
        $street = sanitize_text_field((string) ($address['street'] ?? ''));
        $notes = sanitize_textarea_field((string) ($address['notes'] ?? ''));
        $device_token = sanitize_text_field((string) ($body['device_token'] ?? ''));
        $method = self::normalize_payment_method((string) ($body['payment_method'] ?? ''));

        if ('' === $name || '' === $phone || $city_id <= 0 || empty($items) || '' === $method) {
            return Lexi_Security::error('missing_fields', 'يرجى إكمال بيانات الطلب قبل المتابعة.', 422);
        }

        $city = Lexi_Shipping_Cities::get_by_id($city_id);
        if (!$city || !(bool) ($city['is_active'] ?? false)) {
            return Lexi_Security::error('invalid_city', 'مدينة الشحن غير متاحة حالياً.', 422);
        }

        $prepared_items = self::prepare_items($items);
        if ($prepared_items instanceof WP_REST_Response) {
            return $prepared_items;
        }

        $delivery_location = self::prepare_delivery_location(
            $delivery_location_input,
            $street,
            $notes,
            (string) $city['name']
        );
        if ($delivery_location instanceof WP_REST_Response) {
            return $delivery_location;
        }

        try {
            $order = wc_create_order();
            if (is_wp_error($order)) {
                self::log_error('[CHECKOUT] wc_create_order failed: ' . $order->get_error_message());
                return Lexi_Security::error('checkout_failed', 'تعذر إنشاء الطلب حالياً. حاول مرة أخرى.', 500);
            }

            foreach ($prepared_items as $line) {
                $order->add_product($line['product'], (int) $line['qty']);
            }

            $customer_id = is_user_logged_in() ? get_current_user_id() : 0;
            if ($customer_id > 0) {
                $order->set_customer_id((int) $customer_id);
            }

            list($first_name, $last_name) = self::split_name($name);
            $order->set_billing_first_name($first_name);
            $order->set_billing_last_name($last_name);
            $order->set_billing_phone($phone);
            if ('' !== $email) {
                $order->set_billing_email($email);
            }
            $order->set_billing_address_1($street);
            $order->set_billing_city((string) $city['name']);
            $order->set_billing_country('SY');

            $order->set_shipping_first_name($first_name);
            $order->set_shipping_last_name($last_name);
            $order->set_shipping_address_1($street);
            $order->set_shipping_city((string) $city['name']);
            $order->set_shipping_country('SY');

            if ('' !== $notes) {
                $order->set_customer_note($notes);
            }

            $shipping_item = new WC_Order_Item_Shipping();
            $shipping_item->set_method_title('شحن إلى ' . (string) $city['name']);
            $shipping_item->set_method_id('lexi_city_shipping');
            $shipping_item->set_total((float) $city['price']);
            $shipping_item->set_total((float) $city['price']);
            $order->add_item($shipping_item);

            // Apply Coupon
            $coupon_code = sanitize_text_field((string) ($body['coupon'] ?? ''));
            if ('' !== $coupon_code) {
                $apply_result = $order->apply_coupon($coupon_code);
                if (is_wp_error($apply_result)) {
                    $coupon_message = trim((string) $apply_result->get_error_message());
                    if ('' === $coupon_message) {
                        $coupon_message = 'الكوبون غير صالح أو لا ينطبق على السلة الحالية.';
                    }
                    $order->delete(true);
                    return Lexi_Security::error(
                        'invalid_coupon',
                        $coupon_message,
                        422,
                        array(
                            'coupon_code' => $coupon_code,
                        )
                    );
                }

                if (false === $apply_result) {
                    $order->delete(true);
                    return Lexi_Security::error(
                        'invalid_coupon',
                        'الكوبون غير صالح أو لا ينطبق على السلة الحالية.',
                        422,
                        array(
                            'coupon_code' => $coupon_code,
                        )
                    );
                }
            }

            if ('cod' === $method) {
                $order->set_payment_method('cod');
                $order->set_payment_method_title('الدفع عند الاستلام');
            } else {
                $order->set_payment_method('shamcash');
                $order->set_payment_method_title('شام كاش');
            }

            $order->update_meta_data('_lexi_phone', $phone);
            if ('' !== $device_token) {
                $order->update_meta_data('_lexi_device_token', $device_token);
            }
            $order->update_meta_data('_lexi_payment_method', $method);
            $order->update_meta_data('_lexi_city_id', (int) $city_id);
            $order->update_meta_data('_lexi_city_name', (string) $city['name']);
            $order->update_meta_data('_lexi_shipping_price', (float) $city['price']);

            // Backward compatibility for previous app/admin screens.
            $order->update_meta_data('_lexi_shipping_city_id', (int) $city_id);
            $order->update_meta_data('_lexi_shipping_city_name', (string) $city['name']);
            self::save_delivery_location_meta($order, $delivery_location);

            $order->update_meta_data('_lexi_source', 'flutter_app');
            $order->update_meta_data('_lexi_created_at', current_time('mysql'));

            $order->calculate_totals();
            $order->save();

            Lexi_Notifications::append_timeline(
                $order,
                'created',
                sprintf('تم إنشاء الطلب رقم #%s.', $order->get_order_number())
            );

            if ('cod' === $method) {
                $order->update_status('processing', 'طلب جديد - الدفع عند الاستلام.');
                Lexi_Notifications::notify_admin_new_cod_order($order);
                $next_action = array('type' => 'done');
            } else {
                // Use a short internal Woo status to avoid DB status truncation.
                $order->update_status('on-hold', 'طلب شام كاش بانتظار رفع إيصال الدفع.');
                $next_action = array(
                    'type' => 'upload_proof',
                    'upload_url' => '/wp-json/' . LEXI_API_NAMESPACE . '/payments/shamcash/proof',
                    'upload_endpoint' => '/wp-json/' . LEXI_API_NAMESPACE . '/payments/shamcash/proof',
                    'account_name' => get_option('lexi_shamcash_account_name', ''),
                    'qr_value' => get_option('lexi_shamcash_qr_value', ''),
                    'barcode_value' => get_option('lexi_shamcash_barcode_value', ''),
                    'instructions_ar' => get_option(
                        'lexi_shamcash_instructions_ar',
                        'يرجى كتابة رقم الطلب في ملاحظات التحويل ثم رفع صورة الإيصال.'
                    ),
                );
            }

            $public_status = (string) $order->get_status();
            if ('sham_cash' === $method) {
                $public_status = 'pending-verification';
            }

            return Lexi_Security::success(array(
                'order_id' => (int) $order->get_id(),
                'order_number' => (string) $order->get_order_number(),
                'status' => $public_status,
                'total' => (float) $order->get_total(),
                'currency' => (string) $order->get_currency(),
                'next_action' => $next_action,
                'delivery_location' => self::delivery_location_response_payload($delivery_location),
            ), 201);
        } catch (\Throwable $e) {
            self::log_error('[CHECKOUT] Exception: ' . $e->getMessage());
            return Lexi_Security::error('checkout_failed', 'تعذر إنشاء الطلب حالياً. حاول مرة أخرى.', 500);
        }
    }

    private static function map_legacy_payload(array $legacy): array
    {
        $billing = isset($legacy['billing']) && is_array($legacy['billing']) ? $legacy['billing'] : array();
        $items = isset($legacy['items']) && is_array($legacy['items']) ? $legacy['items'] : array();
        $customer_name = trim(
            sanitize_text_field((string) ($billing['first_name'] ?? '')) . ' ' .
            sanitize_text_field((string) ($billing['last_name'] ?? ''))
        );

        $normalized_items = array();
        foreach ($items as $item) {
            if (!is_array($item)) {
                continue;
            }
            $normalized_items[] = array(
                'product_id' => absint($item['product_id'] ?? 0),
                'variation_id' => absint($item['variation_id'] ?? 0) ?: null,
                'qty' => max(1, absint($item['qty'] ?? $item['quantity'] ?? 1)),
            );
        }

        $method = self::normalize_payment_method((string) ($legacy['payment_method'] ?? ''));
        if ('' === $method && 'shamcash' === strtolower((string) ($legacy['payment_method'] ?? ''))) {
            $method = 'sham_cash';
        }

        return array(
            'customer' => array(
                'name' => $customer_name,
                'phone' => (string) ($billing['phone'] ?? ''),
                'email' => (string) ($billing['email'] ?? ''),
            ),
            'address' => array(
                'city_id' => absint($legacy['shipping_city_id'] ?? 0),
                'street' => (string) ($billing['address_1'] ?? ''),
                'notes' => (string) ($legacy['customer_note'] ?? ''),
            ),
            'items' => $normalized_items,
            'payment_method' => $method,
            'device_token' => (string) ($legacy['device_token'] ?? ''),
            'delivery_location' => isset($legacy['delivery_location']) && is_array($legacy['delivery_location'])
                ? $legacy['delivery_location']
                : array(),
        );
    }

    /**
     * @param array<int, mixed> $items
     * @return array<int, array<string, mixed>>|WP_REST_Response
     */
    private static function prepare_items(array $items)
    {
        $prepared = array();

        foreach ($items as $item) {
            if (!is_array($item)) {
                continue;
            }

            $product_id = absint($item['product_id'] ?? 0);
            $variation_id = absint($item['variation_id'] ?? 0);
            $qty = max(1, absint($item['qty'] ?? 1));

            if ($product_id <= 0) {
                return Lexi_Security::error('invalid_items', 'أحد المنتجات غير صالح.', 422);
            }

            $product = $variation_id > 0 ? wc_get_product($variation_id) : wc_get_product($product_id);
            if (!$product || !($product instanceof WC_Product)) {
                return Lexi_Security::error('invalid_items', 'أحد المنتجات غير متاح حالياً.', 422);
            }

            if (!$product->is_in_stock()) {
                return Lexi_Security::error('out_of_stock', 'أحد المنتجات غير متوفر بالمخزون.', 422);
            }

            $prices = Lexi_Merch::resolve_product_prices($product);
            $price = (float) ($prices['price'] ?? 0.0);
            if ($price <= 0) {
                return Lexi_Security::error('invalid_price', 'سعر أحد المنتجات غير صالح.', 422);
            }

            // Keep checkout totals correct even when Woo _price is stale/zero.
            if ((float) $product->get_price() <= 0 && $price > 0) {
                $product->set_price((string) $price);
            }

            $prepared[] = array(
                'product' => $product,
                'qty' => $qty,
            );
        }

        if (empty($prepared)) {
            return Lexi_Security::error('empty_cart', 'السلة فارغة.', 422);
        }

        return $prepared;
    }

    /**
     * @return array<string,mixed>|WP_REST_Response
     */
    private static function prepare_delivery_location(
        array $raw,
        string $fallback_full_address,
        string $fallback_notes,
        string $fallback_city
    ) {
        $full_address = self::sanitize_limited_text(
            (string) ($raw['full_address'] ?? $fallback_full_address),
            500,
            true
        );
        if ('' === $full_address) {
            return Lexi_Security::error(
                'missing_delivery_address',
                'Delivery address is required.',
                422
            );
        }

        $lat = self::sanitize_optional_coordinate($raw['lat'] ?? null, -90.0, 90.0);
        if (false === $lat) {
            return Lexi_Security::error('invalid_delivery_lat', 'Invalid latitude value.', 422);
        }
        $lng = self::sanitize_optional_coordinate($raw['lng'] ?? null, -180.0, 180.0);
        if (false === $lng) {
            return Lexi_Security::error('invalid_delivery_lng', 'Invalid longitude value.', 422);
        }
        if ((null !== $lat && null === $lng) || (null === $lat && null !== $lng)) {
            return Lexi_Security::error(
                'invalid_delivery_coordinates',
                'Latitude and longitude must be provided together.',
                422
            );
        }

        $accuracy = self::sanitize_optional_float($raw['accuracy_meters'] ?? null);
        if (false === $accuracy) {
            return Lexi_Security::error('invalid_delivery_accuracy', 'Invalid location accuracy.', 422);
        }

        $city = self::sanitize_limited_text((string) ($raw['city'] ?? $fallback_city), 120);
        $area = self::sanitize_limited_text((string) ($raw['area'] ?? ''), 160);
        $street = self::sanitize_limited_text((string) ($raw['street'] ?? ''), 255);
        $building = self::sanitize_limited_text((string) ($raw['building'] ?? ''), 160);
        $notes = self::sanitize_limited_text((string) ($raw['notes'] ?? $fallback_notes), 1000, true);
        $captured_at = self::sanitize_limited_text((string) ($raw['captured_at'] ?? ''), 40);

        if ('' === $captured_at && null !== $lat && null !== $lng) {
            $captured_at = (string) current_time('mysql');
        } elseif ('' !== $captured_at) {
            $timestamp = strtotime($captured_at);
            $captured_at = $timestamp ? gmdate('Y-m-d H:i:s', (int) $timestamp) : '';
        }

        $maps = self::build_maps_urls($lat, $lng);

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
            'maps_open_url' => $maps['open'],
            'maps_navigate_url' => $maps['navigate'],
        );
    }

    /**
     * @param array<string,mixed> $location
     */
    private static function save_delivery_location_meta(WC_Order $order, array $location): void
    {
        $order->update_meta_data('_lexi_delivery_lat', null !== $location['lat'] ? (float) $location['lat'] : '');
        $order->update_meta_data('_lexi_delivery_lng', null !== $location['lng'] ? (float) $location['lng'] : '');
        $order->update_meta_data('_lexi_delivery_accuracy', null !== $location['accuracy_meters'] ? (float) $location['accuracy_meters'] : '');
        $order->update_meta_data('_lexi_delivery_full_address', (string) ($location['full_address'] ?? ''));
        $order->update_meta_data('_lexi_delivery_city', (string) ($location['city'] ?? ''));
        $order->update_meta_data('_lexi_delivery_area', (string) ($location['area'] ?? ''));
        $order->update_meta_data('_lexi_delivery_street', (string) ($location['street'] ?? ''));
        $order->update_meta_data('_lexi_delivery_building', (string) ($location['building'] ?? ''));
        $order->update_meta_data('_lexi_delivery_notes', (string) ($location['notes'] ?? ''));
        $order->update_meta_data('_lexi_delivery_captured_at', (string) ($location['captured_at'] ?? ''));
        $order->update_meta_data('_lexi_maps_open_url', (string) ($location['maps_open_url'] ?? ''));
        $order->update_meta_data('_lexi_maps_navigate_url', (string) ($location['maps_navigate_url'] ?? ''));
    }

    /**
     * @param array<string,mixed> $location
     * @return array<string,mixed>
     */
    private static function delivery_location_response_payload(array $location): array
    {
        return array(
            'lat' => $location['lat'] ?? null,
            'lng' => $location['lng'] ?? null,
            'accuracy_meters' => $location['accuracy_meters'] ?? null,
            'full_address' => (string) ($location['full_address'] ?? ''),
            'city' => (string) ($location['city'] ?? ''),
            'area' => (string) ($location['area'] ?? ''),
            'street' => (string) ($location['street'] ?? ''),
            'building' => (string) ($location['building'] ?? ''),
            'notes' => (string) ($location['notes'] ?? ''),
            'captured_at' => (string) ($location['captured_at'] ?? ''),
            'maps_open_url' => (string) ($location['maps_open_url'] ?? ''),
            'maps_navigate_url' => (string) ($location['maps_navigate_url'] ?? ''),
        );
    }

    private static function sanitize_limited_text(string $value, int $max_length = 255, bool $allow_new_lines = false): string
    {
        $sanitized = $allow_new_lines ? sanitize_textarea_field($value) : sanitize_text_field($value);
        $sanitized = trim((string) $sanitized);
        if (strlen($sanitized) > $max_length) {
            $sanitized = substr($sanitized, 0, $max_length);
        }

        return $sanitized;
    }

    /**
     * @return float|null|false
     */
    private static function sanitize_optional_coordinate($raw_value, float $min, float $max)
    {
        if (null === $raw_value) {
            return null;
        }

        $raw = trim((string) $raw_value);
        if ('' === $raw) {
            return null;
        }
        if (!is_numeric($raw)) {
            return false;
        }

        $value = (float) $raw;
        if ($value < $min || $value > $max) {
            return false;
        }

        return $value;
    }

    /**
     * @return float|null|false
     */
    private static function sanitize_optional_float($raw_value)
    {
        if (null === $raw_value) {
            return null;
        }

        $raw = trim((string) $raw_value);
        if ('' === $raw) {
            return null;
        }
        if (!is_numeric($raw)) {
            return false;
        }

        $value = (float) $raw;
        if ($value < 0) {
            return false;
        }

        return $value;
    }

    /**
     * @return array{open:string,navigate:string}
     */
    private static function build_maps_urls($lat, $lng): array
    {
        if (null === $lat || null === $lng) {
            return array('open' => '', 'navigate' => '');
        }

        $destination = self::format_coordinate((float) $lat) . ',' . self::format_coordinate((float) $lng);

        return array(
            'open' => 'https://www.google.com/maps/search/?api=1&query=' . $destination,
            'navigate' => 'https://www.google.com/maps/dir/?api=1&destination=' . $destination . '&travelmode=driving',
        );
    }

    private static function format_coordinate(float $value): string
    {
        return rtrim(rtrim(sprintf('%.6F', $value), '0'), '.');
    }

    private static function normalize_payment_method(string $raw): string
    {
        $value = strtolower(trim($raw));
        $value = str_replace('-', '_', $value);
        if ('cod' === $value) {
            return 'cod';
        }
        if (in_array($value, array('sham_cash', 'shamcash'), true)) {
            return 'sham_cash';
        }
        return '';
    }

    /**
     * @return array{0:string,1:string}
     */
    private static function split_name(string $name): array
    {
        $name = trim($name);
        if ('' === $name) {
            return array('عميل', '');
        }

        $parts = preg_split('/\s+/', $name, 2);
        $first = sanitize_text_field((string) ($parts[0] ?? 'عميل'));
        $last = sanitize_text_field((string) ($parts[1] ?? ''));

        return array($first, $last);
    }

    private static function logger(): WC_Logger
    {
        return wc_get_logger();
    }

    private static function log_error(string $message): void
    {
        self::logger()->error($message, array('source' => self::LOG_SOURCE));
    }
}
