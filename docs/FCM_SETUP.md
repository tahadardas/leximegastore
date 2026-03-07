# FCM Setup (Flutter + WordPress)

This project uses Firebase Cloud Messaging with:
- Flutter receive flow (`firebase_core`, `firebase_messaging`)
- WordPress sender flow via FCM HTTP v1 + Service Account OAuth2
- No legacy FCM server key delivery path

## 1) Flutter App Setup

### Dependencies
Already present in `pubspec.yaml`:
- `firebase_core`
- `firebase_messaging`

### Android Setup
- Ensure `android/app/google-services.json` exists.
- Ensure Google Services plugin is enabled:
  - `android/settings.gradle.kts`
  - `android/app/build.gradle.kts`
- `AndroidManifest.xml` must include:
  - `android.permission.POST_NOTIFICATIONS`
  - FCM default metadata:
    - `com.google.firebase.messaging.default_notification_icon`
    - `com.google.firebase.messaging.default_notification_channel_id`

### Runtime Flow
`lib/core/notifications/firebase_push_service.dart` handles:
- `Firebase.initializeApp()`
- Permission request (`FirebaseMessaging.requestPermission` and Android notification runtime permission)
- Token fetch + refresh
- Handlers:
  - `FirebaseMessaging.onMessage`
  - `FirebaseMessaging.onMessageOpenedApp`
  - `FirebaseMessaging.instance.getInitialMessage()`

### Device Registration Contract
App registers token to:
- `POST /wp-json/lexi/v1/devices/register`

Payload sent by app includes:
- `token` (also `fcm_token` for backward compatibility)
- `device_id`
- `platform`
- `role`
- `user_id` (when available)
- `guest_id` (fallback for guests)

## 2) WordPress lexi-api Setup

## Required `wp-config.php` constants

Add these constants:

```php
define('LEXI_FCM_PROJECT_ID', 'your-firebase-project-id');
define('LEXI_FCM_SERVICE_ACCOUNT_PATH', '/absolute/path/outside/webroot/service-account.json');
```

Important:
- Store service-account JSON outside public web root.
- Path must be readable by PHP runtime.

## Sender Implementation

`wp-content/plugins/lexi-api/includes/class-push.php` now sends with:
- Endpoint: `https://fcm.googleapis.com/v1/projects/{PROJECT_ID}/messages:send`
- OAuth2 access token from service account using:
  1. `google/auth` (`ServiceAccountCredentials`) if installed
  2. Manual JWT assertion fallback if composer library is unavailable

## Token Registry

`POST /lexi/v1/devices/register` upserts token records with:
- `fcm_token`
- `device_id`
- `platform`
- `user_id`
- `role`
- timestamps (`last_seen_at`, `updated_at`)

Behavior:
- Same `device_id` updates existing token row
- Same token on another row is deduplicated

## Cleanup + Error Handling

On FCM v1 failures:
- `UNREGISTERED` token is deleted from registry
- Failures are logged through `error_log` with context (`order_id`, `user_id`, `target`, token suffix)

## 3) Recommended Verification

1. Login on app, ensure token registration succeeds via `/devices/register`.
2. Trigger admin notify endpoint to user/courier/order.
3. Verify push arrival:
   - Foreground
   - Background
   - Cold-start tap routing
4. Verify invalid token cleanup by sending to a stale token and checking registry removal.

