<?php
/** @package Lexi_API */
defined('ABSPATH') || exit;

class Lexi_Routes_Merch
{
    public static function register(): void
    {
        $ns = LEXI_API_NAMESPACE;

        register_rest_route($ns, '/admin/merch/deals', array(
            'methods' => WP_REST_Server::READABLE,
            'callback' => array(__CLASS__, 'admin_get_deals'),
            'permission_callback' => array('Lexi_Security', 'admin_access'),
        ));

        register_rest_route($ns, '/admin/merch/categories', array(
            array('methods' => WP_REST_Server::READABLE, 'callback' => array(__CLASS__, 'admin_get_categories'), 'permission_callback' => array('Lexi_Security', 'admin_access')),
            array('methods' => WP_REST_Server::EDITABLE, 'callback' => array(__CLASS__, 'admin_patch_categories'), 'permission_callback' => array('Lexi_Security', 'admin_access')),
        ));

        register_rest_route($ns, '/admin/merch/category-products', array(
            'methods' => WP_REST_Server::READABLE,
            'callback' => array(__CLASS__, 'admin_get_category_products'),
            'permission_callback' => array('Lexi_Security', 'admin_access'),
            'args' => array(
                'term_id' => array('required' => true, 'sanitize_callback' => 'absint'),
                'search' => array('required' => false, 'sanitize_callback' => 'sanitize_text_field'),
                'page' => array('required' => false, 'sanitize_callback' => 'absint', 'default' => 1),
                'per_page' => array('required' => false, 'sanitize_callback' => 'absint', 'default' => 50),
            ),
        ));

        register_rest_route($ns, '/admin/merch/category-products/bulk', array(
            'methods' => WP_REST_Server::EDITABLE,
            'callback' => array(__CLASS__, 'admin_patch_category_products_bulk'),
            'permission_callback' => array('Lexi_Security', 'admin_access'),
        ));

        register_rest_route($ns, '/admin/merch/home-sections', array(
            array('methods' => WP_REST_Server::READABLE, 'callback' => array(__CLASS__, 'admin_get_home_sections'), 'permission_callback' => array('Lexi_Security', 'admin_access')),
            array('methods' => WP_REST_Server::CREATABLE, 'callback' => array(__CLASS__, 'admin_create_home_section'), 'permission_callback' => array('Lexi_Security', 'admin_access')),
        ));

        register_rest_route($ns, '/admin/merch/home-sections/reorder', array(
            'methods' => WP_REST_Server::EDITABLE,
            'callback' => array(__CLASS__, 'admin_reorder_home_sections'),
            'permission_callback' => array('Lexi_Security', 'admin_access'),
        ));

        register_rest_route($ns, '/admin/merch/home-sections/(?P<id>\d+)', array(
            array('methods' => WP_REST_Server::EDITABLE, 'callback' => array(__CLASS__, 'admin_patch_home_section'), 'permission_callback' => array('Lexi_Security', 'admin_access')),
            array('methods' => WP_REST_Server::DELETABLE, 'callback' => array(__CLASS__, 'admin_delete_home_section'), 'permission_callback' => array('Lexi_Security', 'admin_access')),
        ));

        register_rest_route($ns, '/admin/merch/home-sections/(?P<id>\d+)/items', array(
            array('methods' => WP_REST_Server::READABLE, 'callback' => array(__CLASS__, 'admin_get_home_section_items'), 'permission_callback' => array('Lexi_Security', 'admin_access')),
            array('methods' => WP_REST_Server::EDITABLE, 'callback' => array(__CLASS__, 'admin_patch_home_section_items'), 'permission_callback' => array('Lexi_Security', 'admin_access')),
        ));

        register_rest_route($ns, '/admin/merch/ad-banners', array(
            array('methods' => WP_REST_Server::READABLE, 'callback' => array(__CLASS__, 'admin_get_ad_banners'), 'permission_callback' => array('Lexi_Security', 'admin_access')),
            array('methods' => WP_REST_Server::EDITABLE, 'callback' => array(__CLASS__, 'admin_patch_ad_banners'), 'permission_callback' => array('Lexi_Security', 'admin_access')),
        ));

        register_rest_route($ns, '/admin/merch/ad-banners/(?P<id>\d+)', array(
            'methods' => WP_REST_Server::DELETABLE,
            'callback' => array(__CLASS__, 'admin_delete_ad_banner'),
            'permission_callback' => array('Lexi_Security', 'admin_access'),
            'args' => array('id' => array('required' => true, 'sanitize_callback' => 'absint')),
        ));

        register_rest_route($ns, '/admin/merch/deals/schedule', array(
            'methods' => WP_REST_Server::CREATABLE,
            'callback' => array(__CLASS__, 'admin_schedule_deal'),
            'permission_callback' => array('Lexi_Security', 'admin_access'),
        ));

        register_rest_route($ns, '/admin/merch/reviews/pending', array(
            'methods' => WP_REST_Server::READABLE,
            'callback' => array(__CLASS__, 'admin_get_pending_reviews'),
            'permission_callback' => array('Lexi_Security', 'admin_access'),
        ));

        register_rest_route($ns, '/admin/merch/reviews/(?P<id>\d+)/approve', array(
            'methods' => WP_REST_Server::CREATABLE,
            'callback' => array(__CLASS__, 'admin_approve_review'),
            'permission_callback' => array('Lexi_Security', 'admin_access'),
            'args' => array('id' => array('required' => true, 'sanitize_callback' => 'absint')),
        ));

        register_rest_route($ns, '/admin/merch/reviews', array(
            'methods' => WP_REST_Server::READABLE,
            'callback' => array(__CLASS__, 'admin_get_reviews'),
            'permission_callback' => array('Lexi_Security', 'admin_access'),
            'args' => array(
                'status' => array('default' => 'hold', 'sanitize_callback' => 'sanitize_text_field'),
                'page' => array('default' => 1, 'sanitize_callback' => 'absint'),
                'per_page' => array('default' => 20, 'sanitize_callback' => 'absint'),
            ),
        ));

        register_rest_route($ns, '/admin/merch/reviews/(?P<id>\d+)', array(
            array('methods' => WP_REST_Server::EDITABLE, 'callback' => array(__CLASS__, 'admin_patch_review'), 'permission_callback' => array('Lexi_Security', 'admin_access')),
            array('methods' => WP_REST_Server::DELETABLE, 'callback' => array(__CLASS__, 'admin_delete_review'), 'permission_callback' => array('Lexi_Security', 'admin_access')),
            'args' => array('id' => array('required' => true, 'sanitize_callback' => 'absint')),
        ));
    }

