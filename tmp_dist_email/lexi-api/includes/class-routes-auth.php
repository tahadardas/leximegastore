<?php
/**
 * Customer auth routes: register + current user profile.
 *
 * @package Lexi_API
 */

defined('ABSPATH') || exit;

class Lexi_Routes_Auth
{

    /**
     * Register auth routes.
     */
    public static function register(): void
    {
        $ns = LEXI_API_NAMESPACE;

        register_rest_route($ns, '/auth/login', array(
            'methods' => WP_REST_Server::CREATABLE,
            'callback' => array(__CLASS__, 'login_customer'),
            'permission_callback' => array('Lexi_Security', 'public_access'),
        ));

        register_rest_route($ns, '/auth/register', array(
            'methods' => WP_REST_Server::CREATABLE,
            'callback' => array(__CLASS__, 'register_customer'),
            'permission_callback' => array('Lexi_Security', 'public_access'),
        ));

        register_rest_route($ns, '/auth/me', array(
            'methods' => WP_REST_Server::READABLE,
            'callback' => array(__CLASS__, 'get_me'),
            'permission_callback' => array('Lexi_Security', 'customer_access'),
        ));

        register_rest_route($ns, '/auth/profile', array(
            'methods' => WP_REST_Server::EDITABLE,
            'callback' => array(__CLASS__, 'update_profile'),
            'permission_callback' => array('Lexi_Security', 'customer_access'),
        ));

        // New endpoints (backward-compatible aliases used by latest app builds).
        register_rest_route($ns, '/profile/update', array(
            'methods' => WP_REST_Server::EDITABLE,
            'callback' => array(__CLASS__, 'update_profile'),
            'permission_callback' => array('Lexi_Security', 'customer_access'),
        ));

        register_rest_route($ns, '/profile/avatar', array(
            'methods' => WP_REST_Server::CREATABLE,
            'callback' => array(__CLASS__, 'update_avatar'),
            'permission_callback' => array('Lexi_Security', 'customer_access'),
        ));

        register_rest_route($ns, '/auth/wishlist', array(
            'methods' => WP_REST_Server::READABLE,
            'callback' => array(__CLASS__, 'get_wishlist'),
            'permission_callback' => array('Lexi_Security', 'customer_access'),
        ));

        register_rest_route($ns, '/auth/wishlist/toggle', array(
            'methods' => WP_REST_Server::CREATABLE,
            'callback' => array(__CLASS__, 'toggle_wishlist'),
            'permission_callback' => array('Lexi_Security', 'customer_access'),
        ));

        register_rest_route($ns, '/auth/refresh', array(
            'methods' => WP_REST_Server::CREATABLE,
            'callback' => array(__CLASS__, 'refresh_session'),
            'permission_callback' => array('Lexi_Security', 'public_access'),
        ));

        register_rest_route($ns, '/auth/logout', array(
            'methods' => WP_REST_Server::CREATABLE,
            'callback' => array(__CLASS__, 'logout_session'),
            'permission_callback' => array('Lexi_Security', 'public_access'),
        ));

        // Password reset flow (public â€” no JWT required).
        register_rest_route($ns, '/auth/forgot-password', array(
            'methods' => WP_REST_Server::CREATABLE,
            'callback' => array(__CLASS__, 'forgot_password'),
            'permission_callback' => array('Lexi_Security', 'public_access'),
        ));

        register_rest_route($ns, '/auth/reset-password', array(
            'methods' => WP_REST_Server::CREATABLE,
            'callback' => array(__CLASS__, 'reset_password'),
            'permission_callback' => array('Lexi_Security', 'public_access'),
        ));

        register_rest_route($ns, '/auth/change-password', array(
            'methods' => WP_REST_Server::CREATABLE,
            'callback' => array(__CLASS__, 'change_password'),
            'permission_callback' => array('Lexi_Security', 'customer_access'),
        ));
    }

    /**
     * Read JSON/body params as a normalized array.
     */
    private static function request_body(WP_REST_Request $request): array
    {
        $body = $request->get_json_params();
        if (is_array($body)) {
            return $body;
        }

        $body = $request->get_body_params();
        return is_array($body) ? $body : array();
    }

