<?php
/**
 * Notifications system: DB table, creation hooks, and helper functions.
 *
 * @package Lexi_API
 */

defined('ABSPATH') || exit;

/**
 * Lexi Notifications Handler
 */
class Lexi_Notifications
{
    /** @var string Table name */
    private static string $table_name = 'lexi_notifications';
    private const TIMELINE_META_KEY = '_lexi_timeline';
    private const CUSTOMER_INBOX_META_KEY = '_lexi_customer_inbox';

    /**
     * Get full table name with WP prefix.
     */
    public static function table_name(): string
    {
        global $wpdb;
        return $wpdb->prefix . self::$table_name;
    }

    /**
     * Create the notifications table.
     */
    public static function create_table(): void
    {
        global $wpdb;

        $table_name = self::table_name();
        $charset_collate = $wpdb->get_charset_collate();

        $sql = "CREATE TABLE {$table_name} (
            id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
            audience ENUM('admin', 'customer') NOT NULL DEFAULT 'customer',
            user_id BIGINT UNSIGNED NULL,
            device_id VARCHAR(64) NULL,
            order_id BIGINT UNSIGNED NULL,
            type VARCHAR(32) NOT NULL,
            title_ar VARCHAR(120) NOT NULL,
            body_ar TEXT NOT NULL,
            data_json LONGTEXT NULL,
            is_read TINYINT(1) NOT NULL DEFAULT 0,
            created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
            PRIMARY KEY (id),
            INDEX idx_audience_read_created (audience, is_read, created_at),
            INDEX idx_user_read_created (user_id, is_read, created_at),
            INDEX idx_device_read_created (device_id, is_read, created_at),
            INDEX idx_order (order_id)
        ) {$charset_collate};";

