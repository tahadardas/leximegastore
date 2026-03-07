# Postman Usage

## Files
- `postman/Lexi_Mega_Store_API.postman_collection.json`
- `postman/Lexi_Mega_Store_API.postman_environment.json`
- `postman/Lexi_Firebase_Notifications.postman_collection.json`

## Import Steps
1. Open Postman.
2. Import both files.
3. Select environment: `Lexi Mega Store - Environment`.
4. Run `Auth > Login` first.
5. The collection test script will auto-fill:
   - `access_token`
   - `refresh_token`

## Notes
- `Auth > Register` now generates a unique email/username automatically each run.
- Protected endpoints need `Bearer {{access_token}}`.
- For customer notifications as guest, provide `device_id`.
- Base URL is configurable via `base_url`.
- Orders endpoints (`lookup`, `track`, `by-phone`) are configured as `POST` in this collection.
- Firebase collection includes:
  - device token registration
  - Firebase settings get/save
  - send campaign with deep-link/image/open mode
  - campaigns history + delivery metrics