    /**
     * Build standard auth success payload.
     *
     * @param array<string, mixed> $tokens
     * @return array<string, mixed>
     */
    private static function auth_payload(int $user_id, array $tokens): array
    {
        return array(
            'access_token' => (string) ($tokens['access_token'] ?? ''),
            'refresh_token' => (string) ($tokens['refresh_token'] ?? ''),
            // Backward-compatible alias used by older clients.
            'token' => (string) ($tokens['access_token'] ?? ''),
            'expires_in' => (int) ($tokens['expires_in'] ?? 0),
            'refresh_expires_in' => (int) ($tokens['refresh_expires_in'] ?? 0),
            'user' => self::map_user($user_id),
        );
    }

    /**
     * POST /auth/login
     *
     * Body:
     * {
     *   "username"?: string,
     *   "email"?: string,
     *   "password": string
     * }
     */
    public static function login_customer(WP_REST_Request $request): WP_REST_Response
    {
        $body = self::request_body($request);
        $password = (string) ($body['password'] ?? '');

        $username = sanitize_user((string) ($body['username'] ?? ''), true);
        $email = sanitize_email((string) ($body['email'] ?? ''));
        $identifier = $username;

        if ('' === $identifier && '' !== $email) {
            $user_by_email = get_user_by('email', $email);
            if ($user_by_email) {
                $identifier = (string) $user_by_email->user_login;
            }
        }

        if ('' === $identifier && '' !== $username) {
            $identifier = $username;
        }

        if ('' === $identifier && isset($body['username'])) {
            // Allow email through `username` field for compatibility.
            $candidate = trim((string) $body['username']);
            if (false !== strpos($candidate, '@')) {
                $user_by_email = get_user_by('email', sanitize_email($candidate));
                if ($user_by_email) {
                    $identifier = (string) $user_by_email->user_login;
                }
            }
            if ('' === $identifier) {
                $identifier = sanitize_user($candidate, true);
            }
        }

        if ('' === $identifier || '' === $password) {
            return Lexi_Security::error('invalid_credentials', 'Username/email and password are required.', 422);
        }

        $user = wp_authenticate($identifier, $password);
        if (is_wp_error($user) || !($user instanceof WP_User)) {
            return Lexi_Security::error('invalid_credentials', 'Invalid login credentials.', 401);
        }

        $tokens = Lexi_Auth_Tokens::issue_token_pair((int) $user->ID);
        if (is_wp_error($tokens)) {
            return Lexi_Security::error(
                'token_issue_failed',
                'Unable to create session.',
                500,
                $tokens->get_error_message()
            );
        }

        return Lexi_Security::success(self::auth_payload((int) $user->ID, $tokens));
    }

