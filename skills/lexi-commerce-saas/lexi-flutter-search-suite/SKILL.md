---
name: lexi-flutter-search-suite
description: Implement robust Flutter search experiences with suggestions, debounce, cancellation, local history with optional sync, stable provider lifecycle, and performance safeguards. Use for search UX/features or provider-related search regressions.
triggers:
  - flutter search
  - suggestions
  - debounce
  - cancellation
  - search history
  - provider lifecycle
boundaries:
  - avoid uninitialized provider state
  - enforce cancellation of stale queries
  - keep perceived latency low
---

# 1) Purpose

Deliver fast, reliable, and crash-resistant search behavior in Flutter customer/admin contexts.

# 2) When to use / When NOT to use

Use when:

- Building or refactoring search bars/results/suggestions.
- Optimizing search request lifecycle and rendering performance.
- Debugging provider async race conditions in search flows.

Do not use when:

- Task is unrelated to search interactions.
- Task is backend-only notification infrastructure.

# 3) Inputs required

- Search endpoints and response schema.
- Query constraints and ranking expectations.
- Local storage strategy for history.
- Platform performance targets.

# 4) Workflow steps (checklist)

- [ ] Implement input debounce window.
- [ ] Cancel in-flight requests on new query.
- [ ] Render suggestions with stable state transitions.
- [ ] Persist local history and optional sync behavior.
- [ ] Guard provider initialization and disposal paths.
- [ ] Add empty/no-match/error states.
- [ ] Optimize list rendering and pagination behavior.
- [ ] Add test scenarios for race and cancellation correctness.

# 5) Output artifacts (files/docs)

- Search interaction sequence diagram.
- Debounce/cancellation policy.
- Provider lifecycle checklist.
- History schema and retention policy.
- Performance test notes.

# 6) Definition of Done + Acceptance Criteria

- Suggestions respond quickly without duplicate request storms.
- Stale results do not overwrite newer query results.
- No provider lifecycle crashes in navigation transitions.
- Search history behaves consistently across app restarts.
- Search UI passes loading/empty/error consistency checks.

# 7) Risk controls (guardrails)

- Block direct setState/provider writes after widget disposal.
- Block uncancelled request chains on rapid typing.
- Block synchronous heavy filtering on UI thread.
- Enforce envelope-safe API parsing and error mapping.

# 8) Example invocation prompts

- Implement a Flutter search suite with debounce, cancellation, and local history.
- Fix provider lifecycle crash in search results screen.
- Optimize suggestions and search performance under rapid input.

