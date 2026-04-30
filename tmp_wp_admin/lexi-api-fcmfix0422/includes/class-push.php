<?php
/**
 * Firebase push settings, token registry, and campaign diagnostics.
 *
 * @package Lexi_API
 */

defined('ABSPATH') || exit;

class Lexi_Push
{
    private const SETTINGS_OPTION = 'lexi_push_settings_v1';
    private const TABLE_TOKENS = 'lexi_push_tokens';
    private const TABLE_CAMPAIGNS = 'lexi_notification_campaigns';
    private const FCM_SCOPE = 'https://www.googleapis.com/auth/firebase.messaging';
    private const FCM_TOKEN_TRANSIENT = 'lexi_fcm_http_v1_access_token_v1';

    /**
     * Create DB tables used by push notifications.
     */
    public static function create_tables(): void
    {
        global $wpdb;

        $charset_collate = $wpdb->get_charset_collate();
        $tokens_table = self::tokens_table();
        $campaigns_table = self::campaigns_table();

        $sql_tokens = "CREATE TABLE {$tokens_table} (
            id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
            user_id BIGINT UNSIGNED NULL,
            role VARCHAR(64) NOT NULL DEFAULT 'guest',
            device_id VARCHAR(128) NULL,
            fcm_token TEXT NOT NULL,
            platform VARCHAR(32) NOT NULL DEFAULT 'android',
            app_version VARCHAR(64) NULL,
            last_seen_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
            created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
            updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
            PRIMARY KEY (id),
            KEY idx_user_id (user_id),
            KEY idx_role (role),
            KEY idx_device_id (device_id),
            KEY idx_platform (platform)
        ) {$charset_collate};";

