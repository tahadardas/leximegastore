# Lexi Product API Contract (Stable)

Base namespace: `/wp-json/lexi/v1`

## Core Endpoints

- `GET /products`
- `GET /products/{id}`
- `GET /products/{id}/similar`
- `GET /products/{id}/reviews`
- `GET /categories`
- `GET /home/sections`
- `GET /search/suggest`
- `GET /search`
- `GET /search/trending`

## List Query Parameters

- `GET /products`
  - `page`, `per_page`, `search`, `category_id`, `sort`, `min_price`, `max_price`
  - `include_unpriced` (optional, default `0`)
    - `0`: exclude products where resolved sell price is missing/zero.
    - `1`: include unpriced products.
- `GET /home/sections`
  - `items_limit`
  - `include_unpriced` (optional, default `0`)
    - `0`: section items exclude unpriced products.
    - `1`: include unpriced products.

## Product Payload (Final Contract)

All keys are returned consistently. If a value is unknown, it is returned as `null` (key is still present).

```json
{
  "id": 2111,
  "name": "Zero Pen Blue 101",
  "slug": "zero-pen-blue-101",
  "type": "simple",
  "status": "publish",
  "sku": "LP.2111-blue",

  "price": 15500,
  "regular_price": 17500,
  "sale_price": 15500,
  "currency": "SYP",
  "discount_percent": 11,

  "stock_status": "instock",
  "stock_quantity": 24,
  "in_stock": true,

  "rating_avg": 4.6,
  "rating_count": 12,
  "rating": 4.6,
  "reviews_count": 12,

  "short_description": "Quick-dry pen",
  "description": "Detailed description...",

  "images": [
    { "id": 1001, "src": "https://leximega.store/wp-content/uploads/...", "alt": "Zero Pen Blue 101" }
  ],
  "featured_image": "https://leximega.store/wp-content/uploads/...",

  "categories": [
    { "id": 33, "name": "Pens", "slug": "pens" }
  ],
  "category_ids": [33],

  "price_min": null,
  "price_max": null,
  "regular_min": null,
  "regular_max": null,
  "sale_min": null,
  "sale_max": null,

  "total_in_stock": null,
  "variants_in_stock": null,
  "total_variants": null,

  "shipping_class_id": null,
  "shipping_class": "",
  "tax_status": "taxable",
  "tax_class": "",
  "attributes": [],
  "variations": [],

  "date_on_sale_from": null,
  "date_on_sale_to": null,
  "created_at": "2026-02-22T10:00:00+00:00",
  "wishlist_count": 0
}
```

## Variable Product Notes

- `price` mirrors `price_min` for variable products.
- Additional range keys are populated:
  - `price_min`, `price_max`
  - `regular_min`, `regular_max`
  - `sale_min`, `sale_max`
- Stock aggregate keys are populated:
  - `total_in_stock`
  - `variants_in_stock`
  - `total_variants`

## Error Envelope

```json
{
  "success": false,
  "error": {
    "code": "products_error",
    "message": "تعذر جلب المنتجات حالياً.",
    "details": {
      "trace_id": "lexi_..."
    }
  }
}
```

`trace_id` is logged server-side and returned to help diagnostics.
