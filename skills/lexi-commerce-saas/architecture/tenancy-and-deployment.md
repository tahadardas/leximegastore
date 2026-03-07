# Tenancy And Deployment

## Objective

Run safely as single-tenant now while preserving a clean migration path to multi-tenant SaaS.

## Tenancy Models

1. Single-tenant (current)
   - One WordPress/WooCommerce instance per business deployment.
   - Simpler operations and debugging.
2. Shared app, tenant-scoped data (future)
   - Every record includes `tenant_id`.
   - Enforce tenant scoping at query layer and cache keys.
3. Hybrid
   - Premium customers receive isolated deployment, others shared.

## Multi-Tenant-Ready Constraints

- Use namespaced config keys: `lexi:<tenant_id>:<feature>`.
- Use tenant-aware cache keys and rate-limit buckets.
- Include tenant context in audit logs.
- Keep tenant-neutral route contracts; tenant resolved by auth/context.

## Environments

- `dev`: local/staging integrations, verbose logs
- `stage`: production-like behavior with safe test data
- `prod`: strict logging, monitored alerts, controlled toggles

## Secrets Management

- Store service credentials outside code repo.
- Use environment-specific secret sources.
- Rotate FCM service account credentials periodically.
- Enforce least privilege on WordPress admin operations.

## Migration Strategy

1. Schema migration:
   - Additive first, non-breaking defaults.
   - Backfill scripts with idempotent execution.
2. Data migration:
   - Snapshot, dry run, checksum, rollback plan.
3. API migration:
   - Keep old route behavior while introducing new fields.
4. Release gates:
   - Prevent deploy without migration verification checks.