        $sql_campaigns = "CREATE TABLE {$campaigns_table} (
            id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
            created_by BIGINT UNSIGNED NULL,
            target VARCHAR(32) NOT NULL,
            audience VARCHAR(32) NOT NULL DEFAULT 'customer',
            type VARCHAR(32) NOT NULL DEFAULT 'manual',
            title_ar VARCHAR(191) NOT NULL,
            body_ar TEXT NOT NULL,
            image_url TEXT NULL,
            deep_link TEXT NULL,
            open_mode VARCHAR(32) NOT NULL DEFAULT 'in_app',
            targeted_count INT UNSIGNED NOT NULL DEFAULT 0,
            stored_count INT UNSIGNED NOT NULL DEFAULT 0,
            push_success INT UNSIGNED NOT NULL DEFAULT 0,
            push_failed INT UNSIGNED NOT NULL DEFAULT 0,
            provider_status VARCHAR(32) NOT NULL DEFAULT 'none',
            provider_error TEXT NULL,
            meta_json LONGTEXT NULL,
            created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
            PRIMARY KEY (id),
            KEY idx_created_at (created_at),
            KEY idx_target (target),
            KEY idx_audience (audience)
        ) {$charset_collate};";

        require_once ABSPATH . 'wp-admin/includes/upgrade.php';
        dbDelta($sql_tokens);
        dbDelta($sql_campaigns);
    }

    public static function tokens_table(): string
    {
        global $wpdb;
        return $wpdb->prefix . self::TABLE_TOKENS;
    }

    public static function campaigns_table(): string
    {
        global $wpdb;
        return $wpdb->prefix . self::TABLE_CAMPAIGNS;
    }
    public static function clear_all_tokens(): void
    {
        global $wpdb;
        $table = self::tokens_table();
        $wpdb->query("TRUNCATE TABLE {$table}");
    }

    /**
     * Register/update FCM token for current device.
     *
     * @param array<string,mixed> $payload
     * @return array<string,mixed>
     */
    public static function register_token(array $payload): array
    {
        global $wpdb;

        $token = trim((string) ($payload['fcm_token'] ?? $payload['token'] ?? ''));
        $device_id = sanitize_text_field((string) ($payload['device_id'] ?? ''));
        $platform = strtolower(trim((string) ($payload['platform'] ?? 'android')));
        $app_version = sanitize_text_field((string) ($payload['app_version'] ?? ''));
        $incoming_role = sanitize_text_field((string) ($payload['role'] ?? ''));

        if ($token === '') {
            return array(
                'success' => false,
                'code' => 'missing_fcm_token',
                'message' => 'معرّف الإشعار (FCM token) مطلوب.',
            );
        }

        if (strlen($token) < 20) {
            return array(
                'success' => false,
                'code' => 'invalid_fcm_token',
                'message' => 'معرّف الإشعار غير صالح.',
            );
        }

        if (!in_array($platform, array('android', 'ios', 'web', 'unknown'), true)) {
            $platform = 'unknown';
        }

        $user_id = absint((int) ($payload['user_id'] ?? 0));
        if ($user_id <= 0) {
            $user_id = get_current_user_id();
        }
        $role = self::resolve_role($incoming_role, $user_id);

        $table = self::tokens_table();
        $now = current_time('mysql', true);
        if (!self::ensure_tokens_table_exists()) {
            return array(
                'success' => false,
                'code' => 'tokens_table_missing',
                'message' => 'FCM tokens table is missing. Please run plugin DB setup.',
            );
        }

        $existing_id = 0;
        if ($device_id !== '') {
            $existing_id = (int) $wpdb->get_var(
                $wpdb->prepare(
                    "SELECT id FROM {$table} WHERE device_id = %s ORDER BY id DESC LIMIT 1",
                    $device_id
                )
            );
        }
        if ($existing_id <= 0) {
            $existing_id = (int) $wpdb->get_var(
                $wpdb->prepare(
                    "SELECT id FROM {$table} WHERE fcm_token = %s LIMIT 1",
                    $token
                )
            );
        }

        $duplicate_token_id = (int) $wpdb->get_var(
            $wpdb->prepare(
                "SELECT id FROM {$table} WHERE fcm_token = %s LIMIT 1",
                $token
            )
        );
        if ($duplicate_token_id > 0 && $duplicate_token_id !== $existing_id) {
            $wpdb->delete($table, array('id' => $duplicate_token_id), array('%d'));
        }

        $row = array(
            'user_id' => $user_id > 0 ? $user_id : null,
            'device_id' => $device_id !== '' ? $device_id : null,
            'fcm_token' => $token,
            'platform' => $platform,
            'app_version' => $app_version !== '' ? $app_version : null,
            'last_seen_at' => $now,
            'updated_at' => $now,
        );
        if (self::tokens_table_has_column('role')) {
            $row['role'] = $role;
        }

        if ($existing_id > 0) {
            $updated = $wpdb->update(
                $table,
                $row,
                array('id' => $existing_id)
            );
            if ($updated === false) {
                return array(
                    'success' => false,
                    'code' => 'token_update_failed',
                    'message' => 'Could not update device token.',
                );
            }
            $id = $existing_id;
        } else {
            $row['created_at'] = $now;
            $inserted = $wpdb->insert($table, $row);
            if ($inserted === false || (int) $wpdb->insert_id <= 0) {
                return array(
                    'success' => false,
                    'code' => 'token_insert_failed',
                    'message' => 'Could not store device token.',
                );
            }
            $id = (int) $wpdb->insert_id;
        }

        error_log(sprintf('[Lexi Push] Registered: %s | Device: %s | Platform: %s | Role: %s', substr($token, -10), $device_id, $platform, $role));

        return array(
            'success' => true,
            'id' => $id,
            'user_id' => $user_id > 0 ? $user_id : null,
            'role' => $role,
            'device_id' => $device_id !== '' ? $device_id : null,
            'platform' => $platform,
        );
    }

    /**
     *
     * @return array<string,mixed>
     */
    public static function get_settings(bool $mask_secret = true): array
    {
        $stored = get_option(self::SETTINGS_OPTION, array());
        $settings = self::sanitize_settings(is_array($stored) ? $stored : array());
        $config_details = self::describe_fcm_configuration($settings);

        if ($mask_secret) {
            $settings['has_server_key'] = trim((string) $settings['server_key']) !== '';
            $settings['server_key'] = self::mask_secret((string) $settings['server_key']);
            $settings['has_fcm_service_account_path'] = trim((string) $settings['fcm_service_account_path']) !== '';
            $settings['fcm_service_account_path'] = self::mask_path((string) $settings['fcm_service_account_path']);
        }

        $settings['effective_project_id'] = $config_details['effective_project_id'];
        $settings['service_account_project_id'] = $config_details['service_account_project_id'];
        $settings['config_warning'] = $config_details['config_warning'];
        return $settings;
    }

    /**
     * Save push settings.
     *
     * @param array<string,mixed> $payload
     * @return array<string,mixed>
     */
    public static function save_settings(array $payload): array
    {
        $current = self::sanitize_settings((array) get_option(self::SETTINGS_OPTION, array()));
        $incoming = self::sanitize_settings(array_merge($current, $payload));
        $merged = $current;

        foreach (array(
            'enabled',
            'provider',
            'default_open_mode',
            'default_image_url',
            'ttl_seconds',
            'fcm_project_id',
        ) as $field) {
            if (array_key_exists($field, $payload)) {
                $merged[$field] = $incoming[$field];
            }
        }

        // Handle secrets: only update if the new value is NOT masked and NOT empty
        if (array_key_exists('server_key', $payload)) {
            $raw = trim((string) $payload['server_key']);
            if ($raw !== '' && strpos($raw, '*') === false) {
                $merged['server_key'] = $raw;
            }
        }
        if (array_key_exists('fcm_service_account_path', $payload)) {
            $raw = trim((string) $payload['fcm_service_account_path']);
            if ($raw !== '' && strpos($raw, '*') === false) {
                $merged['fcm_service_account_path'] = $raw;
            }
        }

        update_option(self::SETTINGS_OPTION, $merged, false);

        return self::get_settings(true);
    }

    /**
     * Send push notification via Firebase Cloud Messaging HTTP v1.
     *
     * @param array<string,mixed> $payload
     * @return array<string,mixed>
     */
    public static function send_push_for_target(array $payload): array
    {
        $title_ar = self::normalize_text((string) ($payload['title_ar'] ?? ''));
        $body_ar = self::normalize_text((string) ($payload['body_ar'] ?? ''));
        $target = sanitize_text_field((string) ($payload['target'] ?? 'broadcast'));
        $audience = sanitize_text_field((string) ($payload['audience'] ?? 'customer'));
        $type = sanitize_text_field((string) ($payload['type'] ?? 'manual'));
        $image_url = esc_url_raw((string) ($payload['image_url'] ?? ''));
        $deep_link = trim((string) ($payload['deep_link'] ?? ''));
        $open_mode = sanitize_text_field((string) ($payload['open_mode'] ?? 'in_app'));
        $user_id = absint((int) ($payload['user_id'] ?? 0));
        $device_id = sanitize_text_field((string) ($payload['device_id'] ?? ''));
        $campaign_id = absint((int) ($payload['campaign_id'] ?? 0));
        $priority = strtolower(trim((string) ($payload['priority'] ?? 'high')));
        if (!in_array($priority, array('high', 'normal'), true)) {
            $priority = 'high';
        }
        $data_only = self::to_bool_int($payload['data_only'] ?? false) === 1;
        $android_channel_id = sanitize_text_field((string) ($payload['android_channel_id'] ?? ''));
        $android_sound = sanitize_text_field((string) ($payload['android_sound'] ?? ''));
        $android_visibility = sanitize_text_field((string) ($payload['android_visibility'] ?? ''));
        $android_category = sanitize_text_field((string) ($payload['android_category'] ?? ''));
        $android_full_screen_intent = self::to_bool_int($payload['android_full_screen_intent'] ?? false) === 1;
        $extra_data = isset($payload['extra_data']) && is_array($payload['extra_data']) ? $payload['extra_data'] : array();
        $order_id = absint((int) ($payload['order_id'] ?? 0));

        $settings = self::get_settings(false);
        $provider = sanitize_text_field((string) ($settings['provider'] ?? 'fcm_http_v1'));
        if (!in_array($provider, array('fcm_http_v1', 'legacy_server_key'), true)) {
            $provider = 'fcm_http_v1';
        }
        $tokens = self::collect_tokens_for_target($target, $audience, $user_id, $device_id);
        $targeted_count = count($tokens);

        $result = array(
            'targeted_count' => $targeted_count,
            'push_success' => 0,
            'push_failed' => 0,
            'provider_status' => 'skipped',
            'provider_error' => '',
        );

        if ($targeted_count <= 0) {
            $result['provider_status'] = 'no_tokens';
            return $result;
        }

        if ((int) ($settings['enabled'] ?? 0) !== 1) {
            $result['provider_status'] = 'disabled';
            return $result;
        }

        if ($image_url === '') {
            $image_url = trim((string) ($settings['default_image_url'] ?? ''));
        }

        $notification = array();
        if (!$data_only) {
            $notification = array(
                'title' => $title_ar,
                'body' => $body_ar,
            );
        }
        if (!$data_only && $image_url !== '') {
            $notification['image'] = $image_url;
        }

        $data = self::normalize_data_payload(array(
            'type' => $type,
            'target' => $target,
            'audience' => $audience,
            'deep_link' => $deep_link,
            'open_mode' => $open_mode,
            'image_url' => $image_url,
            'android_channel_id' => $android_channel_id,
            'android_sound' => $android_sound,
            'android_visibility' => $android_visibility,
            'android_category' => $android_category,
            'android_full_screen_intent' => $android_full_screen_intent ? '1' : '0',
        ));
        if ($campaign_id > 0) {
            $data['campaign_id'] = (string) $campaign_id;
        }
        if (!empty($extra_data)) {
            $data = array_merge($data, self::normalize_data_payload($extra_data));
        }

        $ttl_seconds = max(
            60,
            (int) ($payload['ttl_seconds'] ?? $settings['ttl_seconds'] ?? 3600)
        );

        $delivery_options = array(
            'priority' => $priority,
            'ttl_seconds' => $ttl_seconds,
            'data_only' => $data_only,
            'android_channel_id' => $android_channel_id,
            'android_sound' => $android_sound,
            'android_visibility' => $android_visibility,
            'android_category' => $android_category,
            'android_full_screen_intent' => $android_full_screen_intent,
            'target' => $target,
            'audience' => $audience,
            'user_id' => $user_id,
            'order_id' => $order_id,
        );

        if ($provider === 'legacy_server_key') {
            $delivery = self::send_via_fcm_legacy_server_key(
                $tokens,
                $notification,
                $data,
                $settings,
                $delivery_options
            );
        } else {
            $delivery = self::send_via_fcm_http_v1(
                $tokens,
                $notification,
                $data,
                $settings,
                $delivery_options
            );

            $should_fallback_to_legacy = self::should_fallback_to_legacy_provider($delivery, $settings);

            if ($should_fallback_to_legacy) {
                $legacy_delivery = self::send_via_fcm_legacy_server_key(
                    $tokens,
                    $notification,
                    $data,
                    $settings,
                    $delivery_options
                );

                $delivery = array(
                    'status' => (string) ($legacy_delivery['status'] ?? $delivery['status'] ?? 'failed'),
                    'success' => (int) ($legacy_delivery['success'] ?? 0),
                    'failed' => (int) ($legacy_delivery['failed'] ?? 0),
                    'error' => trim(
                        implode(' | ', array_filter(array(
                            'HTTP v1 fallback: ' . (string) ($delivery['error'] ?? ''),
                            (string) ($legacy_delivery['error'] ?? ''),
                        )))
                    ),
                );
            }
        }

        $result['push_success'] = (int) ($delivery['success'] ?? 0);
        $result['push_failed'] = (int) ($delivery['failed'] ?? 0);
        $result['provider_status'] = (string) ($delivery['status'] ?? 'failed');
        $result['provider_error'] = (string) ($delivery['error'] ?? '');

        return $result;
    }

    /**
     * Store campaign diagnostics.
     *
     * @param array<string,mixed> $payload
     */
    public static function save_campaign(array $payload): int
    {
        global $wpdb;

        $table = self::campaigns_table();
        $created_at = current_time('mysql', true);

        $insert = array(
            'created_by' => absint((int) ($payload['created_by'] ?? 0)) ?: null,
            'target' => sanitize_text_field((string) ($payload['target'] ?? 'broadcast')),
            'audience' => sanitize_text_field((string) ($payload['audience'] ?? 'customer')),
            'type' => sanitize_text_field((string) ($payload['type'] ?? 'manual')),
            'title_ar' => self::normalize_text((string) ($payload['title_ar'] ?? '')),
            'body_ar' => self::normalize_text((string) ($payload['body_ar'] ?? '')),
            'image_url' => esc_url_raw((string) ($payload['image_url'] ?? '')),
            'deep_link' => trim((string) ($payload['deep_link'] ?? '')),
            'open_mode' => sanitize_text_field((string) ($payload['open_mode'] ?? 'in_app')),
            'targeted_count' => max(0, (int) ($payload['targeted_count'] ?? 0)),
            'stored_count' => max(0, (int) ($payload['stored_count'] ?? 0)),
            'push_success' => max(0, (int) ($payload['push_success'] ?? 0)),
            'push_failed' => max(0, (int) ($payload['push_failed'] ?? 0)),
            'provider_status' => sanitize_text_field((string) ($payload['provider_status'] ?? 'none')),
            'provider_error' => sanitize_textarea_field((string) ($payload['provider_error'] ?? '')),
            'meta_json' => !empty($payload['meta']) ? wp_json_encode($payload['meta'], JSON_UNESCAPED_UNICODE) : null,
            'created_at' => $created_at,
        );

        $wpdb->insert($table, $insert);
        return (int) $wpdb->insert_id;
    }

    /**
     * Return paginated campaigns history.
     *
     * @return array<string,mixed>
     */
    public static function list_campaigns(int $page = 1, int $per_page = 20): array
    {
        global $wpdb;

        $page = max(1, $page);
        $per_page = min(100, max(1, $per_page));
        $offset = ($page - 1) * $per_page;

        $table = self::campaigns_table();
        $total = (int) $wpdb->get_var("SELECT COUNT(*) FROM {$table}");

        $rows = $wpdb->get_results(
            $wpdb->prepare(
                "SELECT *
                 FROM {$table}
                 ORDER BY id DESC
                 LIMIT %d OFFSET %d",
                $per_page,
                $offset
            ),
            ARRAY_A
        );

        $items = array_map(static function ($row) {
            $meta = array();
            if (!empty($row['meta_json'])) {
                $decoded = json_decode((string) $row['meta_json'], true);
                if (is_array($decoded)) {
                    $meta = $decoded;
                }
            }

            return array(
                'id' => (int) $row['id'],
                'created_by' => !empty($row['created_by']) ? (int) $row['created_by'] : null,
                'target' => (string) $row['target'],
                'audience' => (string) $row['audience'],
                'type' => (string) $row['type'],
                'title_ar' => self::normalize_text((string) $row['title_ar']),
                'body_ar' => self::normalize_text((string) $row['body_ar']),
                'image_url' => (string) ($row['image_url'] ?? ''),
                'deep_link' => (string) ($row['deep_link'] ?? ''),
                'open_mode' => (string) ($row['open_mode'] ?? 'in_app'),
                'targeted_count' => (int) ($row['targeted_count'] ?? 0),
                'stored_count' => (int) ($row['stored_count'] ?? 0),
                'push_success' => (int) ($row['push_success'] ?? 0),
                'push_failed' => (int) ($row['push_failed'] ?? 0),
                'provider_status' => (string) ($row['provider_status'] ?? 'none'),
                'provider_error' => (string) ($row['provider_error'] ?? ''),
                'meta' => $meta,
                'created_at' => (string) ($row['created_at'] ?? ''),
            );
        }, is_array($rows) ? $rows : array());

        return array(
            'items' => array_values($items),
            'page' => $page,
            'per_page' => $per_page,
            'total' => $total,
            'total_pages' => max(1, (int) ceil($total / $per_page)),
        );
    }

    /**
     * @return array<int,string>
     */
    public static function collect_tokens_for_target(
        string $target,
        string $audience = 'customer',
        int $user_id = 0,
        string $device_id = ''
    ): array {
        global $wpdb;
        $table = self::tokens_table();
        $target = trim($target);
        $audience = trim($audience);
        $device_id = trim($device_id);

        if ($target === 'everyone') {
            return self::clean_tokens(
                (array) $wpdb->get_col("SELECT fcm_token FROM {$table}")
            );
        }

        if ($target === 'specific_user' && $user_id > 0) {
            return self::clean_tokens(
                (array) $wpdb->get_col(
                    $wpdb->prepare(
                        "SELECT fcm_token FROM {$table} WHERE user_id = %d",
                        $user_id
                    )
                )
            );
        }

        if ($target === 'specific_device' && $device_id !== '') {
            return self::clean_tokens(
                (array) $wpdb->get_col(
                    $wpdb->prepare(
                        "SELECT fcm_token FROM {$table} WHERE device_id = %s",
                        $device_id
                    )
                )
            );
        }

        $admin_ids = self::get_admin_user_ids();
        if ($target === 'all_admins' || $audience === 'admin') {
            return self::tokens_by_user_ids($admin_ids);
        }
        if ($target === 'all_couriers' || $audience === 'courier') {
            return self::tokens_by_user_ids(self::get_courier_user_ids());
        }

        // Broadcast to customers: include guest tokens and non-admin users.
        if (empty($admin_ids)) {
            return self::clean_tokens(
                (array) $wpdb->get_col("SELECT fcm_token FROM {$table}")
            );
        }

        $placeholders = implode(',', array_fill(0, count($admin_ids), '%d'));
        $query = "SELECT fcm_token
                  FROM {$table}
                  WHERE user_id IS NULL OR user_id NOT IN ({$placeholders})";
        return self::clean_tokens((array) $wpdb->get_col($wpdb->prepare($query, ...$admin_ids)));
    }

    /**
     * @param array<int,string> $tokens
     * @param array<string,mixed> $notification
     * @param array<string,mixed> $data
     * @param array<string,mixed> $settings
     * @param array<string,mixed> $options
     * @return array<string,mixed>
     */
    private static function send_via_fcm_http_v1(
        array $tokens,
        array $notification,
        array $data,
        array $settings,
        array $options = array()
    ): array {
        $tokens = self::clean_tokens($tokens);
        if (empty($tokens)) {
            return array(
                'status' => 'no_tokens',
                'success' => 0,
                'failed' => 0,
                'error' => '',
            );
        }

        $success = 0;
        $failed = 0;
        $errors = array();
        $sender_mismatch_tokens = array();
        $sender_mismatch_detected = false;
        $priority = (string) ($options['priority'] ?? 'high');
        $ttl_seconds = max(60, (int) ($options['ttl_seconds'] ?? 3600));
        $data_only = self::to_bool_int($options['data_only'] ?? false) === 1;

        $project_id = self::resolve_fcm_project_id($settings);
        $service_account_path = self::resolve_fcm_service_account_path($settings);
        if ($project_id === '' || $service_account_path === '') {
            return array(
                'status' => 'missing_service_account_config',
                'success' => 0,
                'failed' => count($tokens),
                'error' => 'Missing FCM HTTP v1 configuration. Define LEXI_FCM_PROJECT_ID and LEXI_FCM_SERVICE_ACCOUNT_PATH in wp-config.php.',
            );
        }

        $config_validation = self::validate_fcm_configuration($project_id, $service_account_path);
        if (is_wp_error($config_validation)) {
            return array(
                'status' => 'config_mismatch',
                'success' => 0,
                'failed' => count($tokens),
                'error' => $config_validation->get_error_message(),
            );
        }

        $token_result = self::get_fcm_access_token($service_account_path);
        if (is_wp_error($token_result)) {
            return array(
                'status' => 'auth_failed',
                'success' => 0,
                'failed' => count($tokens),
                'error' => $token_result->get_error_message(),
            );
        }
        $access_token = (string) $token_result;
        $endpoint = sprintf(
            'https://fcm.googleapis.com/v1/projects/%s/messages:send',
            rawurlencode($project_id)
        );

        foreach ($tokens as $device_token) {
            $message = self::build_fcm_http_v1_message(
                $device_token,
                $notification,
                $data,
                $priority,
                $ttl_seconds,
                $data_only,
                $options
            );

            $response = wp_remote_post(
                $endpoint,
                array(
                    'timeout' => 20,
                    'headers' => array(
                        'Authorization' => 'Bearer ' . $access_token,
                        'Content-Type' => 'application/json; charset=utf-8',
                    ),
                    'body' => wp_json_encode(array('message' => $message), JSON_UNESCAPED_UNICODE),
                )
            );

            if (is_wp_error($response)) {
                $failed++;
                $errors[] = $response->get_error_message();
                self::log_delivery_failure(array(
                    'status' => 'transport_error',
                    'error' => $response->get_error_message(),
                    'token_suffix' => substr($device_token, -10),
                    'order_id' => (int) ($options['order_id'] ?? 0),
                    'user_id' => (int) ($options['user_id'] ?? 0),
                    'target' => (string) ($options['target'] ?? ''),
                ));
                continue;
            }

            $status_code = (int) wp_remote_retrieve_response_code($response);
            if ($status_code === 401) {
                $refreshed_token = self::get_fcm_access_token($service_account_path, true);
                if (!is_wp_error($refreshed_token)) {
                    $access_token = (string) $refreshed_token;
                    $response = wp_remote_post(
                        $endpoint,
                        array(
                            'timeout' => 20,
                            'headers' => array(
                                'Authorization' => 'Bearer ' . $access_token,
                                'Content-Type' => 'application/json; charset=utf-8',
                            ),
                            'body' => wp_json_encode(array('message' => $message), JSON_UNESCAPED_UNICODE),
                        )
                    );
                    if (!is_wp_error($response)) {
                        $status_code = (int) wp_remote_retrieve_response_code($response);
                    }
                }
            }

            if (is_wp_error($response)) {
                $failed++;
                $errors[] = $response->get_error_message();
                self::log_delivery_failure(array(
                    'status' => 'transport_error',
                    'error' => $response->get_error_message(),
                    'token_suffix' => substr($device_token, -10),
                    'order_id' => (int) ($options['order_id'] ?? 0),
                    'user_id' => (int) ($options['user_id'] ?? 0),
                    'target' => (string) ($options['target'] ?? ''),
                ));
                continue;
            }

            $raw = (string) wp_remote_retrieve_body($response);
            $json = json_decode($raw, true);

            if ($status_code >= 200 && $status_code < 300 && is_array($json) && !empty($json['name'])) {
                $success++;
                continue;
            }

            $failed++;
            $parsed_error = self::parse_fcm_http_v1_error($status_code, $json, $raw);
            $error_message = trim((string) ($parsed_error['message'] ?? ''));
            if ($error_message === '') {
                $error_message = 'HTTP ' . $status_code;
            }
            $errors[] = $error_message;

            if (self::is_sender_id_mismatch_error($parsed_error)) {
                $sender_mismatch_detected = true;
                $sender_mismatch_tokens[$device_token] = $device_token;
            }

            if (self::should_delete_token_from_fcm_error($parsed_error)) {
                self::delete_token($device_token);
            }

            self::log_delivery_failure(array(
                'status' => (string) ($parsed_error['status'] ?? 'failed'),
                'error' => $error_message,
                'fcm_error_code' => (string) ($parsed_error['fcm_error_code'] ?? ''),
                'token_suffix' => substr($device_token, -10),
                'order_id' => (int) ($options['order_id'] ?? 0),
                'user_id' => (int) ($options['user_id'] ?? 0),
                'target' => (string) ($options['target'] ?? ''),
            ));
        }

        // If at least one token succeeded, sender-id mismatches are stale/mixed
        // tokens and can be safely cleaned up.
        if ($success > 0 && !empty($sender_mismatch_tokens)) {
            foreach (array_values($sender_mismatch_tokens) as $token_to_delete) {
                self::delete_token($token_to_delete);
            }
        }

        // If all deliveries failed with SenderId mismatch, keep tokens and
        // surface a clear configuration hint instead of auto-deleting them.
        if ($success === 0 && $sender_mismatch_detected) {
            $settings_hint = self::describe_fcm_configuration($settings);
            $effective_project_id = (string) ($settings_hint['effective_project_id'] ?? '');
            $service_account_project_id = (string) ($settings_hint['service_account_project_id'] ?? '');
            $config_warning = trim((string) ($settings_hint['config_warning'] ?? ''));

            $hint = 'SenderId mismatch detected for all targets. Verify mobile app Firebase project and server FCM project/service-account are identical.';
            if ($effective_project_id !== '' || $service_account_project_id !== '') {
                $hint .= sprintf(
                    ' effective_project_id=%s service_account_project_id=%s.',
                    $effective_project_id !== '' ? $effective_project_id : 'unknown',
                    $service_account_project_id !== '' ? $service_account_project_id : 'unknown'
                );
            }
            if ($config_warning !== '') {
                $hint .= ' ' . $config_warning;
            }
            $errors[] = $hint;
        }

        return array(
            'status' => $failed === 0 ? 'sent' : ($success > 0 ? 'partial' : 'failed'),
            'success' => $success,
            'failed' => $failed,
            'error' => implode(' | ', array_filter(array_unique($errors))),
        );
    }

    /**
     * @param array<int,string> $tokens
     * @param array<string,mixed> $notification
     * @param array<string,string> $data
     * @param array<string,mixed> $settings
     * @param array<string,mixed> $options
     * @return array<string,mixed>
     */
    private static function send_via_fcm_legacy_server_key(
        array $tokens,
        array $notification,
        array $data,
        array $settings,
        array $options = array()
    ): array {
        $tokens = self::clean_tokens($tokens);
        if (empty($tokens)) {
            return array(
                'status' => 'no_tokens',
                'success' => 0,
                'failed' => 0,
                'error' => '',
            );
        }

        $server_key = trim((string) ($settings['server_key'] ?? ''));
        if ($server_key === '') {
            return array(
                'status' => 'missing_server_key',
                'success' => 0,
                'failed' => count($tokens),
                'error' => 'FCM legacy server key is missing.',
            );
        }

        $success = 0;
        $failed = 0;
        $errors = array();
        $sender_mismatch_tokens = array();
        $sender_mismatch_detected = false;
        $priority = strtolower((string) ($options['priority'] ?? 'high')) === 'normal' ? 'normal' : 'high';
        $data_only = self::to_bool_int($options['data_only'] ?? false) === 1;
        $endpoint = 'https://fcm.googleapis.com/fcm/send';

        foreach ($tokens as $device_token) {
            $payload = array(
                'to' => $device_token,
                'priority' => $priority,
                'data' => $data,
            );
            if (!$data_only && (!empty($notification['title']) || !empty($notification['body']) || !empty($notification['image']))) {
                $payload['notification'] = $notification;
            }

            $response = wp_remote_post(
                $endpoint,
                array(
                    'timeout' => 20,
                    'headers' => array(
                        'Authorization' => 'key=' . $server_key,
                        'Content-Type' => 'application/json; charset=utf-8',
                    ),
                    'body' => wp_json_encode($payload, JSON_UNESCAPED_UNICODE),
                )
            );

            if (is_wp_error($response)) {
                $failed++;
                $errors[] = $response->get_error_message();
                continue;
            }

            $status_code = (int) wp_remote_retrieve_response_code($response);
            $raw = (string) wp_remote_retrieve_body($response);
            $json = json_decode($raw, true);

            if ($status_code >= 200 && $status_code < 300 && is_array($json)) {
                $legacy_success = (int) ($json['success'] ?? 0);
                $legacy_failure = (int) ($json['failure'] ?? 0);

                if ($legacy_success > 0 && $legacy_failure === 0) {
                    $success++;
                    continue;
                }

                $failed++;
                $legacy_error_code = '';
                $legacy_error_message = '';
                $result_item = (isset($json['results'][0]) && is_array($json['results'][0]))
                    ? $json['results'][0]
                    : array();

                if (isset($result_item['error'])) {
                    $legacy_error_code = trim((string) $result_item['error']);
                    $legacy_error_message = $legacy_error_code;
                } elseif (isset($result_item['message_id'])) {
                    $success++;
                    $failed--;
                    continue;
                }

                if ($legacy_error_message === '') {
                    $legacy_error_message = 'FCM legacy request failed.';
                }

                $errors[] = $legacy_error_message;

                if (self::is_legacy_sender_mismatch($legacy_error_code, $legacy_error_message)) {
                    $sender_mismatch_detected = true;
                    $sender_mismatch_tokens[$device_token] = $device_token;
                }

                if (self::is_legacy_invalid_token_error($legacy_error_code, $legacy_error_message)) {
                    self::delete_token($device_token);
                }
                continue;
            }

            $failed++;
            $errors[] = $status_code > 0 ? ('HTTP ' . $status_code) : 'Legacy FCM request failed.';
        }

        if ($success > 0 && !empty($sender_mismatch_tokens)) {
            foreach (array_values($sender_mismatch_tokens) as $token_to_delete) {
                self::delete_token($token_to_delete);
            }
        }

        if ($success === 0 && $sender_mismatch_detected) {
            $errors[] = 'SenderId mismatch detected for all targets (legacy).';
        }

        return array(
            'status' => $failed === 0 ? 'sent' : ($success > 0 ? 'partial' : 'failed'),
            'success' => $success,
            'failed' => $failed,
            'error' => implode(' | ', array_filter(array_unique($errors))),
        );
    }

    /**
     * @param array<string,mixed> $notification
     * @param array<string,string> $data
     * @param array<string,mixed> $options
     * @return array<string,mixed>
     */
    private static function build_fcm_http_v1_message(
        string $device_token,
        array $notification,
        array $data,
        string $priority,
        int $ttl_seconds,
        bool $data_only,
        array $options
    ): array {
        $message = array(
            'token' => $device_token,
            'data' => $data,
        );

        if (!$data_only && (!empty($notification['title']) || !empty($notification['body']) || !empty($notification['image']))) {
            $message['notification'] = $notification;
        }

        $android_priority = strtolower($priority) === 'normal' ? 'NORMAL' : 'HIGH';
        $android = array(
            'priority' => $android_priority,
            'ttl' => sprintf('%ds', max(60, $ttl_seconds)),
        );

        $android_notification = array();
        $channel_id = trim((string) ($options['android_channel_id'] ?? ''));
        $sound = trim((string) ($options['android_sound'] ?? ''));
        $visibility = strtoupper(trim((string) ($options['android_visibility'] ?? '')));
        if ($channel_id !== '') {
            $android_notification['channel_id'] = $channel_id;
        }
        if ($sound !== '') {
            $android_notification['sound'] = $sound;
        }
        if (in_array($visibility, array('PUBLIC', 'PRIVATE', 'SECRET'), true)) {
            $android_notification['visibility'] = $visibility;
        }

        if (!empty($notification['image'])) {
            $android_notification['image'] = (string) $notification['image'];
        }

        if (!empty($android_notification)) {
            $android['notification'] = $android_notification;
        }
        $message['android'] = $android;

        $message['apns'] = array(
            'headers' => array(
                'apns-priority' => strtolower($priority) === 'normal' ? '5' : '10',
            ),
            'payload' => array(
                'aps' => array(
                    'sound' => 'default',
                ),
            ),
        );

        return $message;
    }

    /**
     * @param mixed $json
     * @return array<string,string>
     */
    private static function parse_fcm_http_v1_error(int $status_code, $json, string $raw_body): array
    {
        $status = '';
        $message = '';
        $fcm_error_code = '';

        if (is_array($json) && isset($json['error']) && is_array($json['error'])) {
            $error = $json['error'];
            $status = sanitize_text_field((string) ($error['status'] ?? ''));
            $message = sanitize_text_field((string) ($error['message'] ?? ''));
            $details = isset($error['details']) && is_array($error['details']) ? $error['details'] : array();
            foreach ($details as $detail) {
                if (!is_array($detail)) {
                    continue;
                }
                $candidate = sanitize_text_field((string) ($detail['errorCode'] ?? ''));
                if ($candidate !== '') {
                    $fcm_error_code = $candidate;
                    break;
                }
            }
        }

        if ($status === '') {
            $status = $status_code >= 500 ? 'SERVER_ERROR' : 'HTTP_' . $status_code;
        }
        if ($message === '') {
            $message = trim($raw_body) !== '' ? trim($raw_body) : ('HTTP ' . $status_code);
        }

        return array(
            'status' => $status,
            'message' => $message,
            'fcm_error_code' => $fcm_error_code,
        );
    }

    /**
     * @param array<string,mixed> $delivery
     * @param array<string,mixed> $settings
     */
    private static function should_fallback_to_legacy_provider(array $delivery, array $settings): bool
    {
        $legacy_key = trim((string) ($settings['server_key'] ?? ''));
        if ($legacy_key === '') {
            return false;
        }

        // Avoid duplicates when HTTP v1 already delivered to any token.
        if ((int) ($delivery['success'] ?? 0) > 0) {
            return false;
        }

        $status = strtolower(trim((string) ($delivery['status'] ?? '')));
        if (
            in_array(
                $status,
                array('auth_failed', 'config_mismatch', 'missing_service_account_config'),
                true
            )
        ) {
            return true;
        }

        $delivery_error = strtolower(trim((string) ($delivery['error'] ?? '')));
        if ($delivery_error === '') {
            return false;
        }

        $fallback_markers = array(
            'cloudmessaging.messages.create',
            'permission',
            'http 401',
            'http 403',
            'http 404',
            'http 429',
            'http 500',
            'http 502',
            'http 503',
            'http 504',
            'requested entity was not found',
            'method not found',
            'service unavailable',
            'temporarily unavailable',
            'deadline exceeded',
            'internal error',
            'backend error',
            'api has not been used',
            'has not been used in project',
            'service disabled',
            'unimplemented',
            'not_found',
        );

        foreach ($fallback_markers as $marker) {
            if (strpos($delivery_error, $marker) !== false) {
                return true;
            }
        }

        return false;
    }

    /**
     * @param array<string,string> $parsed_error
     */
    private static function is_sender_id_mismatch_error(array $parsed_error): bool
    {
        $fcm_error_code = strtoupper(trim((string) ($parsed_error['fcm_error_code'] ?? '')));
        if ($fcm_error_code === 'SENDER_ID_MISMATCH') {
            return true;
        }

        $status = strtoupper(trim((string) ($parsed_error['status'] ?? '')));
        $message = strtolower((string) ($parsed_error['message'] ?? ''));

        if ($status === 'SENDER_ID_MISMATCH') {
            return true;
        }

        return strpos($message, 'senderid mismatch') !== false
            || strpos($message, 'sender id mismatch') !== false;
    }

    private static function is_legacy_sender_mismatch(string $code, string $message): bool
    {
        $normalized_code = strtoupper(trim($code));
        if ($normalized_code === 'MISMATCHSENDERID' || $normalized_code === 'SENDER_ID_MISMATCH') {
            return true;
        }

        $normalized_message = strtolower(trim($message));
        return strpos($normalized_message, 'mismatchsenderid') !== false
            || strpos($normalized_message, 'senderid mismatch') !== false
            || strpos($normalized_message, 'sender id mismatch') !== false;
    }

    private static function is_legacy_invalid_token_error(string $code, string $message): bool
    {
        $normalized_code = strtoupper(trim($code));
        if (in_array($normalized_code, array('NOTREGISTERED', 'INVALIDREGISTRATION', 'INVALID_ARGUMENT'), true)) {
            return true;
        }

        $normalized_message = strtolower(trim($message));
        return strpos($normalized_message, 'notregistered') !== false
            || strpos($normalized_message, 'invalidregistration') !== false
            || strpos($normalized_message, 'invalid token') !== false;
    }

    /**
     * @param array<string,string> $parsed_error
     */
    private static function should_delete_token_from_fcm_error(array $parsed_error): bool
    {
        $fcm_error_code = strtoupper(trim((string) ($parsed_error['fcm_error_code'] ?? '')));
        if ($fcm_error_code === 'UNREGISTERED') {
            return true;
        }
        if ($fcm_error_code === 'SENDER_ID_MISMATCH') {
            // Sender mismatch is a server/project configuration issue, not
            // a stale token. Keep tokens so delivery resumes after config fix.
            return false;
        }

        if ($fcm_error_code === 'INVALID_ARGUMENT') {
            $message = strtolower((string) ($parsed_error['message'] ?? ''));
            if (strpos($message, 'registration token') !== false || strpos($message, 'invalid token') !== false) {
                return true;
            }
        }

        return false;
    }

    /**
     * @param array<int,int> $user_ids
     * @return array<int,string>
     */
    private static function tokens_by_user_ids(array $user_ids): array
    {
        global $wpdb;
        $table = self::tokens_table();

        $user_ids = array_values(array_filter(array_map('absint', $user_ids)));
        if (empty($user_ids)) {
            return array();
        }

        $placeholders = implode(',', array_fill(0, count($user_ids), '%d'));
        $query = "SELECT fcm_token FROM {$table} WHERE user_id IN ({$placeholders})";
        return self::clean_tokens((array) $wpdb->get_col($wpdb->prepare($query, ...$user_ids)));
    }

    /**
     * @return array<int,int>
     */
    private static function get_admin_user_ids(): array
    {
        $ids = get_users(array(
            'role__in' => array('administrator', 'shop_manager'),
            'fields' => 'ids',
            'number' => 5000,
        ));

        return array_values(array_filter(array_map('absint', (array) $ids)));
    }

    /**
     * @return array<int,int>
     */
    private static function get_courier_user_ids(): array
    {
        $ids = get_users(array(
            'role__in' => array('delivery_agent'),
            'fields' => 'ids',
            'number' => 5000,
        ));

        return array_values(array_filter(array_map('absint', (array) $ids)));
    }

    private static function delete_token(string $token): void
    {
        global $wpdb;
        $wpdb->delete(self::tokens_table(), array('fcm_token' => $token));
    }

    private static function tokens_table_has_column(string $column): bool
    {
        global $wpdb;
        static $cache = array();

        $table = self::tokens_table();
        $key = $table . ':' . $column;
        if (array_key_exists($key, $cache)) {
            return (bool) $cache[$key];
        }

        $exists = (bool) $wpdb->get_var(
            $wpdb->prepare(
                "SHOW COLUMNS FROM {$table} LIKE %s",
                $column
            )
        );
        $cache[$key] = $exists;
        return $exists;
    }

    private static function ensure_tokens_table_exists(): bool
    {
        global $wpdb;

        $table = self::tokens_table();
        $exists = (string) $wpdb->get_var(
            $wpdb->prepare(
                "SHOW TABLES LIKE %s",
                $table
            )
        );
        if ($exists === $table) {
            return true;
        }

        self::create_tables();

        $exists_after_create = (string) $wpdb->get_var(
            $wpdb->prepare(
                "SHOW TABLES LIKE %s",
                $table
            )
        );
        return $exists_after_create === $table;
    }

    /**
     * @param array<int,mixed> $tokens
     * @return array<int,string>
     */
    private static function clean_tokens(array $tokens): array
    {
        $clean = array();
        foreach ($tokens as $token) {
            $value = trim((string) $token);
            if ($value === '') {
                continue;
            }
            $clean[$value] = $value;
        }
        return array_values($clean);
    }

    /**
     * @param array<string,mixed> $raw
     * @return array<string,mixed>
     */
    private static function sanitize_settings(array $raw): array
    {
        $defaults = array(
            'enabled' => 0,
            'provider' => 'fcm_http_v1',
            'server_key' => '',
            'fcm_project_id' => '',
            'fcm_service_account_path' => '',
            'default_open_mode' => 'in_app',
            'default_image_url' => '',
            'ttl_seconds' => 3600,
        );

        $provider = sanitize_text_field((string) ($raw['provider'] ?? $defaults['provider']));
        if (!in_array($provider, array('fcm_http_v1', 'legacy_server_key'), true)) {
            $provider = 'fcm_http_v1';
        }

        $open_mode = sanitize_text_field((string) ($raw['default_open_mode'] ?? $defaults['default_open_mode']));
        if (!in_array($open_mode, array('in_app', 'external', 'product', 'category', 'deals'), true)) {
            $open_mode = 'in_app';
        }

        return array(
            'enabled' => self::to_bool_int($raw['enabled'] ?? $defaults['enabled']),
            'provider' => $provider,
            'server_key' => trim((string) ($raw['server_key'] ?? $defaults['server_key'])),
            'fcm_project_id' => sanitize_text_field((string) ($raw['fcm_project_id'] ?? $defaults['fcm_project_id'])),
            'fcm_service_account_path' => trim((string) ($raw['fcm_service_account_path'] ?? $defaults['fcm_service_account_path'])),
            'default_open_mode' => $open_mode,
            'default_image_url' => esc_url_raw((string) ($raw['default_image_url'] ?? $defaults['default_image_url'])),
            'ttl_seconds' => min(2419200, max(60, absint((int) ($raw['ttl_seconds'] ?? $defaults['ttl_seconds'])))),
        );
    }

    /**
     * @param mixed $value
     */
    private static function resolve_role(string $value, int $user_id): string
    {
        $role = strtolower(trim($value));
        $allowed = array(
            'administrator',
            'shop_manager',
            'delivery_agent',
            'customer',
            'guest',
            'admin',
            'courier',
        );
        if (in_array($role, $allowed, true)) {
            return $role;
        }

        if ($user_id <= 0) {
            return 'guest';
        }

        $user = get_userdata($user_id);
        if ($user instanceof WP_User) {
            $roles = is_array($user->roles) ? array_values($user->roles) : array();
            if (!empty($roles)) {
                return sanitize_text_field((string) $roles[0]);
            }
        }

        return 'customer';
    }

    /**
     * @param array<string,mixed> $data
     * @return array<string,string>
     */
    private static function normalize_data_payload(array $data): array
    {
        $normalized = array();
        foreach ($data as $key => $value) {
            $safe_key = sanitize_key((string) $key);
            if ($safe_key === '') {
                continue;
            }
            if (is_array($value) || is_object($value)) {
                $encoded = wp_json_encode($value, JSON_UNESCAPED_UNICODE);
                if (is_string($encoded) && $encoded !== '') {
                    $normalized[$safe_key] = $encoded;
                }
                continue;
            }
            if (is_bool($value)) {
                $normalized[$safe_key] = $value ? '1' : '0';
                continue;
            }

            $string_value = trim((string) $value);
            if ($string_value === '') {
                continue;
            }
            $normalized[$safe_key] = $string_value;
        }

        return $normalized;
    }

    /**
     * @param array<string,mixed> $settings
     * @return array{effective_project_id:string,service_account_project_id:string,config_warning:string}
     */
    private static function describe_fcm_configuration(array $settings): array
    {
        $effective_project_id = self::resolve_fcm_project_id($settings);
        $service_account_project_id = '';
        $config_warning = '';
        $service_account_path = self::resolve_fcm_service_account_path($settings);

        if ($service_account_path !== '') {
            $service_account = self::load_service_account($service_account_path);
            if (is_wp_error($service_account)) {
                $config_warning = $service_account->get_error_message();
            } else {
                $service_account_project_id = trim((string) ($service_account['project_id'] ?? ''));
                if (
                    $effective_project_id !== ''
                    && $service_account_project_id !== ''
                    && $effective_project_id !== $service_account_project_id
                ) {
                    $config_warning = sprintf(
                        'FCM Project ID "%s" does not match service account project "%s". This will trigger SenderId mismatch.',
                        $effective_project_id,
                        $service_account_project_id
                    );
                }
            }
        }

        return array(
            'effective_project_id' => $effective_project_id,
            'service_account_project_id' => $service_account_project_id,
            'config_warning' => $config_warning,
        );
    }

    /**
     * @param array<string,mixed> $settings
     */
    private static function resolve_fcm_project_id(array $settings): string
    {
        $value = trim((string) ($settings['fcm_project_id'] ?? ''));
        if ($value !== '') {
            return $value;
        }

        $env_value = getenv('LEXI_FCM_PROJECT_ID');
        if (is_string($env_value) && trim($env_value) !== '') {
            return trim($env_value);
        }

        if (defined('LEXI_FCM_PROJECT_ID')) {
            $value = trim((string) constant('LEXI_FCM_PROJECT_ID'));
            if ($value !== '') {
                return $value;
            }
        }

        $service_account_path = self::resolve_fcm_service_account_path($settings);
        if ($service_account_path === '') {
            return '';
        }

        $service_account = self::load_service_account($service_account_path);
        if (is_wp_error($service_account)) {
            return '';
        }

        return trim((string) ($service_account['project_id'] ?? ''));
    }

    /**
     * @param array<string,mixed> $settings
     */
    private static function resolve_fcm_service_account_path(array $settings): string
    {
        $settings_value = trim((string) ($settings['fcm_service_account_path'] ?? ''));
        if ($settings_value !== '') {
            return $settings_value;
        }

        $env_value = getenv('LEXI_FCM_SERVICE_ACCOUNT_PATH');
        if (is_string($env_value) && trim($env_value) !== '') {
            return trim($env_value);
        }

        if (defined('LEXI_FCM_SERVICE_ACCOUNT_PATH')) {
            $value = trim((string) constant('LEXI_FCM_SERVICE_ACCOUNT_PATH'));
            if ($value !== '') {
                return $value;
            }
        }

        return '';
    }

    /**
     * @return true|WP_Error
     */
    private static function validate_fcm_configuration(string $project_id, string $service_account_path)
    {
        $service_account = self::load_service_account($service_account_path);
        if (is_wp_error($service_account)) {
            return $service_account;
        }

        $service_account_project_id = trim((string) ($service_account['project_id'] ?? ''));
        if ($project_id === '' || $service_account_project_id === '') {
            return true;
        }

        if ($project_id !== $service_account_project_id) {
            return new WP_Error(
                'fcm_project_mismatch',
                sprintf(
                    'FCM Project ID "%s" does not match service account project "%s". Update both to the same Firebase project to avoid SenderId mismatch.',
                    $project_id,
                    $service_account_project_id
                )
            );
        }

        return true;
    }

    /**
     * @return string|WP_Error
     */
    private static function get_fcm_access_token(string $service_account_path, bool $force_refresh = false)
    {
        $service_account_path = trim($service_account_path);
        if ($service_account_path === '') {
            return new WP_Error('missing_service_account_path', 'FCM service account path is missing.');
        }

        if (!$force_refresh) {
            $cached = get_transient(self::FCM_TOKEN_TRANSIENT);
            if (is_array($cached)) {
                $token = trim((string) ($cached['token'] ?? ''));
                $expires_at = (int) ($cached['expires_at'] ?? 0);
                if ($token !== '' && $expires_at > (time() + 30)) {
                    return $token;
                }
            }
        }

        $service_account = self::load_service_account($service_account_path);
        if (is_wp_error($service_account)) {
            return $service_account;
        }

        $token_data = self::fetch_access_token_via_google_auth_library($service_account);
        if (is_wp_error($token_data)) {
            $token_data = self::fetch_access_token_via_jwt_assertion($service_account);
        }
        if (is_wp_error($token_data)) {
            return $token_data;
        }

        $token = trim((string) ($token_data['access_token'] ?? ''));
        $expires_in = max(60, (int) ($token_data['expires_in'] ?? 3500));
        if ($token === '') {
            return new WP_Error('invalid_access_token', 'FCM OAuth2 token response did not include an access token.');
        }

        $expires_at = time() + $expires_in;
        set_transient(
            self::FCM_TOKEN_TRANSIENT,
            array(
                'token' => $token,
                'expires_at' => $expires_at,
            ),
            max(60, $expires_in - 30)
        );

        return $token;
    }

    /**
     * @param array<string,mixed> $service_account
     * @return array<string,mixed>|WP_Error
     */
    private static function fetch_access_token_via_google_auth_library(array $service_account)
    {
        if (!class_exists('\Google\Auth\Credentials\ServiceAccountCredentials')) {
            return new WP_Error('google_auth_library_missing', 'google/auth is not installed.');
        }

        try {
            $credentials = new \Google\Auth\Credentials\ServiceAccountCredentials(
                array(self::FCM_SCOPE),
                $service_account
            );
            $token = $credentials->fetchAuthToken();
        } catch (Throwable $e) {
            return new WP_Error('google_auth_token_failed', $e->getMessage());
        }

        if (!is_array($token)) {
            return new WP_Error('google_auth_invalid_response', 'Unexpected token response from google/auth.');
        }

        $access_token = trim((string) ($token['access_token'] ?? ''));
        if ($access_token === '') {
            return new WP_Error('google_auth_no_access_token', 'google/auth did not return an access token.');
        }

        return array(
            'access_token' => $access_token,
            'expires_in' => (int) ($token['expires_in'] ?? 3500),
        );
    }

    /**
     * @param array<string,mixed> $service_account
     * @return array<string,mixed>|WP_Error
     */
    private static function fetch_access_token_via_jwt_assertion(array $service_account)
    {
        $client_email = trim((string) ($service_account['client_email'] ?? ''));
        $private_key = trim((string) ($service_account['private_key'] ?? ''));
        $token_uri = trim((string) ($service_account['token_uri'] ?? 'https://oauth2.googleapis.com/token'));

        if ($client_email === '' || $private_key === '' || $token_uri === '') {
            return new WP_Error('service_account_invalid', 'Service account JSON is missing client_email/private_key/token_uri.');
        }

        $issued_at = time();
        $expires_at = $issued_at + 3600;
        $claims = array(
            'iss' => $client_email,
            'scope' => self::FCM_SCOPE,
            'aud' => $token_uri,
            'iat' => $issued_at,
            'exp' => $expires_at,
        );
        $jwt = self::sign_service_account_jwt($claims, $private_key);
        if (is_wp_error($jwt)) {
            return $jwt;
        }

        $response = wp_remote_post(
            $token_uri,
            array(
                'timeout' => 20,
                'headers' => array(
                    'Content-Type' => 'application/x-www-form-urlencoded',
                ),
                'body' => array(
                    'grant_type' => 'urn:ietf:params:oauth:grant-type:jwt-bearer',
                    'assertion' => $jwt,
                ),
            )
        );

        if (is_wp_error($response)) {
            return new WP_Error('oauth_http_error', $response->get_error_message());
        }

        $status = (int) wp_remote_retrieve_response_code($response);
        $raw = (string) wp_remote_retrieve_body($response);
        $json = json_decode($raw, true);
        if (!is_array($json)) {
            return new WP_Error('oauth_invalid_response', 'Invalid OAuth2 token response.');
        }
        if ($status >= 400) {
            $message = trim((string) ($json['error_description'] ?? $json['error'] ?? 'OAuth2 token request failed.'));
            return new WP_Error('oauth_request_failed', $message);
        }

        $access_token = trim((string) ($json['access_token'] ?? ''));
        if ($access_token === '') {
            return new WP_Error('oauth_access_token_missing', 'OAuth2 response did not include access_token.');
        }

        return array(
            'access_token' => $access_token,
            'expires_in' => (int) ($json['expires_in'] ?? 3500),
        );
    }

    /**
     * @param array<string,mixed> $payload
     * @return string|WP_Error
     */
    private static function sign_service_account_jwt(array $payload, string $private_key)
    {
        $header = array('alg' => 'RS256', 'typ' => 'JWT');
        $header_json = wp_json_encode($header);
        $payload_json = wp_json_encode($payload);
        if (!is_string($header_json) || !is_string($payload_json) || $header_json === '' || $payload_json === '') {
            return new WP_Error('jwt_encode_failed', 'Could not encode JWT payload.');
        }
        $segments = array(
            self::base64url_encode($header_json),
            self::base64url_encode($payload_json),
        );
        $signing_input = implode('.', $segments);

        $signature = '';
        $ok = openssl_sign($signing_input, $signature, $private_key, OPENSSL_ALGO_SHA256);
        if (!$ok) {
            return new WP_Error('jwt_sign_failed', 'Could not sign service-account JWT assertion.');
        }

        $segments[] = self::base64url_encode($signature);
        return implode('.', $segments);
    }

    private static function base64url_encode(string $value): string
    {
        return rtrim(strtr(base64_encode($value), '+/', '-_'), '=');
    }

    /**
     * @return array<string,mixed>|WP_Error
     */
    private static function load_service_account(string $path)
    {
        $path = trim($path);
        if ($path === '') {
            return new WP_Error('service_account_path_missing', 'Service account path is missing.');
        }

        if (stripos($path, 'lexi_internal:') === 0) {
            $alias = trim((string) substr($path, strlen('lexi_internal:')));
            if ($alias === '') {
                return new WP_Error('service_account_internal_alias_missing', 'Internal service account alias is missing.');
            }

            if (!defined('LEXI_API_PLUGIN_DIR')) {
                return new WP_Error('service_account_internal_path_unavailable', 'Plugin directory constant is unavailable.');
            }

            $safe_alias = preg_replace('/[^a-z0-9_\-]/i', '', strtolower($alias));
            $internal_path = trailingslashit((string) constant('LEXI_API_PLUGIN_DIR'))
                . 'includes/secure/fcm-service-account-'
                . $safe_alias
                . '.php';

            if (!file_exists($internal_path)) {
                return new WP_Error('service_account_internal_missing', 'Internal service account file does not exist: ' . $internal_path);
            }

            $data = require $internal_path;
            if (!is_array($data)) {
                return new WP_Error('service_account_internal_invalid', 'Internal service account file must return an array.');
            }

            return $data;
        }

        if (strpos($path, 'http') === 0) {
            $response = wp_safe_remote_get($path, array('timeout' => 15));
            if (is_wp_error($response)) {
                return new WP_Error('service_account_url_failed', 'Failed to fetch service account from URL: ' . $response->get_error_message());
            }
            $status = (int) wp_remote_retrieve_response_code($response);
            if ($status < 200 || $status >= 300) {
                return new WP_Error('service_account_url_http_error', 'FCM service account URL returned HTTP ' . $status);
            }
            $raw = (string) wp_remote_retrieve_body($response);
        } else {
            if (!file_exists($path)) {
                return new WP_Error('service_account_path_not_found', 'Service account file does not exist: ' . $path);
            }
            if (!is_readable($path)) {
                return new WP_Error('service_account_path_unreadable', 'Service account file is not readable.');
            }
            $raw = file_get_contents($path);
        }

        if (!is_string($raw) || trim($raw) === '') {
            return new WP_Error('service_account_read_failed', 'Service account file is empty or unreadable.');
        }

        $json = json_decode($raw, true);
        if (!is_array($json)) {
            return new WP_Error('service_account_json_invalid', 'Service account JSON is invalid.');
        }

        return $json;
    }

    /**
     * @param array<string,mixed> $context
     */
    private static function log_delivery_failure(array $context): void
    {
        $payload = array_filter($context, static function ($value) {
            if (is_string($value)) {
                return trim($value) !== '';
            }
            if (is_int($value)) {
                return $value > 0;
            }
            return !empty($value);
        });

        if (empty($payload)) {
            return;
        }

        $payload['server'] = $_SERVER['SERVER_NAME'] ?? 'cli';
        error_log('[Lexi Push] Failure: ' . wp_json_encode($payload, JSON_UNESCAPED_UNICODE));

    }

    private static function to_bool_int($value): int
    {
        if (is_bool($value)) {
            return $value ? 1 : 0;
        }
        if (is_numeric($value)) {
            return ((int) $value) > 0 ? 1 : 0;
        }
        $normalized = strtolower(trim((string) $value));
        return in_array($normalized, array('1', 'true', 'yes', 'on'), true) ? 1 : 0;
    }

    private static function mask_secret(string $secret): string
    {
        $secret = trim($secret);
        if ($secret === '') {
            return '';
        }
        if (strlen($secret) <= 12) {
            return str_repeat('*', strlen($secret));
        }
        return substr($secret, 0, 6) . str_repeat('*', 12) . substr($secret, -4);
    }

    private static function mask_path(string $path): string
    {
        $path = trim($path);
        if ($path === '') {
            return '';
        }

        $base = basename($path);
        if ($base === '' || $base === '.' || $base === DIRECTORY_SEPARATOR) {
            return '***';
        }

        if (strlen($base) <= 4) {
            return str_repeat('*', strlen($base));
        }

        return substr($base, 0, 2) . str_repeat('*', max(2, strlen($base) - 4)) . substr($base, -2);
    }

    private static function normalize_text($value): string
    {
        if (class_exists('Lexi_Text')) {
            return Lexi_Text::normalize($value);
        }

        return (string) $value;
    }
}


