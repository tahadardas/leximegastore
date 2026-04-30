<?php
/**
 * Shipping Cities: custom DB table, CRUD, seed data.
 *
 * @package Lexi_API
 */

defined('ABSPATH') || exit;

class Lexi_Shipping_Cities
{

    /**
     * Get full table name.
     */
    public static function table_name(): string
    {
        global $wpdb;
        return $wpdb->prefix . 'lexi_shipping_cities';
    }

    /* ── Schema ────────────────────────────────────────────── */

    /**
     * Create the shipping cities table (idempotent).
     */
    public static function create_table(): void
    {
        global $wpdb;

        $table = self::table_name();
        $charset = $wpdb->get_charset_collate();

        $sql = "CREATE TABLE {$table} (
			id         BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
			name       VARCHAR(255)    NOT NULL,
			price      DECIMAL(10,2)   NOT NULL DEFAULT 0,
			is_active  TINYINT(1)      NOT NULL DEFAULT 1,
			sort_order INT             NOT NULL DEFAULT 0,
			created_at DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP,
			updated_at DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
			PRIMARY KEY (id)
		) {$charset};";

        require_once ABSPATH . 'wp-admin/includes/upgrade.php';
        dbDelta($sql);
    }

    /**
     * Seed default cities if table is empty.
     */
    public static function seed(): void
    {
        global $wpdb;

        $table = self::table_name();
        $count = (int) $wpdb->get_var("SELECT COUNT(*) FROM {$table}"); // phpcs:ignore

        if ($count > 0) {
            return;
        }

        $cities = array(
            array('name' => 'دمشق', 'price' => 5000, 'sort_order' => 1),
            array('name' => 'حلب', 'price' => 8000, 'sort_order' => 2),
            array('name' => 'حمص', 'price' => 6000, 'sort_order' => 3),
        );

        foreach ($cities as $city) {
            $wpdb->insert(
                $table,
                array(
                    'name' => $city['name'],
                    'price' => $city['price'],
                    'sort_order' => $city['sort_order'],
                    'is_active' => 1,
                ),
                array('%s', '%f', '%d', '%d')
            );
        }
    }

    /* ── Read ──────────────────────────────────────────────── */

    /**
     * Get all active cities, ordered by sort_order.
     *
     * @return array
     */
    public static function get_active(): array
    {
        global $wpdb;
        $table = self::table_name();

        return $wpdb->get_results(
            "SELECT id, name, price, sort_order FROM {$table} WHERE is_active = 1 ORDER BY sort_order ASC", // phpcs:ignore
            ARRAY_A
        ) ?: array();
    }

    /**
     * Get ALL cities (admin view).
     *
     * @return array
     */
    public static function get_all(): array
    {
        global $wpdb;
        $table = self::table_name();

        return $wpdb->get_results(
            "SELECT * FROM {$table} ORDER BY sort_order ASC", // phpcs:ignore
            ARRAY_A
        ) ?: array();
    }

    /**
     * Get a single city by ID.
     *
     * @param int $id City ID.
     * @return array|null
     */
    public static function get_by_id(int $id): ?array
    {
        global $wpdb;
        $table = self::table_name();

        $row = $wpdb->get_row(
            $wpdb->prepare("SELECT * FROM {$table} WHERE id = %d", $id), // phpcs:ignore
            ARRAY_A
        );

        return $row ?: null;
    }

    /* ── Create ────────────────────────────────────────────── */

    /**
     * Insert a new city.
     *
     * @param array $data { name, price, is_active?, sort_order? }.
     * @return int|false Inserted ID or false.
     */
    public static function create(array $data)
    {
        global $wpdb;

        $result = $wpdb->insert(
            self::table_name(),
            array(
                'name' => sanitize_text_field($data['name']),
                'price' => floatval($data['price']),
                'is_active' => isset($data['is_active']) ? absint($data['is_active']) : 1,
                'sort_order' => isset($data['sort_order']) ? absint($data['sort_order']) : 0,
            ),
            array('%s', '%f', '%d', '%d')
        );

        if (!$result) {
            return false;
        }

        self::invalidate_shipping_cache_if_available();
        return $wpdb->insert_id;
    }

    /* ── Update ────────────────────────────────────────────── */

    /**
     * Update a city.
     *
     * @param int   $id   City ID.
     * @param array $data Fields to update.
     * @return bool
     */
    public static function update(int $id, array $data): bool
    {
        global $wpdb;

        $fields = array();
        $formats = array();

        if (isset($data['name'])) {
            $fields['name'] = sanitize_text_field($data['name']);
            $formats[] = '%s';
        }
        if (isset($data['price'])) {
            $fields['price'] = floatval($data['price']);
            $formats[] = '%f';
        }
        if (isset($data['is_active'])) {
            $fields['is_active'] = absint($data['is_active']);
            $formats[] = '%d';
        }
        if (isset($data['sort_order'])) {
            $fields['sort_order'] = absint($data['sort_order']);
            $formats[] = '%d';
        }

        if (empty($fields)) {
            return false;
        }

        $result = $wpdb->update(
            self::table_name(),
            $fields,
            array('id' => $id),
            $formats,
            array('%d')
        );

        if (false === $result) {
            return false;
        }

        if ($result > 0) {
            self::invalidate_shipping_cache_if_available();
        }

        return true;
    }

    /* ── Delete ────────────────────────────────────────────── */

    /**
     * Delete a city by ID.
     *
     * @param int $id City ID.
     * @return bool
     */
    public static function delete(int $id): bool
    {
        global $wpdb;

        $result = $wpdb->delete(
            self::table_name(),
            array('id' => $id),
            array('%d')
        );

        if (false === $result || $result <= 0) {
            return false;
        }

        self::invalidate_shipping_cache_if_available();
        return true;
    }

    private static function invalidate_shipping_cache_if_available(): void
    {
        if (class_exists('Lexi_Merch') && method_exists('Lexi_Merch', 'invalidate_shipping_cache')) {
            Lexi_Merch::invalidate_shipping_cache();
        }
    }
}