    /**
     * POST /auth/register
     *
     * Body:
     * {
     *   "email": string,
     *   "password": string,
     *   "username"?: string,
     *   "first_name"?: string,
     *   "last_name"?: string,
     *   "phone"?: string,
     *   "address_1"?: string,
     *   "city"?: string
     * }
     */
    public static function register_customer(WP_REST_Request $request): WP_REST_Response
    {
        $body = self::request_body($request);

        $email = sanitize_email((string) ($body['email'] ?? ''));
        $password = (string) ($body['password'] ?? '');
        $username_input = sanitize_user((string) ($body['username'] ?? ''), true);
        $first_name = sanitize_text_field((string) ($body['first_name'] ?? ''));
        $last_name = sanitize_text_field((string) ($body['last_name'] ?? ''));
        $phone = Lexi_Security::sanitize_phone((string) ($body['phone'] ?? ''));
        $address_1 = sanitize_text_field((string) ($body['address_1'] ?? ''));
        $city = sanitize_text_field((string) ($body['city'] ?? ''));

        if ('' === $email || !is_email($email)) {
            return Lexi_Security::error('invalid_email', 'الرجاء إدخال بريد إلكتروني صحيح.', 422);
        }

        if (strlen($password) < 6) {
            return Lexi_Security::error('weak_password', 'كلمة المرور يجب أن تكون 6 أحرف على الأقل.', 422);
        }

        if ('' === $phone || strlen($phone) < 9) {
            return Lexi_Security::error('invalid_phone', 'رقم الهاتف مطلوب ويجب أن يكون صحيحاً.', 422);
        }

        if (email_exists($email)) {
            return Lexi_Security::error('email_exists', 'يوجد حساب مسجل بهذا البريد الإلكتروني. استخدم تسجيل الدخول أو نسيت كلمة المرور.', 409);
        }

        $username = self::build_unique_username($email, $username_input);
        if ('' === $username || username_exists($username)) {
            return Lexi_Security::error('username_exists', 'اسم المستخدم مستخدم مسبقًا.', 409);
        }

        $user_id = wp_create_user($username, $password, $email);
        if (is_wp_error($user_id)) {
            return Lexi_Security::error(
                'register_failed',
                'تعذر إنشاء الحساب.',
                500,
                $user_id->get_error_message()
            );
        }

        $display_name = trim($first_name . ' ' . $last_name);
        if ('' === $display_name) {
            $display_name = $username;
        }

        wp_update_user(array(
            'ID' => (int) $user_id,
            'first_name' => $first_name,
            'last_name' => $last_name,
            'display_name' => $display_name,
        ));

        $user = new WP_User((int) $user_id);
        if ($user) {
            if (class_exists('WooCommerce')) {
                $user->set_role('customer');
            } else {
                $user->set_role('subscriber');
            }
        }

        // Store billing data for checkout auto-fill.
        update_user_meta((int) $user_id, 'billing_first_name', $first_name);
        update_user_meta((int) $user_id, 'billing_last_name', $last_name);
        update_user_meta((int) $user_id, 'billing_email', $email);
        update_user_meta((int) $user_id, 'billing_phone', $phone);
        update_user_meta((int) $user_id, 'billing_address_1', $address_1);
        update_user_meta((int) $user_id, 'billing_city', $city);
        update_user_meta((int) $user_id, 'billing_country', 'SY');

        // Mirror into shipping as a sensible default.
        update_user_meta((int) $user_id, 'shipping_first_name', $first_name);
        update_user_meta((int) $user_id, 'shipping_last_name', $last_name);
        update_user_meta((int) $user_id, 'shipping_address_1', $address_1);
        update_user_meta((int) $user_id, 'shipping_city', $city);
        update_user_meta((int) $user_id, 'shipping_country', 'SY');

        $tokens = Lexi_Auth_Tokens::issue_token_pair((int) $user_id);
        if (is_wp_error($tokens)) {
            return Lexi_Security::error(
                'token_issue_failed',
                'Unable to create session.',
                500,
                $tokens->get_error_message()
            );
        }

        return Lexi_Security::success(
            array_merge(
                array('message' => 'Account created successfully.'),
                self::auth_payload((int) $user_id, $tokens)
            ),
            201
        );
    }

