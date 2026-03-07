# Entity Catalog

## Users

- `id`, `role` (`customer|admin|manager|support|courier|courier-manager`), `status`, timestamps.

## Devices

- `id`, `user_id`, `platform`, `fcm_token`, `last_seen_at`, `is_active`.
- Unique constraint: active token uniqueness per device.

## Orders

- `id`, `customer_id`, `status`, `payment_status`, `city_id`, `totals`, timestamps.

## Order Events

- Immutable timeline rows with actor + old/new state payloads.

## Payments + Ledger

- Order-level summary + append-only ledger transactions.
- Canonical method IDs: `cod`, `shamcash`.

## Courier Assignments

- `order_id`, `courier_id`, `status`, `assigned_at`, `expires_at`, `active`.

## Courier Locations

- Last-known location table mandatory.
- History table optional by retention policy.

## Support Tickets

- `ticket` (header), `messages`, `attachments`, status lifecycle.

## App Config Versions

- `version`, `config_blob`, `etag`, `published_by`, `published_at`, `rollback_of`.

## Constraints

- Keep state enums strict and documented.
- Preserve historical records; no destructive updates to events/ledger.
- Add indexes on common operational filters:
  - `orders(status, payment_status, city_id)`
  - `assignments(status, expires_at)`
  - `events(order_id, created_at)`

