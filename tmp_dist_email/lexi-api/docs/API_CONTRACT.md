# Lexi API — REST Endpoint Contract

**Namespace:** `/wp-json/lexi/v1`
**Response shape:** `{ success: bool, data: ..., error?: { code, message, details? } }`

---

## Public Endpoints (No Authentication)

### GET `/products`

List products with pagination, search, category, and price filters.

| Param | Type | Default | Description |
|-------|------|---------|-------------|
| `page` | int | 1 | Page number |
| `per_page` | int | 20 | Items per page (max 100) |
| `search` | string | "" | Keyword search |
| `category` | string | "" | Category slug |
| `min_price` | number | — | Minimum price filter |
| `max_price` | number | — | Maximum price filter |

**Response 200:**
```json
{
  "success": true,
  "data": {
    "items": [
      {
        "id": 42,
        "name": "قميص قطني",
        "slug": "cotton-shirt",
        "sku": "CS-001",
        "price": "15000",
        "regular_price": "18000",
        "sale_price": "15000",
        "on_sale": true,
        "stock_status": "instock",
        "short_description": "...",
        "description": "...",
        "images": ["https://site.com/wp-content/uploads/shirt.jpg"],
        "categories": [{"id": 5, "name": "ملابس", "slug": "clothing"}]
      }
    ],
    "page": 1,
    "per_page": 20,
    "total": 85,
    "total_pages": 5
  }
}
```

---

### GET `/categories`

**Response 200:**
```json
{
  "success": true,
  "data": [
    { "id": 5, "name": "ملابس", "slug": "clothing", "count": 12, "image": "https://..." }
  ]
}
```

---

### GET `/shipping/cities`

**Response 200:**
```json
{
  "success": true,
  "data": [
    { "id": 1, "name": "دمشق", "price": 5000, "sort_order": 1 },
    { "id": 2, "name": "حلب", "price": 8000, "sort_order": 2 }
  ]
}
```

---

### GET `/shipping/rate?city_id={id}`

**Response 200:**
```json
{ "success": true, "data": { "city_id": 1, "name": "دمشق", "price": 5000 } }
```

**Response 404:**
```json
{ "success": false, "error": { "code": "city_not_found", "message": "المدينة غير موجودة أو غير متاحة." } }
```

---

### GET `/payments/shamcash/config`

**Response 200:**
```json
{
  "success": true,
  "data": {
    "account_name": "Lexi Mega Store",
    "qr_value": "shamcash://pay?account=lexi-store",
    "barcode_value": "LEXI-STORE-001",
    "instructions_ar": "يرجى كتابة رقم الطلب في ملاحظات التحويل ثم رفع صورة الإيصال."
  }
}
```

---

## Checkout

### POST `/checkout/guest`

**Request Body:**
```json
{
  "billing": {
    "first_name": "أحمد",
    "last_name": "محمد",
    "phone": "0912345678",
    "email": "ahmed@example.com",
    "address_1": "شارع بغداد",
    "city": "دمشق"
  },
  "items": [
    { "product_id": 42, "quantity": 2 },
    { "product_id": 15, "quantity": 1 }
  ],
  "shipping_city_id": 1,
  "payment_method": "shamcash",
  "customer_note": "يرجى التوصيل صباحاً"
}
```

**Response 201 (COD):**
```json
{
  "success": true,
  "data": {
    "order_id": 1024,
    "order_number": "1024",
    "status": "processing",
    "total": "35000",
    "next_action": { "type": "none" }
  }
}
```

**Response 201 (ShamCash):**
```json
{
  "success": true,
  "data": {
    "order_id": 1025,
    "order_number": "1025",
    "status": "pending-verification",
    "total": "35000",
    "next_action": {
      "type": "shamcash_payment",
      "account_name": "Lexi Mega Store",
      "qr_value": "shamcash://pay?account=lexi-store",
      "barcode_value": "LEXI-STORE-001",
      "instructions_ar": "يرجى كتابة رقم الطلب في ملاحظات التحويل..."
    }
  }
}
```

---

## Orders

### POST `/orders/lookup`

**Request Body:**
```json
{ "order_id": 1024, "phone": "0912345678" }
```

**Response 200:**
```json
{
  "success": true,
  "data": {
    "id": 1024,
    "order_number": "1024",
    "status": "processing",
    "total": 35000,
    "subtotal": 30000,
    "shipping_cost": 5000,
    "payment_method": "cod",
    "date": "2026-02-12T10:30:00+03:00",
    "billing": {
      "first_name": "أحمد", "last_name": "محمد",
      "phone": "0912345678", "email": "",
      "address_1": "شارع بغداد", "city": "دمشق"
    },
    "items": [
      {
        "product_id": 42, "name": "قميص قطني", "sku": "CS-001",
        "qty": 2, "price": 15000, "subtotal": 30000,
        "image": "https://..."
      }
    ],
    "customer_note": "",
    "payment_proof": null
  }
}
```

---

### GET `/orders/{id}/invoice?phone={phone}&type={provisional|final}`

Returns a signed, time-limited URL (1 hour expiry) to the HTML invoice.

- `phone` — Required for guest access; admin users can omit.
- `type` — `provisional` (default, available immediately) or `final` (after payment confirmation).

**Response 200:**
```json
{
  "success": true,
  "data": {
    "invoice_url": "https://site.com/wp-json/lexi/v1/invoices/render?order_id=1024&type=provisional&expires=1739367600&sig=abc123...",
    "invoice_type": "provisional"
  }
}
```

---

### POST `/payments/shamcash/proof`

Multipart form data (not JSON).

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `order_id` | int | Yes | Order ID |
| `phone` | string | Yes | Billing phone for verification |
| `proof_image` | file | Yes | JPEG/PNG/WebP, max 5 MB |