    /**
     * POST/PATCH /auth/profile
     */
    public static function update_profile(WP_REST_Request $request): WP_REST_Response
    {
        $user_id = get_current_user_id();
        if ($user_id <= 0) {
            return Lexi_Security::error('unauthorized', 'يلزم تسجيل الدخول.', 401);
        }

        $body = self::request_body($request);

        $updatable_keys = array('first_name', 'last_name', 'display_name', 'email', 'phone', 'address_1', 'city');
        $has_updates = false;
        foreach ($updatable_keys as $key) {
            if (array_key_exists($key, $body)) {
                $has_updates = true;
                break;
            }
        }

        if (!$has_updates) {
            return Lexi_Security::error('missing_fields', 'لا توجد بيانات محدثة.', 422);
        }

        $current_user = get_userdata((int) $user_id);
        if (!$current_user) {
            return Lexi_Security::error('user_not_found', 'المستخدم غير موجود.', 404);
        }

        $current_first_name = (string) get_user_meta((int) $user_id, 'first_name', true);
        $current_last_name = (string) get_user_meta((int) $user_id, 'last_name', true);

        $first_name = array_key_exists('first_name', $body)
            ? sanitize_text_field((string) ($body['first_name'] ?? ''))
            : $current_first_name;
        $last_name = array_key_exists('last_name', $body)
            ? sanitize_text_field((string) ($body['last_name'] ?? ''))
            : $current_last_name;

        $email = (string) $current_user->user_email;
        if (array_key_exists('email', $body)) {
            $email = sanitize_email((string) ($body['email'] ?? ''));
            if ('' === $email || !is_email($email)) {
                return Lexi_Security::error('invalid_email', 'الرجاء إدخال بريد إلكتروني صحيح.', 422);
            }

            $existing = email_exists($email);
            if ($existing && (int) $existing !== (int) $user_id) {
                return Lexi_Security::error('email_exists', 'يوجد حساب مسجل بهذا البريد الإلكتروني. استخدم تسجيل الدخول أو نسيت كلمة المرور.', 409);
            }
        }

        $phone = array_key_exists('phone', $body)
            ? Lexi_Security::sanitize_phone((string) ($body['phone'] ?? ''))
            : (string) get_user_meta((int) $user_id, 'billing_phone', true);
        if (array_key_exists('phone', $body) && ('' === $phone || strlen($phone) < 9)) {
            return Lexi_Security::error('invalid_phone', 'رقم الهاتف مطلوب ويجب أن يكون صحيحاً.', 422);
        }

        $address_1 = array_key_exists('address_1', $body)
            ? sanitize_text_field((string) ($body['address_1'] ?? ''))
            : (string) get_user_meta((int) $user_id, 'billing_address_1', true);
        $city = array_key_exists('city', $body)
            ? sanitize_text_field((string) ($body['city'] ?? ''))
            : (string) get_user_meta((int) $user_id, 'billing_city', true);
        $display_name = array_key_exists('display_name', $body)
            ? sanitize_text_field((string) ($body['display_name'] ?? ''))
            : (string) $current_user->display_name;

        $user_update = array(
            'ID' => (int) $user_id,
        );

        if (array_key_exists('first_name', $body)) {
            $user_update['first_name'] = $first_name;
        }
        if (array_key_exists('last_name', $body)) {
            $user_update['last_name'] = $last_name;
        }
        if (array_key_exists('email', $body)) {
            $user_update['user_email'] = $email;
        }

        if (array_key_exists('display_name', $body)) {
            if ('' === $display_name) {
                $display_name = (string) $current_user->display_name;
            }
            $user_update['display_name'] = $display_name;
        } elseif (array_key_exists('first_name', $body) || array_key_exists('last_name', $body)) {
            $display_name = trim($first_name . ' ' . $last_name);
            if ('' === $display_name) {
                $display_name = (string) $current_user->display_name;
            }
            $user_update['display_name'] = $display_name;
        }

        if (count($user_update) > 1) {
            $update_result = wp_update_user($user_update);
            if (is_wp_error($update_result)) {
                return Lexi_Security::error('update_failed', 'تعذر تحديث بيانات الحساب.', 500);
            }
        }

        if (array_key_exists('first_name', $body)) {
            update_user_meta((int) $user_id, 'billing_first_name', $first_name);
            update_user_meta((int) $user_id, 'shipping_first_name', $first_name);
        }
        if (array_key_exists('last_name', $body)) {
            update_user_meta((int) $user_id, 'billing_last_name', $last_name);
            update_user_meta((int) $user_id, 'shipping_last_name', $last_name);
        }
        if (array_key_exists('email', $body)) {
            update_user_meta((int) $user_id, 'billing_email', $email);
        }
        if (array_key_exists('phone', $body)) {
            update_user_meta((int) $user_id, 'billing_phone', $phone);
        }
        if (array_key_exists('address_1', $body)) {
            update_user_meta((int) $user_id, 'billing_address_1', $address_1);
            update_user_meta((int) $user_id, 'shipping_address_1', $address_1);
        }
        if (array_key_exists('city', $body)) {
            update_user_meta((int) $user_id, 'billing_city', $city);
            update_user_meta((int) $user_id, 'shipping_city', $city);
        }

        update_user_meta((int) $user_id, 'billing_country', 'SY');
        update_user_meta((int) $user_id, 'shipping_country', 'SY');

        return Lexi_Security::success(array(
            'message' => 'تم تحديث البيانات بنجاح.',
            'user' => self::map_user((int) $user_id),
        ));
    }

