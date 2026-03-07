# Event Log Schema Template

## Order Events

| Field | Type | Required | Description |
|---|---|---|---|
| `id` | string | yes | UUID |
| `tenant_id` | string | yes | tenant scope |
| `order_id` | string | yes | order identifier |
| `event_type` | string | yes | `order_created`, `status_changed`, `payment_updated`, `assignment_changed` |
| `actor_type` | string | yes | `customer`, `admin`, `courier`, `system` |
| `actor_id` | string | no | user ID, nullable for system |
| `old_value` | object | no | prior state payload |
| `new_value` | object | no | new state payload |
| `metadata` | object | no | extra context |
| `created_at` | datetime | yes | UTC timestamp |

## Courier Events

| Field | Type | Required | Description |
|---|---|---|---|
| `id` | string | yes | UUID |
| `tenant_id` | string | yes | tenant scope |
| `courier_id` | string | yes | courier user ID |
| `order_id` | string | no | related order when applicable |
| `event_type` | string | yes | `assignment_received`, `assignment_accepted`, `location_updated`, `delivery_marked` |
| `payload` | object | no | event details |
| `created_at` | datetime | yes | UTC timestamp |

## Index Recommendations

- `(tenant_id, order_id, created_at desc)` for order timelines
- `(tenant_id, courier_id, created_at desc)` for courier analytics
- `(tenant_id, event_type, created_at desc)` for operational reports

