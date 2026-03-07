---
name: lexi-qa-release-checklists
description: Execute release readiness and QA checklists for Lexi Commerce, covering Android release hardening, COD flow, ShamCash verification flow, courier TTL flow, FCM end-to-end validation, and remote config publish/rollback safety.
triggers:
  - qa checklist
  - release checklist
  - android release
  - cod e2e
  - shamcash e2e
  - remote config qa
boundaries:
  - require deterministic pass/fail evidence
  - block release on critical operational flow failures
  - include notifications and config rollback validation
---

# 1) Purpose

Provide operationally strict quality gates before production releases and major rollout events.

# 2) When to use / When NOT to use

Use when:

- Preparing release candidate validation.
- Running E2E confidence passes after major changes.
- Auditing readiness for app store/backend deployments.

Do not use when:

- Request is exploratory architecture design only.
- Changes are draft-level and not ready for validation.

# 3) Inputs required

- Target build versions and environments.
- In-scope change list and risk areas.
- Test accounts, roles, and sample data.
- Release timeline and rollback window.

# 4) Workflow steps (checklist)

- [ ] Run Android release hardening checklist.
- [ ] Run COD E2E flow checklist.
- [ ] Run ShamCash verification E2E checklist.
- [ ] Run courier assignment/TTL/delivery checklist.
- [ ] Run FCM registration/send/receive checklist.
- [ ] Run remote config publish/rollback checklist.
- [ ] Record pass/fail with evidence and owner.
- [ ] Gate release decision on unresolved critical failures.

# 5) Output artifacts (files/docs)

- Completed checklist evidence pack.
- Defect list with severity and ownership.
- Go/no-go recommendation.
- Rollback triggers and contingency actions.
- Post-release monitoring watch list.

# 6) Definition of Done + Acceptance Criteria

- All mandatory checklists executed with documented outcomes.
- Critical defects either fixed or explicitly accepted with mitigation.
- Operational flows (orders/payments/courier/config/push) validated.
- Release decision is traceable and signed off by owners.

# 7) Risk controls (guardrails)

- Block production release with unresolved critical operational failures.
- Block checklist completion without evidence artifacts.
- Block untested remote config publish paths.
- Block release if FCM or order visibility sanity tests fail.

# 8) Example invocation prompts

- Run full QA and release checklist for Android + backend rollout.
- Validate COD, ShamCash, courier TTL, FCM, and remote config before release.
- Produce go/no-go report with risk-based mitigation actions.