    /**
     * POST /profile/avatar
     */
    public static function update_avatar(WP_REST_Request $request): WP_REST_Response
    {
        $user_id = get_current_user_id();
        if ($user_id <= 0) {
            return Lexi_Security::error('unauthorized', 'يلزم تسجيل الدخول.', 401);
        }

        $files = $request->get_file_params();
        if (!isset($files['avatar']) || !is_array($files['avatar'])) {
            return Lexi_Security::error('missing_file', 'يرجى اختيار صورة للمتابعة.', 422);
        }

        require_once ABSPATH . 'wp-admin/includes/file.php';
        require_once ABSPATH . 'wp-admin/includes/image.php';
        require_once ABSPATH . 'wp-admin/includes/media.php';

        $attachment_id = media_handle_upload('avatar', 0);
        if (is_wp_error($attachment_id)) {
            return Lexi_Security::error('upload_failed', 'تعذر رفع الصورة حالياً.', 500);
        }

        $avatar_url = wp_get_attachment_image_url((int) $attachment_id, 'medium');
        if (!$avatar_url) {
            $avatar_url = wp_get_attachment_url((int) $attachment_id);
        }

        update_user_meta((int) $user_id, 'lexi_avatar_id', (int) $attachment_id);
        update_user_meta((int) $user_id, 'lexi_avatar_url', (string) $avatar_url);

        return Lexi_Security::success(array(
            'message' => 'تم تحديث الصورة الشخصية.',
            'user' => self::map_user((int) $user_id),
        ));
    }

    /**
     * GET /auth/wishlist
     */
    public static function get_wishlist(WP_REST_Request $request): WP_REST_Response
    {
        $user_id = get_current_user_id();
        if ($user_id <= 0) {
            return Lexi_Security::error('unauthorized', 'يلزم تسجيل الدخول.', 401);
        }

        return Lexi_Security::success(array(
            'ids' => self::get_wishlist_ids((int) $user_id),
        ));
    }

    /**
     * POST /auth/wishlist/toggle
     */
    public static function toggle_wishlist(WP_REST_Request $request): WP_REST_Response
    {
        $user_id = get_current_user_id();
        if ($user_id <= 0) {
            return Lexi_Security::error('unauthorized', 'يلزم تسجيل الدخول.', 401);
        }

        $body = (array) $request->get_json_params();
        if (empty($body)) {
            $body = (array) $request->get_body_params();
        }

        $product_id = absint((int) ($body['product_id'] ?? 0));
        $action = strtolower(trim((string) ($body['action'] ?? 'toggle')));

        if ($product_id <= 0) {
            return Lexi_Security::error('invalid_product', 'المنتج غير صالح.', 422);
        }

        $product = wc_get_product($product_id);
        if (!$product || 'publish' !== get_post_status($product_id)) {
            return Lexi_Security::error('product_not_found', 'المنتج غير موجود.', 404);
        }

        $ids = self::get_wishlist_ids((int) $user_id);
        $lookup = array_fill_keys($ids, true);
        $exists = isset($lookup[$product_id]);
        $tracked_event = null;

        if ('add' === $action) {
            if (!$exists) {
                $ids[] = $product_id;
                $tracked_event = 'add_wishlist';
            }
        } elseif ('remove' === $action) {
            if ($exists) {
                $ids = array_values(array_filter($ids, function ($id) use ($product_id) {
                    return (int) $id !== (int) $product_id;
                }));
                $tracked_event = 'remove_wishlist';
            }
        } else {
            if ($exists) {
                $ids = array_values(array_filter($ids, function ($id) use ($product_id) {
                    return (int) $id !== (int) $product_id;
                }));
                $tracked_event = 'remove_wishlist';
            } else {
                $ids[] = $product_id;
                $tracked_event = 'add_wishlist';
            }
        }

        $ids = array_values(array_unique(array_map('intval', $ids)));
        self::save_wishlist_ids((int) $user_id, $ids);

        if ($tracked_event && class_exists('Lexi_AI_Core')) {
            Lexi_AI_Core::instance()->track_event([
                'event_type' => $tracked_event,
                'product_id' => $product_id,
                'device_id' => $request->get_header('X-Lexi-Device-ID'),
                'session_id' => $request->get_header('X-Lexi-Session-ID'),
            ]);
        }

        return Lexi_Security::success(array(
            'ids' => $ids,
            'in_wishlist' => in_array($product_id, $ids, true),
        ));
    }

