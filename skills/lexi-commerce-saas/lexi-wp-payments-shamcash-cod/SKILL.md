---
name: lexi-wp-payments-shamcash-cod
description: Implement payment workflows for ShamCash and COD, including proof upload, admin verification decisions, canonical payment_method IDs, partial payments, ledger tracking, and audit-safe reporting. Use for payment lifecycle features or reconciliation issues.
triggers:
  - shamcash
  - cod payment
  - payment ledger
  - proof upload
  - partial payment
  - reconciliation
boundaries:
  - canonical payment_method ids only: cod, shamcash
  - no multi-currency support
  - immutable ledger entries required
---

# 1) Purpose

Provide reliable, auditable payment workflows for ShamCash and COD without compromising order visibility or ledger consistency.

# 2) When to use / When NOT to use

Use when:

- Building/adjusting payment verification workflows.
- Implementing or auditing payment ledger behavior.
- Fixing COD partial payment or ShamCash method mismatch issues.

Do not use when:

- Task is unrelated to payments.
- Task is purely push notification display logic.

# 3) Inputs required

- Payment methods in scope (`cod`, `shamcash`).
- Proof verification policy and role permissions.
- Ledger and reporting requirements.
- Existing payment metadata and order integration points.

# 4) Workflow steps (checklist)

- [ ] Define canonical payment method enums.
- [ ] Implement ShamCash proof upload endpoint and storage rules.
- [ ] Implement admin approve/reject decision workflow.
- [ ] Implement COD collection and partial payment logic.
- [ ] Write immutable ledger records for all payment actions.
- [ ] Recompute order payment status from ledger + policy.
- [ ] Emit payment audit events and reports.
- [ ] Add acceptance tests for full flow scenarios.

# 5) Output artifacts (files/docs)

- Payment workflow spec (ShamCash + COD).
- Ledger schema and event mappings.
- Endpoint contracts for proof upload/decision/ledger retrieval.
- Reconciliation report query checklist.
- Acceptance test matrix.

# 6) Definition of Done + Acceptance Criteria

- `shamcash` and `cod` are the only accepted method IDs.
- Proof upload and decision events are traceable.
- Partial COD payments update ledger and order payment state correctly.
- Payment actions are actor-attributed in audit logs.
- All payment endpoints follow global response envelope.

# 7) Risk controls (guardrails)

- Block non-canonical method IDs.
- Block mutable ledger updates; allow append-only entries.
- Block delivery completion logic that bypasses payment reconciliation rules.
- Block release without ShamCash and COD E2E test pass.

# 8) Example invocation prompts

- Build ShamCash proof upload and admin decision flow with audit logs.
- Implement COD partial payment ledger and outstanding balance reporting.
- Fix shamcash vs sham_cash mismatch and add regression tests.

