# Status And Visibility Debugging

## Canonical Fulfillment Statuses

- `pending_review`
- `confirmed`
- `assigned_to_driver`
- `out_for_delivery`
- `delivered`
- `failed`
- `returned`
- `cancelled`

## Common Invisible-Order Root Causes

1. Status filters omit custom states.
2. Payment method mismatch (`sham_cash` vs `shamcash`) used in joins/filters.
3. Tracking endpoint filters only completed Woo states.
4. Role query scope excludes expected tenant/order subsets.

## Debug Endpoint Recommendations

- `/orders/debug/visibility?order_id=...`
  - Return status, payment method, list inclusion flags, filter decisions.
- `/orders/debug/status-map`
  - Return registered statuses and transition configuration.

## Acceptance Assertions

- ShamCash order appears in admin list, customer list, and tracking view.
- COD order remains visible before and after partial payment.
- Returned/cancelled orders remain queryable in audit views.

