# Order Tracking QA Checklist

## Logged-in customer (My Orders)

- **Login required**
  - Verify drawer shows `طلباتي` and routes to `/orders`.
  - Verify `/orders` loads without asking for any input.

- **Orders list**
  - Verify first load fetches from `GET /wp-json/lexi/v1/my-orders?page=1&per_page=20`.
  - Verify list shows:
    - Order number
    - Status
    - Date
    - Total
    - Item count
  - Verify pull-to-refresh reloads page 1.
  - Verify infinite scroll fetches next page.

- **Authorization filtering**
  - With two different users, verify user A never sees user B orders.
  - Try opening `/wp-json/lexi/v1/my-orders/{order_id}` for an order not belonging to the current user:
    - Must return `order_not_found` (no hint).

- **Order details**
  - Tap an order -> details opens.
  - Verify invoice opens without needing phone for orders that belong to the logged-in customer.

## Guest (Track Order by Order Number)

- **Navigation**
  - When logged out, verify drawer shows `تتبع طلب` and routes to `/track-order`.

- **Validation**
  - Empty input -> blocked with validation message.
  - Inputs accepted:
    - `12345`
    - `#12345`
  - Inputs rejected:
    - `12` (too short)
    - very long numbers (too long)
    - non-numeric only

- **API behavior**
  - Verify request: `POST /wp-json/lexi/v1/track-order` with `{ "order_number": "12345" }`.
  - For non-existing orders:
    - response is generic `order_not_found`.
  - Verify response does not include full addresses, raw email, raw phone.

- **Rate limiting / anti-enumeration**
  - Make many invalid attempts:
    - eventually receive `429 rate_limited`.
    - verify `Retry-After` header exists.
  - Verify repeated misses are logged in server logs as suspicious activity.

## Regression checks

- **Phone-based tracking removed**
  - Verify app has no visible flow to track orders by phone.
  - Verify deprecated endpoints return HTTP `410 endpoint_disabled`:
    - `POST /orders/lookup`
    - `POST /orders/by-phone`
    - `POST /orders/track`

- **HTTPS only**
  - Verify production base URL uses `https://`.

