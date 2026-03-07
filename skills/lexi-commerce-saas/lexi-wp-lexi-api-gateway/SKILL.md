---
name: lexi-wp-lexi-api-gateway
description: Build and maintain the WordPress lexi-api plugin as a strict business-logic gateway with validation, sanitization, permission checks, rate limiting, caching, and consistent response/error schema. Use for route design and backend integration with Flutter apps.
triggers:
  - lexi-api plugin
  - wordpress rest gateway
  - woocommerce api integration
  - route validation
  - rate limiting
  - permission checks
boundaries:
  - enforce global success/error envelope
  - preserve backward-compatible API versions
  - reject unsafe direct wp/wc state mutations
---

# 1) Purpose

Provide a hardened API gateway layer in WordPress that exposes stable, app-friendly contracts and enforces business rules centrally.

# 2) When to use / When NOT to use

Use when:

- Adding/modifying WordPress REST routes.
- Implementing validation, authz, rate limits, and caching policy.
- Standardizing response/error payloads across endpoints.

Do not use when:

- Work is purely Flutter UI behavior with no backend changes.
- Change is limited to WooCommerce admin UI settings.

# 3) Inputs required

- Required endpoints and role permissions.
- Request/response schema definitions.
- Cache invalidation and rate limit requirements.
- Expected integration with WooCommerce objects.

# 4) Workflow steps (checklist)

- [ ] Define route contracts using shared API template.
- [ ] Implement request validation and sanitization first.
- [ ] Enforce authentication and role-based authorization.
- [ ] Apply route-specific rate limiting.
- [ ] Add safe cache strategy and invalidation hooks.
- [ ] Wrap all responses in global envelopes.
- [ ] Add structured error codes and trace IDs.
- [ ] Add endpoint tests for success, validation, auth, and conflicts.

# 5) Output artifacts (files/docs)

- Route map and permissions matrix.
- Controller/service class templates.
- Error code registry.
- Cache and rate-limit policy docs.
- Integration tests or deterministic test checklist.

# 6) Definition of Done + Acceptance Criteria

- Every route returns envelope-compliant payloads.
- Validation and permission failures map to deterministic error codes.
- Rate limits prevent abuse without blocking valid flows.
- Caching does not serve stale critical operational data.
- Backward compatibility preserved for existing app versions.

# 7) Risk controls (guardrails)

- Block endpoint merge if envelope format is inconsistent.
- Block route without capability check or nonce/token auth.
- Block direct SQL writes bypassing domain service layer.
- Block unversioned breaking API changes.

# 8) Example invocation prompts

- Create lexi-api routes for orders, payments, and config with strict validation.
- Add rate limiting and error schema to existing plugin endpoints.
- Refactor WordPress gateway into controllers/services with deterministic contracts.