    public static function admin_get_deals(WP_REST_Request $request): WP_REST_Response
    {
        return Lexi_Security::success(array('items' => Lexi_Merch::get_flash_deals()));
    }

    public static function admin_get_categories(WP_REST_Request $request): WP_REST_Response
    {
        $terms = Lexi_Merch::get_sorted_categories(false);
        $items = array();
        foreach ($terms as $term) {
            $term_id = (int) $term->term_id;
            $thumb_id = (int) get_term_meta($term_id, 'thumbnail_id', true);
            $image_url = '';
            if ($thumb_id > 0) {
                $raw = wp_get_attachment_image_url($thumb_id, 'woocommerce_thumbnail');
                if ($raw) {
                    $image_url = Lexi_Merch::normalize_image_url((string) $raw);
                }
            }
            $items[] = array(
                'id' => $term_id,
                'name' => (string) $term->name,
                'slug' => (string) $term->slug,
                'count' => (int) $term->count,
                'image_url' => $image_url,
                'sort_order' => Lexi_Merch::get_category_sort_order($term_id),
            );
        }
        return Lexi_Security::success(array('items' => $items));
    }

    public static function admin_patch_categories(WP_REST_Request $request): WP_REST_Response
    {
        $body = (array) $request->get_json_params();
        $items = isset($body['items']) && is_array($body['items']) ? $body['items'] : array();
        if (empty($items)) {
            return Lexi_Security::error('items_required', 'Categories list is required.', 422);
        }

        foreach ($items as $item) {
            if (!is_array($item)) {
                continue;
            }
            $term_id = absint((int) ($item['id'] ?? 0));
            if ($term_id <= 0) {
                continue;
            }
            $term = get_term($term_id, 'product_cat');
            if (!$term || is_wp_error($term)) {
                continue;
            }
            Lexi_Merch::set_category_sort_order($term_id, max(0, (int) ($item['sort_order'] ?? 0)));
        }

        return Lexi_Security::success(array('message' => 'Categories order saved.'));
    }

