<?php
/**
 * Access/refresh token session helpers for Lexi API auth.
 *
 * @package Lexi_API
 */

defined('ABSPATH') || exit;

class Lexi_Auth_Session
{
    private const ACCESS_TTL_SECONDS = 900; // 15 minutes.
    private const REFRESH_TTL_SECONDS = 15552000; // 180 days.
    private const REFRESH_META_KEY = '_lexi_refresh_tokens';
    private const MAX_REFRESH_TOKENS_PER_USER = 10;

    /**
     * Hook request authentication for Lexi REST namespace.
     */
    public static function init(): void
    {
        add_filter('determine_current_user', array(__CLASS__, 'determine_current_user'), 25);
    }

    /**
     * Authenticate Bearer tokens for /lexi/v1 routes.
     *
     * @param int|false $user_id Current resolved user.
     * @return int|false
     */
    public static function determine_current_user($user_id)
    {
        if (!empty($user_id)) {
            return $user_id;
        }

        if (!defined('REST_REQUEST') || !REST_REQUEST) {
            return $user_id;
        }

        if (!self::is_lexi_rest_request()) {
            return $user_id;
        }

        $token = self::read_bearer_token();
        if ('' === $token) {
            return $user_id;
        }

        $payload = self::decode_access_token($token);
        if (!is_array($payload)) {
            return $user_id;
        }

        $resolved_id = absint($payload['sub'] ?? 0);
        if ($resolved_id <= 0) {
            return $user_id;
        }

        $user = get_user_by('id', $resolved_id);
        if (!$user instanceof WP_User) {
            return $user_id;
        }

        return (int) $resolved_id;
    }

    /**
     * Create a full auth session for a user.
     *
     * @return array<string, mixed>|null
     */
    public static function issue_session(int $user_id): ?array
    {
        $user = get_user_by('id', $user_id);
        if (!$user instanceof WP_User) {
            return null;
        }

        $access = self::create_access_token((int) $user_id);
        if ('' === $access) {
            return null;
        }

        $refresh = self::create_refresh_token($user);
        if ('' === $refresh) {
            return null;
        }

        return array(
            'access_token' => $access,
            'refresh_token' => $refresh,
            'expires_in' => self::ACCESS_TTL_SECONDS,
        );
    }

    /**
     * Rotate refresh token and return a fresh auth session.
     *
     * @return array<string, mixed>|null
     */
    public static function refresh_session(string $refresh_token): ?array
    {
        $validated = self::validate_refresh_token($refresh_token);
        if (!is_array($validated)) {
            return null;
        }

        $user_id = absint($validated['user_id'] ?? 0);
        if ($user_id <= 0) {
            return null;
        }

        $user = get_user_by('id', $user_id);
        if (!$user instanceof WP_User) {
            return null;
        }

        // Refresh is invalidated on password changes.
        if (($validated['pwd_sig'] ?? '') !== self::password_signature($user)) {
            self::revoke_refresh_token($user_id, $refresh_token);
            return null;
        }

        $session = self::issue_session($user_id);
        if (!is_array($session)) {
            return null;
        }

        self::revoke_refresh_token($user_id, $refresh_token);
        return $session;
    }

    /**
     * Revoke a specific refresh token for a user.
     */
    public static function revoke_refresh_token(int $user_id, string $refresh_token): void
    {
        $parts = self::parse_refresh_token($refresh_token);
        if (!is_array($parts)) {
            return;
        }

        $token_id = (string) ($parts['token_id'] ?? '');
        if ('' === $token_id) {
            return;
        }

        $tokens = self::read_refresh_tokens($user_id);
        if (empty($tokens)) {
            return;
        }

        $changed = false;
        foreach ($tokens as &$token) {
            if (($token['id'] ?? '') === $token_id && empty($token['revoked'])) {
                $token['revoked'] = 1;
                $token['revoked_at'] = time();
                $changed = true;
            }
        }
        unset($token);

        if ($changed) {
            update_user_meta($user_id, self::REFRESH_META_KEY, $tokens);
        }
    }

    /**
     * Revoke all refresh tokens for a user.
     */
    public static function revoke_all_refresh_tokens(int $user_id): void
    {
        delete_user_meta($user_id, self::REFRESH_META_KEY);
    }

