<?php
/**
 * Lexi Store Settings Page
 */

defined('ABSPATH') || exit;

class Lexi_Settings
{
    public static function init(): void
    {
        add_action('admin_menu', array(__CLASS__, 'add_admin_menu'));
    }

    public static function add_admin_menu(): void
    {
        add_submenu_page(
            'woocommerce',
            'إعدادات تطبيق Lexi',
            'إعدادات Lexi',
            'manage_options',
            'lexi-api-settings',
            array(__CLASS__, 'render_settings_page')
        );
    }

    public static function render_settings_page(): void
    {
        if (!current_user_can('manage_options')) {
            return;
        }

        // Handle form submission
        if (isset($_POST['lexi_settings_nonce']) && wp_verify_nonce(sanitize_text_field(wp_unslash($_POST['lexi_settings_nonce'])), 'lexi_save_settings')) {
            self::save_settings($_POST);
            echo '<div class="notice notice-success is-dismissible"><p>تم حفظ الإعدادات بنجاح.</p></div>';
        }

        // Handle clear tokens action
        if (isset($_POST['lexi_clear_tokens_btn'])) {
            if (!isset($_POST['lexi_clear_tokens_nonce']) || !wp_verify_nonce(sanitize_text_field(wp_unslash($_POST['lexi_clear_tokens_nonce'])), 'lexi_clear_tokens_action')) {
                echo '<div class="notice notice-error is-dismissible"><p>خطأ في التحقق من الأمان. يرجى المحاولة مرة أخرى.</p></div>';
            } else {
                if (class_exists('Lexi_Push')) {
                    Lexi_Push::clear_all_tokens();
                    echo '<div class="notice notice-success is-dismissible"><p>تم مسح جميع توكنات الإشعارات (FCM Tokens) بنجاح.</p></div>';
                }
            }
        }

        // Get current options
        $enabled = get_option('lexi_shamcash_enabled', 'yes');
        $account = get_option('lexi_shamcash_account_name', 'Lexi Mega Store');
        $qr = get_option('lexi_shamcash_qr_value', 'shamcash://pay?account=lexi-store');
        $barcode = get_option('lexi_shamcash_barcode_value', 'LEXI-STORE-001');
        $inst_ar = get_option('lexi_shamcash_instructions_ar', 'يرجى كتابة رقم الطلب في ملاحظات التحويل ثم رفع صورة الإيصال.');
        $inst_en = get_option('lexi_shamcash_instructions_en', 'Please write the order number in the transfer notes and upload the receipt.');

        ?>
        <div class="wrap">
            <h1>إعدادات تطبيق Lexi Mega Store</h1>
            <form method="post" action="">
                <?php wp_nonce_field('lexi_save_settings', 'lexi_settings_nonce'); ?>
                
                <h2>إعدادات الدفع (شام كاش)</h2>
                <table class="form-table">
                    <tr>
                        <th scope="row">تفعيل شام كاش في التطبيق</th>
                        <td>
                            <label>
                                <input type="checkbox" name="lexi_shamcash_enabled" value="yes" <?php checked($enabled, 'yes'); ?> />
                                تفعيل طريقة الدفع
                            </label>
                        </td>
                    </tr>
                    <tr>
                        <th scope="row">اسم الحساب (Account Name)</th>
                        <td>
                            <input type="text" name="lexi_shamcash_account_name" class="regular-text" value="<?php echo esc_attr($account); ?>" required />
                        </td>
                    </tr>
                    <tr>
                        <th scope="row">قيمة رمز الاستجابة السريعة (QR Value)</th>
                        <td>
                            <input type="text" name="lexi_shamcash_qr_value" class="large-text" value="<?php echo esc_attr($qr); ?>" required />
                        </td>
                    </tr>
                    <tr>
                        <th scope="row">قيمة الباركود (Barcode Value)</th>
                        <td>
                            <input type="text" name="lexi_shamcash_barcode_value" class="regular-text" value="<?php echo esc_attr($barcode); ?>" required />
                        </td>
                    </tr>
                    <tr>
                        <th scope="row">التعليمات (عربي)</th>
                        <td>
                            <textarea name="lexi_shamcash_instructions_ar" rows="4" class="large-text" required><?php echo esc_textarea($inst_ar); ?></textarea>
                        </td>
                    </tr>
                    <tr>
                        <th scope="row">التعليمات (إنكليزي)</th>
                        <td>
                            <textarea name="lexi_shamcash_instructions_en" rows="4" class="large-text"><?php echo esc_textarea($inst_en); ?></textarea>
                        </td>
                    </tr>
                </table>

                <?php submit_button('حفظ الإعدادات'); ?>
            </form>

            <hr />

            <h2>أدوات الإشعارات (Push Notifications Tools)</h2>
            <p>استخدم هذا الزر لمسح جميع التوكنات القديمة إذا واجهت مشكلة <code>SenderId mismatch</code> بعد تغيير مشروع Firebase.</p>
            <form method="post" action="" onsubmit="return confirm('هل أنت متأكد من رغبتك في مسح جميع التوكنات؟ سيؤدي هذا إلى إعادة تسجيل الأجهزة تلقائياً عند فتح التطبيق.');">
                <?php wp_nonce_field('lexi_clear_tokens_action', 'lexi_clear_tokens_nonce'); ?>
                <input type="submit" name="lexi_clear_tokens_btn" class="button button-secondary" value="مسح جميع التوكنات (FCM Tokens)" />
            </form>
        </div>
        <?php
    }

    private static function save_settings($data): void
    {
        $enabled = isset($data['lexi_shamcash_enabled']) ? 'yes' : 'no';
        update_option('lexi_shamcash_enabled', $enabled);

        if (isset($data['lexi_shamcash_account_name'])) {
            update_option('lexi_shamcash_account_name', sanitize_text_field(wp_unslash($data['lexi_shamcash_account_name'])));
        }
        if (isset($data['lexi_shamcash_qr_value'])) {
            update_option('lexi_shamcash_qr_value', sanitize_text_field(wp_unslash($data['lexi_shamcash_qr_value'])));
        }
        if (isset($data['lexi_shamcash_barcode_value'])) {
            update_option('lexi_shamcash_barcode_value', sanitize_text_field(wp_unslash($data['lexi_shamcash_barcode_value'])));
        }
        if (isset($data['lexi_shamcash_instructions_ar'])) {
            update_option('lexi_shamcash_instructions_ar', sanitize_textarea_field(wp_unslash($data['lexi_shamcash_instructions_ar'])));
        }
        if (isset($data['lexi_shamcash_instructions_en'])) {
            update_option('lexi_shamcash_instructions_en', sanitize_textarea_field(wp_unslash($data['lexi_shamcash_instructions_en'])));
        }
        
        update_option('lexi_shamcash_updated_at', gmdate('c'));
    }
}
