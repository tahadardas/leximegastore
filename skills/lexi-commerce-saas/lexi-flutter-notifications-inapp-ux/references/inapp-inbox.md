# In-App Inbox Reference

## Notification Item Fields

- `id`
- `type`
- `title`
- `body`
- `role_target`
- `created_at`
- `is_read`
- `deeplink`
- `dedupe_key`

## Dedupe Rule

- Ignore message if `dedupe_key` already processed within configurable window.

## Throttle Rule

- Limit foreground surface alerts by type within a short time bucket.
- Always allow courier urgent type to bypass normal throttle.

## Read State

- Mark-as-read updates local state immediately.
- Sync read updates to backend when online.