    /**
     * GET /auth/me
     */
    public static function get_me(WP_REST_Request $request): WP_REST_Response
    {
        $user_id = get_current_user_id();
        if ($user_id <= 0) {
            return Lexi_Security::error('unauthorized', 'يلزم تسجيل الدخول.', 401);
        }

        return Lexi_Security::success(self::map_user((int) $user_id));
    }

    /**
     * POST /auth/refresh
     */
    public static function refresh_session(WP_REST_Request $request): WP_REST_Response
    {
        $body = self::request_body($request);
        $refresh_token = trim((string) ($body['refresh_token'] ?? ''));

        if ('' === $refresh_token) {
            return Lexi_Security::error('missing_refresh_token', 'Refresh token is required.', 422);
        }

        $tokens = Lexi_Auth_Tokens::rotate_refresh_token($refresh_token);
        if (is_wp_error($tokens)) {
            return Lexi_Security::error(
                $tokens->get_error_code() ?: 'invalid_refresh_token',
                'Session expired. Please login again.',
                401
            );
        }

        return Lexi_Security::success(array(
            'access_token' => (string) ($tokens['access_token'] ?? ''),
            'refresh_token' => (string) ($tokens['refresh_token'] ?? ''),
            // Backward-compatible alias used by older clients.
            'token' => (string) ($tokens['access_token'] ?? ''),
            'expires_in' => (int) ($tokens['expires_in'] ?? 0),
            'refresh_expires_in' => (int) ($tokens['refresh_expires_in'] ?? 0),
        ));
    }

    /**
     * POST /auth/logout
     */
    public static function logout_session(WP_REST_Request $request): WP_REST_Response
    {
        $body = self::request_body($request);
        $refresh_token = trim((string) ($body['refresh_token'] ?? ''));

        if ('' !== $refresh_token) {
            Lexi_Auth_Tokens::revoke_refresh_token($refresh_token);
        } else {
            $user_id = get_current_user_id();
            if ($user_id > 0) {
                Lexi_Auth_Tokens::revoke_all_for_user((int) $user_id);
            }
        }

        return Lexi_Security::success(array(
            'message' => 'Logged out.',
        ));
    }

    /**
     * Build a unique username from input/email.
     */
    private static function build_unique_username(string $email, string $requested): string
    {
        $base = trim($requested);

        if ('' === $base) {
            $email_local = strtolower((string) strstr($email, '@', true));
            $base = sanitize_user($email_local, true);
        }

        if ('' === $base) {
            $base = 'user' . wp_rand(1000, 9999);
        }

        $candidate = $base;
        $counter = 1;
        while (username_exists($candidate)) {
            $candidate = $base . $counter;
            $counter++;
            if ($counter > 999) {
                $candidate = $base . wp_rand(1000, 9999);
                break;
            }
        }

        return sanitize_user($candidate, true);
    }

