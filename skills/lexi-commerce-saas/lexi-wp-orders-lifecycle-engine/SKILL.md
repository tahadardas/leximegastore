---
name: lexi-wp-orders-lifecycle-engine
description: Implement and enforce the WooCommerce-backed order lifecycle engine with custom statuses, transition permissions, tracking rules, and visibility safeguards. Use for order state machine changes, tracking endpoints, or order visibility regressions.
triggers:
  - order state machine
  - woocommerce status
  - order lifecycle
  - tracking endpoint
  - invisible orders
  - courier assignment state
boundaries:
  - enforce allowed transitions only
  - separate payment status from fulfillment status
  - never hide orders because of payment method quirks
---

# 1) Purpose

Define and enforce a deterministic order lifecycle with explicit transitions, role permissions, audit events, and visibility guarantees.

# 2) When to use / When NOT to use

Use when:

- Registering or modifying WooCommerce/lexi statuses.
- Updating transition logic or tracking endpoints.
- Debugging missing/invisible orders in admin/customer/courier views.

Do not use when:

- Work concerns only catalog UI or non-order features.
- Issue is FCM delivery unrelated to order states.

# 3) Inputs required

- Required statuses and business rules.
- Role permissions for each transition.
- Existing Woo status mappings and filters.
- Order list/filter behavior requirements.

# 4) Workflow steps (checklist)

- [ ] Register canonical statuses and labels.
- [ ] Define allowed transitions and actor permissions.
- [ ] Implement transition guard service with conflict handling.
- [ ] Emit order events for every transition.
- [ ] Update tracking endpoints and list filters.
- [ ] Add debug endpoints for state visibility diagnostics.
- [ ] Add regression tests for invisible-order class bugs.
- [ ] Verify lifecycle integration with payment and courier modules.

# 5) Output artifacts (files/docs)

- State transition matrix.
- Woo status registration map.
- Tracking endpoint contract.
- Visibility/debug checklist.
- Regression test cases.

# 6) Definition of Done + Acceptance Criteria

- All required states exist and are queryable in APIs/lists.
- Invalid transitions are rejected with `CONFLICT`.
- Every transition creates an immutable order event.
- ShamCash/COD orders remain visible across relevant filters.
- Tracking endpoint returns consistent order and timeline data.

# 7) Risk controls (guardrails)

- Block transition changes without matrix update and tests.
- Block filters that couple visibility to non-canonical payment values.
- Block terminal-state rewrites without explicit admin override policy.
- Enforce global API envelope in tracking/debug routes.

# 8) Example invocation prompts

- Implement pending_review -> confirmed -> assigned_to_driver lifecycle in Woo.
- Fix invisible ShamCash orders by correcting status filters and debug routes.
- Add transition guardrails and timeline events for courier delivery flow.