    public static function admin_get_category_products(WP_REST_Request $request): WP_REST_Response
    {
        $term_id = absint((int) $request->get_param('term_id'));
        $search = trim((string) $request->get_param('search'));
        $page = max(1, (int) $request->get_param('page'));
        $per_page = min(100, max(1, (int) $request->get_param('per_page')));

        $term = get_term($term_id, 'product_cat');
        if (!$term || is_wp_error($term)) {
            return Lexi_Security::error('term_not_found', 'Category not found.', 404);
        }

        $all_ids = Lexi_Merch::get_category_product_ids_by_date($term_id, $search);
        $order_rows = Lexi_Merch::get_category_order_rows($term_id);
        $order_map = Lexi_Merch::get_category_order_map($term_id);

        $lookup = array_fill_keys($all_ids, true);
        $ordered_ids = array();
        foreach ($order_rows as $row) {
            $product_id = (int) ($row['product_id'] ?? 0);
            if ($product_id > 0 && isset($lookup[$product_id])) {
                $ordered_ids[] = $product_id;
            }
        }

        $ordered_ids = array_values(array_unique($ordered_ids));
        $remaining_ids = array_values(array_diff($all_ids, $ordered_ids));
        $combined_ids = array_merge($ordered_ids, $remaining_ids);

        $total = count($combined_ids);
        $offset = ($page - 1) * $per_page;
        $paged_ids = array_slice($combined_ids, $offset, $per_page);
        $products = Lexi_Merch::get_products_by_ids($paged_ids);

        $items = array();
        foreach ($paged_ids as $product_id) {
            if (!isset($products[$product_id])) {
                continue;
            }
            $summary = Lexi_Merch::product_summary((int) $product_id);
            if (!is_array($summary)) {
                continue;
            }
            $order_data = $order_map[$product_id] ?? null;
            $summary['pinned'] = is_array($order_data) ? (bool) ($order_data['pinned'] ?? false) : false;
            $summary['sort_order'] = is_array($order_data) ? (int) ($order_data['sort_order'] ?? 0) : null;
            $summary['in_stock'] = (bool) $products[$product_id]->is_in_stock();
            $items[] = $summary;
        }

        return Lexi_Security::success(array(
            'items' => $items,
            'page' => $page,
            'per_page' => $per_page,
            'total' => $total,
            'total_pages' => (int) ceil($total / max(1, $per_page)),
        ));
    }

