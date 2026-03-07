<?php
/**
 * Main plugin bootstrap: singleton, custom order statuses, route loading.
 *
 * @package Lexi_API
 */

defined('ABSPATH') || exit;

class Lexi_Plugin
{
    private const HOOK_DAILY_SHAMCASH_CLEANUP = 'lexi_daily_cleanup_shamcash';
    private const HOOK_ASSIGNMENT_TTL_CLEANUP = 'lexi_assignment_ttl_cleanup';
    private const OPTION_SHAMCASH_METHOD_MIGRATION = 'lexi_shamcash_method_migrated_v1';
    private const ORDER_EVENTS_META_BOX_ID = 'lexi_order_events_audit';

    /** @var self|null */
    private static ?self $instance = null;

    /**
     * Singleton accessor.
     */
    public static function instance(): self
    {
        if (null === self::$instance) {
            self::$instance = new self();
        }

        return self::$instance;
    }

    /**
     * Constructor hooks.
     */
    private function __construct()
    {
        add_action('init', array($this, 'register_delivery_agent_role'), 5);

        add_action('init', array($this, 'register_order_statuses'));
        add_filter('wc_order_statuses', array($this, 'add_order_statuses'));
        add_filter('bulk_actions-edit-shop_order', array($this, 'add_bulk_actions'));
        add_action('admin_head', array($this, 'render_admin_order_status_styles'));
        add_action('add_meta_boxes_shop_order', array($this, 'register_order_events_meta_box'));
        add_action('add_meta_boxes_woocommerce_page_wc-orders', array($this, 'register_order_events_meta_box'));

        Lexi_Emails::init();

        add_action('rest_api_init', array($this, 'register_routes'));

        add_action('register_form', array($this, 'render_wp_register_phone_field'));
        add_filter('registration_errors', array($this, 'validate_wp_register_phone_field'), 10, 3);
        add_action('user_register', array($this, 'save_wp_register_phone_meta'));
        add_action('user_register', array(__CLASS__, 'notify_new_user_registration'), 20);

        add_action('woocommerce_order_status_completed', array($this, 'ai_track_purchase'));
        add_action('woocommerce_order_status_processing', array($this, 'ai_track_purchase'));

        add_action('lexi_ai_hourly_aggregation', array($this, 'ai_hourly_aggregation'));
        add_action('lexi_ai_daily_aggregation', array($this, 'ai_daily_aggregation'));

        add_filter('cron_schedules', array(__CLASS__, 'register_cron_schedules'));
        add_action(self::HOOK_DAILY_SHAMCASH_CLEANUP, array($this, 'cleanup_old_shamcash_orders'));
        add_action(self::HOOK_ASSIGNMENT_TTL_CLEANUP, array($this, 'cleanup_expired_assignments'));

        add_action('init', array($this, 'maybe_run_shamcash_method_migration'), 20);

        add_action('admin_menu', array($this, 'register_admin_dashboard_menu'));
        add_action('admin_enqueue_scripts', array($this, 'enqueue_admin_dashboard_assets'));
    }

    /**
     * Ensure all plugin schedules exist.
     */
    public static function ensure_scheduled_events(): void
    {
        if (!wp_next_scheduled(self::HOOK_DAILY_SHAMCASH_CLEANUP)) {
            wp_schedule_event(time(), 'daily', self::HOOK_DAILY_SHAMCASH_CLEANUP);
        }

        if (!wp_next_scheduled(self::HOOK_ASSIGNMENT_TTL_CLEANUP)) {
            wp_schedule_event(time(), 'lexi_every_five_minutes', self::HOOK_ASSIGNMENT_TTL_CLEANUP);
        }
    }

    /**
     * Activation-only maintenance tasks.
     */
    public static function run_on_activation_tasks(): void
    {
        self::ensure_scheduled_events();
        self::migrate_shamcash_payment_method_ids(true);
    }