**Response 201:**
```json
{
  "success": true,
  "data": {
    "attachment_id": 456,
    "url": "https://site.com/wp-content/uploads/proof-1024.jpg",
    "message": "تم رفع إثبات الدفع بنجاح. سيتم مراجعته من قبل الإدارة."
  }
}
```

---

## Admin Endpoints (Requires `manage_woocommerce`)

Auth via JWT `Authorization: Bearer <token>` or WP cookie session.

### GET `/admin/dashboard`

**Response 200:**
```json
{
  "success": true,
  "data": {
    "today_sales": 150000,
    "today_orders_count": 8,
    "total_orders_count": 342,
    "pending_verification_count": 3,
    "processing_count": 12
  }
}
```

---

### GET `/admin/orders?status={status}&page=1&per_page=20`

Same order shape as `/orders/lookup` response, wrapped in paginated envelope.

---

### PATCH `/admin/orders/{id}`

**Request Body:**
```json
{
  "status": "processing",
  "note": "تم التحقق من إيصال الدفع"
}
```

**Response 200:**
```json
{
  "success": true,
  "data": {
    "order_id": 1025,
    "old_status": "pending-verification",
    "new_status": "processing",
    "message": "تم تحديث حالة الطلب بنجاح."
  }
}
```

---

### Shipping Cities CRUD

#### GET `/admin/shipping/cities`
Returns all cities (including inactive ones with `is_active`, `created_at`, `updated_at`).

#### POST `/admin/shipping/cities`
```json
{ "name": "اللاذقية", "price": 7000, "is_active": 1, "sort_order": 4 }
```

#### PATCH `/admin/shipping/cities/{id}`
```json
{ "price": 7500 }
```

#### DELETE `/admin/shipping/cities/{id}`
```json
{ "success": true, "data": { "message": "تم حذف المدينة بنجاح." } }
```

---

## Error Codes Reference

| Code | HTTP | Description |
|------|------|-------------|
| `missing_billing_field` | 422 | Required billing field missing |
| `empty_cart` | 422 | No items in checkout |
| `invalid_payment` | 422 | Payment method not cod/shamcash |
| `invalid_city` | 422 | Shipping city not found or inactive |
| `invalid_product` | 422 | Product ID not found |
| `out_of_stock` | 422 | Product not in stock |
| `checkout_failed` | 500 | Order creation exception |
| `order_not_found` | 404 | Order ID doesn't exist |
| `phone_mismatch` | 403 | Phone doesn't match billing |
| `city_not_found` | 404 | City not found |
| `invalid_signature` | 403 | Signed URL invalid |
| `link_expired` | 403 | Signed URL expired |
| `no_file` | 422 | Proof image not uploaded |
| `invalid_file_type` | 422 | File not JPEG/PNG/WebP |
| `file_too_large` | 422 | File exceeds 5 MB |

---

## Merchandising Endpoints

### Public

#### GET `/categories`
Returns sorted categories from admin manual order:
- first by `sort_order` (term meta `lexi_sort_order`)
- then by category name

Example item:
```json
{
  "id": 33,
  "name": "حقائب مدرسية",
  "slug": "school-bags",
  "count": 12,
  "image": "https://leximega.store/wp-content/uploads/...",
  "image_url": "https://leximega.store/wp-content/uploads/...",
  "sort_order": 1
}
```

#### GET `/products?category_id=33&sort=manual`
Manual category merchandising:
- pinned products first
- then custom `sort_order`
- then remaining products by newest

Supports:
- `sort=manual|newest|price_asc|price_desc|top_rated|on_sale`

Example product fields (when `category_id` is provided):
```json
{
  "id": 992,
  "name": "حقيبة مدرسية",
  "price": 2000,
  "regular_price": 2500,
  "sale_price": 2000,
  "pinned": true,
  "sort_order": 1
}
```

#### GET `/home/sections`
Returns active home sections sorted by `sort_order` and already resolved products.

```json
{
  "success": true,
  "data": [
    {
      "id": 1,
      "title_ar": "الأكثر طلباً",
      "type": "manual_products",
      "sort_order": 1,
      "items": []
    }
  ]
}
```

### Admin (JWT + manage_woocommerce)

#### Categories Order
- `GET /admin/merch/categories`
- `PATCH /admin/merch/categories`

Request:
```json
{
  "items": [
    { "id": 33, "sort_order": 1 },
    { "id": 34, "sort_order": 2 }
  ]
}
```

#### Category Products Merchandising
- `GET /admin/merch/category-products?term_id=33&page=1&per_page=50&search=`
- `PATCH /admin/merch/category-products/bulk`

Request:
```json
{
  "term_id": 33,
  "replace_all": true,
  "items": [
    { "product_id": 992, "pinned": true, "sort_order": 1 },
    { "product_id": 993, "pinned": false, "sort_order": 2 }
  ]
}
```

#### Home Sections
- `GET /admin/merch/home-sections`
- `POST /admin/merch/home-sections`
- `PATCH /admin/merch/home-sections/{id}`
- `DELETE /admin/merch/home-sections/{id}`
- `PATCH /admin/merch/home-sections/reorder`

Request:
```json
{
  "items": [
    { "id": 1, "sort_order": 1 },
    { "id": 2, "sort_order": 2 }
  ]
}
```

#### Manual Section Items
- `GET /admin/merch/home-sections/{id}/items`
- `PATCH /admin/merch/home-sections/{id}/items`

Request:
```json
{
  "items": [
    { "product_id": 992, "pinned": true, "sort_order": 1 },
    { "product_id": 994, "pinned": false, "sort_order": 2 }
  ]
}
```