    /**
     * Convert WP user + billing meta into API payload.
     */
    private static function map_user(int $user_id): array
    {
        $user = get_userdata($user_id);
        if (!$user) {
            return array(
                'id' => $user_id,
            );
        }

        $first_name = (string) get_user_meta($user_id, 'first_name', true);
        $last_name = (string) get_user_meta($user_id, 'last_name', true);
        $billing_phone = (string) get_user_meta($user_id, 'billing_phone', true);
        $billing_address_1 = (string) get_user_meta($user_id, 'billing_address_1', true);
        $billing_city = (string) get_user_meta($user_id, 'billing_city', true);
        $billing_country = (string) get_user_meta($user_id, 'billing_country', true);
        $avatar_meta = (string) get_user_meta($user_id, 'lexi_avatar_url', true);
        $avatar_url = '' !== trim($avatar_meta)
            ? trim($avatar_meta)
            : (string) get_avatar_url($user_id, array('size' => 256));

        if ('' === $billing_country) {
            $billing_country = 'SY';
        }

        return array(
            'id' => (int) $user_id,
            'user_login' => (string) $user->user_login,
            'email' => (string) $user->user_email,
            'display_name' => (string) $user->display_name,
            'roles' => array_values((array) $user->roles),
            'first_name' => $first_name,
            'last_name' => $last_name,
            'billing_phone' => $billing_phone,
            'billing_address_1' => $billing_address_1,
            'billing_city' => $billing_city,
            'billing_country' => $billing_country,
            'avatar_url' => $avatar_url,
            'is_admin' => in_array('administrator', (array) $user->roles, true) || in_array('shop_manager', (array) $user->roles, true),
        );
    }

    /**
     * @return array<int, int>
     */
    private static function get_wishlist_ids(int $user_id): array
    {
        $raw = get_user_meta($user_id, 'lexi_wishlist_ids', true);
        $items = array();

        if (is_array($raw)) {
            $items = $raw;
        } elseif (is_string($raw) && '' !== trim($raw)) {
            $decoded = json_decode($raw, true);
            if (is_array($decoded)) {
                $items = $decoded;
            }
        }

        $ids = array_values(array_unique(array_filter(array_map('intval', $items))));
        return $ids;
    }

    /**
     * @param array<int, int> $ids
     */
    private static function save_wishlist_ids(int $user_id, array $ids): void
    {
        update_user_meta($user_id, 'lexi_wishlist_ids', array_values($ids));
    }

    /**
     * POST /auth/forgot-password
     *
     * Body: { "email": string }
     *
     * Generates a 6-digit OTP, stores it in a WordPress transient keyed by
     * email (15 min TTL), and sends it via wp_mail.  Rate-limited to one
     * request per 60 seconds per email address.
     */
    public static function forgot_password(WP_REST_Request $request): WP_REST_Response
    {
        $body = self::request_body($request);

        $email = sanitize_email((string) ($body['email'] ?? ''));
        if ('' === $email || !is_email($email)) {
            return Lexi_Security::error('invalid_email', 'الرجاء إدخال بريد إلكتروني صحيح.', 422);
        }

        // Rate-limit: 1 request / 60 s per email.
        $rate_key = 'lexi_pwd_rate_' . md5($email);
        if (false !== get_transient($rate_key)) {
            return Lexi_Security::error(
                'rate_limited',
                'يرجى الانتظار قليلاً قبل إعادة إرسال رمز التحقق.',
                429
            );
        }

        // Always respond with success to avoid email enumeration.
        $user = get_user_by('email', $email);
        if (!$user) {
            // Set rate-limit even for non-existent emails.
            set_transient($rate_key, 1, 60);
            return Lexi_Security::success(array(
                'message' => 'إذا كان البريد الإلكتروني مسجلاً، سيتم إرسال رمز التحقق.',
            ));
        }

        // Generate 6-digit OTP.
        $code = str_pad((string) wp_rand(0, 999999), 6, '0', STR_PAD_LEFT);

        // Store OTP in transient (15 min TTL).
        $otp_key = 'lexi_pwd_otp_' . md5($email);
        set_transient($otp_key, array(
            'code'    => $code,
            'user_id' => (int) $user->ID,
            'tries'   => 0,
        ), 15 * MINUTE_IN_SECONDS);

        // Set rate-limit.
        set_transient($rate_key, 1, 60);

        // Send email.
        $site_name = get_bloginfo('name');
        $subject   = $site_name . ' – رمز إعادة تعيين كلمة المرور';
        $message   = "مرحباً {$user->display_name},\n\n"
            . "رمز التحقق الخاص بك هو:\n\n"
            . "    {$code}\n\n"
            . "هذا الرمز صالح لمدة 15 دقيقة.\n"
            . "إذا لم تطلب إعادة تعيين كلمة المرور، تجاهل هذه الرسالة.\n\n"
            . "— {$site_name}";

        $headers = array('Content-Type: text/plain; charset=UTF-8');
        wp_mail($email, $subject, $message, $headers);

        return Lexi_Security::success(array(
            'message' => 'إذا كان البريد الإلكتروني مسجلاً، سيتم إرسال رمز التحقق.',
        ));
    }

