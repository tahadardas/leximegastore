# ShamCash Order Filters (2026-03-03)

## Customer Orders (`GET /wp-json/lexi/v1/my-orders`)

Updated visibility filter now explicitly includes:

- `pending`
- `processing`
- `on-hold`
- `completed`
- `cancelled`
- `failed`
- `refunded`
- `pending-verification`
- `pending-verificat` (legacy truncated custom status)
- `out-for-delivery`
- `delivered-unpaid`

Optional query param support:

- `payment_method=cod`
- `payment_method=sham_cash`
- `payment_method=shamcash` (legacy alias; normalized internally)

## Admin Orders (`GET /wp-json/lexi/v1/admin/orders`)

Status handling now normalizes the pending verification group:

- `status=pending-verification`
- `status=on-hold`
- `status=pending-verificat`

All of the above resolve to the same pending-verification status bucket.

Optional query param support:

- `payment_method=cod`
- `payment_method=sham_cash`
- `payment_method=shamcash` (legacy alias)

Admin payment filter is implemented using meta query against both:

- `_payment_method`
- `_lexi_payment_method`

with backward-compatible ShamCash values:

- `sham_cash`
- `shamcash`

## Storage Status Note

- Public API status remains `pending-verification`.
- DB-safe persisted status is `pending-verificat` (20-char compatible with `wc-` prefix).
- Both are registered and accepted in filters:
  - `wc-pending-verification`
  - `wc-pending-verificat`

## Admin Debug Endpoint

- `GET /wp-json/lexi/v1/admin/debug/order/{id}`
- Returns canonical diagnostics:
  - existence, post/wc status, payment method (raw + normalized), decision/proof meta.