    /**
     * Validate refresh token format + signature + expiry.
     *
     * @return array<string, mixed>|null
     */
    public static function validate_refresh_token(string $refresh_token): ?array
    {
        $parts = self::parse_refresh_token($refresh_token);
        if (!is_array($parts)) {
            return null;
        }

        $user_id = absint($parts['user_id'] ?? 0);
        $token_id = (string) ($parts['token_id'] ?? '');
        $secret = (string) ($parts['secret'] ?? '');

        if ($user_id <= 0 || '' === $token_id || '' === $secret) {
            return null;
        }

        $tokens = self::read_refresh_tokens($user_id);
        if (empty($tokens)) {
            return null;
        }

        $secret_hash = self::hash_refresh_secret($secret);
        $now = time();
        $changed = false;
        $matched = null;

        foreach ($tokens as $idx => $token) {
            $expires_at = (int) ($token['expires_at'] ?? 0);
            $revoked = !empty($token['revoked']);
            if ($expires_at > 0 && $expires_at <= $now) {
                $tokens[$idx]['revoked'] = 1;
                $tokens[$idx]['revoked_at'] = $now;
                $changed = true;
                continue;
            }

            if ($revoked) {
                continue;
            }

            if (($token['id'] ?? '') !== $token_id) {
                continue;
            }

            $stored_hash = (string) ($token['hash'] ?? '');
            if ('' !== $stored_hash && hash_equals($stored_hash, $secret_hash)) {
                $matched = $token;
                break;
            }
        }

        if ($changed) {
            update_user_meta($user_id, self::REFRESH_META_KEY, $tokens);
        }

        if (!is_array($matched)) {
            return null;
        }

        return array(
            'user_id' => $user_id,
            'token_id' => $token_id,
            'pwd_sig' => (string) ($matched['pwd_sig'] ?? ''),
        );
    }

    /**
     * Return access token TTL in seconds.
     */
    public static function access_ttl(): int
    {
        return self::ACCESS_TTL_SECONDS;
    }

    /**
     * Create a signed JWT access token.
     */
    private static function create_access_token(int $user_id): string
    {
        if ($user_id <= 0) {
            return '';
        }

        $header = array(
            'alg' => 'HS256',
            'typ' => 'JWT',
        );
        $now = time();
        $payload = array(
            'iss' => home_url('/'),
            'sub' => $user_id,
            'iat' => $now,
            'exp' => $now + self::ACCESS_TTL_SECONDS,
        );

        return self::encode_jwt($header, $payload);
    }

    /**
     * Decode + validate access token.
     *
     * @return array<string, mixed>|null
     */
    private static function decode_access_token(string $token): ?array
    {
        $parts = explode('.', $token);
        if (count($parts) !== 3) {
            return null;
        }

        $encoded_header = $parts[0];
        $encoded_payload = $parts[1];
        $encoded_sig = $parts[2];

        $raw_sig = self::base64url_decode($encoded_sig);
        if ('' === $raw_sig) {
            return null;
        }

        $expected_sig = hash_hmac('sha256', $encoded_header . '.' . $encoded_payload, self::access_secret(), true);
        if (!hash_equals($expected_sig, $raw_sig)) {
            return null;
        }

        $payload_json = self::base64url_decode($encoded_payload);
        if ('' === $payload_json) {
            return null;
        }

        $payload = json_decode($payload_json, true);
        if (!is_array($payload)) {
            return null;
        }

        $exp = (int) ($payload['exp'] ?? 0);
        if ($exp <= 0 || $exp < time()) {
            return null;
        }

        return $payload;
    }

    /**
     * Create a new refresh token and persist hash only.
     */
    private static function create_refresh_token(WP_User $user): string
    {
        $user_id = (int) $user->ID;
        if ($user_id <= 0) {
            return '';
        }

        try {
            $token_id = bin2hex(random_bytes(8));
            $secret = bin2hex(random_bytes(32));
        } catch (Exception $e) {
            return '';
        }

        $tokens = self::read_refresh_tokens($user_id);
        $tokens = self::cleanup_refresh_tokens($tokens);

        $tokens[] = array(
            'id' => $token_id,
            'hash' => self::hash_refresh_secret($secret),
            'created_at' => time(),
            'expires_at' => time() + self::REFRESH_TTL_SECONDS,
            'revoked' => 0,
            'revoked_at' => 0,
            'pwd_sig' => self::password_signature($user),
        );

        if (count($tokens) > self::MAX_REFRESH_TOKENS_PER_USER) {
            usort($tokens, function ($a, $b) {
                return (int) ($a['created_at'] ?? 0) <=> (int) ($b['created_at'] ?? 0);
            });
            $tokens = array_slice($tokens, -self::MAX_REFRESH_TOKENS_PER_USER);
        }

        update_user_meta($user_id, self::REFRESH_META_KEY, array_values($tokens));

        return $user_id . '.' . $token_id . '.' . $secret;
    }

    /**
     * @param array<int, mixed> $tokens
     * @return array<int, array<string, mixed>>
     */
    private static function cleanup_refresh_tokens(array $tokens): array
    {
        $now = time();
        $clean = array();
        foreach ($tokens as $token) {
            if (!is_array($token)) {
                continue;
            }
            if (!empty($token['revoked'])) {
                continue;
            }
            $expires_at = (int) ($token['expires_at'] ?? 0);
            if ($expires_at > 0 && $expires_at <= $now) {
                continue;
            }
            $clean[] = $token;
        }

        return $clean;
    }

