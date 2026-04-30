<?php
/**
 * Delivery audit log: courier assignment and COD collection attempts.
 *
 * @package Lexi_API
 */

defined('ABSPATH') || exit;

class Lexi_Delivery_Audit
{
    private const TABLE = 'lexi_delivery_audit';

    public static function table_name(): string
    {
        global $wpdb;
        return $wpdb->prefix . self::TABLE;
    }

    public static function create_table(): void
    {
        global $wpdb;
        require_once ABSPATH . 'wp-admin/includes/upgrade.php';

        $table = self::table_name();
        $charset = $wpdb->get_charset_collate();

        $sql = "CREATE TABLE {$table} (
            id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
            event_type VARCHAR(60) NOT NULL,
            order_id BIGINT UNSIGNED NOT NULL,
            courier_id BIGINT UNSIGNED NULL,
            admin_id BIGINT UNSIGNED NULL,
            status VARCHAR(40) NOT NULL DEFAULT 'info',
            message TEXT NULL,
            meta LONGTEXT NULL,
            ip VARCHAR(64) NULL,
            user_agent VARCHAR(255) NULL,
            created_at DATETIME NOT NULL,
            PRIMARY KEY  (id),
            KEY order_id (order_id),
            KEY courier_id (courier_id),
            KEY event_type (event_type),
            KEY created_at (created_at)
        ) {$charset};";

        dbDelta($sql);
    }

    /**
     * @param array<string,mixed> $meta
     */
    public static function log(
        string $event_type,
        int $order_id,
        ?int $courier_id = null,
        ?int $admin_id = null,
        string $status = 'info',
        string $message = '',
        array $meta = array()
    ): void {
        global $wpdb;

        $ip = '';
        if (!empty($_SERVER['REMOTE_ADDR'])) {
            $ip = sanitize_text_field(wp_unslash((string) $_SERVER['REMOTE_ADDR']));
        }

        $ua = '';
        if (!empty($_SERVER['HTTP_USER_AGENT'])) {
            $ua = substr(sanitize_text_field(wp_unslash((string) $_SERVER['HTTP_USER_AGENT'])), 0, 255);
        }

        $wpdb->insert(
            self::table_name(),
            array(
                'event_type' => sanitize_text_field($event_type),
                'order_id' => (int) $order_id,
                'courier_id' => null !== $courier_id ? (int) $courier_id : null,
                'admin_id' => null !== $admin_id ? (int) $admin_id : null,
                'status' => sanitize_text_field($status),
                'message' => sanitize_textarea_field($message),
                'meta' => !empty($meta) ? wp_json_encode($meta) : null,
                'ip' => $ip,
                'user_agent' => $ua,
                'created_at' => current_time('mysql', true),
            ),
            array('%s', '%d', '%d', '%d', '%s', '%s', '%s', '%s', '%s', '%s')
        );
    }

    /**
     * @return array<int,array<string,mixed>>
     */
    public static function list(array $filters = array(), int $page = 1, int $per_page = 50): array
    {
        global $wpdb;

        $page = max(1, $page);
        $per_page = min(200, max(1, $per_page));
        $offset = ($page - 1) * $per_page;

        $where = array('1=1');
        $params = array();

        if (!empty($filters['order_id'])) {
            $where[] = 'order_id = %d';
            $params[] = (int) $filters['order_id'];
        }

        if (!empty($filters['courier_id'])) {
            $where[] = 'courier_id = %d';
            $params[] = (int) $filters['courier_id'];
        }

        if (!empty($filters['event_type'])) {
            $where[] = 'event_type = %s';
            $params[] = (string) $filters['event_type'];
        }

        $table = self::table_name();
        $sql = "SELECT * FROM {$table} WHERE " . implode(' AND ', $where) . ' ORDER BY id DESC LIMIT %d OFFSET %d';
        $params[] = $per_page;
        $params[] = $offset;

        $prepared = $wpdb->prepare($sql, $params);
        $rows = $wpdb->get_results($prepared, ARRAY_A);

        return is_array($rows) ? $rows : array();
    }
}
