<?php
/**
 * Access/refresh token helpers for mobile auth sessions.
 *
 * @package Lexi_API
 */

defined('ABSPATH') || exit;

class Lexi_Auth_Tokens
{
    private const TABLE = 'lexi_refresh_tokens';
    private const JWT_ALGORITHM = 'HS256';
    private const DEFAULT_ACCESS_TTL = 900; // 15 minutes
    private const DEFAULT_REFRESH_TTL = 31536000; // 365 days

    /**
     * Create/upgrade the refresh-token table.
     */
    public static function create_table(): void
    {
        global $wpdb;

        $table = self::table_name();
        $charset_collate = $wpdb->get_charset_collate();

        $sql = "CREATE TABLE {$table} (
            id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
            user_id BIGINT UNSIGNED NOT NULL,
            token_hash CHAR(64) NOT NULL,
            family_id VARCHAR(64) NOT NULL,
            replaced_by_hash CHAR(64) NULL,
            revoked_at DATETIME NULL,
            expires_at DATETIME NOT NULL,
            created_at DATETIME NOT NULL,
            last_used_at DATETIME NULL,
            user_agent VARCHAR(255) NULL,
            ip_address VARCHAR(45) NULL,
            PRIMARY KEY (id),
            UNIQUE KEY token_hash (token_hash),
            KEY user_id (user_id),
            KEY family_id (family_id),
            KEY expires_at (expires_at),
            KEY revoked_at (revoked_at)
        ) {$charset_collate};";

