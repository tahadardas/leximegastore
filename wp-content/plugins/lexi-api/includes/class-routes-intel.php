<?php
/**
 * Store Intelligence REST routes.
 *
 * @package Lexi_API
 */

defined('ABSPATH') || exit;

class Lexi_Routes_Intel
{
    /**
     * Register intelligence routes.
     */
    public static function register(): void
    {
        $ns = LEXI_API_NAMESPACE;

        register_rest_route($ns, '/events/track', array(
            'methods' => WP_REST_Server::CREATABLE,
            'callback' => array(__CLASS__, 'track_event'),
            'permission_callback' => array('Lexi_Security', 'public_access'),
        ));

        register_rest_route($ns, '/admin/intel/overview', array(
            'methods' => WP_REST_Server::READABLE,
            'callback' => array(__CLASS__, 'overview'),
            'permission_callback' => array('Lexi_Intel', 'admin_intel_access'),
            'args' => array(
                'range' => array('default' => 'today', 'sanitize_callback' => 'sanitize_text_field'),
            ),
        ));

        register_rest_route($ns, '/admin/intel/trending-products', array(
            'methods' => WP_REST_Server::READABLE,
            'callback' => array(__CLASS__, 'trending_products'),
            'permission_callback' => array('Lexi_Intel', 'admin_intel_access'),
            'args' => array(
                'range' => array('default' => '24h', 'sanitize_callback' => 'sanitize_text_field'),
                'limit' => array('default' => 20, 'sanitize_callback' => 'absint'),
            ),
        ));

        register_rest_route($ns, '/admin/intel/opportunities', array(
            'methods' => WP_REST_Server::READABLE,
            'callback' => array(__CLASS__, 'opportunities'),
            'permission_callback' => array('Lexi_Intel', 'admin_intel_access'),
            'args' => array(
                'range' => array('default' => '7d', 'sanitize_callback' => 'sanitize_text_field'),
                'limit' => array('default' => 30, 'sanitize_callback' => 'absint'),
            ),
        ));

        register_rest_route($ns, '/admin/intel/wishlist-top', array(
            'methods' => WP_REST_Server::READABLE,
            'callback' => array(__CLASS__, 'wishlist_top'),
            'permission_callback' => array('Lexi_Intel', 'admin_intel_access'),
            'args' => array(
                'range' => array('default' => '7d', 'sanitize_callback' => 'sanitize_text_field'),
                'limit' => array('default' => 30, 'sanitize_callback' => 'absint'),
            ),
        ));

        register_rest_route($ns, '/admin/intel/search', array(
            'methods' => WP_REST_Server::READABLE,
            'callback' => array(__CLASS__, 'search_intelligence'),
            'permission_callback' => array('Lexi_Intel', 'admin_intel_access'),
            'args' => array(
                'range' => array('default' => '7d', 'sanitize_callback' => 'sanitize_text_field'),
                'limit' => array('default' => 50, 'sanitize_callback' => 'absint'),
            ),
        ));

        register_rest_route($ns, '/admin/intel/bundles', array(
            'methods' => WP_REST_Server::READABLE,
            'callback' => array(__CLASS__, 'bundles'),
            'permission_callback' => array('Lexi_Intel', 'admin_intel_access'),
            'args' => array(
                'range' => array('default' => '30d', 'sanitize_callback' => 'sanitize_text_field'),
                'product_id' => array('required' => true, 'sanitize_callback' => 'absint'),
                'limit' => array('default' => 10, 'sanitize_callback' => 'absint'),
            ),
        ));

        register_rest_route($ns, '/admin/intel/stock-alerts', array(
            'methods' => WP_REST_Server::READABLE,
            'callback' => array(__CLASS__, 'stock_alerts'),
            'permission_callback' => array('Lexi_Intel', 'admin_intel_access'),
        ));

        register_rest_route($ns, '/admin/intel/actions/create-offer-draft', array(
            'methods' => WP_REST_Server::CREATABLE,
            'callback' => array(__CLASS__, 'create_offer_draft'),
            'permission_callback' => array('Lexi_Intel', 'admin_intel_access'),
        ));

        register_rest_route($ns, '/admin/intel/actions/pin-home', array(
            'methods' => WP_REST_Server::CREATABLE,
            'callback' => array(__CLASS__, 'pin_home'),
            'permission_callback' => array('Lexi_Intel', 'admin_intel_access'),
        ));
    }

    /**
     * POST /events/track
     */
    public static function track_event(WP_REST_Request $request): WP_REST_Response
    {
        return Lexi_Intel::track_public_event($request);
    }

