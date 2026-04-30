<?php
/**
 * Debug REST routes: order health check + checkout test.
 *
 * All endpoints require `manage_woocommerce` capability (admin only).
 *
 * @package Lexi_API
 */

defined('ABSPATH') || exit;

class Lexi_Routes_Debug
{

    /**
     * Register debug routes.
     */
    public static function register(): void
    {
        register_rest_route(LEXI_API_NAMESPACE, '/debug/order-health', array(
            'methods' => WP_REST_Server::READABLE,
            'callback' => array(__CLASS__, 'order_health'),
            'permission_callback' => array('Lexi_Security', 'admin_access'),
        ));

        register_rest_route(LEXI_API_NAMESPACE, '/debug/checkout-test', array(
            'methods' => WP_REST_Server::CREATABLE,
            'callback' => array(__CLASS__, 'checkout_test'),
            'permission_callback' => array('Lexi_Security', 'admin_access'),
        ));

        register_rest_route(LEXI_API_NAMESPACE, '/debug/product-price', array(
            'methods' => WP_REST_Server::READABLE,
            'callback' => array(__CLASS__, 'product_price'),
            'permission_callback' => array('Lexi_Security', 'admin_access'),
            'args' => array(
                'product_id' => array(
                    'required' => true,
                    'sanitize_callback' => 'absint',
                    'validate_callback' => function ($value) {
                        return absint((int) $value) > 0;
                    },
                ),
            ),
        ));

        register_rest_route(LEXI_API_NAMESPACE, '/debug/repair-prices', array(
            'methods' => WP_REST_Server::CREATABLE,
            'callback' => array(__CLASS__, 'repair_prices'),
            'permission_callback' => array('Lexi_Security', 'admin_access'),
        ));
    }

    /* ------------------------------------------------------------------ */

    /**
     * GET /debug/order-health
     *
     * Returns:
     * - WooCommerce active status
     * - Can-create-order dry-run
     * - Last 5 Lexi orders (filtered by _lexi_payment_method meta)
     * - Server time
     */
    public static function order_health(WP_REST_Request $request): WP_REST_Response
    {
        $data = array();

        // 1. WooCommerce active?
        $data['woocommerce_active'] = class_exists('WooCommerce');
        $data['woocommerce_version'] = defined('WC_VERSION') ? WC_VERSION : null;

        // 2. Can create order? (dry-run: create -> delete)
        $data['can_create_order'] = false;
        $data['dry_run_error'] = null;

        try {
            $test_order = wc_create_order();
            if (is_wp_error($test_order)) {
                $data['dry_run_error'] = $test_order->get_error_message();
            } else {
                $data['can_create_order'] = true;
                $test_order->delete(true); // Force-delete the dry-run order.
            }
        } catch (\Exception $e) {
            $data['dry_run_error'] = $e->getMessage();
        }

        // 3. Last 5 Lexi orders.
        $data['recent_lexi_orders'] = self::get_recent_lexi_orders(5);

        // 4. Server time.
        $data['server_time'] = current_time('mysql');
        $data['server_timezone'] = wp_timezone_string();

        return Lexi_Security::success($data);
    }

