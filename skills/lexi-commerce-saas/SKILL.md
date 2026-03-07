---
name: lexi-commerce-saas
description: Orchestrate end-to-end build, refactor, and operation of a WooCommerce-connected e-commerce platform with Flutter customer app, full Flutter admin console, optional Flutter courier app, and WordPress lexi-api gateway. Use when prompts mention store build, WooCommerce app, admin dashboard, courier flows, ShamCash, COD, remote config, FCM, or SaaS commerce architecture.
triggers:
  - build store
  - woocommerce app
  - full flutter admin panel
  - admin dashboard
  - courier assignment
  - shamcash
  - cod
  - fcm
  - remote app config
  - order lifecycle
boundaries:
  - no multi-currency in this version
  - preserve operational state integrity
  - require backward-compatible API versioning
  - documentation-first and data-first execution
---

# Purpose

Act as the master orchestrator for a commercial, sellable SaaS-grade e-commerce platform skill system.

Route tasks to focused sub-skills while enforcing shared architecture constraints, data contracts, and operational safety.

# When To Use / When NOT To Use

Use this skill when:

- The request spans backend + customer/admin/courier apps.
- The request impacts order, payment, courier, notification, or remote config workflows.
- The request needs production-grade docs, acceptance criteria, and release discipline.

Do not use this skill when:

- The request is a small isolated bug fix that clearly belongs to a single existing sub-skill.
- The request is unrelated to commerce platform architecture and operations.

# Global Constraints (Always Enforce)

1. Documentation-first: write specs and acceptance criteria before implementation.
2. Data-first: define schema/contracts before API routes and UI changes.
3. Never break operational states: enforce deterministic order/payment/courier transitions.
4. Backward-compatible API versioning: additive changes first; preserve old fields or deprecate with migration notes.
5. Deterministic acceptance criteria: every task must have testable pass/fail checks.
6. No multi-currency in this version.
7. Global API envelope:
   - Success: `{ "ok": true, "data": { ... } }`
   - Error: `{ "ok": false, "code": "SOME_CODE", "message": "Human readable", "details": { ... } }`

# Routing Logic

Route by dominant concern:

- SaaS topology, tenancy, environments, migration strategy:
  - `lexi-saas-architecture-foundation`
- Entity design, ERD constraints, JSON schemas:
  - `lexi-data-modeling-commerce`
- WordPress gateway plugin, API standards, validation, rate limit:
  - `lexi-wp-lexi-api-gateway`
- Order statuses and lifecycle rules:
  - `lexi-wp-orders-lifecycle-engine`
- ShamCash/COD workflows and payment ledger:
  - `lexi-wp-payments-shamcash-cod`
- FCM device registry and sender implementation:
  - `lexi-wp-notifications-fcm-v1`
- Remote config publishing/rollback:
  - `lexi-wp-remote-config-console`
- Customer app foundation and user flows:
  - `lexi-flutter-customer-app-core`
- Search interactions and performance:
  - `lexi-flutter-search-suite`
- In-app notifications UX behavior:
  - `lexi-flutter-notifications-inapp-ux`
- Full Flutter admin operations panel:
  - `lexi-flutter-admin-console`
- Courier app ops and delivery execution:
  - `lexi-flutter-courier-app`
- Regressions, crashes, invisible orders class:
  - `lexi-debug-triage-and-regression`
- Release gates and E2E QA execution:
  - `lexi-qa-release-checklists`

If multiple concerns exist, run in this order:

1. `lexi-saas-architecture-foundation`
2. `lexi-data-modeling-commerce`
3. Backend sub-skills
4. Flutter sub-skills
5. Reliability and QA sub-skills

# Inputs Required

- Business scope and tenant model for current delivery.
- Existing DB/API/schema artifacts if available.
- Current app screen list and role matrix.
- Operational rules for orders, payments, courier assignments, and support.
- Environment targets (dev/stage/prod) and deployment constraints.

# Workflow Steps (Checklist)

1. Decompose scope into modules and dependencies.
2. Define/validate data contracts and invariants.
3. Plan versioned API routes and response/error envelopes.
4. Map UI screens by role: Customer + Admin (+ Courier if in scope).
5. Produce PR-style implementation phases with acceptance tests.
6. Build risk register with proactive mitigations.
7. Produce DoD and QA checklist tied to business flows.

# Mandatory Output Artifacts (Always Produce)

1. Scope decomposition (modules)
2. Data model/contracts
3. API routes plan
4. UI screens map (Customer + Admin)
5. Implementation plan (PR-style)
6. Risk register + mitigations
7. Definition of Done + QA checklist

# Definition Of Done + Acceptance Criteria

- All required artifacts are produced and internally consistent.
- Order/payment/courier states are protected by explicit rules and tests.
- API versioning and envelope standards are enforced in all routes.
- Remote config and notification flows include rollback/failure handling.
- QA checklists include COD, ShamCash, courier TTL expiry, FCM, and config rollback scenarios.

# Risk Controls (Guardrails)

- Block release if order states become unreachable or bypassable.
- Block release if payment method IDs are inconsistent (`shamcash` canonical only).
- Block release if push token cleanup on `UNREGISTERED` is missing.
- Block release if config publishing lacks schema validation and rollback.
- Block release if API responses violate the global envelope.

# Example Invocation Prompts

- Build a WooCommerce-connected e-commerce app with full Flutter admin panel.
- Plan and implement ShamCash + COD operational workflow with audit trail.
- Add courier assignment TTL and notifications without breaking order visibility.
- Introduce remote app config publish/rollback with ETag support.

