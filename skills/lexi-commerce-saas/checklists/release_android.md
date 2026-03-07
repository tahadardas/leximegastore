# Android Release Checklist

- [ ] Update app version and build number.
- [ ] Confirm minify/shrink settings are intentionally configured for release.
- [ ] Verify required permissions only (remove unused permissions).
- [ ] Validate FCM configuration (`google-services.json`, channels, handlers).
- [ ] Run smoke tests on RTL layouts across key screens.
- [ ] Confirm remote config fallback behavior when API unavailable.
- [ ] Verify crash reporting and logging keys by environment.
- [ ] Execute E2E: COD, ShamCash, courier assignment, and order tracking.
- [ ] Ensure no debug endpoints or verbose logs are enabled in production.
- [ ] Record release notes and rollback plan.

