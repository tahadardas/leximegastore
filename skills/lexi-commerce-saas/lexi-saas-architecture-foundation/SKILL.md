---
name: lexi-saas-architecture-foundation
description: Define SaaS-ready architecture foundations for Lexi Commerce, including single-tenant now with multi-tenant-ready patterns, versioning, environments, secrets, logging, and migration strategy. Use for platform topology, deployment model decisions, and architecture guardrails.
triggers:
  - saas architecture
  - tenancy model
  - migration strategy
  - environments
  - secrets management
  - logging strategy
boundaries:
  - no multi-currency design
  - preserve backward-compatible API versioning
  - keep current deployment single-tenant-capable
---

# 1) Purpose

Produce architecture decisions and guardrails that support current single-tenant delivery while enabling future multi-tenant SaaS scaling.

# 2) When to use / When NOT to use

Use when:

- Defining tenancy and environment topology.
- Designing namespace/versioning strategy.
- Planning schema/data/API migrations.

Do not use when:

- The task is strictly Flutter UI implementation.
- The task is isolated endpoint bug fixing without architecture impact.

# 3) Inputs required

- Target deployment model (`single-tenant now`, `multi-tenant-ready later`).
- Environment constraints (`dev`, `stage`, `prod`).
- Security and compliance expectations.
- Existing infrastructure and hosting assumptions.

# 4) Workflow steps (checklist)

- [ ] Confirm current tenant mode and growth assumptions.
- [ ] Select tenancy pattern and document migration path.
- [ ] Define namespace, config, and cache-key conventions.
- [ ] Define API versioning and deprecation policy.
- [ ] Define secrets management and rotation policy.
- [ ] Define logging, tracing, and audit taxonomy.
- [ ] Define schema + data migration protocol with rollback.
- [ ] Validate that operational workflows remain deterministic.

# 5) Output artifacts (files/docs)

- Architecture decision record (ADR) with tenancy choice.
- Environment matrix and secret ownership map.
- Versioning/deprecation policy.
- Migration runbook (schema + data + rollback).
- Risk register entries for topology-level risks.

# 6) Definition of Done + Acceptance Criteria

- Architecture is explicit for single-tenant now and multi-tenant-ready future.
- Config/cache/logging patterns include tenant scope strategy.
- Migration plan is idempotent, testable, and rollback-safe.
- API versioning policy is clear and backward-compatible.

# 7) Risk controls (guardrails)

- Do not merge architecture changes without migration rollback path.
- Do not allow unscoped caches that would break tenant isolation later.
- Do not introduce secret handling in code or repo.
- Enforce global API envelopes for all services.

# 8) Example invocation prompts

- Define a single-tenant-now, multi-tenant-ready architecture for Lexi Commerce.
- Create migration and logging strategy for WooCommerce + lexi-api growth.
- Write tenancy and versioning ADRs for commercial SaaS packaging.

