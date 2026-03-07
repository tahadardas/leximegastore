<?php
/**
 * Main plugin bootstrap: singleton, custom order status, route loading.
 *
 * @package Lexi_API
 */

defined('ABSPATH') || exit;

class Lexi_Plugin
{

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
     * Constructor — hooks.
     */
    private function __construct()
    {
        // Register custom order status.
        add_action('init', array($this, 'register_order_statuses'));
        add_filter('wc_order_statuses', array($this, 'add_order_statuses'));
        add_filter('bulk_actions-edit-shop_order', array($this, 'add_bulk_actions'));

        // Init WooCommerce email hooks.
        Lexi_Emails::init();

        // Register REST routes.
        add_action('rest_api_init', array($this, 'register_routes'));

        // Add phone field to native WordPress registration form.
        add_action('register_form', array($this, 'render_wp_register_phone_field'));
        add_filter('registration_errors', array($this, 'validate_wp_register_phone_field'), 10, 3);
        add_action('user_register', array($this, 'save_wp_register_phone_meta'));

        // Send email notification to management/accounting when new user registers.
        add_action('user_register', array(__CLASS__, 'notify_new_user_registration'), 20);

        // AI Core hooks - WooCommerce purchase tracking
        add_action('woocommerce_order_status_completed', array($this, 'ai_track_purchase'));
        add_action('woocommerce_order_status_processing', array($this, 'ai_track_purchase'));

        // AI Core cron jobs
        add_action('lexi_ai_hourly_aggregation', array($this, 'ai_hourly_aggregation'));
        add_action('lexi_ai_daily_aggregation', array($this, 'ai_daily_aggregation'));
    }

    /**
     * Track purchase in AI Core
     */
    public function ai_track_purchase($order_id): void
    {
        Lexi_AI_Core::instance()->record_purchase($order_id);
    }

    /**
     * AI hourly aggregation
     */
    public function ai_hourly_aggregation(): void
    {
        Lexi_AI_Core::instance()->hourly_aggregation();
    }

    /**
     * AI daily aggregation
     */
    public function ai_daily_aggregation(): void
    {
        Lexi_AI_Core::instance()->daily_aggregation();
    }

    /* ── Custom Order Status ───────────────────────────────── */

    /**
     * Register the pending-verification order status.
     */
    public function register_order_statuses(): void
    {
        register_post_status('wc-pending-verification', array(
            'label' => 'بانتظار التحقق',
            'public' => true,
            'exclude_from_search' => false,
            'show_in_admin_all_list' => true,
            'show_in_admin_status_list' => true,
            /* translators: %s: number of orders */
            'label_count' => _n_noop(
                'بانتظار التحقق <span class="count">(%s)</span>',
                'بانتظار التحقق <span class="count">(%s)</span>',
                'lexi-api'
            ),
        ));
    }

    /**
     * Add custom status to WooCommerce order statuses dropdown.
     *
     * @param array $statuses Existing statuses.
     * @return array
     */
    public function add_order_statuses(array $statuses): array
    {
        $statuses['wc-pending-verification'] = 'بانتظار التحقق';
        return $statuses;
    }

    /**
     * Add custom status to bulk actions.
     *
     * @param array $actions Existing bulk actions.
     * @return array
     */
    public function add_bulk_actions(array $actions): array
    {
        $actions['mark_pending-verification'] = 'تغيير الحالة إلى بانتظار التحقق';
        return $actions;
    }

    /* ── REST Routes ───────────────────────────────────────── */

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
        Lexi_Routes_Intel::register();
        Lexi_Routes_Merch::register();
        Lexi_Routes_Support::register();
        Lexi_Routes_Notifications::register();
        Lexi_AI_Routes::instance()->register_routes();
        Lexi_Routes_Coupons::register();
        Lexi_Routes_Wishlist::register();

        // Debug routes: only available when WP_DEBUG is enabled.
        if ( defined( 'WP_DEBUG' ) && WP_DEBUG ) {
            require_once LEXI_API_PLUGIN_DIR . 'includes/class-routes-debug.php';
            Lexi_Routes_Debug::register();
        }
    }

    /* ── Native WP Registration Phone ─────────────────────── */

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
     */
    public function validate_wp_register_phone_field($errors, $sanitized_user_login, $user_email)
    {
        $phone_raw = isset($_POST['phone']) ? wp_unslash((string) $_POST['phone']) : '';
        $phone = Lexi_Security::sanitize_phone($phone_raw);

        if ('' === $phone) {
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
        if ('' === $phone) {
            return;
        }

        update_user_meta($user_id, 'billing_phone', $phone);
    }

    /**
     * Send email notification to management/accounting when a new user registers.
     *
     * @param int $user_id The newly registered user ID.
     */
    public static function notify_new_user_registration(int $user_id): void
    {
        if (class_exists('Lexi_Emails')) {
            Lexi_Emails::send_new_user_email($user_id);
        }
    }
}
