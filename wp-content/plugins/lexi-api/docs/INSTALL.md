# Lexi API — Installation Guide

## Prerequisites

- WordPress 5.8+
- WooCommerce 6.0+
- PHP 7.4+
- HTTPS (required for JWT and REST API security)

---

## 1. Install the Plugin

1. Copy the `lexi-api` folder into `wp-content/plugins/`.
2. Go to **Plugins → Installed Plugins** in WP Admin.
3. Click **Activate** on "Lexi API".
4. On activation, the plugin will:
   - Create the `wp_lexi_shipping_cities` database table.
   - Seed 3 default shipping cities (دمشق, حلب, حمص).
   - Set default ShamCash configuration in wp_options.

---

## 2. Permalinks

> **Critical:** REST API endpoints require pretty permalinks.

Go to **Settings → Permalinks** and select any option other than "Plain" (e.g., "Post name"). Click **Save Changes**.

Verify the API is accessible:
```
GET https://your-site.com/wp-json/lexi/v1/shipping/cities
```

---

## 3. WooCommerce Settings

### Guest Checkout
Go to **WooCommerce → Settings → Accounts & Privacy**:
- ✅ Enable "Allow customers to place orders without an account"

### Emails
Go to **WooCommerce → Settings → Emails → New Order**:
- Configure recipient email(s) for admin notifications.
- The plugin uses WooCommerce's built-in email system; all recipients configured here will receive order alerts from the API.

### Currency
Go to **WooCommerce → Settings → General**:
- Set currency to **Syrian Pound (SYP)** or your preferred currency.

---

## 4. JWT Authentication (for Admin Endpoints)

The admin endpoints require WordPress authentication. We recommend **JWT Authentication for WP-API**:

1. Install: [Simple JWT Login](https://wordpress.org/plugins/simple-jwt-login/) or [JWT Auth](https://wordpress.org/plugins/jwt-auth/).
2. Configure per the plugin's docs. Typically you need:
   - Add `JWT_AUTH_SECRET_KEY` constant to `wp-config.php`:
     ```php
     define('JWT_AUTH_SECRET_KEY', 'your-secret-key-here');
     define('JWT_AUTH_CORS_ENABLE', true);
     ```
   - Enable the JWT auth plugin.
3. Obtain tokens via:
   ```
   POST /wp-json/jwt-auth/v1/token
   { "username": "admin", "password": "password" }
   ```
4. Use the token in requests:
   ```
   Authorization: Bearer eyJhbGciOiJIUzI1NiIs...
   ```

> **Note:** The user must have the `manage_woocommerce` capability (Administrator or Shop Manager role).

---

## 5. ShamCash Configuration

The plugin stores ShamCash config in the `wp_options` table. Default values are set on activation.

To update, use **WP-CLI** or the database directly:

```bash
wp option update lexi_shamcash_account_name "Lexi Mega Store"
wp option update lexi_shamcash_qr_value "shamcash://pay?account=lexi-store-production"
wp option update lexi_shamcash_barcode_value "LEXI-PROD-001"
wp option update lexi_shamcash_instructions_ar "يرجى كتابة رقم الطلب في ملاحظات التحويل ثم رفع صورة الإيصال."
```

Or via the database:
```sql
UPDATE wp_options SET option_value = 'Your Value' WHERE option_name = 'lexi_shamcash_account_name';
```

> **Tip:** A future update will add a WP Admin settings page for ShamCash config.

---

## 6. Custom Order Status

The plugin registers a custom WooCommerce order status:

| Slug | Label | Usage |
|------|-------|-------|
| `wc-pending-verification` | بانتظار التحقق | ShamCash orders awaiting proof review |

This status appears in:
- WP Admin → Orders filter dropdown
- Bulk actions
- REST API responses

---

## 7. Invoice System

The plugin generates **Arabic HTML invoices** via signed URLs.

- **Provisional invoice (فاتورة مبدئية):** Available immediately after order creation.
- **Final invoice (فاتورة نهائية):** Available after order status is `processing` or `completed`.

Invoice URLs expire after **1 hour** (HMAC-signed with `wp_salt('auth')`).

### PDF Invoice Plugin (Optional)

If you want PDF invoices, install a WooCommerce PDF invoice plugin like:
- [WooCommerce PDF Invoices & Packing Slips](https://wordpress.org/plugins/woocommerce-pdf-invoices-packing-slips/)

The Lexi API HTML invoice serves as a reliable fallback and works well for mobile viewing and printing.

---

## 8. CORS (for Flutter Web)

If your Flutter app runs on web and calls the API cross-origin, add CORS headers.

Add to `wp-config.php` or a mu-plugin:
```php
header("Access-Control-Allow-Origin: *");
header("Access-Control-Allow-Methods: GET, POST, PATCH, DELETE, OPTIONS");
header("Access-Control-Allow-Headers: Authorization, Content-Type");
```

Or use a CORS plugin: [WP-CORS](https://wordpress.org/plugins/wp-cors/)

---

## 9. File Uploads

For ShamCash proof uploads:
- The max upload size is governed by PHP settings (`upload_max_filesize`, `post_max_size`).
- The plugin enforces a **5 MB** limit and only allows JPEG, PNG, WebP, and GIF.
- Uploaded proof images are stored in the WordPress media library and linked to the order via meta.

---

## 10. Testing

After installation, verify endpoints using curl:

```bash
# List cities
curl https://your-site.com/wp-json/lexi/v1/shipping/cities

# ShamCash config
curl https://your-site.com/wp-json/lexi/v1/payments/shamcash/config

# Guest checkout (COD)
curl -X POST https://your-site.com/wp-json/lexi/v1/checkout/guest \
  -H "Content-Type: application/json" \
  -d '{
    "billing": {"first_name":"أحمد","last_name":"محمد","phone":"0912345678","address_1":"شارع بغداد","city":"دمشق"},
    "items": [{"product_id": 1, "quantity": 2}],
    "shipping_city_id": 1,
    "payment_method": "cod"
  }'

# Admin dashboard (requires JWT token)
curl https://your-site.com/wp-json/lexi/v1/admin/dashboard \
  -H "Authorization: Bearer YOUR_JWT_TOKEN"
```

---

## Troubleshooting

| Issue | Solution |
|-------|----------|
| `rest_no_route` | Flush permalinks: Settings → Permalinks → Save |
| 401 on admin routes | Verify JWT token and user has `manage_woocommerce` cap |
| Orders not emailing | Check WooCommerce → Settings → Emails → New Order is enabled |
| DB table missing | Deactivate then reactivate the plugin |
| ShamCash config empty | Run the WP-CLI commands from section 5 |