    /**
     * Add short custom interval for assignment TTL cleanup.
     *
     * @param array<string,array<string,mixed>> $schedules
     * @return array<string,array<string,mixed>>
     */
    public static function register_cron_schedules(array $schedules): array
    {
        if (!isset($schedules['lexi_every_five_minutes'])) {
            $schedules['lexi_every_five_minutes'] = array(
                'interval' => 5 * MINUTE_IN_SECONDS,
                'display' => 'Every 5 Minutes (Lexi)',
            );
        }

        return $schedules;
    }

    /**
     * One-time migration for old ShamCash payment method id.
     */
    public function maybe_run_shamcash_method_migration(): void
    {
        self::migrate_shamcash_payment_method_ids(false);
    }

    public static function migrate_shamcash_payment_method_ids(bool $force = false): void
    {
        $already = get_option(self::OPTION_SHAMCASH_METHOD_MIGRATION, array());
        if (!$force && is_array($already) && !empty($already['done'])) {
            return;
        }

        $legacy_ids = wc_get_orders(array(
            'limit' => -1,
            'return' => 'ids',
            'payment_method' => Lexi_Order_Flow::PAYMENT_METHOD_SHAMCASH_LEGACY,
        ));
        $meta_ids = wc_get_orders(array(
            'limit' => -1,
            'return' => 'ids',
            'meta_key' => '_lexi_payment_method',
            'meta_value' => Lexi_Order_Flow::PAYMENT_METHOD_SHAMCASH_LEGACY,
        ));

        $candidate_ids = array_unique(array_map('intval', array_merge((array) $legacy_ids, (array) $meta_ids)));
        $migrated = 0;
        foreach ($candidate_ids as $order_id) {
            $order = wc_get_order((int) $order_id);
            if (!$order instanceof WC_Order) {
                continue;
            }

            $raw_method = strtolower(trim((string) $order->get_payment_method()));
            $meta_method = strtolower(trim((string) $order->get_meta('_lexi_payment_method')));
            if (
                $raw_method !== Lexi_Order_Flow::PAYMENT_METHOD_SHAMCASH_LEGACY &&
                $meta_method !== Lexi_Order_Flow::PAYMENT_METHOD_SHAMCASH_LEGACY
            ) {
                continue;
            }

            $order->set_payment_method(Lexi_Order_Flow::canonical_shamcash_payment_id());
            $order->update_meta_data('_lexi_payment_method', Lexi_Order_Flow::canonical_shamcash_payment_id());
            $order->save();
            $migrated++;
        }

        update_option(
            self::OPTION_SHAMCASH_METHOD_MIGRATION,
            array(
                'done' => true,
                'migrated_orders' => $migrated,
                'migrated_at' => current_time('mysql'),
            ),
            false
        );

        if (function_exists('wc_get_logger')) {
            wc_get_logger()->info(
                sprintf(
                    'ShamCash method migration finished. migrated_orders=%d canonical=%s',
                    $migrated,
                    Lexi_Order_Flow::canonical_shamcash_payment_id()
                ),
                array('source' => 'lexi-api')
            );
        }
    }

    /**
     * Track purchase in AI Core.
     *
     * @param int|string $order_id
     */
    public function ai_track_purchase($order_id): void
    {
        Lexi_AI_Core::instance()->record_purchase($order_id);
    }

    /**
     * AI hourly aggregation.
     */
    public function ai_hourly_aggregation(): void
    {
        Lexi_AI_Core::instance()->hourly_aggregation();
    }

    /**
     * AI daily aggregation.
     */
    public function ai_daily_aggregation(): void
    {
        Lexi_AI_Core::instance()->daily_aggregation();
    }

    /**
     * Delete incomplete ShamCash orders older than 3 days.
     */
    public function cleanup_old_shamcash_orders(): void
    {
        $orders = wc_get_orders(array(
            'status' => array(
                'pending',
                'on-hold',
                Lexi_Order_Flow::STATUS_PENDING_VERIFICATION,
                Lexi_Order_Flow::STATUS_PENDING_VERIFICATION_LEGACY,
            ),
            'date_created' => '<' . gmdate('Y-m-d H:i:s', time() - (3 * DAY_IN_SECONDS)),
            'limit' => -1,
        ));

        foreach ($orders as $order) {
            if (!$order instanceof WC_Order) {
                continue;
            }
            if (!Lexi_Order_Flow::is_shamcash_order($order)) {
                continue;
            }

            $order->delete(false);
        }
    }

