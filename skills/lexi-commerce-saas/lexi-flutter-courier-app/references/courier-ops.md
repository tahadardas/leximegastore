# Courier Ops Reference

## Core Flow

1. Login and location permission check.
2. Receive assignment with TTL.
3. Accept/reject assignment.
4. Navigate to destination.
5. Mark out for delivery.
6. Mark delivered.
7. Submit COD collection if required.

## Offline Queue

- Queue mutating actions with idempotency key.
- Replay in order when online.
- Mark action success/failure with explicit UI feedback.

## Urgent Alerts

- High-priority assignment update should:
  - trigger system notification sound
  - show blocking in-app popup
  - provide immediate action buttons

## Safety Checks

- Do not show stale assignment as active after TTL expiry.
- Do not allow delivery completion without accepted assignment.
- Do not suppress backend conflict errors.

