<?php
/**
 * Security helpers: permission callbacks, response formatting, signed URLs.
 *
 * @package Lexi_API
 */

defined('ABSPATH') || exit;

class Lexi_Security
{

    /* ── Response Helpers ───────────────────────────────────── */

    /**
     * Wrap data in a consistent success envelope.
     *
     * @param mixed $data    Payload.
     * @param int   $status  HTTP status code.
     * @return WP_REST_Response
     */
    public static function success($data = null, int $status = 200): WP_REST_Response
    {
        return new WP_REST_Response(
            array(
                'success' => true,
                'data' => $data,
            ),
            $status
        );
    }

    /**
     * Wrap error in a consistent error envelope.
     *
     * @param string $code    Machine-readable code.
     * @param string $message Human-readable message (Arabic).
     * @param int    $status  HTTP status code.
     * @param mixed  $details Optional extra detail.
     * @return WP_REST_Response
     */
    public static function error(string $code, string $message, int $status = 400, $details = null): WP_REST_Response
    {
        $error = array(
            'code' => $code,
            'message' => $message,
        );
        if (null !== $details) {
            $error['details'] = $details;
        }

        return new WP_REST_Response(
            array(
                'success' => false,
                'error' => $error,
            ),
            $status
        );
    }

    /* ── Permission Callbacks ──────────────────────────────── */

    /**
     * REST permission callback: public (always allowed).
     */
    public static function public_access(): bool
    {
        return true;
    }

    /**
     * REST permission callback: current user must be logged in AND
     * have either 'manage_woocommerce' or 'administrator' capability.
     *
     * Works with WordPress session cookies and JWT Auth plugins
     * (the JWT plugin sets the current user from the Authorization header
     * before permission callbacks fire — no custom logic needed here).
     */
    public static function admin_access()
    {
        if (!is_user_logged_in()) {
            return new WP_Error(
                'rest_forbidden',
                'بيانات الدخول غير صحيحة.',
                array('status' => 401)
            );
        }

        return current_user_can('manage_woocommerce')
            || current_user_can('administrator');
    }

    /**
     * REST permission callback: any authenticated user.
     *
     * Works with both WordPress cookies and JWT (Authorization: Bearer ...).
     */
    public static function customer_access(): bool
    {
        return is_user_logged_in();
    }

    /* ── Sanitization ──────────────────────────────────────── */

    /**
     * Normalize a Syrian phone number to digits-only, stripping +963 / 00963.
     *
     * @param string $phone Raw phone input.
     * @return string Sanitized phone.
     */
    public static function sanitize_phone(string $phone): string
    {
        $phone = preg_replace('/[^\d+]/', '', $phone);
        // Strip international prefix.
        $phone = preg_replace('/^(\+963|00963)/', '0', $phone);
        return $phone;
    }

    /* ── Signed URLs (HMAC, time-limited) ──────────────────── */

    /**
     * Generate an HMAC-signed URL with expiry.
     *
     * @param string $base_url The URL to sign.
     * @param int    $ttl      Time-to-live in seconds (default 3600 = 1 hour).
     * @return string Signed URL.
     */
    public static function generate_signed_url(string $base_url, int $ttl = 3600): string
    {
        $expires = time() + $ttl;
        $url = add_query_arg('expires', $expires, $base_url);
        $sig = hash_hmac('sha256', $url, wp_salt('auth'));
        return add_query_arg('sig', $sig, $url);
    }

    /**
     * Verify a signed URL.
     *
     * @param WP_REST_Request $request Request containing `expires` and `sig` params.
     * @return bool|WP_REST_Response True on valid, error response on invalid.
     */
    public static function verify_signed_request(WP_REST_Request $request)
    {
        $expires = absint($request->get_param('expires'));
        $sig = sanitize_text_field($request->get_param('sig'));

        if (!$expires || !$sig) {
            return self::error('invalid_signature', 'رابط غير صالح.', 403);
        }

        if (time() > $expires) {
            return self::error('link_expired', 'انتهت صلاحية الرابط.', 403);
        }

        // Reconstruct the URL that was signed.
        $current_url = rest_url($request->get_route());
        $params = $request->get_query_params();
        unset($params['sig']);
        $url_to_check = add_query_arg($params, $current_url);

        $expected_sig = hash_hmac('sha256', $url_to_check, wp_salt('auth'));

        if (!hash_equals($expected_sig, $sig)) {
            return self::error('invalid_signature', 'توقيع الرابط غير صالح.', 403);
        }

        return true;
    }
}
