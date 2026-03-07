# Payment Ledger Schema Template

## Ledger Entry

| Field | Type | Required | Description |
|---|---|---|---|
| `id` | string | yes | UUID |
| `tenant_id` | string | yes | tenant scope |
| `order_id` | string | yes | linked order |
| `payment_method` | string | yes | `cod` or `shamcash` |
| `status` | string | yes | `unpaid`, `partial`, `paid`, `failed`, `reversed` |
| `amount` | number | yes | positive decimal |
| `currency` | string | yes | fixed platform currency |
| `direction` | string | yes | `debit` or `credit` |
| `reference` | string | no | transaction/proof ID |
| `note` | string | no | operator note |
| `actor_type` | string | yes | `admin`, `courier`, `system` |
| `actor_id` | string | no | actor identifier |
| `created_at` | datetime | yes | UTC timestamp |

## Rules

- Canonical method IDs only:
  - `cod`
  - `shamcash`
- No multi-currency conversion in this release.
- Any adjustment must write a new ledger row; never mutate historical entries.
- Order payment status is derived from ledger totals and business overrides.

