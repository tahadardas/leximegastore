# Operational Workflows

## Order Lifecycle

Canonical states:

- `pending_review`
- `confirmed`
- `assigned_to_driver`
- `out_for_delivery`
- `delivered`
- `failed`
- `returned`
- `cancelled`

Payment states:

- `unpaid`
- `partial`
- `paid`

Rules:

- Separate fulfillment status from payment status.
- Every transition writes an immutable event to `order_events`.
- Transition requires actor role and permission check.

## Payment Workflows

### COD

- Allow full/partial collection.
- Write each collection or adjustment to payment ledger.
- Require actor attribution for overrides.

### ShamCash

- Canonical method ID: `shamcash`.
- Store proof reference, verify with admin decision workflow.
- Expose order visibility regardless of verification outcome.

## Courier Assignment Workflow

- Assignments include TTL.
- Expired assignment returns order to assignment queue.
- Assignment changes always emit events and notifications.

## Notification Workflow

- Store device token registrations by user + platform.
- Send typed notifications per role (customer/admin/courier).
- Handle FCM `UNREGISTERED` by token cleanup.

## Remote App Config Workflow

- Edit draft config in admin console.
- Validate schema before publish.
- Publish as new version with metadata.
- Support rollback to previous known-good version.
- Serve config with `ETag`; return `304` when unchanged.

