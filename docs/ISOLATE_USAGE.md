# Isolate Usage (Targeted)

## Rule Applied
- Use isolate only for heavy CPU-bound transforms.
- Do not use isolate for network calls.

## Implemented Use Case
- File: `lib/features/orders/data/parsers/order_parsing.dart`
- Entry point:
  - `parseOrdersInBackground(List<Map<String, dynamic>> rawItems)`
- Strategy:
  - if item count `< 40` or platform is web: parse on main isolate
  - if item count `>= 40` and not web: parse with `compute()`

## Integration Point
- File: `lib/features/orders/data/datasources/order_remote_datasource.dart`
- `myOrders()` now parses payload via `parseOrdersInBackground(...)`.

## Why This Helps
- Large order payload mapping (`Order.fromJson` over many items) can block UI thread.
- Offloading above threshold reduces potential jank while keeping small payloads cheap.

## Error/Architecture Safety
- Pure-data transform only (serializable args/return values).
- No dependency injection or network client inside isolate.
- Fallback to main isolate on web (where `compute` behavior differs and worker overhead can be wasteful).

## Not Applied Elsewhere Yet
- No additional isolate usage was introduced for search/notifications/location because current operations are network-bound and lightweight mapping.