        require_once ABSPATH . 'wp-admin/includes/upgrade.php';
        dbDelta($sql);
    }

    /**
     * Insert a notification.
     *
     * @param array $args Notification data.
     * @return int|false Inserted ID or false on failure.
     */
    public static function insert(array $args): int|false
    {
        global $wpdb;

        $defaults = [
            'audience' => 'customer',
            'user_id' => null,
            'device_id' => null,
            'order_id' => null,
            'type' => '',
            'title_ar' => '',
            'body_ar' => '',
            'data_json' => null,
            'is_read' => 0,
            'created_at' => current_time('mysql', true),
        ];

        $data = wp_parse_args($args, $defaults);

        // Sanitize
        $data['title_ar'] = sanitize_text_field($data['title_ar']);
        $data['body_ar'] = sanitize_textarea_field($data['body_ar']);
        $data['type'] = sanitize_text_field($data['type']);

        if ($data['data_json'] !== null && is_array($data['data_json'])) {
            $data['data_json'] = wp_json_encode($data['data_json'], JSON_UNESCAPED_UNICODE);
        }

        $result = $wpdb->insert(self::table_name(), $data);

        return $result ? (int) $wpdb->insert_id : false;
    }

    /**
     * Create notification for admin users (fan-out to all admins).
     *
     * @param string $type Notification type.
     * @param string $title_ar Arabic title.
     * @param string $body_ar Arabic body.
     * @param int|null $order_id Order ID.
     * @param array|null $data_json Additional data.
     */
    public static function notify_admins(
        string $type,
        string $title_ar,
        string $body_ar,
        ?int $order_id = null,
        ?array $data_json = null
    ): void {
        // Get all admin and shop_manager users
        $admin_users = get_users([
            'role__in' => ['administrator', 'shop_manager'],
            'fields' => ['ID'],
        ]);

        foreach ($admin_users as $admin) {
            self::insert([
                'audience' => 'admin',
                'user_id' => (int) $admin->ID,
                'order_id' => $order_id,
                'type' => $type,
                'title_ar' => $title_ar,
                'body_ar' => $body_ar,
                'data_json' => $data_json,
            ]);
        }
    }

    /**
     * Broadcast notification to all customers who have used the app.
     * Note: This is an expensive operation if the user base is huge.
     * In a real enterprise app, this would use a background task or FCM broadcast.
     *
     * @param string $type
     * @param string $title_ar
     * @param string $body_ar
     * @return int Number of rows inserted.
     */
    public static function broadcast_customer(string $type, string $title_ar, string $body_ar): int
    {
        global $wpdb;
        $table = self::table_name();

        // Find all unique users and device IDs from the notifications table to identify "active" targets
        // This is a naive way to find "customers" without iterating over the entire WP Users table.
        $targets = $wpdb->get_results(
            "SELECT DISTINCT user_id, device_id 
             FROM {$table} 
             WHERE audience = 'customer' 
             AND (user_id IS NOT NULL OR device_id IS NOT NULL)",
            ARRAY_A
        );

        if (empty($targets)) {
            return 0;
        }

        $count = 0;
        foreach ($targets as $target) {
            $inserted = self::insert([
                'audience' => 'customer',
                'user_id' => $target['user_id'] ? (int) $target['user_id'] : null,
                'device_id' => $target['device_id'] ?: null,
                'type' => $type,
                'title_ar' => $title_ar,
                'body_ar' => $body_ar,
            ]);
            if ($inserted) {
                $count++;
            }
        }

        return $count;
    }

    /**
     * Create notification for a customer.
     * @param int|null $user_id WP user ID (for logged-in customers).
     * @param string|null $device_id Device ID (for guest customers).
     * @param string $type Notification type.
     * @param string $title_ar Arabic title.
     * @param string $body_ar Arabic body.
     * @param int|null $order_id Order ID.
     * @param array|null $data_json Additional data.
     */
    public static function notify_customer(
        ?int $user_id,
        ?string $device_id,
        string $type,
        string $title_ar,
        string $body_ar,
        ?int $order_id = null,
        ?array $data_json = null
    ): void {
        if ($user_id === null && empty($device_id)) {
            return; // Cannot identify customer
        }

        self::insert([
            'audience' => 'customer',
            'user_id' => $user_id,
            'device_id' => $device_id ? sanitize_text_field($device_id) : null,
            'order_id' => $order_id,
            'type' => $type,
            'title_ar' => $title_ar,
            'body_ar' => $body_ar,
            'data_json' => $data_json,
        ]);
    }

    /**
     * Get notifications for a user.
     *
     * @param string $audience 'admin' or 'customer'.
     * @param int|null $user_id WP user ID.
     * @param string|null $device_id Device ID for guests.
     * @param int $page Page number.
     * @param int $per_page Items per page.
     * @return array ['items' => array, 'total' => int, 'unread_count' => int]
     */
    public static function get_notifications(
        string $audience,
        ?int $user_id = null,
        ?string $device_id = null,
        int $page = 1,
        int $per_page = 20
    ): array {
        global $wpdb;

        $table = self::table_name();
        $offset = ($page - 1) * $per_page;

        $where = 'WHERE audience = %s';
        $args = [$audience];

        if ($audience === 'customer') {
            if ($user_id) {
                $where .= ' AND user_id = %d';
                $args[] = $user_id;
            } elseif ($device_id) {
                $where .= ' AND device_id = %s';
                $args[] = $device_id;
            } else {
                return ['items' => [], 'total' => 0, 'unread_count' => 0];
            }
        } elseif ($audience === 'admin' && $user_id) {
            $where .= ' AND user_id = %d';
            $args[] = $user_id;
        }

        // Get total count
        $count_query = "SELECT COUNT(*) FROM {$table} {$where}";
        $total = (int) $wpdb->get_var($wpdb->prepare($count_query, ...$args));

        // Get unread count
        $unread_query = "SELECT COUNT(*) FROM {$table} {$where} AND is_read = 0";
        $unread_count = (int) $wpdb->get_var($wpdb->prepare($unread_query, ...$args));

        // Get items
        $args[] = $per_page;
        $args[] = $offset;
        $items_query = "SELECT * FROM {$table} {$where} ORDER BY created_at DESC LIMIT %d OFFSET %d";
        $rows = $wpdb->get_results($wpdb->prepare($items_query, ...$args), ARRAY_A);

        $items = array_map(function ($row) {
            return [
                'id' => (int) $row['id'],
                'type' => $row['type'],
                'title_ar' => $row['title_ar'],
                'body_ar' => $row['body_ar'],
                'order_id' => $row['order_id'] ? (int) $row['order_id'] : null,
                'is_read' => (bool) $row['is_read'],
                'created_at' => $row['created_at'],
                'data' => $row['data_json'] ? json_decode($row['data_json'], true) : null,
            ];
        }, $rows);

        return [
            'items' => $items,
            'total' => $total,
            'unread_count' => $unread_count,
        ];
    }

    /**
     * Mark notifications as read.
     *
     * @param array $ids Notification IDs.
     * @param string $audience 'admin' or 'customer'.
     * @param int|null $user_id WP user ID.
     * @param string|null $device_id Device ID for guests.
     * @return int Number of updated rows.
     */
    public static function mark_read(
        array $ids,
        string $audience,
        ?int $user_id = null,
        ?string $device_id = null
    ): int {
        global $wpdb;

        if (empty($ids)) {
            return 0;
        }

        $table = self::table_name();
        $ids = array_map('intval', $ids);
        $ids_placeholders = implode(',', array_fill(0, count($ids), '%d'));

        $where = "WHERE id IN ({$ids_placeholders}) AND audience = %s";
        $args = [...$ids, $audience];

        if ($audience === 'customer') {
            if ($user_id) {
                $where .= ' AND user_id = %d';
                $args[] = $user_id;
            } elseif ($device_id) {
                $where .= ' AND device_id = %s';
                $args[] = $device_id;
            }
        } elseif ($audience === 'admin' && $user_id) {
            $where .= ' AND user_id = %d';
            $args[] = $user_id;
        }

        $sql = "UPDATE {$table} SET is_read = 1 {$where}";
        return (int) $wpdb->query($wpdb->prepare($sql, ...$args));
    }

    /**
     * Mark all notifications as read.
     *
     * @param string $audience 'admin' or 'customer'.
     * @param int|null $user_id WP user ID.
     * @param string|null $device_id Device ID for guests.
     * @return int Number of updated rows.
     */
    public static function mark_all_read(
        string $audience,
        ?int $user_id = null,
        ?string $device_id = null
    ): int {
        global $wpdb;

        $table = self::table_name();

        $where = 'WHERE audience = %s AND is_read = 0';
        $args = [$audience];

        if ($audience === 'customer') {
            if ($user_id) {
                $where .= ' AND user_id = %d';
                $args[] = $user_id;
            } elseif ($device_id) {
                $where .= ' AND device_id = %s';
                $args[] = $device_id;
            }
        } elseif ($audience === 'admin' && $user_id) {
            $where .= ' AND user_id = %d';
            $args[] = $user_id;
        }

        $sql = "UPDATE {$table} SET is_read = 1 {$where}";
        return (int) $wpdb->query($wpdb->prepare($sql, ...$args));
    }

    /**
     * Get unread count.
     *
     * @param string $audience 'admin' or 'customer'.
     * @param int|null $user_id WP user ID.
     * @param string|null $device_id Device ID for guests.
     * @return int Unread count.
     */
    public static function get_unread_count(
        string $audience,
        ?int $user_id = null,
        ?string $device_id = null
    ): int {
        global $wpdb;

        $table = self::table_name();

        $where = 'WHERE audience = %s AND is_read = 0';
        $args = [$audience];

        if ($audience === 'customer') {
            if ($user_id) {
                $where .= ' AND user_id = %d';
                $args[] = $user_id;
            } elseif ($device_id) {
                $where .= ' AND device_id = %s';
                $args[] = $device_id;
            } else {
                return 0;
            }
        } elseif ($audience === 'admin' && $user_id) {
            $where .= ' AND user_id = %d';
            $args[] = $user_id;
        }

        $sql = "SELECT COUNT(*) FROM {$table} {$where}";
        return (int) $wpdb->get_var($wpdb->prepare($sql, ...$args));
    }

    /**
     * Append an order timeline event.
     */
    public static function append_timeline(WC_Order $order, string $type, string $message_ar): void
    {
        $type = sanitize_key($type);
        $message_ar = trim(wp_strip_all_tags($message_ar));
        if ('' === $type || '' === $message_ar) {
            return;
        }

        $timeline = self::get_timeline($order);
        $timeline[] = array(
            'type' => $type,
            'message_ar' => $message_ar,
            'created_at' => current_time('mysql'),
        );

        if (count($timeline) > 200) {
            $timeline = array_slice($timeline, -200);
        }

        $order->update_meta_data(self::TIMELINE_META_KEY, array_values($timeline));
        $order->save();
    }

    /**
     * Return timeline items for tracking endpoint.
     *
     * @return array<int, array<string, string>>
     */
    public static function get_timeline(WC_Order $order): array
    {
        $raw = $order->get_meta(self::TIMELINE_META_KEY, true);
        $items = self::normalize_timeline_items($raw);

        if (empty($items)) {
            $created = $order->get_date_created();
            $items[] = array(
                'type' => 'created',
                'message_ar' => sprintf('تم إنشاء الطلب رقم #%s.', $order->get_order_number()),
                'created_at' => $created ? $created->date_i18n('Y-m-d H:i:s') : current_time('mysql'),
            );
        }

        usort($items, static function (array $a, array $b): int {
            return strcmp((string) ($a['created_at'] ?? ''), (string) ($b['created_at'] ?? ''));
        });

        return array_values($items);
    }

    /**
     * Notify admins for COD order creation.
     */
    public static function notify_admin_new_cod_order(WC_Order $order): void
    {
        $order_number = (string) $order->get_order_number();
        self::notify_admins(
            'new_cod_order',
            'طلب جديد - الدفع عند الاستلام',
            sprintf('تم إنشاء طلب جديد رقم #%s بالدفع عند الاستلام.', $order_number),
            (int) $order->get_id(),
            array(
                'order_id' => (int) $order->get_id(),
                'order_number' => $order_number,
                'payment_method' => 'cod',
            )
        );

        if (class_exists('Lexi_Emails')) {
            Lexi_Emails::send_internal_order_email_once($order, 'notify_admin_new_cod_order');
            Lexi_Emails::trigger_new_order_email((int) $order->get_id());
        }
    }

    /**
     * Notify admins when ShamCash proof is uploaded.
     */
    public static function notify_admin_shamcash_proof_uploaded(WC_Order $order, string $proof_url): void
    {
        $order_number = (string) $order->get_order_number();
        self::notify_admins(
            'shamcash_proof_uploaded',
            'طلب جديد - إيصال شام كاش مرفوع',
            sprintf('تم رفع إيصال شام كاش للطلب رقم #%s.', $order_number),
            (int) $order->get_id(),
            array(
                'order_id' => (int) $order->get_id(),
                'order_number' => $order_number,
                'payment_method' => 'sham_cash',
                'proof_url' => esc_url_raw($proof_url),
            )
        );

        if (class_exists('Lexi_Emails')) {
            Lexi_Emails::send_internal_order_email_once($order, 'notify_admin_shamcash_proof_uploaded');
            Lexi_Emails::trigger_new_order_email((int) $order->get_id());
        }
    }

    /**
     * Notify customer about approve/reject decision and store inbox fallback.
     */
    public static function notify_customer_decision(WC_Order $order, string $decision, string $note_ar = ''): void
    {
        $decision = strtolower(trim($decision));
        $order_number = (string) $order->get_order_number();

        if ('approved' === $decision) {
            $title = 'تم قبول طلبك';
            $message = sprintf('تم قبول طلبك رقم #%s وسيتم تجهيزه.', $order_number);
        } else {
            $title = 'تم رفض طلبك';
            $message = sprintf('تم رفض طلبك رقم #%s. يرجى التواصل معنا إذا كان هناك خطأ.', $order_number);
            $decision = 'rejected';
        }

        $clean_note = trim(wp_strip_all_tags($note_ar));
        if ('' !== $clean_note) {
            $message .= ' ملاحظة الإدارة: ' . $clean_note;
        }

        $user_id = (int) $order->get_user_id();
        $device_id = trim((string) $order->get_meta('_lexi_device_id'));
        if ('' === $device_id) {
            $device_id = trim((string) $order->get_meta('_lexi_device_token'));
        }

        self::notify_customer(
            $user_id > 0 ? $user_id : null,
            '' !== $device_id ? $device_id : null,
            'order_' . $decision,
            $title,
            $message,
            (int) $order->get_id(),
            array(
                'order_id' => (int) $order->get_id(),
                'order_number' => $order_number,
                'decision' => $decision,
            )
        );

        self::append_customer_inbox($order, $title, $message);
    }

    /**
     * Return customer inbox messages for a specific order.
     *
     * @return array<int, array<string, string>>
     */
    public static function get_customer_inbox(WC_Order $order): array
    {
        $items = self::normalize_inbox_items($order->get_meta(self::CUSTOMER_INBOX_META_KEY, true));

        global $wpdb;
        $table = self::table_name();
        $table_exists = (string) $wpdb->get_var(
            $wpdb->prepare('SHOW TABLES LIKE %s', $table)
        ) === $table;

        if ($table_exists) {
            $rows = $wpdb->get_results(
                $wpdb->prepare(
                    "SELECT title_ar, body_ar, created_at
                     FROM {$table}
                     WHERE audience = 'customer' AND order_id = %d
                     ORDER BY id DESC
                     LIMIT 20",
                    (int) $order->get_id()
                ),
                ARRAY_A
            );

            if (is_array($rows)) {
                foreach ($rows as $row) {
                    if (!is_array($row)) {
                        continue;
                    }
                    $items[] = array(
                        'title' => sanitize_text_field((string) ($row['title_ar'] ?? '')),
                        'message' => sanitize_textarea_field((string) ($row['body_ar'] ?? '')),
                        'created_at' => sanitize_text_field((string) ($row['created_at'] ?? '')),
                    );
                }
            }
        }

        $items = array_values(array_filter($items, static function (array $item): bool {
            return '' !== trim((string) ($item['title'] ?? '')) || '' !== trim((string) ($item['message'] ?? ''));
        }));

        usort($items, static function (array $a, array $b): int {
            return strcmp((string) ($b['created_at'] ?? ''), (string) ($a['created_at'] ?? ''));
        });

        if (count($items) > 20) {
            $items = array_slice($items, 0, 20);
        }

        return $items;
    }

    /**
     * Store customer-facing message in order meta for track fallback.
     */
    private static function append_customer_inbox(WC_Order $order, string $title, string $message): void
    {
        $title = sanitize_text_field($title);
        $message = sanitize_textarea_field($message);
        if ('' === $title && '' === $message) {
            return;
        }

        $items = self::normalize_inbox_items($order->get_meta(self::CUSTOMER_INBOX_META_KEY, true));
        $items[] = array(
            'title' => $title,
            'message' => $message,
            'created_at' => current_time('mysql'),
        );

        if (count($items) > 50) {
            $items = array_slice($items, -50);
        }

        $order->update_meta_data(self::CUSTOMER_INBOX_META_KEY, array_values($items));
        $order->save();
    }

    /**
     * @param mixed $raw
     * @return array<int, array<string, string>>
     */
    private static function normalize_timeline_items($raw): array
    {
        if (!is_array($raw)) {
            return array();
        }

        $items = array();
        foreach ($raw as $item) {
            if (!is_array($item)) {
                continue;
            }

            $type = sanitize_key((string) ($item['type'] ?? ''));
            $message = sanitize_textarea_field((string) ($item['message_ar'] ?? ''));
            $created_at = sanitize_text_field((string) ($item['created_at'] ?? ''));

            if ('' === $type || '' === $message || '' === $created_at) {
                continue;
            }

            $items[] = array(
                'type' => $type,
                'message_ar' => $message,
                'created_at' => $created_at,
            );
        }

        return $items;
    }

    /**
     * @param mixed $raw
     * @return array<int, array<string, string>>
     */
    private static function normalize_inbox_items($raw): array
    {
        if (!is_array($raw)) {
            return array();
        }

        $items = array();
        foreach ($raw as $item) {
            if (!is_array($item)) {
                continue;
            }

            $title = sanitize_text_field((string) ($item['title'] ?? ''));
            $message = sanitize_textarea_field((string) ($item['message'] ?? ''));
            $created_at = sanitize_text_field((string) ($item['created_at'] ?? ''));

            if ('' === $created_at) {
                $created_at = current_time('mysql');
            }

            if ('' === $title && '' === $message) {
                continue;
            }

            $items[] = array(
                'title' => $title,
                'message' => $message,
                'created_at' => $created_at,
            );
        }

        return $items;
    }

    /**
     * Format currency for display.
     *
     * @param float $amount Amount.
     * @return string Formatted amount.
     */
    public static function format_currency(float $amount): string
    {
        return number_format($amount, 0, ',', ',') . ' ل.س';
    }
}
