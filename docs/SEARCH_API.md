# Search API

## Base
- Namespace: `/wp-json/lexi/v1`

## Endpoints

### 1) Suggestions
- `GET /search/suggestions?q={query}&limit={n}`
- Purpose: typeahead query + product suggestions
- Notes:
  - New route added for contract clarity.
  - Backward compatible with existing `/search/suggest`.

Example request:
```http
GET /wp-json/lexi/v1/search/suggestions?q=iphone&limit=10
```

Example response:
```json
{
  "q": "iphone",
  "suggestions": ["iphone 15", "iphone charger"],
  "products": [
    {
      "id": 123,
      "name": "iPhone 15",
      "price": 1000,
      "sale_price": 950,
      "regular_price": 1000,
      "currency": "SYP",
      "image": "https://...",
      "rating": 4.7,
      "reviews_count": 120,
      "in_stock": true
    }
  ],
  "categories": [
    {
      "id": 55,
      "name": "Phones",
      "image": "https://..."
    }
  ]
}
```

### 2) Product Search
- `GET /search/products?q={query}&page={n}&limit={n}&sort={sort}`
- Purpose: full result list + pagination metadata
- Notes:
  - New route added for explicit results contract.
  - Backward compatible with existing `/search`.

Supported sort values:
- `relevance` (default)
- `newest`
- `price_asc`
- `price_desc`
- `top_rated`
- `on_sale`

Example request:
```http
GET /wp-json/lexi/v1/search/products?q=iphone&page=1&limit=20&sort=relevance
```

Example response:
```json
{
  "q": "iphone",
  "items": [
    {
      "id": 123,
      "name": "iPhone 15",
      "price": 1000,
      "regular_price": 1000,
      "sale_price": 950,
      "in_stock": true
    }
  ],
  "page": 1,
  "limit": 20,
  "total": 999,
  "total_pages": 50,
  "next_page": 2
}
```

### 3) Trending Searches
- `GET /search/trending?limit={n}`
- Purpose: popular/trending query chips
- Response includes both compatibility keys:
  - `queries` (legacy)
  - `items` (new contract)

Example request:
```http
GET /wp-json/lexi/v1/search/trending?limit=10
```

Example response:
```json
{
  "success": true,
  "data": {
    "queries": ["airpods", "samsung"],
    "items": ["airpods", "samsung"]
  }
}
```

## Compatibility Notes
- Flutter API client first calls:
  - `/search/suggestions`
  - `/search/products`
- If either returns `404`, client automatically falls back to legacy routes:
  - `/search/suggest`
  - `/search`

## Performance / Safety
- Suggestions: transient cache keyed by normalized query + limit.
- Trending: transient cache by limit.
- Inputs are sanitized using route arg sanitizers (`sanitize_text_field`, `absint`).

## Flutter Mapping
- Client code:
  - `lib/features/search/search_api.dart`
- Endpoint constants:
  - `lib/config/constants/endpoints.dart`