    /**
     * POST /debug/checkout-test
     *
     * Creates a real test order with 1 unit of the given product_id (COD).
     *
     * Expected JSON body:
     * { "product_id": int }
     */
    public static function checkout_test(WP_REST_Request $request): WP_REST_Response
    {
        $body = $request->get_json_params();
        $product_id = isset($body['product_id']) ? absint($body['product_id']) : 0;

        if ($product_id === 0) {
            return Lexi_Security::error(
                'missing_product_id',
                'يرجى تمرير product_id صالح.',
                422
            );
        }

        $product = wc_get_product($product_id);
        if (!$product) {
            return Lexi_Security::error(
                'invalid_product',
                sprintf('المنتج %d غير موجود.', $product_id),
                422
            );
        }

        try {
            $order = wc_create_order();

            if (is_wp_error($order)) {
                return Lexi_Security::error(
                    'order_creation_failed',
                    'فشل إنشاء الطلب: ' . $order->get_error_message(),
                    500
                );
            }

            // Add product.
            $order->add_product($product, 1);

            // Minimal billing.
            $order->set_billing_first_name('Lexi');
            $order->set_billing_last_name('Debug Test');
            $order->set_billing_phone('0000000000');
            $order->set_billing_address_1('Test Address');
            $order->set_billing_city('Test City');
            $order->set_billing_country('SY');

            // Payment.
            $order->set_payment_method('cod');
            $order->set_payment_method_title('Debug Test — COD');

            // Meta.
            $order->update_meta_data('_lexi_payment_method', 'cod');
            $order->update_meta_data('_lexi_source', 'debug_test');
            $order->update_meta_data('_lexi_created_at', current_time('mysql'));

            // Customer note.
            $order->set_customer_note('🧪 طلب تجريبي من endpoint debug/checkout-test');

            // Calculate + save + status.
            $order->calculate_totals();
            $order->save();
            $order->update_status('processing', 'طلب تجريبي عبر debug/checkout-test.');

            // Log.
            wc_get_logger()->info(sprintf(
                '[DEBUG] Test order created — ID: %d, total: %s',
                $order->get_id(),
                $order->get_total()
            ), array('source' => 'lexi-api'));

            return Lexi_Security::success(array(
                'order_id' => $order->get_id(),
                'status' => $order->get_status(),
                'total' => $order->get_total(),
                'currency' => $order->get_currency(),
                'message' => 'تم إنشاء طلب تجريبي بنجاح. تحقق من WooCommerce → الطلبات.',
            ), 201);

        } catch (\Exception $e) {
            wc_get_logger()->error(sprintf(
                '[DEBUG] checkout-test exception: %s | Trace: %s',
                $e->getMessage(),
                $e->getTraceAsString()
            ), array('source' => 'lexi-api'));

            return Lexi_Security::error(
                'test_failed',
                'فشل إنشاء الطلب التجريبي: ' . $e->getMessage(),
                500
            );
        }
    }

    /**
     * GET /debug/product-price?product_id=123
     *
     * Returns resolved price and candidate meta keys used for diagnostics.
     */
    public static function product_price(WP_REST_Request $request): WP_REST_Response
    {
        $product_id = absint((int) $request->get_param('product_id'));
        if ($product_id <= 0) {
            return Lexi_Security::error('missing_product_id', 'يرجى تمرير product_id صالح.', 422);
        }

        $product = wc_get_product($product_id);
        if (!$product instanceof WC_Product) {
            return Lexi_Security::error('product_not_found', sprintf('المنتج %d غير موجود.', $product_id), 404);
        }

        $raw_price = (string) $product->get_price();
        $raw_regular = (string) $product->get_regular_price();
        $raw_sale = (string) $product->get_sale_price();

        return Lexi_Security::success(array(
            'product' => array(
                'id' => $product_id,
                'name' => (string) $product->get_name(),
                'type' => (string) $product->get_type(),
                'sku' => (string) $product->get_sku(),
                'status' => (string) get_post_status($product_id),
            ),
            'wc_raw' => array(
                'price' => $raw_price,
                'regular_price' => $raw_regular,
                'sale_price' => $raw_sale,
            ),
            'wc_parsed' => array(
                'price' => Lexi_Merch::parse_price_for_debug($raw_price),
                'regular_price' => Lexi_Merch::parse_price_for_debug($raw_regular),
                'sale_price' => Lexi_Merch::parse_price_for_debug($raw_sale),
            ),
            'resolved' => Lexi_Merch::resolve_product_prices($product),
            'meta_candidates' => Lexi_Merch::get_product_price_meta_candidates($product_id, 120),
        ));
    }

