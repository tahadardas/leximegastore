---
name: lexi-flutter-notifications-inapp-ux
description: Implement Flutter in-app notification UX including inbox, unread badge, role-specific alert behavior, dedupe/throttling, and user settings controls. Use for client-side notification handling and role-tailored UX behavior.
triggers:
  - in-app notifications
  - unread badge
  - courier alert popup
  - notification throttling
  - notification settings
  - dedupe notifications
boundaries:
  - courier urgent alerts require popup + system sound
  - respect user notification settings
  - avoid duplicate notifications and visual spam
---

# 1) Purpose

Provide a high-confidence in-app notification experience that is actionable, non-spammy, and role-aware.

# 2) When to use / When NOT to use

Use when:

- Building inbox and unread indicators.
- Implementing foreground notification behavior.
- Tuning dedupe and throttling logic.

Do not use when:

- Task is backend sender infrastructure only.
- Task is unrelated to notification presentation.

# 3) Inputs required

- Notification type matrix and payload schema.
- Role behavior rules (customer/admin/courier).
- UX policy for urgent vs informational messages.
- User settings model.

# 4) Workflow steps (checklist)

- [ ] Build notification inbox data model and list UI.
- [ ] Implement unread badge updates and read-state sync.
- [ ] Implement role-based rendering/actions.
- [ ] Implement courier urgent mode: popup + system sound.
- [ ] Add dedupe keys and client-side throttle windows.
- [ ] Implement settings toggles and preference storage.
- [ ] Add deep-link routing from notifications.
- [ ] Add tests for duplicate, burst, and offline cases.

# 5) Output artifacts (files/docs)

- Notification inbox schema and state transitions.
- Dedupe/throttle policy document.
- Role behavior table.
- Settings keys and defaults.
- UX QA checklist.

# 6) Definition of Done + Acceptance Criteria

- Inbox accurately shows message history and read states.
- Unread badge counts remain consistent across sessions.
- Courier urgent notifications show blocking popup and sound.
- Duplicate payloads are deduplicated deterministically.
- User settings reliably enable/disable categories.

# 7) Risk controls (guardrails)

- Block role-blind rendering of sensitive notification types.
- Block alert loops caused by repeated foreground events.
- Block badge desync after reconnect/app restart.
- Enforce envelope-safe parsing for in-app payload ingestion.

# 8) Example invocation prompts

- Build an in-app notification inbox with unread badge and settings toggles.
- Add courier urgent alert popup/sound and dedupe safeguards.
- Refactor foreground notification handling to prevent spam bursts.