    /**
     * GET /admin/intel/overview
     */
    public static function overview(WP_REST_Request $request): WP_REST_Response
    {
        $range = sanitize_text_field((string) $request->get_param('range'));
        $data = Lexi_Intel::get_overview($range);
        return Lexi_Security::success($data);
    }

    /**
     * GET /admin/intel/trending-products
     */
    public static function trending_products(WP_REST_Request $request): WP_REST_Response
    {
        $range = sanitize_text_field((string) $request->get_param('range'));
        $limit = absint((int) $request->get_param('limit'));
        $data = Lexi_Intel::get_trending_products($range, $limit);
        return Lexi_Security::success($data);
    }

    /**
     * GET /admin/intel/opportunities
     */
    public static function opportunities(WP_REST_Request $request): WP_REST_Response
    {
        $range = sanitize_text_field((string) $request->get_param('range'));
        $limit = absint((int) $request->get_param('limit'));
        $data = Lexi_Intel::get_opportunities($range, $limit);
        return Lexi_Security::success($data);
    }

    /**
     * GET /admin/intel/wishlist-top
     */
    public static function wishlist_top(WP_REST_Request $request): WP_REST_Response
    {
        $range = sanitize_text_field((string) $request->get_param('range'));
        $limit = absint((int) $request->get_param('limit'));
        $data = Lexi_Intel::get_wishlist_top($range, $limit);
        return Lexi_Security::success($data);
    }

    /**
     * GET /admin/intel/search
     */
    public static function search_intelligence(WP_REST_Request $request): WP_REST_Response
    {
        $range = sanitize_text_field((string) $request->get_param('range'));
        $limit = absint((int) $request->get_param('limit'));
        $data = Lexi_Intel::get_search_intelligence($range, $limit);
        return Lexi_Security::success($data);
    }

    /**
     * GET /admin/intel/bundles
     */
    public static function bundles(WP_REST_Request $request): WP_REST_Response
    {
        $range = sanitize_text_field((string) $request->get_param('range'));
        $product_id = absint((int) $request->get_param('product_id'));
        $limit = absint((int) $request->get_param('limit'));

        if ($product_id <= 0) {
            return Lexi_Security::error('product_required', 'معرّف المنتج مطلوب.', 422);
        }

        $data = Lexi_Intel::get_bundles($range, $product_id, $limit);
        return Lexi_Security::success($data);
    }

    /**
     * GET /admin/intel/stock-alerts
     */
    public static function stock_alerts(WP_REST_Request $request): WP_REST_Response
    {
        $data = Lexi_Intel::get_stock_alerts();
        return Lexi_Security::success($data);
    }

    /**
     * POST /admin/intel/actions/create-offer-draft
     */
    public static function create_offer_draft(WP_REST_Request $request): WP_REST_Response
    {
        $body = (array) $request->get_json_params();
        if (empty($body)) {
            $body = (array) $request->get_body_params();
        }

        $result = Lexi_Intel::create_offer_draft($body);
        if (empty($result['ok'])) {
            return Lexi_Security::error(
                'offer_draft_failed',
                (string) ($result['error'] ?? 'تعذر إنشاء مسودة العرض حالياً.'),
                422
            );
        }

        return Lexi_Security::success(array(
            'offer_id' => (int) ($result['offer_id'] ?? 0),
            'is_active' => 0,
            'message' => 'تم إنشاء مسودة العرض وبانتظار اعتماد الإدارة.',
        ));
    }

    /**
     * POST /admin/intel/actions/pin-home
     */
    public static function pin_home(WP_REST_Request $request): WP_REST_Response
    {
        $body = (array) $request->get_json_params();
        if (empty($body)) {
            $body = (array) $request->get_body_params();
        }

        $product_id = absint((int) ($body['product_id'] ?? 0));
        $section = sanitize_text_field((string) ($body['section'] ?? ''));

        $result = Lexi_Intel::pin_product_home($product_id, $section);
        if (empty($result['ok'])) {
            return Lexi_Security::error(
                'pin_home_failed',
                (string) ($result['error'] ?? 'تعذر تثبيت المنتج حالياً.'),
                422
            );
        }

        return Lexi_Security::success(array(
            'section' => (string) ($result['section'] ?? ''),
            'section_id' => (int) ($result['section_id'] ?? 0),
            'product_id' => (int) ($result['product_id'] ?? 0),
            'message' => 'تم تثبيت المنتج في الرئيسية بنجاح.',
        ));
    }
}

