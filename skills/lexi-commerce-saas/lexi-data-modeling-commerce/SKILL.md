---
name: lexi-data-modeling-commerce
description: Design and validate commerce data models, ERD constraints, and JSON schemas for users, devices, orders, payments, courier assignments/locations, support tickets, and remote app config versions. Use before API/UI implementation or when refactoring domain contracts.
triggers:
  - data model
  - erd
  - schema design
  - json schema
  - entity relationship
  - domain contracts
boundaries:
  - no multi-currency support
  - preserve operational state integrity
  - enforce canonical ids and status enums
---

# 1) Purpose

Define the canonical commerce data model and enforce constraints required for safe order, payment, courier, support, and config operations.

# 2) When to use / When NOT to use

Use when:

- Creating or changing entities and relationships.
- Producing ERD notes and JSON contract schemas.
- Auditing data consistency issues.

Do not use when:

- Work is pure UI styling without data impact.
- Issue is limited to infra provisioning.

# 3) Inputs required

- Required entity list and role matrix.
- Operational state rules for orders/payments/courier flows.
- Existing DB tables and plugin metadata conventions.
- Reporting and audit requirements.

# 4) Workflow steps (checklist)

- [ ] Enumerate entities and ownership boundaries.
- [ ] Define keys, indexes, constraints, and enum values.
- [ ] Separate fulfillment, payment, and courier assignment state.
- [ ] Define immutable audit/event tables.
- [ ] Define JSON schemas for API payloads.
- [ ] Validate canonical payment method IDs (`cod`, `shamcash`).
- [ ] Validate remote config versioning model.
- [ ] Document migration impact and backfill logic.

# 5) Output artifacts (files/docs)

- ERD notes with cardinality and constraints.
- Entity schema definitions (tables and JSON schema).
- State enum registry.
- Data quality checks and consistency queries.
- Migration notes per changed entity.

# 6) Definition of Done + Acceptance Criteria

- All required entities are modeled with clear relationships.
- Order, payment, and courier data are independently queryable.
- Event/audit model is append-only and actor-attributed.
- JSON schemas validate request/response contracts.
- No ambiguous payment IDs or unsupported currency features.

# 7) Risk controls (guardrails)

- Block schema changes without migration/backfill plan.
- Block enums that allow invalid operational transitions.
- Block nullable critical foreign keys in event/ledger records.
- Enforce global API envelope compatibility.

# 8) Example invocation prompts

- Create ERD and JSON schemas for orders, ledger, courier assignments, and support tickets.
- Refactor data model to prevent invisible ShamCash orders.
- Define remote app config version entity with publish/rollback audit.

