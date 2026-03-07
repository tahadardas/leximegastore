# FCM v1 Implementation Notes

## Required Endpoints

- `POST /devices/register`
- `POST /devices/unregister`
- `POST /admin/notifications/send`
- `POST /admin/notifications/send-test`
- `GET /admin/notifications/history`

## Message Types (Examples)

- `order_status_changed` (customer)
- `assignment_received` (courier, high priority)
- `payment_verified` (customer/admin)
- `support_reply` (customer)
- `broadcast_notice` (role-targeted cohort)

## Priority Conventions

- Courier urgent assignments: high priority + visible blocking behavior in app.
- Informational admin/customer updates: normal priority.

## Cleanup Rules

- On `UNREGISTERED` or `INVALID_ARGUMENT` token errors:
  - Mark token inactive
  - Increment failure counter
  - Optionally delete after threshold

## Envelope Reminder

Success:

```json
{"ok": true, "data": {"message_id": "..." }}
```

Error:

```json
{"ok": false, "code": "FCM_SEND_FAILED", "message": "Push send failed", "details": {"reason": "..."}}
```

