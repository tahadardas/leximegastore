# Courier Reports

## Purpose

Courier reporting now uses a dedicated events table as the single source of truth, not only order meta/status snapshots.

This fixes "empty/incorrect courier dashboard reports" by aggregating real operational events written at action time.

## Data Source

Table: `{$wpdb->prefix}lexi_order_events` (created by `Lexi_Order_Events::create_table()`).

Relevant columns for reporting:

- `id` bigint unsigned PK
- `order_id` bigint unsigned nullable
- `courier_id` bigint unsigned nullable
- `event_type` varchar(64)
- `amount` decimal(20,6) nullable
- `actor_role` varchar(32)
- `actor_id` bigint unsigned nullable
- `payload_json` longtext nullable
- `created_at` datetime (UTC)

Indexes used by report queries:

- `idx_created_at (created_at)`
- `idx_event_type (event_type)`
- `idx_courier_id (courier_id)`
- `idx_actor (actor_role, actor_id)`

## Event Writing Rules

The following actions write events (or are normalized to these canonical types):

- Admin assigns/reassigns courier -> `assigned`
- Courier accepts assignment -> `accepted`
- Courier rejects assignment -> `rejected`
- Courier starts delivery -> `out_for_delivery`
- Courier marks delivered -> `delivered`
- Courier collects COD -> `cod_collected` (with `amount`)
- Courier fails/returns delivery -> `failed_delivery` or `returned`

Compatibility aliases still recognized in reports:

- `driver_assigned`, `driver_reassigned` -> `assigned`
- `driver_accepted` -> `accepted`
- `driver_rejected` -> `rejected`
- `failed_delivery`, `returned` -> failed bucket

## Report Endpoint

`GET /wp-json/lexi/v1/admin/couriers/report`

Args:

- `date` (legacy day filter, optional)
- `from` (optional: `Y-m-d` or datetime)
- `to` (optional: `Y-m-d` or datetime)
- `courier_id` (optional)
- `available_only` (optional)
- `search` (optional)
- `include_details` (0/1)
- `details_limit` (1..200)

Window behavior:

- If `from/to` are missing and `date` missing -> defaults to current site day.
- If only one boundary exists -> other boundary uses start/end of same day.
- Date window is converted from site timezone to UTC before SQL filtering.

## SQL/Aggregation Logic

Implementation entry:

- `Lexi_Routes_Admin::get_couriers_report()`
- helper `list_courier_event_rows($start_utc_sql, $end_utc_sql, $courier_id_filter)`

Filtered event set:

- `assigned`, `driver_assigned`, `driver_reassigned`
- `accepted`, `driver_accepted`
- `rejected`, `driver_rejected`
- `out_for_delivery`
- `delivered`
- `failed_delivery`, `returned`
- `cod_collected`

Courier resolution precedence per event row:

1. `courier_id` column
2. (`actor_role == courier` and `actor_id > 0`)
3. `payload_json.courier_id`

Metric definitions:

- `assigned_count`: count of normalized `assigned`
- `accepted_count`: count of normalized `accepted`
- `rejected_count`: count of normalized `rejected`
- `delivered_count`: count of normalized `delivered`
- `failed_count`: count of normalized failed bucket
- `cod_collected_sum`: sum of `amount` on `cod_collected`
- `avg_delivery_minutes`: average of `(delivered_at - assigned_at)` per `(courier_id, order_id)` pair when both timestamps exist

Summary fields aggregate courier rows:

- `assigned_total`
- `accepted_total`
- `rejected_total`
- `delivered_total`
- `failed_total`
- `cod_collected_total`
- `average_delivery_minutes`

Back-compat summary keys kept:

- `delivered_today_total`
- `active_assigned_orders_total`

## Notes and Non-Goals

- Report metrics are intentionally event-driven and not tied to Woo status names.
- Custom order statuses like `pending-verification` do not break courier reporting.
- No multi-currency logic was introduced.

## Quick Verification

1. Assign order to courier from admin.
2. Courier accepts, sets out-for-delivery, delivers, and collects COD.
3. Call `GET /admin/couriers/report?from=YYYY-MM-DD&to=YYYY-MM-DD`.
4. Verify:
   - counts increment correctly
   - COD sum includes collected amount
   - average minutes appears when assigned+delivered timestamps exist
