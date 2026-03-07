# Order State Machine Template

## Canonical States

- `pending_review`
- `confirmed`
- `assigned_to_driver`
- `out_for_delivery`
- `delivered`
- `failed`
- `returned`
- `cancelled`

## Payment States

- `unpaid`
- `partial`
- `paid`

## Allowed Transitions

| From | To | Allowed Roles | Notes |
|---|---|---|---|
| `pending_review` | `confirmed` | admin, manager | after stock/verification checks |
| `pending_review` | `cancelled` | admin, manager, support | cancellation reason required |
| `confirmed` | `assigned_to_driver` | admin, courier-manager | assignment TTL required |
| `assigned_to_driver` | `out_for_delivery` | courier | courier must accept assignment |
| `out_for_delivery` | `delivered` | courier | delivery confirmation required |
| `out_for_delivery` | `failed` | courier, admin | failure reason required |
| `failed` | `assigned_to_driver` | admin, courier-manager | retry assignment |
| `delivered` | `returned` | admin, manager | return reason required |
| any non-terminal | `cancelled` | admin, manager | policy-driven cancellation |

Terminal states: `delivered`, `returned`, `cancelled`.

## Guardrails

- Reject invalid transitions with `CONFLICT`.
- Log each transition as immutable event.
- Keep payment state independent from fulfillment state.
- Never hide orders due to payment verification status.

