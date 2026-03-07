# Streams Upgrade

## Overview
Implemented HTTP-poll + stream fanout services as "single source of truth" for:
- Orders
- Notifications
- Courier location (admin)

Each service emits a snapshot model with:
- current data
- loading flag
- stale flag (cached data shown after refresh failure)
- error
- updated timestamp

## Orders Stream
- Service: `lib/features/orders/data/realtime/orders_realtime_service.dart`
- Provider:
  - `ordersRealtimeServiceProvider`
  - `ordersStreamProvider` (`StreamProvider.autoDispose`)
  - `ordersRealtimeBootstrapProvider`
- Interval: `45s` (`defaultInterval`)
- Fetch behavior:
  - pulls first page (`perPage: 50`)
  - sorts newest first by order date
- Mutation hooks:
  - checkout success triggers `notifyOrderMutation()`
  - ShamCash proof upload success triggers `notifyOrderMutation()`
- Lifecycle:
  - timer starts on first stream listener
  - timer stops when no listeners
  - bootstrap primes on login and clears on logout

## Notifications Stream
- Service: `lib/features/notifications/data/notifications_realtime_service.dart`
- Provider:
  - `notificationsRealtimeServiceProvider`
  - `notificationsStreamProvider`
  - `notificationsUnreadCountStreamProvider`
  - `notificationsRealtimeBootstrapProvider`
- Interval: `45s`
- Fetch behavior:
  - customer notifications always fetched when logged in
  - admin notifications fetched only for admin users
- Optimistic updates:
  - mark single notification read (customer/admin) updates local stream first
  - mark all read updates local stream first
  - falls back to hard refresh on API failure
- Lifecycle:
  - timer active only while listeners exist
  - bootstrap prime on login, clear on logout

## Courier Location Stream (Admin)
- Service: `lib/features/admin/data/realtime/courier_location_realtime_service.dart`
- Provider:
  - `courierLocationRealtimeServiceProvider`
  - `courierLocationStreamProvider(courierId)`
- Interval: `12s` while courier detail stream is observed
- Behavior:
  - per-courier stream entry
  - per-courier lock to serialize refresh calls
  - stale snapshot on fetch failure when last known location exists
- Lifecycle:
  - per-courier timer starts on first listener
  - per-courier timer stops when no listeners
  - all timers/controllers disposed with provider lifecycle

## UI Consumption Changes
- My Orders screen now consumes stream-backed controller state and shows stale banner.
- Notification badge now consumes unread stream count.
- Notifications page consumes stream snapshots and optimistic read mutations.
- Admin courier reports page "Find Courier" modal consumes live location stream.

## Lifecycle Safety Rules Applied
- Broadcast stream controllers with `onListen/onCancel`.
- Timers created lazily and canceled when no listeners.
- All services call `dispose()` via `ref.onDispose`.
- Refresh operations serialized with `Lock` to avoid overlapping fetch races.

