# Tenancy Playbook

## Objective

Support immediate single-tenant delivery without blocking a controlled migration to multi-tenant SaaS.

## Recommended Baseline

- Keep current deployment isolated per business client.
- Adopt tenant-aware naming in all new tables and cache keys (`tenant_id`).
- Keep route contracts tenant-neutral; resolve tenant from auth context.

## Namespace Convention

- API: `/wp-json/lexi/v1/...`
- Config keys: `lexi:<tenant_id>:config:<version>`
- Cache keys: `lexi:<tenant_id>:<domain>:<id>`

## Logging Taxonomy

- `trace_id`, `tenant_id`, `actor_id`, `role`, `event_type`, `resource_id`, `status`.
- Include request latency and normalized error code.

## Migration Protocol

1. Add schema fields with defaults.
2. Backfill in idempotent batches.
3. Validate row counts and checksums.
4. Switch reads to new fields.
5. Switch writes.
6. Decommission old fields after a safe window.