    /**
     * Periodic assignment TTL cleanup.
     */
    public function cleanup_expired_assignments(): void
    {
        if (!class_exists('Lexi_Routes_Delivery')) {
            return;
        }

        Lexi_Routes_Delivery::expire_stale_assignments(200);
    }

    /**
     * Register custom order statuses.
     */
    public function register_order_statuses(): void
    {
        $pending_verification_args = array(
            'label' => 'بانتظار التحقق',
            'public' => true,
            'exclude_from_search' => false,
            'show_in_admin_all_list' => true,
            'show_in_admin_status_list' => true,
            'label_count' => _n_noop(
                'بانتظار التحقق <span class="count">(%s)</span>',
                'بانتظار التحقق <span class="count">(%s)</span>',
                'lexi-api'
            ),
        );

        // DB-safe status key (20 chars with `wc-` prefix).
        register_post_status('wc-pending-verificat', $pending_verification_args);
        // Compatibility alias for old code paths that still reference full slug.
        register_post_status('wc-pending-verification', $pending_verification_args);

        register_post_status('wc-out-for-delivery', array(
            'label' => 'خرج للتسليم',
            'public' => true,
            'exclude_from_search' => false,
            'show_in_admin_all_list' => true,
            'show_in_admin_status_list' => true,
            'label_count' => _n_noop(
                'خرج للتسليم <span class="count">(%s)</span>',
                'خرج للتسليم <span class="count">(%s)</span>',
                'lexi-api'
            ),
        ));

        register_post_status('wc-delivered-unpaid', array(
            'label' => 'تم التسليم - غير مسدد',
            'public' => true,
            'exclude_from_search' => false,
            'show_in_admin_all_list' => true,
            'show_in_admin_status_list' => true,
            'label_count' => _n_noop(
                'تم التسليم - غير مسدد <span class="count">(%s)</span>',
                'تم التسليم - غير مسدد <span class="count">(%s)</span>',
                'lexi-api'
            ),
        ));
    }

    /**
     * Ensure delivery agent role exists with required capabilities.
     */
    public function register_delivery_agent_role(): void
    {
        $capabilities = array(
            'read' => true,
            'lexi_delivery_agent' => true,
        );

        $role = get_role('delivery_agent');
        if (!$role) {
            add_role('delivery_agent', 'مندوب التوصيل', $capabilities);
            return;
        }

        foreach ($capabilities as $cap => $allowed) {
            if ($allowed) {
                $role->add_cap($cap);
            }
        }
    }

    /**
     * Add custom status entries to WooCommerce statuses dropdown.
     *
     * @param array<string,string> $statuses
     * @return array<string,string>
     */
    public function add_order_statuses(array $statuses): array
    {
        $statuses['wc-pending-verificat'] = 'بانتظار التحقق';
        $statuses['wc-pending-verification'] = 'بانتظار التحقق';
        $statuses['wc-out-for-delivery'] = 'خرج للتسليم';
        $statuses['wc-delivered-unpaid'] = 'تم التسليم - غير مسدد';

        return $statuses;
    }

    /**
     * Add custom status entries to bulk actions.
     *
     * @param array<string,string> $actions
     * @return array<string,string>
     */
    public function add_bulk_actions(array $actions): array
    {
        $actions['mark_pending-verificat'] = 'تغيير الحالة إلى بانتظار التحقق';
        $actions['mark_pending-verification'] = 'تغيير الحالة إلى بانتظار التحقق';
        $actions['mark_out-for-delivery'] = 'تغيير الحالة إلى خرج للتسليم';
        $actions['mark_delivered-unpaid'] = 'تغيير الحالة إلى تم التسليم - غير مسدد';

        return $actions;
    }

