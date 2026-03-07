---
name: lexi-wp-notifications-fcm-v1
description: Implement end-to-end Firebase Cloud Messaging from WordPress using HTTP v1 with OAuth2 service account, device token registration/cleanup, notification type mapping by role, and delivery-safe conventions. Use for push notification backend design and operations.
triggers:
  - fcm
  - push notifications
  - http v1 sender
  - device token registration
  - unregistered cleanup
  - broadcast notification
boundaries:
  - admin-only broadcast controls
  - token lifecycle management required
  - global API envelope for all notification routes
---

# 1) Purpose

Provide reliable push delivery infrastructure across customer/admin/courier apps with deterministic token lifecycle and role-aware messaging.

# 2) When to use / When NOT to use

Use when:

- Implementing WordPress-side FCM sender or device endpoints.
- Designing push message types and priority conventions.
- Investigating push delivery failures or stale tokens.

Do not use when:

- Task is only local UI badge rendering with no backend integration.
- Task is unrelated to notifications.

# 3) Inputs required

- FCM project/service account configuration.
- Role-based notification taxonomy.
- Target routes for registration/send/history.
- Retry and cleanup policy requirements.

# 4) Workflow steps (checklist)

- [ ] Define device registration endpoint (user, role, platform, token).
- [ ] Implement OAuth2 token minting for FCM HTTP v1.
- [ ] Implement sender service for targeted and broadcast notifications.
- [ ] Define notification type map by role and priority.
- [ ] Handle `UNREGISTERED` responses by deactivating tokens.
- [ ] Store send attempts and outcomes for audit/reporting.
- [ ] Add admin-only guardrails on mass notification routes.
- [ ] Validate end-to-end delivery from backend to Flutter handlers.

# 5) Output artifacts (files/docs)

- Device token API contracts.
- Notification type and payload matrix.
- Sender service implementation pattern.
- Delivery error handling and cleanup policy.
- QA checklist for push reliability.

# 6) Definition of Done + Acceptance Criteria

- Devices can register/update tokens per authenticated user.
- Backend sends via FCM HTTP v1 with valid OAuth2 access token.
- Role-targeted messages reach intended recipients only.
- `UNREGISTERED` cleanup occurs automatically.
- All responses and errors use global envelope standard.

# 7) Risk controls (guardrails)

- Block storing unscoped tokens without user/role binding.
- Block unauthenticated or non-admin broadcast endpoints.
- Block retries without dedupe keys.
- Block release if cleanup path for invalid tokens is missing.

# 8) Example invocation prompts

- Build WordPress FCM HTTP v1 sender with OAuth2 and admin broadcast route.
- Add token registration and stale token cleanup on UNREGISTERED.
- Define notification type mapping for customer/admin/courier roles.

