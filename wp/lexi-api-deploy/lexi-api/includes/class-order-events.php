<?php
/**
 * Operational order events audit log.
 *
 * @package Lexi_API
 */

defined('ABSPATH') || exit;

class Lexi_Order_Events
{
    private const TABLE = 'lexi_order_events';

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
            order_id BIGINT UNSIGNED NULL,
            courier_id BIGINT UNSIGNED NULL,
            event_type VARCHAR(64) NOT NULL,
            amount DECIMAL(20,6) NULL,
            actor_role VARCHAR(32) NOT NULL DEFAULT 'system',
            actor_id BIGINT UNSIGNED NULL,
            payload_json LONGTEXT NULL,
            created_at DATETIME NOT NULL,
            PRIMARY KEY (id),
            KEY idx_order_id (order_id),
            KEY idx_courier_id (courier_id),
            KEY idx_event_type (event_type),
            KEY idx_actor (actor_role, actor_id),
            KEY idx_created_at (created_at)
        ) {$charset};";

        dbDelta($sql);
    }

    /**
     * @param array<string,mixed> $payload
     */
    public static function log(
        ?int $order_id,
        string $event_type,
        string $actor_role = 'system',
        ?int $actor_id = null,
        array $payload = array(),
        ?int $courier_id = null,
        ?float $amount = null
    ): void {
        global $wpdb;

        if (
            (null === $order_id || $order_id <= 0) &&
            (null === $courier_id || $courier_id <= 0) &&
            (null === $actor_id || $actor_id <= 0)
        ) {
            return;
        }
        if (trim($event_type) === '') {
            return;
        }

        $role = strtolower(trim($actor_role));
        if (!in_array($role, array('system', 'admin', 'courier', 'customer'), true)) {
            $role = 'system';
        }

        $resolved_courier_id = self::resolve_courier_id(
            $courier_id,
            $role,
            $actor_id,
            $payload
        );
        $resolved_amount = self::resolve_amount($amount, $payload);

        $wpdb->insert(
            self::table_name(),
            array(
                'order_id' => null !== $order_id && $order_id > 0 ? (int) $order_id : null,
                'courier_id' => $resolved_courier_id,
                'event_type' => sanitize_key($event_type),
                'amount' => null !== $resolved_amount ? (string) $resolved_amount : null,
                'actor_role' => $role,
                'actor_id' => null !== $actor_id && $actor_id > 0 ? (int) $actor_id : null,
                'payload_json' => !empty($payload)
                    ? wp_json_encode($payload, JSON_UNESCAPED_UNICODE)
                    : null,
                'created_at' => current_time('mysql', true),
            ),
            array('%d', '%d', '%s', '%f', '%s', '%d', '%s', '%s')
        );
    }

    /**
     * @return array<int,array<string,mixed>>
     */
    public static function list_by_order(int $order_id, int $limit = 100): array
    {
        global $wpdb;

        if ($order_id <= 0) {
            return array();
        }

        $limit = min(500, max(1, $limit));
        $table = self::table_name();

        $rows = $wpdb->get_results(
            $wpdb->prepare(
                "SELECT id, order_id, courier_id, event_type, amount, actor_role, actor_id, payload_json, created_at
                 FROM {$table}
                 WHERE order_id = %d
                 ORDER BY id DESC
                 LIMIT %d",
                $order_id,
                $limit
            ),
            ARRAY_A
        );

        if (!is_array($rows)) {
            return array();
        }

        return array_map(
            static function (array $row): array {
                $payload = array();
                if (!empty($row['payload_json'])) {
                    $decoded = json_decode((string) $row['payload_json'], true);
                    if (is_array($decoded)) {
                        $payload = $decoded;
                    }
                }

                return array(
                    'id' => (int) ($row['id'] ?? 0),
                    'order_id' => (int) ($row['order_id'] ?? 0),
                    'courier_id' => !empty($row['courier_id']) ? (int) $row['courier_id'] : null,
                    'event_type' => (string) ($row['event_type'] ?? ''),
                    'amount' => isset($row['amount']) && $row['amount'] !== null ? (float) $row['amount'] : null,
                    'actor_role' => (string) ($row['actor_role'] ?? 'system'),
                    'actor_id' => !empty($row['actor_id']) ? (int) $row['actor_id'] : null,
                    'payload' => $payload,
                    'created_at' => (string) ($row['created_at'] ?? ''),
                );
            },
            $rows
        );
    }

    /**
     * @param array<string,mixed> $payload
     */
    private static function resolve_courier_id(
        ?int $courier_id,
        string $actor_role,
        ?int $actor_id,
        array $payload
    ): ?int {
        if (null !== $courier_id && $courier_id > 0) {
            return (int) $courier_id;
        }

        if ($actor_role === 'courier' && null !== $actor_id && $actor_id > 0) {
            return (int) $actor_id;
        }

        $payload_courier_id = isset($payload['courier_id'])
            ? (int) $payload['courier_id']
            : 0;
        if ($payload_courier_id > 0) {
            return $payload_courier_id;
        }

        return null;
    }

    /**
     * @param array<string,mixed> $payload
     */
    private static function resolve_amount(?float $amount, array $payload): ?float
    {
        if (null !== $amount && is_numeric($amount)) {
            return (float) $amount;
        }

        $candidates = array(
            $payload['amount'] ?? null,
            $payload['received'] ?? null,
            $payload['collected_total'] ?? null,
            $payload['final_amount'] ?? null,
        );

        foreach ($candidates as $candidate) {
            if ($candidate === null || $candidate === '') {
                continue;
            }
            if (is_numeric($candidate)) {
                return (float) $candidate;
            }
        }

        return null;
    }
}