    public static function admin_patch_category_products_bulk(WP_REST_Request $request): WP_REST_Response
    {
        global $wpdb;

        $body = (array) $request->get_json_params();
        $term_id = absint((int) ($body['term_id'] ?? 0));
        $items = isset($body['items']) && is_array($body['items']) ? $body['items'] : array();
        $replace_all = Lexi_Merch::bool_int($body['replace_all'] ?? false) === 1;

        if ($term_id <= 0) {
            return Lexi_Security::error('term_required', 'Category is required.', 422);
        }
        $term = get_term($term_id, 'product_cat');
        if (!$term || is_wp_error($term)) {
            return Lexi_Security::error('term_not_found', 'Category not found.', 404);
        }

        $table = Lexi_Merch::category_product_order_table();
        $now = Lexi_Merch::now();
        $valid_ids = array();

        foreach ($items as $index => $item) {
            if (!is_array($item)) {
                continue;
            }
            $product_id = absint((int) ($item['product_id'] ?? 0));
            if ($product_id <= 0) {
                continue;
            }
            $product = wc_get_product($product_id);
            if (!$product instanceof WC_Product || 'publish' !== get_post_status($product_id)) {
                continue;
            }

            $valid_ids[] = $product_id;
            $wpdb->replace(
                $table,
                array(
                    'term_id' => $term_id,
                    'product_id' => $product_id,
                    'sort_order' => max(0, (int) ($item['sort_order'] ?? ($index + 1))),
                    'pinned' => Lexi_Merch::bool_int($item['pinned'] ?? false),
                    'created_at' => $now,
                    'updated_at' => $now,
                ),
                array('%d', '%d', '%d', '%d', '%s', '%s')
            );
        }

        $valid_ids = array_values(array_unique(array_filter(array_map('intval', $valid_ids))));

        if ($replace_all) {
            if (empty($valid_ids)) {
                $wpdb->query($wpdb->prepare("DELETE FROM {$table} WHERE term_id = %d", $term_id));
            } else {
                $placeholders = implode(',', array_fill(0, count($valid_ids), '%d'));
                $params = array_merge(array($term_id), $valid_ids);
                $sql = $wpdb->prepare("DELETE FROM {$table} WHERE term_id = %d AND product_id NOT IN ({$placeholders})", $params);
                $wpdb->query($sql);
            }
        }

        error_log(sprintf('[Lexi Merch] Category bulk save term=%d items=%d replace_all=%d', $term_id, count($valid_ids), $replace_all ? 1 : 0));

        return Lexi_Security::success(array(
            'message' => 'Category product order saved.',
            'saved_items' => count($valid_ids),
        ));
    }
    public static function admin_get_home_sections(WP_REST_Request $request): WP_REST_Response
    {
        global $wpdb;

        $sections = Lexi_Merch::get_home_sections(false);
        $items_table = Lexi_Merch::home_section_items_table();
        $result = array();

        foreach ($sections as $section) {
            $id = (int) ($section['id'] ?? 0);
            $count = (int) $wpdb->get_var($wpdb->prepare("SELECT COUNT(*) FROM {$items_table} WHERE section_id = %d", $id));

            $term_name = null;
            $term_id = isset($section['term_id']) ? (int) $section['term_id'] : 0;
            if ($term_id > 0) {
                $term = get_term($term_id, 'product_cat');
                if ($term && !is_wp_error($term)) {
                    $term_name = (string) $term->name;
                }
            }

            $section['items_count'] = $count;
            $section['term_name'] = $term_name;
            $result[] = $section;
        }

        return Lexi_Security::success(array('items' => $result));
    }

    public static function admin_create_home_section(WP_REST_Request $request): WP_REST_Response
    {
        global $wpdb;

        $body = (array) $request->get_json_params();
        $title_ar = trim(sanitize_text_field(self::normalize_text($body['title_ar'] ?? '')));
        $type = Lexi_Merch::normalize_section_type((string) ($body['type'] ?? 'manual_products'));
        $term_id = isset($body['term_id']) ? absint((int) $body['term_id']) : null;
        $is_active = Lexi_Merch::bool_int($body['is_active'] ?? true);
        $sort_order = isset($body['sort_order']) ? (int) $body['sort_order'] : 0;

        if ('' === $title_ar) {
            return Lexi_Security::error('title_required', 'Section title is required.', 422);
        }

        if ('category' === $type) {
            $term = get_term((int) $term_id, 'product_cat');
            if (!$term || is_wp_error($term)) {
                return Lexi_Security::error('term_required', 'Category is required for this section type.', 422);
            }
        }

        $table = Lexi_Merch::home_sections_table();
        $now = Lexi_Merch::now();

        $ok = $wpdb->insert(
            $table,
            array(
                'title_ar' => $title_ar,
                'type' => $type,
                'term_id' => $term_id,
                'sort_order' => max(0, $sort_order),
                'is_active' => $is_active,
                'created_at' => $now,
                'updated_at' => $now,
            ),
            array('%s', '%s', '%d', '%d', '%d', '%s', '%s')
        );

        if (false === $ok) {
            return Lexi_Security::error('create_failed', 'Unable to create section right now.', 500);
        }

        return Lexi_Security::success(array('id' => (int) $wpdb->insert_id, 'message' => 'Section created.'), 201);
    }