    /**
     * POST /auth/reset-password
     *
     * Body: { "email": string, "code": string, "new_password": string }
     */
    public static function reset_password(WP_REST_Request $request): WP_REST_Response
    {
        $body = self::request_body($request);

        $email        = sanitize_email((string) ($body['email'] ?? ''));
        $code         = trim((string) ($body['code'] ?? ''));
        $new_password = (string) ($body['new_password'] ?? '');

        if ('' === $email || !is_email($email)) {
            return Lexi_Security::error('invalid_email', 'الرجاء إدخال بريد إلكتروني صحيح.', 422);
        }

        if ('' === $code) {
            return Lexi_Security::error('missing_code', 'رمز التحقق مطلوب.', 422);
        }

        if (strlen($new_password) < 6) {
            return Lexi_Security::error('weak_password', 'كلمة المرور يجب أن تكون 6 أحرف على الأقل.', 422);
        }

        $otp_key = 'lexi_pwd_otp_' . md5($email);
        $stored  = get_transient($otp_key);

        if (false === $stored || !is_array($stored)) {
            return Lexi_Security::error('invalid_code', 'رمز التحقق غير صالح أو منتهي الصلاحية.', 422);
        }

        // Max 5 failed attempts.
        $tries = (int) ($stored['tries'] ?? 0);
        if ($tries >= 5) {
            delete_transient($otp_key);
            return Lexi_Security::error('too_many_tries', 'تم تجاوز عدد المحاولات. اطلب رمزاً جديداً.', 429);
        }

        if (!hash_equals($stored['code'], $code)) {
            $stored['tries'] = $tries + 1;
            set_transient($otp_key, $stored, 15 * MINUTE_IN_SECONDS);
            return Lexi_Security::error('invalid_code', 'رمز التحقق غير صحيح.', 422);
        }

        // OTP valid â€” reset password.
        $user_id = (int) $stored['user_id'];
        wp_set_password($new_password, $user_id);
        Lexi_Auth_Tokens::revoke_all_for_user($user_id);

        // Clean up.
        delete_transient($otp_key);

        return Lexi_Security::success(array(
            'message' => 'تم تغيير كلمة المرور بنجاح. يمكنك تسجيل الدخول الآن.',
        ));
    }

    /**
     * POST /auth/change-password  (authenticated)
     *
     * Body: { "current_password": string, "new_password": string }
     */
    public static function change_password(WP_REST_Request $request): WP_REST_Response
    {
        $user_id = get_current_user_id();
        if ($user_id <= 0) {
            return Lexi_Security::error('unauthorized', 'يلزم تسجيل الدخول.', 401);
        }

        $body = self::request_body($request);

        $current_password = (string) ($body['current_password'] ?? '');
        $new_password     = (string) ($body['new_password'] ?? '');

        if ('' === $current_password) {
            return Lexi_Security::error('missing_current', 'كلمة المرور الحالية مطلوبة.', 422);
        }

        if (strlen($new_password) < 6) {
            return Lexi_Security::error('weak_password', 'كلمة المرور الجديدة يجب أن تكون 6 أحرف على الأقل.', 422);
        }

        $user = get_userdata((int) $user_id);
        if (!$user || !wp_check_password($current_password, $user->user_pass, $user_id)) {
            return Lexi_Security::error('wrong_password', 'كلمة المرور الحالية غير صحيحة.', 403);
        }

        wp_set_password($new_password, (int) $user_id);
        Lexi_Auth_Tokens::revoke_all_for_user((int) $user_id);

        return Lexi_Security::success(array(
            'message' => 'تم تغيير كلمة المرور بنجاح.',
        ));
    }
}
