# Async Upgrade Audit (2026-03-03)

## Scope
- App: Lexi Mega Store (Flutter)
- Goal: production-safe async upgrade without rewriting architecture
- Explicit non-goal: multi-currency

## Current Architecture
- State management: Riverpod (`Provider`, `StateNotifierProvider`, `AsyncNotifierProvider`, `ChangeNotifierProvider`, `StreamProvider`).
- HTTP layer: centralized `DioClient` with `AuthInterceptor`, retry interceptor, and endpoint auth policy.
- Session/auth:
  - `AppSession` persists tokens and profile.
  - `AuthSessionController` maps session to app auth state.
  - 401/expired-token refresh pipeline through interceptor callback.
- Domain modules rely on repositories + datasources and expose Riverpod providers.

## Existing Async Flows (Before Upgrade)
- Orders:
  - "My Orders" was primarily pull-based and manually refreshed.
  - Order mutation actions (checkout/proof upload) did not always push immediate updates to orders UI source-of-truth.
- Notifications:
  - Old refresh path used controller-level timer polling (60s) and could diverge from screen lifecycle.
- Courier location:
  - Admin location fetch existed as point-in-time fetch; no centralized stream-driven live poll layer.
- Search:
  - Search had cancel tokens/version guards, but debounce behavior needed to be explicit and shared.
- Auth refresh:
  - Interceptor had single-flight behavior, but app-level refresh coordination needed a shared lock service to avoid duplicated refresh attempts across code paths.
- Checkout/ShamCash submit:
  - No centralized submit lock for all critical submit points.

## Polling / Manual Refresh Patterns Found
- `lib/features/notifications/presentation/controllers/notification_controller.dart`
  - Timer-based unread refresh every 60s.
- `lib/features/orders/presentation/pages/order_status_page.dart`
  - Timer-based polling every 20s.
- `lib/features/support/presentation/pages/support_ticket_chat_page.dart`
  - Polling every 6s.
- `lib/features/admin/presentation/controllers/admin_dashboard_controller.dart`
  - Polling every 60s.
- `lib/features/admin/presentation/controllers/admin_intel_controller.dart`
  - Polling every 60s.
- UI-local timers also exist for banners/animations in home/admin screens.

## Weak Points
- Multiple module-specific polling implementations increase lifecycle leak risk.
- UI widgets/controllers had to own refresh logic instead of consuming one stream source.
- No global stale-data contract (cached data + error) across modules.
- Submit race risk on repeated taps (checkout/proof upload).
- Token refresh race risk across interceptor/app session flows.
- Heavy order parsing could happen on UI isolate for larger payloads.

## Upgrade Plan by Module
- Auth:
  - Add app-level single-flight refresher + lock.
  - Keep interceptor retry-once behavior; coalesce parallel refresh requests.
- Payments/Checkout:
  - Add centralized submit locks for checkout and per-order ShamCash upload.
- Search:
  - Standardize debounce with reusable `Debouncer` (300ms).
  - Keep request cancelation/versioning to ignore stale responses.
- Orders realtime:
  - Add `OrdersRealtimeService` with stream snapshots, interval refresh, stale/error states.
  - Trigger immediate refresh after order mutations.
- Notifications realtime:
  - Add `NotificationsRealtimeService` with stream snapshots, unread count stream, optimistic read.
- Courier location realtime (admin):
  - Add per-courier stream service with periodic refresh only while listeners exist.
- Heavy-work offload:
  - Use `compute()` for large order JSON parsing only.

## Implemented Result
- Realtime hub pattern introduced for orders, notifications, and courier location.
- Locks implemented for token refresh and payment submit paths.
- Search debounce stabilized.
- Isolate use limited to heavy parsing threshold to avoid architectural disruption.
- Full `flutter analyze` passes after integration.