    public static function admin_patch_home_section(WP_REST_Request $request): WP_REST_Response
    {
        global $wpdb;

        $id = absint((int) $request->get_param('id'));
        $section = self::get_section($id);
        if (!is_array($section)) {
            return Lexi_Security::error('section_not_found', 'Section not found.', 404);
        }

        $body = (array) $request->get_json_params();
        $data = array();
        $format = array();

        if (array_key_exists('title_ar', $body)) {
            $title = trim(sanitize_text_field(self::normalize_text($body['title_ar'])));
            if ('' === $title) {
                return Lexi_Security::error('title_required', 'Section title is required.', 422);
            }
            $data['title_ar'] = $title;
            $format[] = '%s';
        }
        if (array_key_exists('type', $body)) {
            $data['type'] = Lexi_Merch::normalize_section_type((string) $body['type']);
            $format[] = '%s';
        }
        if (array_key_exists('term_id', $body)) {
            $term_id = absint((int) $body['term_id']);
            if ($term_id > 0) {
                $term = get_term($term_id, 'product_cat');
                if (!$term || is_wp_error($term)) {
                    return Lexi_Security::error('term_not_found', 'Category not found.', 422);
                }
                $data['term_id'] = $term_id;
            } else {
                $data['term_id'] = null;
            }
            $format[] = '%d';
        }
        if (array_key_exists('sort_order', $body)) {
            $data['sort_order'] = max(0, (int) $body['sort_order']);
            $format[] = '%d';
        }
        if (array_key_exists('is_active', $body)) {
            $data['is_active'] = Lexi_Merch::bool_int($body['is_active']);
            $format[] = '%d';
        }

        if (empty($data)) {
            return Lexi_Security::error('missing_fields', 'No fields to update.', 422);
        }

        if (isset($data['type']) && 'category' === $data['type']) {
            $final_term_id = isset($data['term_id']) ? (int) $data['term_id'] : (int) ($section['term_id'] ?? 0);
            $term = get_term($final_term_id, 'product_cat');
            if (!$term || is_wp_error($term)) {
                return Lexi_Security::error('term_required', 'Category is required for this section type.', 422);
            }
        }

        $data['updated_at'] = Lexi_Merch::now();
        $format[] = '%s';

        $ok = $wpdb->update(Lexi_Merch::home_sections_table(), $data, array('id' => $id), $format, array('%d'));
        if (false === $ok) {
            return Lexi_Security::error('update_failed', 'Unable to update section right now.', 500);
        }

        return Lexi_Security::success(array('message' => 'Section updated.'));
    }

    public static function admin_delete_home_section(WP_REST_Request $request): WP_REST_Response
    {
        global $wpdb;

        $id = absint((int) $request->get_param('id'));
        $section = self::get_section($id);
        if (!is_array($section)) {
            return Lexi_Security::error('section_not_found', 'Section not found.', 404);
        }

        $wpdb->delete(Lexi_Merch::home_section_items_table(), array('section_id' => $id), array('%d'));
        $wpdb->delete(Lexi_Merch::home_sections_table(), array('id' => $id), array('%d'));

        return Lexi_Security::success(array('message' => 'Section deleted.'));
    }

    public static function admin_reorder_home_sections(WP_REST_Request $request): WP_REST_Response
    {
        global $wpdb;

        $body = (array) $request->get_json_params();
        $items = isset($body['items']) && is_array($body['items']) ? $body['items'] : array();
        if (empty($items)) {
            return Lexi_Security::error('items_required', 'Sections list is required.', 422);
        }

        $table = Lexi_Merch::home_sections_table();
        $now = Lexi_Merch::now();

        foreach ($items as $item) {
            if (!is_array($item)) {
                continue;
            }
            $id = absint((int) ($item['id'] ?? 0));
            if ($id <= 0) {
                continue;
            }
            $sort_order = max(0, (int) ($item['sort_order'] ?? 0));
            $wpdb->update($table, array('sort_order' => $sort_order, 'updated_at' => $now), array('id' => $id), array('%d', '%s'), array('%d'));
        }

        return Lexi_Security::success(array('message' => 'Sections order saved.'));
    }

