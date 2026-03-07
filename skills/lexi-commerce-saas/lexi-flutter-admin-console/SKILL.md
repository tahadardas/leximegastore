---
name: lexi-flutter-admin-console
description: Build a full commercial Flutter Admin Console for e-commerce operations: auth/roles, KPI dashboard, order management, ShamCash verification, courier assignment and tracking, support tickets, app config console, notifications center, and audit log viewer with RTL support and operational reliability.
triggers:
  - full flutter admin panel
  - admin dashboard
  - order management console
  - shamcash verification
  - courier manager
  - audit log viewer
boundaries:
  - use flutter as full admin console (not wp-admin replacement ui)
  - rtl-first and timeago timestamps
  - no-crash operational workflow handling
---

# 1) Purpose

Deliver a fast, consistent, production-grade Flutter Admin Console that can operate the platform end-to-end without relying on WordPress admin as daily ops UI.

# 2) When to use / When NOT to use

Use when:

- Building or expanding admin operational modules.
- Refactoring admin architecture for reliability and speed.
- Implementing role-gated operational controls.

Do not use when:

- Task is customer-only app behavior.
- Task is backend route internals without admin surface impact.

# 3) Inputs required

- Role matrix: `admin`, `manager`, `support`, `courier-manager`.
- KPI definitions and reporting windows.
- Order/payment/courier/support/config API contracts.
- Print/share and map navigation integration requirements.

# 4) Workflow steps (checklist)

- [ ] Implement auth/session bootstrap and role gates.
- [ ] Build KPI dashboard cards and trend slices.
- [ ] Build orders list with advanced filters.
- [ ] Build order detail timeline and actions:
  - shamcash approve/reject
  - courier assign/reassign
  - navigate to customer
  - payment ledger view
  - print/share summary
- [ ] Build courier management:
  - courier list
  - last-known location lookup
  - assignment queue + TTL indicators
  - performance reports
- [ ] Build support tickets list/detail/reply with attachments.
- [ ] Build app config console (flags/nav/home/publish/rollback).
- [ ] Build notifications center for targeted/broadcast sends.
- [ ] Build audit log viewer with filters.
- [ ] Apply full RTL support and `timeago` formatting.

# 5) Output artifacts (files/docs)

- Admin module architecture map.
- Screen map and role-access matrix.
- Action permissions + endpoint bindings.
- Crash-safe state management checklist.
- Admin E2E QA scenarios.

# 6) Definition of Done + Acceptance Criteria

- All listed modules are functional and role-gated.
- Order operations are complete and state-safe.
- Courier assignment, TTL visibility, and location actions work.
- Support tickets and attachments flow correctly.
- App config publish/rollback and notifications center function.
- Audit log viewer filters by actor/date/type.
- RTL and `timeago` formatting verified platform-wide.

# 7) Risk controls (guardrails)

- Block privileged actions without server-side permission checks.
- Block order action UI that can bypass transition guards.
- Block stale UI caches for critical operational data.
- Block release without crash triage and key E2E flow pass.
- Enforce global API envelope handling on all admin requests.

# 8) Example invocation prompts

- Build a full Flutter admin console with order, courier, and support operations.
- Add ShamCash verification and payment ledger panel to order details.
- Implement app config publish/rollback and audit log viewer in admin.

