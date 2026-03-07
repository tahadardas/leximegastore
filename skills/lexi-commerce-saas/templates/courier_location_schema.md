# Courier Location Schema Template

## Last Known Location

| Field | Type | Required | Description |
|---|---|---|---|
| `courier_id` | string | yes | courier user ID |
| `tenant_id` | string | yes | tenant scope |
| `lat` | number | yes | latitude |
| `lng` | number | yes | longitude |
| `accuracy_m` | number | no | gps accuracy meters |
| `speed_mps` | number | no | speed in m/s |
| `heading` | number | no | degrees |
| `captured_at` | datetime | yes | device capture time |
| `received_at` | datetime | yes | server receive time |
| `source` | string | yes | `foreground`, `background`, `manual` |

## Optional History Table

| Field | Type | Required | Description |
|---|---|---|---|
| `id` | string | yes | UUID |
| `courier_id` | string | yes | courier user ID |
| `tenant_id` | string | yes | tenant scope |
| `lat` | number | yes | latitude |
| `lng` | number | yes | longitude |
| `captured_at` | datetime | yes | timestamp |
| `order_id` | string | no | linked active order |

## Rules

- Require location permission before courier can receive assignments.
- Reject stale locations older than policy threshold.
- Keep location payload lean for mobile battery efficiency.