    public static function admin_get_home_section_items(WP_REST_Request $request): WP_REST_Response
    {
        $id = absint((int) $request->get_param('id'));
        $section = self::get_section($id);
        if (!is_array($section)) {
            return Lexi_Security::error('section_not_found', 'Section not found.', 404);
        }

        $rows = Lexi_Merch::get_home_section_items($id);
        $items = array();
        foreach ($rows as $row) {
            $product_id = (int) ($row['product_id'] ?? 0);
            if ($product_id <= 0) {
                continue;
            }
            $summary = Lexi_Merch::product_summary($product_id);
            if (!is_array($summary)) {
                continue;
            }
            $summary['pinned'] = !empty($row['pinned']);
            $summary['sort_order'] = (int) ($row['sort_order'] ?? 0);
            $items[] = $summary;
        }

        return Lexi_Security::success(array('section' => $section, 'items' => $items));
    }

    public static function admin_patch_home_section_items(WP_REST_Request $request): WP_REST_Response
    {
        global $wpdb;

        $section_id = absint((int) $request->get_param('id'));
        $section = self::get_section($section_id);
        if (!is_array($section)) {
            return Lexi_Security::error('section_not_found', 'Section not found.', 404);
        }

        $body = (array) $request->get_json_params();
        $items = isset($body['items']) && is_array($body['items']) ? $body['items'] : array();

        $table = Lexi_Merch::home_section_items_table();
        $now = Lexi_Merch::now();
        $valid_ids = array();

        foreach ($items as $index => $item) {
            if (!is_array($item)) {
                continue;
            }
            $product_id = absint((int) ($item['product_id'] ?? 0));
            if ($product_id <= 0) {
                continue;
            }
            $product = wc_get_product($product_id);
            if (!$product instanceof WC_Product || 'publish' !== get_post_status($product_id)) {
                continue;
            }

            $valid_ids[] = $product_id;
            $wpdb->replace(
                $table,
                array(
                    'section_id' => $section_id,
                    'product_id' => $product_id,
                    'sort_order' => max(0, (int) ($item['sort_order'] ?? ($index + 1))),
                    'pinned' => Lexi_Merch::bool_int($item['pinned'] ?? false),
                    'created_at' => $now,
                    'updated_at' => $now,
                ),
                array('%d', '%d', '%d', '%d', '%s', '%s')
            );
        }

        $valid_ids = array_values(array_unique(array_filter(array_map('intval', $valid_ids))));
        if (empty($valid_ids)) {
            $wpdb->query($wpdb->prepare("DELETE FROM {$table} WHERE section_id = %d", $section_id));
        } else {
            $placeholders = implode(',', array_fill(0, count($valid_ids), '%d'));
            $params = array_merge(array($section_id), $valid_ids);
            $sql = $wpdb->prepare("DELETE FROM {$table} WHERE section_id = %d AND product_id NOT IN ({$placeholders})", $params);
            $wpdb->query($sql);
        }

        error_log(sprintf('[Lexi Merch] Home section items save section=%d items=%d', $section_id, count($valid_ids)));
        return Lexi_Security::success(array('message' => 'Home section items saved.', 'saved_items' => count($valid_ids)));
    }

    public static function admin_get_ad_banners(WP_REST_Request $request): WP_REST_Response
    {
        return Lexi_Security::success(array('items' => Lexi_Merch::get_home_ad_banners(false)));
    }

    public static function admin_patch_ad_banners(WP_REST_Request $request): WP_REST_Response
    {
        $body = (array) $request->get_json_params();
        $items = isset($body['items']) && is_array($body['items']) ? $body['items'] : array();
        $saved = Lexi_Merch::save_home_ad_banners($items);
        return Lexi_Security::success(array('message' => 'Ad banners saved successfully.', 'items' => $saved));
    }

    public static function admin_delete_ad_banner(WP_REST_Request $request): WP_REST_Response
    {
        $id = absint((int) $request->get_param('id'));
        $banners = Lexi_Merch::get_home_ad_banners(false);
        $filtered = array();
        foreach ($banners as $banner) {
            if ((int) $banner['id'] !== $id) {
                $filtered[] = $banner;
            }
        }
        Lexi_Merch::save_home_ad_banners($filtered);
        return Lexi_Security::success(array('message' => 'Banner deleted.'));
    }

    public static function admin_get_pending_reviews(WP_REST_Request $request): WP_REST_Response
    {
        $request->set_param('status', 'hold');
        return self::admin_get_reviews($request);
    }

    public static function admin_approve_review(WP_REST_Request $request): WP_REST_Response
    {
        $request->set_param('status', 'approve');
        return self::admin_patch_review($request);
    }

