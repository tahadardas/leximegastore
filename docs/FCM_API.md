# FCM API (lexi-api)

Base namespace: `/wp-json/lexi/v1`

## 1) Register Device Token

Endpoint:
- `POST /devices/register`

Alias (backward compatibility):
- `POST /notifications/register-token`

Auth:
- Logged-in users: token is linked to current authenticated user.
- Guests: allowed when `device_id` or `guest_id` is provided.

Request JSON:

```json
{
  "token": "FCM_TOKEN",
  "fcm_token": "FCM_TOKEN",
  "platform": "android",
  "device_id": "device-uuid",
  "guest_id": "guest-device-id",
  "user_id": 123,
  "role": "customer"
}
```

Notes:
- `token` and `fcm_token` are both accepted.
- `user_id` from guest payload is ignored; authenticated identity is authoritative.
- `role` is normalized/stored with token metadata.

Success response:

```json
{
  "success": true,
  "data": {
    "message": "Device token registered successfully.",
    "token": {
      "id": 1,
      "user_id": 123,
      "role": "customer",
      "device_id": "device-uuid",
      "platform": "android"
    }
  }
}
```

## 2) Admin Send to User

Endpoint:
- `POST /admin/notify/user`

Auth:
- Admin only (`manage_woocommerce`)

Request JSON:

```json
{
  "user_id": 123,
  "title": "عنوان",
  "body": "نص الإشعار",
  "audience": "customer",
  "type": "manual",
  "open_mode": "in_app",
  "deep_link": "/orders",
  "priority": "normal",
  "data": {
    "type": "manual",
    "order_id": "123"
  }
}
```

## 3) Admin Send to Courier

Endpoint:
- `POST /admin/notify/courier`

Auth:
- Admin only

Request JSON:

```json
{
  "courier_id": 45,
  "title": "مهمة جديدة",
  "body": "لديك تحديث جديد",
  "type": "courier_manual",
  "open_mode": "in_app",
  "deep_link": "/delivery",
  "data": {
    "type": "courier_assignment"
  }
}
```

## 4) Admin Send by Order Target

Endpoint:
- `POST /admin/notify/order`

Auth:
- Admin only

Request JSON:

```json
{
  "order_id": 123,
  "target": "customer",
  "title": "تحديث الطلب",
  "body": "تم تحديث حالة طلبك",
  "type": "order_update",
  "open_mode": "in_app",
  "deep_link": "/orders/status?order_number=123",
  "data": {
    "type": "order_update"
  }
}
```

`target` values:
- `customer`: resolves to order customer user, else order device ID
- `courier`: resolves to assigned courier from `_lexi_delivery_agent_id`
- `admin`: sends to all admin/shop-manager tokens

## 5) Sender Behavior

All admin notify endpoints call FCM HTTP v1 sender and return:
- `targeted_count`
- `push_success`
- `push_failed`
- `provider_status`
- `provider_error`

If FCM responds with `UNREGISTERED`, token is deleted from `lexi_push_tokens`.

