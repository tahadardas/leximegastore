---
name: lexi-flutter-customer-app-core
description: Build and maintain the Flutter customer app core architecture including shell navigation, routing stability, auth/session persistence, home server-driven sections, catalog, cart, checkout wizard, order tracking, support tickets, and resilient UI states.
triggers:
  - flutter customer app
  - checkout wizard
  - order tracking ui
  - server driven home
  - cart and product details
  - rtl mobile ux
boundaries:
  - city selection only in checkout flow
  - enforce stable back-stack behavior
  - support rtl-first layouts and copy
---

# 1) Purpose

Deliver a production-ready Flutter customer app foundation with reliable navigation, operational flows, and graceful handling of loading/error/empty states.

# 2) When to use / When NOT to use

Use when:

- Implementing customer-facing app shell or major modules.
- Refactoring routes, providers, or state handling for reliability.
- Integrating backend contracts into customer flows.

Do not use when:

- Work is admin-only console functionality.
- Task is backend plugin logic without customer app impact.

# 3) Inputs required

- Screen/module scope and user journeys.
- API contracts and auth/session requirements.
- Navigation model and deeplink behavior.
- Remote config dependencies.

# 4) Workflow steps (checklist)

- [ ] Define app shell with `convex_bottom_bar` and route map.
- [ ] Implement persistent auth/session bootstrap.
- [ ] Implement server-driven home sections.
- [ ] Implement categories/brands/tags and product details.
- [ ] Implement cart and checkout wizard with city selection only at checkout.
- [ ] Implement order tracking timeline and support ticket module.
- [ ] Add caching and skeleton loaders for key screens.
- [ ] Standardize error/empty states and retry actions.

# 5) Output artifacts (files/docs)

- Route and module map.
- Screen-level API contract bindings.
- State management lifecycle notes.
- UI state matrix (loading/error/empty/content).
- Customer flow QA checklist.

# 6) Definition of Done + Acceptance Criteria

- Navigation and back behavior are deterministic.
- Session survives app restarts and invalid-token handling is correct.
- Core commerce flow works: browse -> cart -> checkout -> track order.
- Support ticket flow works end-to-end.
- RTL layout and text alignment are verified across core screens.

# 7) Risk controls (guardrails)

- Block uninitialized provider access during route transitions.
- Block checkout implementations that bypass city validation.
- Block inconsistent envelope parsing in API client.
- Block release without loading/error/empty state coverage.

# 8) Example invocation prompts

- Build the Flutter customer app core with server-driven home and checkout wizard.
- Refactor customer app routing to fix unstable back behavior.
- Add order tracking and support ticket modules with resilient UI states.

