<?php
/**
 * Support ticketing data layer and helpers.
 *
 * @package Lexi_API
 */

defined('ABSPATH') || exit;

class Lexi_Support
{
    private const TICKETS_TABLE = 'lexi_support_tickets';
    private const MESSAGES_TABLE = 'lexi_support_messages';
    private const ATTACHMENTS_TABLE = 'lexi_support_attachments';
    private const VIEWS_TABLE = 'lexi_support_ticket_views';
    private const CANNED_OPTION = 'lexi_support_canned_replies';

    /**
     * Allowed values.
     *
     * @return array<string, array<int, string>>
     */
    public static function enums(): array
    {
        return array(
            'category' => array('shipping', 'payment', 'product', 'technical', 'other'),
            'priority' => array('low', 'medium', 'high', 'urgent'),
            'status' => array('open', 'pending_admin', 'pending_customer', 'in_progress', 'resolved', 'closed'),
            'channel' => array('in_app'),
            'sender_type' => array('customer', 'agent', 'system'),
        );
    }

    /**
     * Create/upgrade support tables.
     */
    public static function create_tables(): void
    {
        global $wpdb;

        require_once ABSPATH . 'wp-admin/includes/upgrade.php';

        $charset = $wpdb->get_charset_collate();
        $tickets = self::tickets_table();
        $messages = self::messages_table();
        $attachments = self::attachments_table();
        $views = self::views_table();

        $sql_tickets = "CREATE TABLE {$tickets} (
            id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
            ticket_number VARCHAR(32) NOT NULL,
            name VARCHAR(190) NOT NULL,
            phone VARCHAR(50) NOT NULL,
            email VARCHAR(190) NULL,
            subject VARCHAR(255) NOT NULL,
            category VARCHAR(50) NOT NULL,
            priority VARCHAR(20) NOT NULL,
            status VARCHAR(30) NOT NULL,
            channel VARCHAR(20) NOT NULL,
            tags TEXT NULL,
            assigned_user_id BIGINT UNSIGNED NULL,
            customer_user_id BIGINT UNSIGNED NULL,
            created_at DATETIME NOT NULL,
            updated_at DATETIME NOT NULL,
            last_message_at DATETIME NOT NULL,
            first_response_at DATETIME NULL,
            resolved_at DATETIME NULL,
            closed_at DATETIME NULL,
            sla_first_response_minutes INT NOT NULL DEFAULT 60,
            sla_resolution_minutes INT NOT NULL DEFAULT 1440,
            customer_rating TINYINT UNSIGNED NULL,
            customer_feedback TEXT NULL,
            chat_token VARCHAR(64) NOT NULL,
            PRIMARY KEY (id),
            UNIQUE KEY ticket_number (ticket_number),
            UNIQUE KEY chat_token (chat_token),
            KEY phone (phone),
            KEY status (status),
            KEY priority (priority),
            KEY assigned_user_id (assigned_user_id),
            KEY customer_user_id (customer_user_id),
            KEY updated_at (updated_at),
            KEY last_message_at (last_message_at)
        ) {$charset};";

