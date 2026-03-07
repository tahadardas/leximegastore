# Locks / Mutex Points

## Objective
Prevent duplicate critical operations and race conditions in production flows.

## 1) Token Refresh Single-Flight

### App-level refresher
- File: `lib/core/auth/auth_token_refresher.dart`
- Mechanism:
  - `Lock _lock`
  - shared `_inFlight` future
- Behavior:
  - first caller starts refresh
  - concurrent callers await the same future
  - `_inFlight` cleared on completion

### Session-level refresh lock
- File: `lib/core/session/app_session.dart`
- Mechanism:
  - `Lock _refreshLock`
  - `_refreshInFlight` future
- Behavior:
  - ensures only one actual refresh HTTP call at a time even if called from multiple code paths

### Interceptor single-flight
- File: `lib/core/network/auth_interceptor.dart`
- Mechanism:
  - `_refreshCompleter`
- Behavior:
  - coalesces parallel 401 refresh attempts before retrying requests once

## 2) Payment Submit Locks

### Central submit lock service
- File: `lib/core/locks/submit_locks.dart`
- Lock points:
  - checkout lock (`_checkoutLock`)
  - per-order ShamCash proof lock map (`_proofLocksByOrder`)

### Checkout submit protection
- File: `lib/features/checkout/presentation/controllers/checkout_controller.dart`
- Behavior:
  - `placeOrder` wrapped in `runCheckoutSubmit`
  - duplicate taps while in flight are ignored

### ShamCash proof upload protection
- File: `lib/features/payment/presentation/pages/sham_cash_payment_page.dart`
- Behavior:
  - upload wrapped in `runShamCashProofUpload(orderId: ...)`
  - duplicate upload taps for same order are ignored and user is informed

## 3) Realtime Refresh Serialization
- Files:
  - `orders_realtime_service.dart`
  - `notifications_realtime_service.dart`
  - `courier_location_realtime_service.dart` (per-courier lock)
- Behavior:
  - avoids overlapping poll refreshes and inconsistent snapshot ordering.

## Result
- No parallel token refresh storm.
- No duplicate checkout/proof submissions from repeated taps.
- Reduced risk of race-driven UI inconsistencies.