    /**
     * POST /debug/repair-prices
     *
     * Body:
     * {
     *   "source_meta_key": "my_custom_price", // optional
     *   "dry_run": true,                      // default true
     *   "only_zero_price": true,              // default true
     *   "limit": 500                          // 1..5000
     * }
     */
    public static function repair_prices(WP_REST_Request $request): WP_REST_Response
    {
        $body = (array) $request->get_json_params();
        $source_meta_key = trim((string) ($body['source_meta_key'] ?? ''));
        $dry_run = !array_key_exists('dry_run', $body) ? true : (bool) $body['dry_run'];
        $only_zero_price = !array_key_exists('only_zero_price', $body) ? true : (bool) $body['only_zero_price'];
        $limit = min(5000, max(1, (int) ($body['limit'] ?? 500)));

        $product_ids = wc_get_products(array(
            'limit' => $limit,
            'status' => 'publish',
            'orderby' => 'date',
            'order' => 'DESC',
            'return' => 'ids',
        ));

        $scanned = 0;
        $eligible = 0;
        $fixed = 0;
        $skipped = 0;
        $sample = array();

        foreach ($product_ids as $id) {
            $product_id = absint((int) $id);
            if ($product_id <= 0) {
                continue;
            }

            $product = wc_get_product($product_id);
            if (!$product instanceof WC_Product) {
                continue;
            }

            $scanned++;
            $current_price = Lexi_Merch::parse_price_for_debug($product->get_price());
            $current_price = null !== $current_price ? (float) $current_price : 0.0;

            if ($only_zero_price && $current_price > 0) {
                $skipped++;
                continue;
            }

            $target_price = 0.0;
            $source = '';

            if ('' !== $source_meta_key) {
                $target_raw = get_post_meta($product_id, $source_meta_key, true);
                $target_parsed = Lexi_Merch::parse_price_for_debug($target_raw);
                $target_price = null !== $target_parsed ? (float) $target_parsed : 0.0;
                $source = 'meta:' . $source_meta_key;
            } else {
                $resolved = Lexi_Merch::resolve_product_prices($product);
                $target_price = (float) ($resolved['price'] ?? 0.0);
                $source = 'resolved';
            }

            if ($target_price <= 0) {
                $skipped++;
                continue;
            }

            $eligible++;
            if (!$dry_run) {
                $product->set_regular_price((string) $target_price);

                $sale_price = Lexi_Merch::parse_price_for_debug($product->get_sale_price());
                if (null !== $sale_price && $sale_price > 0 && $sale_price < $target_price) {
                    $product->set_price((string) $sale_price);
                } else {
                    $product->set_price((string) $target_price);
                }

                $product->save();
            }
            $fixed++;

            if (count($sample) < 30) {
                $sample[] = array(
                    'product_id' => $product_id,
                    'name' => (string) $product->get_name(),
                    'old_price' => $current_price,
                    'new_price' => $target_price,
                    'source' => $source,
                );
            }
        }

        return Lexi_Security::success(array(
            'dry_run' => $dry_run,
            'source_meta_key' => $source_meta_key,
            'only_zero_price' => $only_zero_price,
            'limit' => $limit,
            'scanned' => $scanned,
            'eligible' => $eligible,
            'fixed' => $fixed,
            'skipped' => $skipped,
            'sample' => $sample,
        ));
    }

    /* ------------------------------------------------------------------ */

    /**
     * Fetch the most recent orders created by lexi-api.
     *
     * @param int $limit Number of orders.
     * @return array
     */
    private static function get_recent_lexi_orders(int $limit = 5): array
    {
        $orders = wc_get_orders(array(
            'limit' => $limit,
            'orderby' => 'date',
            'order' => 'DESC',
            'meta_key' => '_lexi_payment_method',
            'meta_compare' => 'EXISTS',
        ));

        $result = array();
        foreach ($orders as $order) {
            $result[] = array(
                'id' => $order->get_id(),
                'status' => $order->get_status(),
                'total' => $order->get_total(),
                'currency' => $order->get_currency(),
                'payment_method' => $order->get_meta('_lexi_payment_method'),
                'source' => $order->get_meta('_lexi_source'),
                'date_created' => $order->get_date_created() ? $order->get_date_created()->format('Y-m-d H:i:s') : null,
            );
        }

        return $result;
    }
}