        $sql_messages = "CREATE TABLE {$messages} (
            id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
            ticket_id BIGINT UNSIGNED NOT NULL,
            sender_type VARCHAR(20) NOT NULL,
            sender_user_id BIGINT UNSIGNED NULL,
            message TEXT NOT NULL,
            is_internal TINYINT(1) NOT NULL DEFAULT 0,
            created_at DATETIME NOT NULL,
            PRIMARY KEY (id),
            KEY ticket_id (ticket_id),
            KEY created_at (created_at)
        ) {$charset};";

        $sql_attachments = "CREATE TABLE {$attachments} (
            id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
            ticket_id BIGINT UNSIGNED NOT NULL,
            message_id BIGINT UNSIGNED NULL,
            wp_attachment_id BIGINT UNSIGNED NOT NULL,
            url TEXT NOT NULL,
            mime_type VARCHAR(100) NOT NULL,
            size_bytes BIGINT UNSIGNED NOT NULL,
            created_at DATETIME NOT NULL,
            PRIMARY KEY (id),
            KEY ticket_id (ticket_id),
            KEY message_id (message_id)
        ) {$charset};";

        $sql_views = "CREATE TABLE {$views} (
            id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
            ticket_id BIGINT UNSIGNED NOT NULL,
            viewer_type VARCHAR(20) NOT NULL,
            viewer_key VARCHAR(100) NOT NULL,
            last_seen_message_id BIGINT UNSIGNED NOT NULL DEFAULT 0,
            updated_at DATETIME NOT NULL,
            PRIMARY KEY (id),
            UNIQUE KEY uniq_view (ticket_id, viewer_type, viewer_key)
        ) {$charset};";

        dbDelta($sql_tickets);
        dbDelta($sql_messages);
        dbDelta($sql_attachments);
        dbDelta($sql_views);
    }

    /**
     * Upgrade tables if DB version changed.
     */
    public static function maybe_upgrade(): void
    {
        $installed = (string) get_option('lexi_api_db_version', '');
        if ($installed === LEXI_API_DB_VERSION) {
            return;
        }

        self::create_tables();
        update_option('lexi_api_db_version', LEXI_API_DB_VERSION);
    }

    public static function tickets_table(): string
    {
        global $wpdb;
        return $wpdb->prefix . self::TICKETS_TABLE;
    }

    public static function messages_table(): string
    {
        global $wpdb;
        return $wpdb->prefix . self::MESSAGES_TABLE;
    }

    public static function attachments_table(): string
    {
        global $wpdb;
        return $wpdb->prefix . self::ATTACHMENTS_TABLE;
    }

    public static function views_table(): string
    {
        global $wpdb;
        return $wpdb->prefix . self::VIEWS_TABLE;
    }

    public static function now(): string
    {
        return (string) current_time('mysql');
    }

    public static function generate_chat_token(): string
    {
        try {
            return bin2hex(random_bytes(32));
        } catch (Throwable $e) {
            return hash('sha256', wp_generate_password(64, true, true) . microtime(true));
        }
    }

    public static function normalize_category(string $value): string
    {
        $value = strtolower(trim($value));
        return in_array($value, self::enums()['category'], true) ? $value : 'other';
    }

    public static function normalize_priority(string $value): string
    {
        $value = strtolower(trim($value));
        return in_array($value, self::enums()['priority'], true) ? $value : 'medium';
    }

    public static function normalize_status(string $value): string
    {
        $value = strtolower(trim($value));
        return in_array($value, self::enums()['status'], true) ? $value : 'open';
    }

    public static function status_label_ar(string $status): string
    {
        $map = array(
            'open' => 'مفتوحة',
            'pending_admin' => 'بانتظار الدعم',
            'pending_customer' => 'بانتظارك',
            'in_progress' => 'قيد المعالجة',
            'resolved' => 'تم الحل',
            'closed' => 'مغلقة',
        );

        $status = self::normalize_status($status);
        return $map[$status] ?? 'مفتوحة';
    }

    public static function category_label_ar(string $category): string
    {
        $map = array(
            'shipping' => 'الشحن',
            'payment' => 'الدفع',
            'product' => 'المنتجات',
            'technical' => 'تقني',
            'other' => 'أخرى',
        );

        $category = self::normalize_category($category);
        return $map[$category] ?? 'أخرى';
    }

    public static function priority_label_ar(string $priority): string
    {
        $map = array(
            'low' => 'منخفضة',
            'medium' => 'متوسطة',
            'high' => 'عالية',
            'urgent' => 'عاجلة',
        );

        $priority = self::normalize_priority($priority);
        return $map[$priority] ?? 'متوسطة';
    }

    /**
     * Create ticket and its initial system message.
     *
     * @param array<string, mixed> $payload
     * @return array<string, mixed>|null
     */
    public static function create_ticket(array $payload): ?array
    {
        global $wpdb;

        $table = self::tickets_table();
        $now = self::now();
        $token = self::generate_chat_token();
        $temp_ticket_number = 'TMP-' . substr($token, 0, 20);

        $inserted = $wpdb->insert(
            $table,
            array(
                'ticket_number' => $temp_ticket_number,
                'name' => sanitize_text_field((string) ($payload['name'] ?? '')),
                'phone' => Lexi_Security::sanitize_phone((string) ($payload['phone'] ?? '')),
                'email' => sanitize_email((string) ($payload['email'] ?? '')),
                'subject' => sanitize_text_field((string) ($payload['subject'] ?? '')),
                'category' => self::normalize_category((string) ($payload['category'] ?? 'other')),
                'priority' => self::normalize_priority((string) ($payload['priority'] ?? 'medium')),
                'status' => 'open',
                'channel' => 'in_app',
                'tags' => '',
                'assigned_user_id' => null,
                'customer_user_id' => isset($payload['customer_user_id']) ? absint($payload['customer_user_id']) : null,
                'created_at' => $now,
                'updated_at' => $now,
                'last_message_at' => $now,
                'first_response_at' => null,
                'resolved_at' => null,
                'closed_at' => null,
                'sla_first_response_minutes' => (int) ($payload['sla_first_response_minutes'] ?? 60),
                'sla_resolution_minutes' => (int) ($payload['sla_resolution_minutes'] ?? 1440),
                'customer_rating' => null,
                'customer_feedback' => null,
                'chat_token' => $token,
            ),
            array(
                '%s',
                '%s',
                '%s',
                '%s',
                '%s',
                '%s',
                '%s',
                '%s',
                '%s',
                '%d',
                '%d',
                '%s',
                '%s',
                '%s',
                '%s',
                '%s',
                '%s',
                '%d',
                '%d',
                '%d',
                '%s',
                '%s',
                '%s',
            )
        );

        if (false === $inserted) {
            return null;
        }

        $id = (int) $wpdb->insert_id;
        $ticket_number = self::generate_ticket_number($id);
        $wpdb->update(
            $table,
            array('ticket_number' => $ticket_number),
            array('id' => $id),
            array('%s'),
            array('%d')
        );

        self::add_message(
            $id,
            'system',
            'تم إنشاء التذكرة',
            0,
            0
        );

        return self::get_ticket($id);
    }

    public static function generate_ticket_number(int $id): string
    {
        $year = gmdate('Y');
        return sprintf('LEXI-%s-%06d', $year, $id);
    }

    /**
     * @return array<string, mixed>|null
     */
    public static function get_ticket(int $ticket_id): ?array
    {
        global $wpdb;

        $table = self::tickets_table();
        $row = $wpdb->get_row(
            $wpdb->prepare("SELECT * FROM {$table} WHERE id = %d", $ticket_id),
            ARRAY_A
        );

        return is_array($row) ? $row : null;
    }

    /**
     * @return array<int, array<string, mixed>>
     */
    public static function get_messages(int $ticket_id, bool $include_internal = false, int $since_id = 0): array
    {
        global $wpdb;
        $table = self::messages_table();

        $where = "ticket_id = %d AND id > %d";
        if (!$include_internal) {
            $where .= " AND is_internal = 0";
        }

        $rows = $wpdb->get_results(
            $wpdb->prepare(
                "SELECT id, ticket_id, sender_type, sender_user_id, message, is_internal, created_at
                 FROM {$table}
                 WHERE {$where}
                 ORDER BY id ASC",
                $ticket_id,
                $since_id
            ),
            ARRAY_A
        );

        if (!is_array($rows)) {
            return array();
        }

        $out = array();
        foreach ($rows as $row) {
            $out[] = array(
                'id' => (int) ($row['id'] ?? 0),
                'ticket_id' => (int) ($row['ticket_id'] ?? 0),
                'sender_type' => (string) ($row['sender_type'] ?? ''),
                'sender_user_id' => (int) ($row['sender_user_id'] ?? 0),
                'message' => (string) ($row['message'] ?? ''),
                'is_internal' => ((int) ($row['is_internal'] ?? 0)) === 1,
                'created_at' => (string) ($row['created_at'] ?? ''),
            );
        }

        return $out;
    }

    /**
     * @param array<int, int> $message_ids
     * @return array<int, array<string, mixed>>
     */
    public static function get_attachments(int $ticket_id, array $message_ids = array()): array
    {
        global $wpdb;
        $table = self::attachments_table();

        if (!empty($message_ids)) {
            $ids = array_values(array_unique(array_filter(array_map('absint', $message_ids))));
            if (!empty($ids)) {
                $placeholders = implode(',', array_fill(0, count($ids), '%d'));
                $params = array_merge(array($ticket_id), $ids);
                $sql = $wpdb->prepare(
                    "SELECT id, ticket_id, message_id, wp_attachment_id, url, mime_type, size_bytes, created_at
                     FROM {$table}
                     WHERE ticket_id = %d AND message_id IN ({$placeholders})
                     ORDER BY id ASC",
                    $params
                );
                $rows = $wpdb->get_results($sql, ARRAY_A);
                return self::normalize_attachments($rows);
            }
        }

        $rows = $wpdb->get_results(
            $wpdb->prepare(
                "SELECT id, ticket_id, message_id, wp_attachment_id, url, mime_type, size_bytes, created_at
                 FROM {$table}
                 WHERE ticket_id = %d
                 ORDER BY id ASC",
                $ticket_id
            ),
            ARRAY_A
        );

        return self::normalize_attachments($rows);
    }

    /**
     * @param mixed $rows
     * @return array<int, array<string, mixed>>
     */
    private static function normalize_attachments($rows): array
    {
        if (!is_array($rows)) {
            return array();
        }

        $out = array();
        foreach ($rows as $row) {
            if (!is_array($row)) {
                continue;
            }

            $out[] = array(
                'id' => (int) ($row['id'] ?? 0),
                'ticket_id' => (int) ($row['ticket_id'] ?? 0),
                'message_id' => isset($row['message_id']) ? (int) $row['message_id'] : null,
                'wp_attachment_id' => (int) ($row['wp_attachment_id'] ?? 0),
                'url' => (string) ($row['url'] ?? ''),
                'mime_type' => (string) ($row['mime_type'] ?? ''),
                'size_bytes' => (int) ($row['size_bytes'] ?? 0),
                'created_at' => (string) ($row['created_at'] ?? ''),
            );
        }

        return $out;
    }

    public static function last_message_id(int $ticket_id, bool $include_internal = true): int
    {
        global $wpdb;
        $table = self::messages_table();

        if ($include_internal) {
            $id = (int) $wpdb->get_var(
                $wpdb->prepare("SELECT MAX(id) FROM {$table} WHERE ticket_id = %d", $ticket_id)
            );
            return $id;
        }

        $id = (int) $wpdb->get_var(
            $wpdb->prepare("SELECT MAX(id) FROM {$table} WHERE ticket_id = %d AND is_internal = 0", $ticket_id)
        );
        return $id;
    }

    public static function add_message(
        int $ticket_id,
        string $sender_type,
        string $message,
        int $sender_user_id = 0,
        int $is_internal = 0
    ): ?array {
        global $wpdb;

        $message = trim(sanitize_textarea_field($message));
        if ('' === $message) {
            return null;
        }

        $sender_type = strtolower(trim($sender_type));
        if (!in_array($sender_type, self::enums()['sender_type'], true)) {
            $sender_type = 'system';
        }

        $table = self::messages_table();
        $now = self::now();

        $ok = $wpdb->insert(
            $table,
            array(
                'ticket_id' => $ticket_id,
                'sender_type' => $sender_type,
                'sender_user_id' => $sender_user_id > 0 ? $sender_user_id : null,
                'message' => $message,
                'is_internal' => $is_internal === 1 ? 1 : 0,
                'created_at' => $now,
            ),
            array('%d', '%s', '%d', '%s', '%d', '%s')
        );

        if (false === $ok) {
            return null;
        }

        $message_id = (int) $wpdb->insert_id;
        self::touch_ticket($ticket_id);

        $row = $wpdb->get_row(
            $wpdb->prepare(
                "SELECT id, ticket_id, sender_type, sender_user_id, message, is_internal, created_at
                 FROM {$table}
                 WHERE id = %d",
                $message_id
            ),
            ARRAY_A
        );

        if (!is_array($row)) {
            return null;
        }

        return array(
            'id' => (int) $row['id'],
            'ticket_id' => (int) $row['ticket_id'],
            'sender_type' => (string) $row['sender_type'],
            'sender_user_id' => (int) ($row['sender_user_id'] ?? 0),
            'message' => (string) $row['message'],
            'is_internal' => ((int) ($row['is_internal'] ?? 0)) === 1,
            'created_at' => (string) $row['created_at'],
        );
    }

    public static function touch_ticket(int $ticket_id): void
    {
        global $wpdb;
        $table = self::tickets_table();
        $now = self::now();
        $wpdb->update(
            $table,
            array('updated_at' => $now, 'last_message_at' => $now),
            array('id' => $ticket_id),
            array('%s', '%s'),
            array('%d')
        );
    }

    /**
     * @param array<string, mixed> $fields
     */
    public static function update_ticket(int $ticket_id, array $fields): bool
    {
        global $wpdb;

        if (empty($fields)) {
            return true;
        }

        $table = self::tickets_table();
        $allowed = array(
            'status' => '%s',
            'priority' => '%s',
            'category' => '%s',
            'tags' => '%s',
            'assigned_user_id' => '%d',
            'first_response_at' => '%s',
            'resolved_at' => '%s',
            'closed_at' => '%s',
            'customer_rating' => '%d',
            'customer_feedback' => '%s',
            'updated_at' => '%s',
            'last_message_at' => '%s',
        );

        $data = array();
        $format = array();
        foreach ($fields as $key => $value) {
            if (!isset($allowed[$key])) {
                continue;
            }
            $data[$key] = $value;
            $format[] = $allowed[$key];
        }

        if (!isset($data['updated_at'])) {
            $data['updated_at'] = self::now();
            $format[] = '%s';
        }

        if (empty($data)) {
            return true;
        }

        $result = $wpdb->update(
            $table,
            $data,
            array('id' => $ticket_id),
            $format,
            array('%d')
        );

        return false !== $result;
    }

    /**
     * @param array<string, mixed> $attachment
     * @return array<string, mixed>|null
     */
    public static function add_attachment(int $ticket_id, int $message_id, array $attachment): ?array
    {
        global $wpdb;

        $table = self::attachments_table();
        $now = self::now();

        $ok = $wpdb->insert(
            $table,
            array(
                'ticket_id' => $ticket_id,
                'message_id' => $message_id > 0 ? $message_id : null,
                'wp_attachment_id' => (int) ($attachment['wp_attachment_id'] ?? 0),
                'url' => (string) ($attachment['url'] ?? ''),
                'mime_type' => (string) ($attachment['mime_type'] ?? ''),
                'size_bytes' => (int) ($attachment['size_bytes'] ?? 0),
                'created_at' => $now,
            ),
            array('%d', '%d', '%d', '%s', '%s', '%d', '%s')
        );

        if (false === $ok) {
            return null;
        }

        self::touch_ticket($ticket_id);

        $id = (int) $wpdb->insert_id;
        return array(
            'id' => $id,
            'ticket_id' => $ticket_id,
            'message_id' => $message_id > 0 ? $message_id : null,
            'wp_attachment_id' => (int) ($attachment['wp_attachment_id'] ?? 0),
            'url' => (string) ($attachment['url'] ?? ''),
            'mime_type' => (string) ($attachment['mime_type'] ?? ''),
            'size_bytes' => (int) ($attachment['size_bytes'] ?? 0),
            'created_at' => $now,
        );
    }

    public static function verify_chat_token(array $ticket, string $token): bool
    {
        $saved = (string) ($ticket['chat_token'] ?? '');
        $token = trim($token);
        if ('' === $saved || '' === $token) {
            return false;
        }

        return hash_equals($saved, $token);
    }

    public static function customer_viewer_key(string $chat_token): string
    {
        return hash_hmac('sha256', $chat_token, wp_salt('auth'));
    }

    public static function admin_viewer_key(int $user_id): string
    {
        return (string) max(0, $user_id);
    }

    public static function mark_view(int $ticket_id, string $viewer_type, string $viewer_key, int $last_seen_message_id): void
    {
        global $wpdb;

        $table = self::views_table();
        $now = self::now();
        $viewer_type = strtolower(trim($viewer_type));
        if (!in_array($viewer_type, array('customer', 'admin'), true)) {
            return;
        }

        $existing_id = (int) $wpdb->get_var(
            $wpdb->prepare(
                "SELECT id FROM {$table} WHERE ticket_id = %d AND viewer_type = %s AND viewer_key = %s",
                $ticket_id,
                $viewer_type,
                $viewer_key
            )
        );

        if ($existing_id > 0) {
            $wpdb->update(
                $table,
                array(
                    'last_seen_message_id' => max(0, $last_seen_message_id),
                    'updated_at' => $now,
                ),
                array('id' => $existing_id),
                array('%d', '%s'),
                array('%d')
            );
            return;
        }

        $wpdb->insert(
            $table,
            array(
                'ticket_id' => $ticket_id,
                'viewer_type' => $viewer_type,
                'viewer_key' => $viewer_key,
                'last_seen_message_id' => max(0, $last_seen_message_id),
                'updated_at' => $now,
            ),
            array('%d', '%s', '%s', '%d', '%s')
        );
    }

    public static function get_last_seen(int $ticket_id, string $viewer_type, string $viewer_key): int
    {
        global $wpdb;
        $table = self::views_table();

        $value = (int) $wpdb->get_var(
            $wpdb->prepare(
                "SELECT last_seen_message_id FROM {$table}
                 WHERE ticket_id = %d AND viewer_type = %s AND viewer_key = %s
                 LIMIT 1",
                $ticket_id,
                $viewer_type,
                $viewer_key
            )
        );

        return max(0, $value);
    }

    public static function admin_unread_count(int $ticket_id, int $admin_user_id): int
    {
        global $wpdb;

        $last_seen = self::get_last_seen($ticket_id, 'admin', self::admin_viewer_key($admin_user_id));
        $messages = self::messages_table();

        $count = (int) $wpdb->get_var(
            $wpdb->prepare(
                "SELECT COUNT(*) FROM {$messages}
                 WHERE ticket_id = %d
                 AND id > %d
                 AND sender_type = %s
                 AND is_internal = 0",
                $ticket_id,
                $last_seen,
                'customer'
            )
        );

        return max(0, $count);
    }

    /**
     * @return array<string, mixed>
     */
    public static function with_sla_flags(array $ticket): array
    {
        $now = time();

        $created_at = strtotime((string) ($ticket['created_at'] ?? '')) ?: $now;
        $first_response_at = strtotime((string) ($ticket['first_response_at'] ?? '')) ?: 0;
        $resolved_at = strtotime((string) ($ticket['resolved_at'] ?? '')) ?: 0;
        $closed_at = strtotime((string) ($ticket['closed_at'] ?? '')) ?: 0;

        $first_limit = max(1, (int) ($ticket['sla_first_response_minutes'] ?? 60)) * MINUTE_IN_SECONDS;
        $resolve_limit = max(1, (int) ($ticket['sla_resolution_minutes'] ?? 1440)) * MINUTE_IN_SECONDS;

        $status = self::normalize_status((string) ($ticket['status'] ?? 'open'));

        $first_response_overdue = (0 === $first_response_at) && (($now - $created_at) > $first_limit);
        $resolution_overdue = !in_array($status, array('resolved', 'closed'), true)
            && (0 === $resolved_at)
            && (0 === $closed_at)
            && (($now - $created_at) > $resolve_limit);

        $ticket['first_response_overdue'] = $first_response_overdue;
        $ticket['resolution_overdue'] = $resolution_overdue;

        return $ticket;
    }

    /**
     * @return array<int, string>
     */
    public static function get_admin_recipients(): array
    {
        $recipients = array();

        if (class_exists('Lexi_Emails')) {
            $settings = Lexi_Emails::get_notification_settings();
            $management = is_array($settings['management_emails'] ?? null) ? $settings['management_emails'] : array();
            $accounting = is_array($settings['accounting_emails'] ?? null) ? $settings['accounting_emails'] : array();
            $recipients = array_merge($management, $accounting);
        }

        if (empty($recipients)) {
            $admin_email = (string) get_option('admin_email', '');
            if ('' !== $admin_email) {
                $recipients[] = $admin_email;
            }
        }

        $normalized = array();
        foreach ($recipients as $email) {
            $email = sanitize_email((string) $email);
            if ('' === $email) {
                continue;
            }
            $normalized[] = $email;
        }

        return array_values(array_unique($normalized));
    }

    public static function notify_admin(string $subject, string $html_body): void
    {
        $to = self::get_admin_recipients();
        if (empty($to)) {
            return;
        }

        if (class_exists('Lexi_Text')) {
            $subject = Lexi_Text::normalize($subject);
            $html_body = Lexi_Text::normalize($html_body);
        }

        wp_mail(
            implode(',', $to),
            $subject,
            $html_body,
            array('Content-Type: text/html; charset=UTF-8')
        );
    }

    /**
     * @return array<int, string>
     */
    public static function get_canned_replies(): array
    {
        $raw = get_option(self::CANNED_OPTION, array());
        if (!is_array($raw)) {
            return array();
        }

        $items = array();
        foreach ($raw as $row) {
            $text = trim(sanitize_text_field((string) $row));
            if ('' === $text) {
                continue;
            }
            $items[] = $text;
        }

        return array_values(array_unique($items));
    }

    /**
     * @param array<int, string> $items
     * @return array<int, string>
     */
    public static function save_canned_replies(array $items): array
    {
        $sanitized = array();
        foreach ($items as $row) {
            $text = trim(sanitize_text_field((string) $row));
            if ('' === $text) {
                continue;
            }
            $sanitized[] = $text;
        }

        $sanitized = array_values(array_unique($sanitized));
        update_option(self::CANNED_OPTION, $sanitized, false);
        return $sanitized;
    }

    /**
     * @param array<string, mixed> $ticket
     * @return array<string, mixed>
     */
    public static function normalize_ticket_payload(array $ticket): array
    {
        $status = self::normalize_status((string) ($ticket['status'] ?? 'open'));
        $category = self::normalize_category((string) ($ticket['category'] ?? 'other'));
        $priority = self::normalize_priority((string) ($ticket['priority'] ?? 'medium'));
        $tags_text = (string) ($ticket['tags'] ?? '');
        $tags = array_values(array_filter(array_map('trim', explode(',', $tags_text)), static function ($item) {
            return '' !== (string) $item;
        }));

        return array(
            'id' => (int) ($ticket['id'] ?? 0),
            'ticket_number' => (string) ($ticket['ticket_number'] ?? ''),
            'name' => (string) ($ticket['name'] ?? ''),
            'phone' => (string) ($ticket['phone'] ?? ''),
            'email' => (string) ($ticket['email'] ?? ''),
            'subject' => (string) ($ticket['subject'] ?? ''),
            'category' => $category,
            'category_label_ar' => self::category_label_ar($category),
            'priority' => $priority,
            'priority_label_ar' => self::priority_label_ar($priority),
            'status' => $status,
            'status_label_ar' => self::status_label_ar($status),
            'channel' => (string) ($ticket['channel'] ?? 'in_app'),
            'tags' => $tags,
            'tags_text' => $tags_text,
            'assigned_user_id' => (int) ($ticket['assigned_user_id'] ?? 0),
            'created_at' => (string) ($ticket['created_at'] ?? ''),
            'updated_at' => (string) ($ticket['updated_at'] ?? ''),
            'last_message_at' => (string) ($ticket['last_message_at'] ?? ''),
            'first_response_at' => (string) ($ticket['first_response_at'] ?? ''),
            'resolved_at' => (string) ($ticket['resolved_at'] ?? ''),
            'closed_at' => (string) ($ticket['closed_at'] ?? ''),
            'sla_first_response_minutes' => (int) ($ticket['sla_first_response_minutes'] ?? 60),
            'sla_resolution_minutes' => (int) ($ticket['sla_resolution_minutes'] ?? 1440),
            'customer_rating' => isset($ticket['customer_rating']) ? (int) $ticket['customer_rating'] : null,
            'customer_feedback' => (string) ($ticket['customer_feedback'] ?? ''),
        );
    }
}