    public static function admin_delete_review(WP_REST_Request $request): WP_REST_Response
    {
        $request->set_param('status', 'delete');
        return self::admin_patch_review($request);
    }

    private static function get_section(int $id): ?array
    {
        global $wpdb;

        if ($id <= 0) {
            return null;
        }

        $table = Lexi_Merch::home_sections_table();
        $row = $wpdb->get_row(
            $wpdb->prepare(
                "SELECT id, title_ar, type, term_id, sort_order, is_active, created_at, updated_at FROM {$table} WHERE id = %d",
                $id
            ),
            ARRAY_A
        );

        if (!is_array($row)) {
            return null;
        }

        $term_name = null;
        $term_id = isset($row['term_id']) ? (int) $row['term_id'] : 0;
        if ($term_id > 0) {
            $term = get_term($term_id, 'product_cat');
            if ($term && !is_wp_error($term)) {
                $term_name = self::normalize_text($term->name);
            }
        }

        return array(
            'id' => (int) ($row['id'] ?? 0),
            'title_ar' => self::normalize_text($row['title_ar'] ?? ''),
            'type' => Lexi_Merch::normalize_section_type((string) ($row['type'] ?? 'manual_products')),
            'term_id' => isset($row['term_id']) ? (int) $row['term_id'] : null,
            'term_name' => $term_name,
            'sort_order' => (int) ($row['sort_order'] ?? 0),
            'is_active' => ((int) ($row['is_active'] ?? 0)) === 1,
            'created_at' => (string) ($row['created_at'] ?? ''),
            'updated_at' => (string) ($row['updated_at'] ?? ''),
        );
    }

    private static function normalize_text($value): string
    {
        if (class_exists('Lexi_Text')) {
            return Lexi_Text::normalize($value);
        }
        return (string) $value;
    }

    public static function admin_schedule_deal(WP_REST_Request $request): WP_REST_Response
    {
        $body = (array) $request->get_json_params();

        $product_id = absint((int) ($body['product_id'] ?? 0));
        $sale_price = (float) ($body['sale_price'] ?? 0);
        $date_from = sanitize_text_field((string) ($body['date_from'] ?? ''));
        $date_to = sanitize_text_field((string) ($body['date_to'] ?? ''));

        if ($product_id <= 0) {
            return Lexi_Security::error('product_required', 'Product is required.', 422);
        }

        $product = wc_get_product($product_id);
        if (!$product || !($product instanceof WC_Product)) {
            return Lexi_Security::error('product_not_found', 'Product not found.', 404);
        }

        if ($sale_price <= 0) {
            $product->set_sale_price('');
            $product->set_date_on_sale_from('');
            $product->set_date_on_sale_to('');
            $product->delete_meta_data('_lexi_flash_deal_active');
            $product->delete_meta_data('_lexi_flash_deal_from_ts');
            $product->delete_meta_data('_lexi_flash_deal_to_ts');
            $product->delete_meta_data('_lexi_flash_deal_price');
            $product->save();
            Lexi_Merch::invalidate_products_list_cache();
            return Lexi_Security::success(array('message' => 'Deal removed.'));
        }

        $from_ts = is_numeric($date_from) ? (int) $date_from : strtotime($date_from);
        $to_ts = is_numeric($date_to) ? (int) $date_to : strtotime($date_to);
        if (!$from_ts || !$to_ts || $to_ts <= $from_ts) {
            return Lexi_Security::error('invalid_dates', 'Invalid deal date range.', 422);
        }

        try {
            $product->set_sale_price((string) $sale_price);
            $product->set_date_on_sale_from($from_ts);
            $product->set_date_on_sale_to($to_ts);
            $product->update_meta_data('_lexi_flash_deal_active', 'yes');
            $product->update_meta_data('_lexi_flash_deal_from_ts', (string) $from_ts);
            $product->update_meta_data('_lexi_flash_deal_to_ts', (string) $to_ts);
            $product->update_meta_data('_lexi_flash_deal_price', (string) $sale_price);
            $product->save();
            Lexi_Merch::invalidate_products_list_cache();

            return Lexi_Security::success(array(
                'message' => 'Deal scheduled.',
                'product_id' => $product_id,
                'sale_price' => $sale_price,
                'starts' => date('Y-m-d H:i:s', $from_ts),
                'ends' => date('Y-m-d H:i:s', $to_ts),
            ));
        } catch (\Exception $e) {
            return Lexi_Security::error('update_failed', 'Unable to save deal: ' . $e->getMessage(), 500);
        }
    }

