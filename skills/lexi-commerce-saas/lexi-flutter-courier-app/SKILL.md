---
name: lexi-flutter-courier-app
description: Build and maintain the Flutter courier app with mandatory location gate, assignment accept/reject, delivery workflow transitions, customer navigation, COD collection submission, offline action queueing, and high-priority alert behavior.
triggers:
  - flutter courier app
  - assignment accept reject
  - courier location gate
  - out for delivery
  - cod collection
  - offline queue
boundaries:
  - no assignments without location permission
  - enforce order transition constraints
  - support offline-safe queued actions
---

# 1) Purpose

Deliver courier operations tooling that is reliable under field conditions and tightly aligned with backend state machine rules.

# 2) When to use / When NOT to use

Use when:

- Building courier workflow screens and action handlers.
- Integrating location, mapping, and delivery transitions.
- Improving resilience in low-connectivity scenarios.

Do not use when:

- Task is admin/customer app-only.
- Task is unrelated to courier execution.

# 3) Inputs required

- Courier workflow and state transition rules.
- Location permission and update policy.
- Assignment TTL and retry/requeue behavior.
- COD collection payload requirements.

# 4) Workflow steps (checklist)

- [ ] Implement login bootstrap with mandatory location gate.
- [ ] Implement assignment queue and accept/reject actions.
- [ ] Implement map navigation to customer address.
- [ ] Implement transition actions: `out_for_delivery`, `delivered`.
- [ ] Implement COD collection form and submission.
- [ ] Add offline action queue with deterministic replay.
- [ ] Add urgent alert popup + system sound behavior.
- [ ] Validate reconciliation with backend order/payment states.

# 5) Output artifacts (files/docs)

- Courier route/screen map.
- Assignment and TTL behavior spec.
- Offline queue state model.
- COD collection integration contract.
- Courier QA runbook.

# 6) Definition of Done + Acceptance Criteria

- Courier cannot receive assignments before location readiness.
- Assignment lifecycle handles accept/reject/expiry correctly.
- Delivery transitions synchronize with backend state machine.
- COD submissions create ledger entries and status updates.
- Offline actions replay safely without duplicate side effects.

# 7) Risk controls (guardrails)

- Block order transitions when assignment preconditions are unmet.
- Block silent action failures in offline mode.
- Block duplicate replay of queued mutating actions.
- Enforce global API envelope parsing and robust retry handling.

# 8) Example invocation prompts

- Build a Flutter courier app with location gate and assignment queue.
- Add COD collection and offline-safe delivery actions.
- Implement high-priority courier alert popup with sound.