    /**
     * Custom Woo admin badge colors for operational statuses.
     */
    public function render_admin_order_status_styles(): void
    {
        if (!function_exists('get_current_screen')) {
            return;
        }
        $screen = get_current_screen();
        if (!$screen || $screen->id !== 'edit-shop_order') {
            return;
        }

        echo '<style>
            mark.order-status.status-out-for-delivery{background:#e6f7ff;color:#0369a1;}
            mark.order-status.status-delivered-unpaid{background:#fff7ed;color:#9a3412;}
            mark.order-status.status-pending-verificat{background:#fef9c3;color:#854d0e;}
            mark.order-status.status-pending-verification{background:#fef9c3;color:#854d0e;}
        </style>';
    }

    /**
     * Register order events meta box in Woo admin order details screen.
     */
    public function register_order_events_meta_box(): void
    {
        add_meta_box(
            self::ORDER_EVENTS_META_BOX_ID,
            'Lexi Order Events',
            array($this, 'render_order_events_meta_box'),
            'shop_order',
            'normal',
            'default'
        );

        add_meta_box(
            self::ORDER_EVENTS_META_BOX_ID,
            'Lexi Order Events',
            array($this, 'render_order_events_meta_box'),
            'woocommerce_page_wc-orders',
            'normal',
            'default'
        );
    }

    /**
     * @param WP_Post $post
     */
    public function render_order_events_meta_box($post): void
    {
        $order_id = isset($post->ID) ? (int) $post->ID : 0;
        if ($order_id <= 0 || !class_exists('Lexi_Order_Events')) {
            echo '<p>No events found.</p>';
            return;
        }

        $items = Lexi_Order_Events::list_by_order($order_id, 80);
        if (empty($items)) {
            echo '<p>No events found.</p>';
            return;
        }

        echo '<div style="max-height:360px;overflow:auto">';
        echo '<table class="widefat striped"><thead><tr>';
        echo '<th style="width:180px">Created</th>';
        echo '<th style="width:160px">Event</th>';
        echo '<th style="width:130px">Actor</th>';
        echo '<th>Payload</th>';
        echo '</tr></thead><tbody>';

        foreach ($items as $item) {
            $created_at = esc_html((string) ($item['created_at'] ?? ''));
            $event_type = esc_html((string) ($item['event_type'] ?? ''));
            $actor_role = esc_html((string) ($item['actor_role'] ?? 'system'));
            $actor_id = !empty($item['actor_id']) ? (int) $item['actor_id'] : null;
            $actor = $actor_id ? $actor_role . ' #' . $actor_id : $actor_role;
            $payload = isset($item['payload']) ? wp_json_encode($item['payload'], JSON_UNESCAPED_UNICODE) : '';

            echo '<tr>';
            echo '<td>' . $created_at . '</td>';
            echo '<td><code>' . $event_type . '</code></td>';
            echo '<td>' . esc_html($actor) . '</td>';
            echo '<td><code style="white-space:pre-wrap;word-break:break-word;display:block;">' .
                esc_html((string) $payload) .
                '</code></td>';
            echo '</tr>';
        }

        echo '</tbody></table></div>';
    }

    /**
     * Load and register all route classes.
     */
    public function register_routes(): void
    {
        $route_files = array(
            'class-routes-public.php',
            'class-routes-auth.php',
            'class-routes-checkout.php',
            'class-routes-orders.php',
            'class-routes-admin.php',
            'class-routes-delivery.php',
            'class-routes-intel.php',
            'class-routes-merch.php',
            'class-routes-support.php',
            'class-routes-notifications.php',
            'class-ai-routes.php',
            'class-routes-coupons.php',
            'class-routes-wishlist.php',
        );

        foreach ($route_files as $file) {
            require_once LEXI_API_PLUGIN_DIR . 'includes/' . $file;
        }

        Lexi_Routes_Public::register();
        Lexi_Routes_Auth::register();
        Lexi_Routes_Checkout::register();
        Lexi_Routes_Orders::register();
        Lexi_Routes_Admin::register();
        Lexi_Routes_Delivery::register();
        Lexi_Routes_Intel::register();
        Lexi_Routes_Merch::register();
        Lexi_Routes_Support::register();
        Lexi_Routes_Notifications::register();
        Lexi_AI_Routes::instance()->register_routes();
        Lexi_Routes_Coupons::register();
        Lexi_Routes_Wishlist::register();

        if (defined('WP_DEBUG') && WP_DEBUG) {
            require_once LEXI_API_PLUGIN_DIR . 'includes/class-routes-debug.php';
            Lexi_Routes_Debug::register();
        }
    }

    /**
     * Render phone input on wp-login.php?action=register.
     */
    public function render_wp_register_phone_field(): void
    {
        $phone = '';
        if (isset($_POST['phone'])) {
            $phone = esc_attr(Lexi_Security::sanitize_phone(wp_unslash((string) $_POST['phone'])));
        }

        echo '<p>';
        echo '<label for="phone">رقم الهاتف<br />';
        echo '<input type="text" name="phone" id="phone" class="input" value="' . $phone . '" size="25" /></label>';
        echo '</p>';
    }

    /**
     * Validate phone input during native WP registration.
     *
     * @param WP_Error $errors
     * @param string $sanitized_user_login
     * @param string $user_email
     * @return WP_Error
     */
    public function validate_wp_register_phone_field($errors, $sanitized_user_login, $user_email)
    {
        $phone_raw = isset($_POST['phone']) ? wp_unslash((string) $_POST['phone']) : '';
        $phone = Lexi_Security::sanitize_phone($phone_raw);

        if ($phone === '') {
            $errors->add('phone_required', 'رقم الهاتف مطلوب.');
        } elseif (strlen($phone) < 9) {
            $errors->add('phone_invalid', 'رقم الهاتف غير صحيح.');
        }

        return $errors;
    }

    /**
     * Persist phone into Woo billing meta after native WP registration.
     */
    public function save_wp_register_phone_meta(int $user_id): void
    {
        if (!isset($_POST['phone'])) {
            return;
        }

        $phone = Lexi_Security::sanitize_phone(wp_unslash((string) $_POST['phone']));
        if ($phone === '') {
            return;
        }

        update_user_meta($user_id, 'billing_phone', $phone);
    }

    /**
     * Send email notification to management/accounting when a new user registers.
     */
    public static function notify_new_user_registration(int $user_id): void
    {
        if (class_exists('Lexi_Emails')) {
            Lexi_Emails::send_new_user_email($user_id);
        }
    }

    /**
     * Register custom Lexi Dashboard in WP Admin.
     */
    public function register_admin_dashboard_menu(): void
    {
        add_menu_page(
            'Lexi Dashboard',
            'Lexi Dashboard',
            'manage_options',
            'lexi-dashboard',
            array($this, 'render_admin_dashboard_page'),
            'dashicons-dashboard',
            2
        );
    }

    /**
     * Render the custom dashboard page.
     */
    public function render_admin_dashboard_page(): void
    {
        $template = LEXI_API_PLUGIN_DIR . 'includes/admin/admin-dashboard.php';
        if (file_exists($template)) {
            require_once $template;
        } else {
            echo '<div class="wrap"><h1>Lexi Dashboard</h1><p>Template not found.</p></div>';
        }
    }

    /**
     * Enqueue CSS and JS for the custom dashboard.
     */
    public function enqueue_admin_dashboard_assets($hook): void
    {
        if ('toplevel_page_lexi-dashboard' !== $hook) {
            return;
        }

        wp_enqueue_style(
            'lexi-admin-dashboard',
            plugins_url('assets/css/admin-dashboard.css', LEXI_API_PLUGIN_DIR . 'lexi-api.php'),
            array(),
            '1.0.0'
        );

        wp_enqueue_script(
            'lexi-admin-dashboard',
            plugins_url('assets/js/admin-dashboard.js', LEXI_API_PLUGIN_DIR . 'lexi-api.php'),
            array('jquery'),
            '1.0.0',
            true
        );

        // Pass API settings to JS
        wp_localize_script('lexi-admin-dashboard', 'lexiAdminData', array(
            'root' => esc_url_raw(rest_url(LEXI_API_NAMESPACE)),
            'nonce' => wp_create_nonce('wp_rest'),
        ));
    }
}