    public static function admin_get_reviews(WP_REST_Request $request): WP_REST_Response
    {
        $status = sanitize_text_field((string) $request->get_param('status'));
        $page = max(1, (int) $request->get_param('page'));
        $per_page = min(100, max(1, (int) $request->get_param('per_page')));

        $comment_status = 'hold';
        if (in_array($status, array('approved', 'approve'), true)) {
            $comment_status = 'approve';
        } elseif ('trash' === $status) {
            $comment_status = 'trash';
        }

        $query = new WP_Comment_Query();
        $comments = $query->query(array(
            'status' => $comment_status,
            'type' => 'review',
            'number' => $per_page,
            'offset' => ($page - 1) * $per_page,
            'orderby' => 'comment_date_gmt',
            'order' => 'DESC',
        ));

        if (!is_array($comments)) {
            $comments = array();
        }

        $items = array();
        foreach ($comments as $comment) {
            if (!$comment instanceof WP_Comment) {
                continue;
            }

            $product_id = (int) $comment->comment_post_ID;
            $product = wc_get_product($product_id);
            $rating = (int) get_comment_meta($comment->comment_ID, 'rating', true);

            $items[] = array(
                'id' => (int) $comment->comment_ID,
                'product_id' => $product_id,
                'product_name' => $product instanceof WC_Product ? self::normalize_text($product->get_name()) : '',
                'author_name' => self::normalize_text($comment->comment_author),
                'content' => self::normalize_text($comment->comment_content),
                'rating' => $rating,
                'status' => self::normalize_review_status($comment->comment_approved),
                'created_at' => (string) $comment->comment_date_gmt,
            );
        }

        $total = (int) get_comments(array(
            'status' => $comment_status,
            'type' => 'review',
            'count' => true,
        ));

        return Lexi_Security::success(array(
            'items' => $items,
            'page' => $page,
            'per_page' => $per_page,
            'total' => $total,
            'total_pages' => (int) ceil($total / max(1, $per_page)),
        ));
    }

    public static function admin_patch_review(WP_REST_Request $request): WP_REST_Response
    {
        $id = absint((int) $request->get_param('id'));
        if ($id <= 0) {
            return Lexi_Security::error('review_required', 'Review ID is required.', 422);
        }

        $comment = get_comment($id);
        if (!$comment instanceof WP_Comment) {
            return Lexi_Security::error('review_not_found', 'Review not found.', 404);
        }

        $body = (array) $request->get_json_params();
        $status = strtolower(trim(sanitize_text_field((string) ($body['status'] ?? ''))));
        if ('' === $status) {
            return Lexi_Security::error('status_required', 'Status is required.', 422);
        }

        if (in_array($status, array('delete', 'deleted'), true)) {
            wp_delete_comment($id, true);
            return Lexi_Security::success(array('message' => 'Review deleted.'));
        }

        $mapped = '';
        if (in_array($status, array('approved', 'approve', '1'), true)) {
            $mapped = 'approve';
        } elseif (in_array($status, array('hold', 'pending', '0'), true)) {
            $mapped = 'hold';
        } elseif ('trash' === $status) {
            $mapped = 'trash';
        }

        if ('' === $mapped) {
            return Lexi_Security::error('invalid_status', 'Invalid review status.', 422);
        }

        $ok = wp_set_comment_status($id, $mapped, true);
        if (!$ok) {
            return Lexi_Security::error('update_failed', 'Unable to update review status right now.', 500);
        }

        return Lexi_Security::success(array('message' => 'Review updated.'));
    }

    private static function normalize_review_status($approved): string
    {
        if ('1' === (string) $approved || 'approve' === (string) $approved) {
            return 'approved';
        }
        if ('trash' === (string) $approved) {
            return 'trash';
        }
        return 'hold';
    }
}
