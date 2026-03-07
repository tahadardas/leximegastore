# QA Checklist: FCM End-To-End

- [ ] Device token registration works for customer/admin/courier roles.
- [ ] WP sender uses OAuth2 service account with HTTP v1 endpoint.
- [ ] Broadcast notification delivered to intended role cohort only.
- [ ] Targeted notification delivered to selected user/device.
- [ ] In-app inbox increments unread badge on receive.
- [ ] Courier urgent notification triggers blocking popup + system sound.
- [ ] Duplicate notifications are deduplicated client-side.
- [ ] Throttling rules prevent notification spam.
- [ ] `UNREGISTERED` token responses trigger token cleanup.
- [ ] Notification send attempts are audit logged.

