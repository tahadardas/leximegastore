---
name: lexi-debug-triage-and-regression
description: Run structured crash triage and regression prevention for Lexi Commerce across Flutter and WordPress layers, with focus on navigation/provider/async failures, DB existence checks, API contract compliance, and invisible-order bug class prevention.
triggers:
  - crash triage
  - regression
  - invisible orders bug
  - provider async issue
  - api contract mismatch
  - db existence check
boundaries:
  - prioritize production-impacting failures first
  - enforce deterministic reproduction and fix validation
  - preserve operational state machine integrity
---

# 1) Purpose

Provide a repeatable triage and regression workflow that finds root causes quickly and prevents recurrence of critical operational bugs.

# 2) When to use / When NOT to use

Use when:

- Investigating crashes or severe behavior regressions.
- Diagnosing missing data/order visibility issues.
- Validating API contract drift between backend and Flutter clients.

Do not use when:

- Task is only feature design with no failure context.
- Issue is infrastructure billing or unrelated external service setup.

# 3) Inputs required

- Reproduction steps and observed impact.
- Logs, traces, and sample API payloads.
- Affected module(s) and build versions.
- Known recent changes or suspect PRs.

# 4) Workflow steps (checklist)

- [ ] Reproduce issue deterministically and capture baseline.
- [ ] Classify failure class (navigation/provider/async/data/API/state).
- [ ] Validate DB existence and status/payment consistency.
- [ ] Validate API envelope and schema compatibility.
- [ ] Validate order list/status filters for visibility regressions.
- [ ] Implement minimal safe fix with targeted tests.
- [ ] Add regression checklist item and monitoring signal.
- [ ] Document root cause and verification evidence.

# 5) Output artifacts (files/docs)

- Triage report with root cause and blast radius.
- Reproduction script/checklist.
- Fix summary with changed contracts or queries.
- Regression test cases and monitoring updates.
- Post-incident risk updates.

# 6) Definition of Done + Acceptance Criteria

- Issue reproduced before fix and absent after fix.
- Root cause is documented and technically verified.
- No new API envelope or state machine violations introduced.
- Regression test or checklist added and executed.
- Impacted operational workflows are revalidated end-to-end.

# 7) Risk controls (guardrails)

- Block fixes that only mask symptoms without root cause.
- Block release if invisible-order regression checks are missing.
- Block schema/enum changes without backward compatibility checks.
- Enforce audit logging on state-changing fix paths.

# 8) Example invocation prompts

- Triage why ShamCash orders are missing from admin order list.
- Debug provider async crash when navigating from search to product detail.
- Validate API contract drift causing Flutter parsing failures.

