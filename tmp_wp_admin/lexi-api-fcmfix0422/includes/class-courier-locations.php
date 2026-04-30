<?php
/**
 * Courier last-known location storage.
 *
 * @package Lexi_API
 */

defined('ABSPATH') || exit;

class Lexi_Courier_Locations
{
    private const TABLE = 'lexi_courier_locations';
    private const DEFAULT_STALE_AFTER_MINUTES = 10;

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
            courier_id BIGINT UNSIGNED NOT NULL,
            lat DOUBLE NOT NULL,
            lng DOUBLE NOT NULL,
            accuracy_m DOUBLE NULL,
            heading DOUBLE NULL,
            speed_mps DOUBLE NULL,
            updated_at DATETIME NOT NULL,
            device_id VARCHAR(191) NULL,
            PRIMARY KEY (courier_id),
            KEY idx_updated_at (updated_at),
            KEY idx_device_id (device_id)
        ) {$charset};";

        dbDelta($sql);
    }

    public static function stale_after_minutes(): int
    {
        $raw = get_option('lexi_courier_location_stale_minutes', self::DEFAULT_STALE_AFTER_MINUTES);
        $value = is_numeric($raw) ? (int) $raw : self::DEFAULT_STALE_AFTER_MINUTES;
        return min(60, max(1, $value));
    }

    public static function upsert(
        int $courier_id,
        float $lat,
        float $lng,
        ?float $accuracy_m = null,
        ?float $heading = null,
        ?float $speed_mps = null,
        string $device_id = ''
    ): bool {
        global $wpdb;

        if ($courier_id <= 0) {
            return false;
        }

        $result = $wpdb->replace(
            self::table_name(),
            array(
                'courier_id' => $courier_id,
                'lat' => $lat,
                'lng' => $lng,
                'accuracy_m' => $accuracy_m,
                'heading' => $heading,
                'speed_mps' => $speed_mps,
                'updated_at' => current_time('mysql', true),
                'device_id' => $device_id !== '' ? $device_id : null,
            ),
            array('%d', '%f', '%f', '%f', '%f', '%f', '%s', '%s')
        );

        return $result !== false;
    }

    /**
     * @return array<string,mixed>|null
     */
    public static function get(int $courier_id): ?array
    {
        global $wpdb;

        if ($courier_id <= 0) {
            return null;
        }

        $row = $wpdb->get_row(
            $wpdb->prepare(
                "SELECT courier_id, lat, lng, accuracy_m, heading, speed_mps, updated_at, device_id
                 FROM " . self::table_name() . "
                 WHERE courier_id = %d
                 LIMIT 1",
                $courier_id
            ),
            ARRAY_A
        );
        if (!is_array($row)) {
            return null;
        }

        return array(
            'courier_id' => (int) ($row['courier_id'] ?? 0),
            'lat' => isset($row['lat']) ? (float) $row['lat'] : 0.0,
            'lng' => isset($row['lng']) ? (float) $row['lng'] : 0.0,
            'accuracy_m' => isset($row['accuracy_m']) && $row['accuracy_m'] !== null ? (float) $row['accuracy_m'] : null,
            'heading' => isset($row['heading']) && $row['heading'] !== null ? (float) $row['heading'] : null,
            'speed_mps' => isset($row['speed_mps']) && $row['speed_mps'] !== null ? (float) $row['speed_mps'] : null,
            'updated_at' => (string) ($row['updated_at'] ?? ''),
            'device_id' => (string) ($row['device_id'] ?? ''),
        );
    }

    public static function has_recent_ping(int $courier_id, ?int $max_age_minutes = null): bool
    {
        $location = self::get($courier_id);
        if (!is_array($location)) {
            return false;
        }

        $updated_at = trim((string) ($location['updated_at'] ?? ''));
        if ($updated_at === '') {
            return false;
        }

        $updated_ts = strtotime($updated_at . ' UTC');
        if ($updated_ts === false || $updated_ts <= 0) {
            return false;
        }

        $age_minutes = (time() - $updated_ts) / 60;
        $limit = $max_age_minutes !== null
            ? max(1, $max_age_minutes)
            : self::stale_after_minutes();

        return $age_minutes <= $limit;
    }
}