        require_once ABSPATH . 'wp-admin/includes/upgrade.php';
        dbDelta($sql);
    }

    /**
     * Issue a new access+refresh token pair for a user.
     *
     * @return array|WP_Error
     */
    public static function issue_token_pair(int $user_id, string $family_id = '')
    {
        self::purge_expired_tokens();

        $user = get_userdata($user_id);
        if (!$user || !self::user_is_active($user)) {
            return new WP_Error('session_invalidated', 'Session is no longer valid.');
        }

        $access_token = self::issue_access_token($user);
        if (is_wp_error($access_token)) {
            return $access_token;
        }

        $refresh_record = self::create_refresh_record($user_id, $family_id);
        if (is_wp_error($refresh_record)) {
            return $refresh_record;
        }

        return array(
            'access_token' => $access_token,
            'refresh_token' => $refresh_record['token'],
            'expires_in' => self::access_ttl(),
            'refresh_expires_in' => self::refresh_ttl(),
        );
    }

    /**
     * Rotate refresh token and issue a fresh access token.
     *
     * @return array|WP_Error
     */
    public static function rotate_refresh_token(string $refresh_token)
    {
        self::purge_expired_tokens();

        $token = trim($refresh_token);
        if ('' === $token) {
            return new WP_Error('invalid_refresh_token', 'Refresh token is required.');
        }

        global $wpdb;
        $table = self::table_name();
        $token_hash = self::hash_token($token);
        $now = self::now_mysql();
        $now_ts = time();

        $row = $wpdb->get_row(
            $wpdb->prepare(
                "SELECT * FROM {$table} WHERE token_hash = %s LIMIT 1",
                $token_hash
            ),
            ARRAY_A
        );

        if (!$row) {
            return new WP_Error('invalid_refresh_token', 'Refresh token is invalid.');
        }

        $user_id = (int) ($row['user_id'] ?? 0);
        $family_id = (string) ($row['family_id'] ?? '');
        $revoked_at = (string) ($row['revoked_at'] ?? '');
        $replaced_by_hash = (string) ($row['replaced_by_hash'] ?? '');
        $expires_at = (string) ($row['expires_at'] ?? '');
        $expires_ts = strtotime($expires_at . ' UTC');
        $is_expired = false !== $expires_ts && $expires_ts <= $now_ts;

        if ('' !== trim($revoked_at) || $is_expired) {
            // Reuse-detection: if this token was already rotated, revoke family.
            if ('' !== trim($replaced_by_hash) && $user_id > 0 && '' !== $family_id) {
                self::revoke_family($user_id, $family_id);
            }
            return new WP_Error('invalid_refresh_token', 'Refresh token is invalid.');
        }

        $user = get_userdata($user_id);
        if (!$user || !self::user_is_active($user)) {
            if ($user_id > 0) {
                self::revoke_all_for_user($user_id);
            }
            return new WP_Error('session_invalidated', 'Session is no longer valid.');
        }

        $next = self::create_refresh_record($user_id, $family_id);
        if (is_wp_error($next)) {
            return $next;
        }

        $updated = $wpdb->query(
            $wpdb->prepare(
                "UPDATE {$table}
                 SET revoked_at = %s, replaced_by_hash = %s, last_used_at = %s
                 WHERE id = %d AND revoked_at IS NULL",
                $now,
                $next['token_hash'],
                $now,
                (int) $row['id']
            )
        );

        if (1 !== (int) $updated) {
            self::revoke_family($user_id, $family_id);
            return new WP_Error('invalid_refresh_token', 'Refresh token is invalid.');
        }

        $access_token = self::issue_access_token($user);
        if (is_wp_error($access_token)) {
            self::revoke_family($user_id, $family_id);
            return $access_token;
        }

        return array(
            'access_token' => $access_token,
            'refresh_token' => $next['token'],
            'expires_in' => self::access_ttl(),
            'refresh_expires_in' => self::refresh_ttl(),
        );
    }

    /**
     * Revoke one refresh token by its raw value.
     */
    public static function revoke_refresh_token(string $refresh_token): void
    {
        $token = trim($refresh_token);
        if ('' === $token) {
            return;
        }

        global $wpdb;
        $table = self::table_name();
        $now = self::now_mysql();
        $hash = self::hash_token($token);

        $wpdb->query(
            $wpdb->prepare(
                "UPDATE {$table}
                 SET revoked_at = %s
                 WHERE token_hash = %s AND revoked_at IS NULL",
                $now,
                $hash
            )
        );
    }

    /**
     * Revoke all refresh tokens for a user.
     */
    public static function revoke_all_for_user(int $user_id): void
    {
        if ($user_id <= 0) {
            return;
        }

        global $wpdb;
        $table = self::table_name();
        $now = self::now_mysql();

        $wpdb->query(
            $wpdb->prepare(
                "UPDATE {$table}
                 SET revoked_at = %s
                 WHERE user_id = %d AND revoked_at IS NULL",
                $now,
                $user_id
            )
        );
    }

    /**
     * Revoke a full token family for reuse protection.
     */
    public static function revoke_family(int $user_id, string $family_id): void
    {
        if ($user_id <= 0 || '' === trim($family_id)) {
            return;
        }

        global $wpdb;
        $table = self::table_name();
        $now = self::now_mysql();

        $wpdb->query(
            $wpdb->prepare(
                "UPDATE {$table}
                 SET revoked_at = %s
                 WHERE user_id = %d AND family_id = %s AND revoked_at IS NULL",
                $now,
                $user_id,
                $family_id
            )
        );
    }

    /**
     * Remove old expired refresh-token rows.
     */
    public static function purge_expired_tokens(): void
    {
        global $wpdb;
        $table = self::table_name();
        $cutoff = gmdate('Y-m-d H:i:s', time() - (30 * DAY_IN_SECONDS));

        $wpdb->query(
            $wpdb->prepare(
                "DELETE FROM {$table} WHERE expires_at < %s",
                $cutoff
            )
        );
    }

    private static function table_name(): string
    {
        global $wpdb;
        return $wpdb->prefix . self::TABLE;
    }

    /**
     * @return array|WP_Error
     */
    private static function create_refresh_record(int $user_id, string $family_id = '')
    {
        global $wpdb;
        $table = self::table_name();

        $token = self::generate_token();
        $token_hash = self::hash_token($token);
        $family = trim($family_id);
        if ('' === $family) {
            $family = wp_generate_uuid4();
        }

        $created_at = self::now_mysql();
        $expires_at = gmdate('Y-m-d H:i:s', time() + self::refresh_ttl());
        $user_agent = self::user_agent();
        $ip_address = self::ip_address();

        $inserted = $wpdb->insert(
            $table,
            array(
                'user_id' => $user_id,
                'token_hash' => $token_hash,
                'family_id' => $family,
                'replaced_by_hash' => null,
                'revoked_at' => null,
                'expires_at' => $expires_at,
                'created_at' => $created_at,
                'last_used_at' => null,
                'user_agent' => $user_agent,
                'ip_address' => $ip_address,
            ),
            array('%d', '%s', '%s', '%s', '%s', '%s', '%s', '%s', '%s', '%s')
        );

        if (false === $inserted) {
            return new WP_Error('token_store_failed', 'Could not store refresh token.');
        }

        return array(
            'token' => $token,
            'token_hash' => $token_hash,
            'family_id' => $family,
            'expires_at' => $expires_at,
        );
    }

    /**
     * @return string|WP_Error
     */
    private static function issue_access_token(WP_User $user)
    {
        if (!defined('JWT_AUTH_SECRET_KEY') || '' === trim((string) JWT_AUTH_SECRET_KEY)) {
            return new WP_Error('jwt_secret_missing', 'JWT auth secret is not configured.');
        }

        if (!class_exists('\Firebase\JWT\JWT')) {
            return new WP_Error('jwt_library_missing', 'JWT library is unavailable.');
        }

        $issued_at = time();
        $not_before = apply_filters('jwt_auth_not_before', $issued_at, $issued_at);
        $expire = apply_filters(
            'jwt_auth_expire',
            $issued_at + self::access_ttl(),
            $issued_at
        );

        $payload = array(
            'iss' => get_bloginfo('url'),
            'iat' => $issued_at,
            'nbf' => $not_before,
            'exp' => $expire,
            'data' => array(
                'user' => array(
                    'id' => (int) $user->ID,
                ),
            ),
        );

        $payload = apply_filters('jwt_auth_token_before_sign', $payload, $user);

        try {
            $jwt = \Firebase\JWT\JWT::encode(
                $payload,
                JWT_AUTH_SECRET_KEY,
                self::JWT_ALGORITHM
            );
        } catch (Exception $e) {
            return new WP_Error('jwt_encode_failed', 'Could not issue access token.');
        }

        $dispatch = apply_filters(
            'jwt_auth_token_before_dispatch',
            array(
                'token' => $jwt,
                'user_email' => $user->user_email,
                'user_nicename' => $user->user_nicename,
                'user_display_name' => $user->display_name,
            ),
            $user
        );

        if (is_array($dispatch) && isset($dispatch['token'])) {
            return (string) $dispatch['token'];
        }

        return $jwt;
    }

    private static function user_is_active(WP_User $user): bool
    {
        if ((int) $user->user_status !== 0) {
            return false;
        }

        return !empty((array) $user->roles);
    }

    private static function access_ttl(): int
    {
        $value = (int) apply_filters('lexi_auth_access_ttl', self::DEFAULT_ACCESS_TTL);
        return $value > 60 ? $value : self::DEFAULT_ACCESS_TTL;
    }

    private static function refresh_ttl(): int
    {
        $value = (int) apply_filters('lexi_auth_refresh_ttl', self::DEFAULT_REFRESH_TTL);
        return $value > DAY_IN_SECONDS ? $value : self::DEFAULT_REFRESH_TTL;
    }

    private static function generate_token(): string
    {
        try {
            return bin2hex(random_bytes(48));
        } catch (Exception $e) {
            return hash('sha256', wp_generate_password(64, true, true) . wp_rand());
        }
    }

    private static function hash_token(string $token): string
    {
        return hash('sha256', $token);
    }

    private static function now_mysql(): string
    {
        return (string) current_time('mysql', true);
    }

    private static function user_agent(): string
    {
        if (empty($_SERVER['HTTP_USER_AGENT'])) {
            return '';
        }
        return substr(sanitize_text_field(wp_unslash($_SERVER['HTTP_USER_AGENT'])), 0, 255);
    }

    private static function ip_address(): string
    {
        $raw = '';
        if (!empty($_SERVER['HTTP_X_FORWARDED_FOR'])) {
            $raw = (string) wp_unslash($_SERVER['HTTP_X_FORWARDED_FOR']);
            $parts = explode(',', $raw);
            $raw = trim((string) ($parts[0] ?? ''));
        } elseif (!empty($_SERVER['REMOTE_ADDR'])) {
            $raw = (string) wp_unslash($_SERVER['REMOTE_ADDR']);
        }

        if ('' === $raw) {
            return '';
        }

        return substr(sanitize_text_field($raw), 0, 45);
    }
}