    /**
     * @return array<int, array<string, mixed>>
     */
    private static function read_refresh_tokens(int $user_id): array
    {
        $raw = get_user_meta($user_id, self::REFRESH_META_KEY, true);
        if (!is_array($raw)) {
            return array();
        }

        $items = array();
        foreach ($raw as $row) {
            if (!is_array($row)) {
                continue;
            }
            $items[] = $row;
        }

        return $items;
    }

    /**
     * @return array<string, string|int>|null
     */
    private static function parse_refresh_token(string $refresh_token): ?array
    {
        $parts = explode('.', trim($refresh_token));
        if (count($parts) !== 3) {
            return null;
        }

        $user_id = absint($parts[0]);
        $token_id = sanitize_key($parts[1]);
        $secret = trim((string) $parts[2]);

        if ($user_id <= 0 || '' === $token_id || '' === $secret) {
            return null;
        }

        return array(
            'user_id' => $user_id,
            'token_id' => $token_id,
            'secret' => $secret,
        );
    }

    /**
     * Encode JWT as base64url(header).base64url(payload).signature.
     *
     * @param array<string, mixed> $header
     * @param array<string, mixed> $payload
     */
    private static function encode_jwt(array $header, array $payload): string
    {
        $encoded_header = self::base64url_encode((string) wp_json_encode($header));
        $encoded_payload = self::base64url_encode((string) wp_json_encode($payload));
        $signature = hash_hmac('sha256', $encoded_header . '.' . $encoded_payload, self::access_secret(), true);
        $encoded_signature = self::base64url_encode($signature);

        return $encoded_header . '.' . $encoded_payload . '.' . $encoded_signature;
    }

    private static function access_secret(): string
    {
        if (defined('JWT_AUTH_SECRET_KEY') && '' !== trim((string) JWT_AUTH_SECRET_KEY)) {
            return (string) JWT_AUTH_SECRET_KEY;
        }

        if (defined('AUTH_KEY') && '' !== trim((string) AUTH_KEY)) {
            return (string) AUTH_KEY;
        }

        return (string) wp_salt('auth');
    }

    private static function hash_refresh_secret(string $secret): string
    {
        return hash_hmac('sha256', $secret, (string) wp_salt('nonce'));
    }

    private static function password_signature(WP_User $user): string
    {
        $raw = (string) ($user->user_pass ?? '');
        return hash_hmac('sha256', $raw, (string) wp_salt('auth'));
    }

    private static function base64url_encode(string $input): string
    {
        return rtrim(strtr(base64_encode($input), '+/', '-_'), '=');
    }

    private static function base64url_decode(string $input): string
    {
        $remainder = strlen($input) % 4;
        if ($remainder > 0) {
            $input .= str_repeat('=', 4 - $remainder);
        }

        $decoded = base64_decode(strtr($input, '-_', '+/'), true);
        return false === $decoded ? '' : $decoded;
    }

    private static function read_bearer_token(): string
    {
        $header = '';
        if (!empty($_SERVER['HTTP_AUTHORIZATION'])) {
            $header = (string) wp_unslash($_SERVER['HTTP_AUTHORIZATION']);
        } elseif (!empty($_SERVER['REDIRECT_HTTP_AUTHORIZATION'])) {
            $header = (string) wp_unslash($_SERVER['REDIRECT_HTTP_AUTHORIZATION']);
        } elseif (function_exists('getallheaders')) {
            $headers = getallheaders();
            if (is_array($headers)) {
                $header = (string) ($headers['Authorization'] ?? $headers['authorization'] ?? '');
            }
        }

        if (preg_match('/Bearer\s+(.+)/i', $header, $matches)) {
            return trim((string) $matches[1]);
        }

        return '';
    }

    private static function is_lexi_rest_request(): bool
    {
        $uri = isset($_SERVER['REQUEST_URI']) ? (string) $_SERVER['REQUEST_URI'] : '';
        if ('' === $uri) {
            return false;
        }

        // Standard pretty permalinks
        if (false !== strpos($uri, '/wp-json/' . LEXI_API_NAMESPACE)) {
            return true;
        }

        // Query param rest_route (common in some setups or when permalinks are off)
        $rest_route = isset($_GET['rest_route']) ? (string) wp_unslash($_GET['rest_route']) : '';
        if ('' !== $rest_route && 0 === strpos(trim($rest_route, '/'), LEXI_API_NAMESPACE)) {
            return true;
        }

        // Support for cases where rest_route might be in the URI string directly
        if (false !== strpos($uri, 'rest_route=/' . LEXI_API_NAMESPACE) || false !== strpos($uri, 'rest_route=' . LEXI_API_NAMESPACE)) {
            return true;
        }

        return false;
    }
}

