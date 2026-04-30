<?php
/**
 * Wishlist routes: manage user wishlist items.
 *
 * @package Lexi_API
 */

defined('ABSPATH') || exit;

class Lexi_Routes_Wishlist
{
    /**
     * Register wishlist routes.
     */
    public static function register(): void
    {
        $ns = LEXI_API_NAMESPACE;

        register_rest_route($ns, '/wishlist', array(
            'methods' => WP_REST_Server::READABLE,
            'callback' => array(__CLASS__, 'get_items'),
            'permission_callback' => array('Lexi_Security', 'customer_access'),
        ));

        register_rest_route($ns, '/wishlist/toggle', array(
            'methods' => WP_REST_Server::CREATABLE,
            'callback' => array(__CLASS__, 'toggle_item'),
            'permission_callback' => array('Lexi_Security', 'customer_access'),
        ));
    }

    /**
     * GET /wishlist
     * Returns list of products in the user's wishlist.
     */
    public static function get_items(WP_REST_Request $request): WP_REST_Response
    {
        $user_id = get_current_user_id();
        if (!$user_id) {
            return Lexi_Security::error('unauthorized', 'يجب عليك تسجيل الدخول.', 401);
        }

        $wishlist = get_user_meta($user_id, '_lexi_wishlist', true);
        if (!is_array($wishlist)) {
            $wishlist = array();
        }

        if (empty($wishlist)) {
             return Lexi_Security::success(array());
        }

        // Fetch products
        $products = wc_get_products(array(
            'include' => $wishlist,
            'status' => 'publish',
            'limit' => -1,
        ));

        $items = array();
        foreach ($products as $product) {
            $items[] = self::format_product($product);
        }

        return Lexi_Security::success($items);
    }

    /**
     * POST /wishlist/toggle
     * Toggle a product ID in the wishlist.
     */
    public static function toggle_item(WP_REST_Request $request): WP_REST_Response
    {
        $user_id = get_current_user_id();
        if (!$user_id) {
            return Lexi_Security::error('unauthorized', 'يجب عليك تسجيل الدخول.', 401);
        }

        $product_id = absint($request->get_param('product_id'));
        if (!$product_id) {
            return Lexi_Security::error('missing_product_id', 'رقم المنتج مطلوب.', 422);
        }

        $wishlist = get_user_meta($user_id, '_lexi_wishlist', true);
        if (!is_array($wishlist)) {
            $wishlist = array();
        }

        // Clean up invalid entries
        $wishlist = array_map('absint', $wishlist);
        $wishlist = array_unique(array_filter($wishlist));

        $exists = in_array($product_id, $wishlist, true);

        if ($exists) {
            // Remove
            $wishlist = array_diff($wishlist, array($product_id));
            $message = 'تمت إزالة المنتج من المفضلة.';
            $added = false;
        } else {
            // Add
            $wishlist[] = $product_id;
            $message = 'تمت إضافة المنتج إلى المفضلة.';
            $added = true;
        }

        // Re-index array
        $wishlist = array_values($wishlist);
        update_user_meta($user_id, '_lexi_wishlist', $wishlist);

        return Lexi_Security::success(array(
            'in_wishlist' => $added,
            'count' => count($wishlist),
            'message' => $message,
            'items' => $wishlist,
        ));
    }

    /**
     * Format minimal product data for wishlist view.
     */
    private static function format_product(WC_Product $product): array
    {
        $data = $product->get_data();
        $image_id = $product->get_image_id();
        $image_url = $image_id ? wp_get_attachment_image_url($image_id, 'woocommerce_thumbnail') : '';
        $prices = Lexi_Merch::resolve_product_prices($product);

        return array(
            'id' => $product->get_id(),
            'name' => $product->get_name(),
            'price' => (float) ($prices['price'] ?? 0.0),
            'regular_price' => (float) ($prices['regular_price'] ?? 0.0),
            'sale_price' => isset($prices['sale_price']) ? $prices['sale_price'] : null,
            'on_sale' => $product->is_on_sale(),
            'image' => $image_url,
            'stock_status' => $product->get_stock_status(),
            'average_rating' => (float) $product->get_average_rating(),
            'review_count' => $product->get_review_count(),
        );
    }
}
