# Courier Location Tracking

## Purpose

Location is mandatory for courier operations:

- Courier cannot see delivery orders without valid location access and recent location ping.
- Admin can fetch the latest courier location and open navigation directly.

Tracking stores only last known location (no full history table).

## Data Model

Table: `{$wpdb->prefix}lexi_courier_locations` (created by `Lexi_Courier_Locations::create_table()`).

Columns:

- `courier_id` bigint unsigned PK
- `lat` double
- `lng` double
- `accuracy_m` double nullable
- `heading` double nullable
- `speed_mps` double nullable
- `updated_at` datetime (UTC)
- `device_id` varchar(191) nullable

Indexes:

- `PRIMARY KEY (courier_id)` for upsert/last-known record
- `idx_updated_at`
- `idx_device_id`

Stale threshold option:

- WP option key: `lexi_courier_location_stale_minutes`
- Default: `10`
- Clamped range: `1..60`

## API Endpoints

### Courier Ping

`POST /wp-json/lexi/v1/courier/location` (courier auth required)

Body:

- `lat` (required)
- `lng` (required)
- `accuracy` (optional)
- `heading` (optional)
- `speed` (optional)
- `device_id` (optional)

Behavior:

- Validates coordinate presence and range.
- Upserts into `lexi_courier_locations`.
- Optionally logs `location_ping` event in `lexi_order_events`.

Success payload includes:

- coordinates
- `updated_at`
- `maps_navigate_url`

### Admin Find Courier

`GET /wp-json/lexi/v1/admin/couriers/{id}/location` (admin auth required)

Response:

- `courier_id`
- `lat`, `lng`
- `accuracy_m`, `heading`, `speed_mps`
- `updated_at` (UTC), `updated_at_local`
- `age_minutes`
- `is_outdated`
- `stale_after_minutes`
- `maps_navigate_url`
- `maps_open_url`

Navigation URL format:

- `https://www.google.com/maps/dir/?api=1&destination={lat},{lng}&travelmode=driving`

## Mandatory Location Guard (Backend)

Courier orders endpoint:

- `GET /wp-json/lexi/v1/delivery/orders`

Guard behavior before listing orders:

1. If no location record exists -> reject with HTTP `428`
   - code: `courier_location_required`
2. If location exists but older than stale threshold -> reject with HTTP `428`
   - code: `courier_location_stale`

Both errors include metadata like `required_within_minutes` and settings hint.

`GET /delivery/me` includes:

- `location_required`
- `location_stale_after_minutes`
- `has_recent_location`

## Flutter App Behavior

Core service: `CourierLocationTracker` (`geolocator` + Riverpod).

Policy implemented:

- On courier session start, app requests/checks location access.
- If permission denied/services disabled, courier sees blocking "Location Required" UI.
- Courier dashboard/orders are not shown until location state is ready.
- While foreground + authenticated courier + ready:
  - ping interval: every `45` seconds
  - ping endpoint: `POST /courier/location`
- On background, periodic pings stop (foreground-only tracking).

Blocking UI actions:

- Enable location permission
- Open location settings/app settings
- Retry and force ping, then reload courier dashboard

Admin UI:

- "Find Courier" button (`Ijad Al-Mandoub`) on courier reports/cards
- Shows location sheet with:
  - last update timestamp
  - coordinates
  - outdated badge (`Location Outdated`) if stale
  - `Navigate` and `Open Map` actions

## Security and Privacy

- Only admins can query courier location endpoint.
- Courier location is not exposed to customer APIs.
- System stores only latest location per courier.
- Avoid printing raw lat/lng in production logs.

## Test Checklist

1. Courier login with location service OFF:
   - blocked screen appears
   - orders are not fetched.
2. Enable service + permission:
   - location becomes ready
   - pings are sent
   - orders load.
3. Admin "Find Courier":
   - receives latest coordinates
   - navigation links open in maps.
4. Wait past stale threshold:
   - courier orders endpoint returns `courier_location_stale` until new ping.
