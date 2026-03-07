# Maintenance Baseline Report (2026-03-01)

## Scope
Initial baseline before implementing the maintenance plan for:
- Flutter app (`lib`, `android`)
- WordPress plugin (`wp-content/plugins/lexi-api`)
- Design system consistency checks

## Commands Executed
1. `flutter analyze`
2. `flutter test`
3. `dart run scripts/design_token_lint.dart`

## Results Summary
- `flutter analyze`: **FAILED** (1 issue)
- `flutter test`: **FAILED** (1 failing test)
- `design_token_lint`: **PASSED** (no mixed token imports)

Baseline failure rate across mandatory checks: **2/3 checks failing (66.7%)**.

## Confirmed Issues
1. Analyzer warning:
   - `lib/features/payment/presentation/pages/sham_cash_payment_page.dart:200`
   - `use_build_context_synchronously`
2. Test failure:
   - `test/core/security/app_lock_service_test.dart`
   - Test: `AppLockService - Cooldown & Failure Escalation forces logout after 10 attempts`
   - Expected: `PinVerifyResult.forcedLogout`
   - Actual: `PinVerifyResult.inCooldown`

## Design Lint Hints (Non-blocking)
Hard-coded color/spacing hints were reported in these high-impact files:
- `lib/features/home/presentation/pages/home_page.dart`
- `lib/features/product/presentation/pages/product_page.dart`
- `lib/shared/widgets/product_card.dart`
- `lib/features/orders/presentation/pages/order_status_page.dart`
- Plus additional spacing candidates listed by the lint output.

## Target Files By Phase
### Phase 2 - Flutter/Android security
- `lib/main.dart`
- `android/app/src/main/AndroidManifest.xml`
- `android/app/src/debug/AndroidManifest.xml` (if needed)
- `android/app/src/main/res/xml/network_security_config.xml`

### Phase 3 - WordPress critical security
- `wp-content/plugins/lexi-api/lexi-api.php`
- `wp-content/plugins/lexi-api/includes/class-routes-orders.php`
- `wp-content/plugins/lexi-api/includes/class-routes-checkout.php`
- `wp-content/plugins/lexi-api/includes/class-ai-routes.php`
- `wp-content/plugins/lexi-api/test_cron.php`

### Phase 4 - Arabic encoding cleanup
- `scripts/fix_arabic_mojibake.py`
- `lib/**`
- `wp-content/plugins/lexi-api/**`
- `docs/**`
- `lib/l10n/app_ar.arb`

### Phase 5 - Localization rollout
- `lib/app/app.dart`
- Critical feature pages: login/register/checkout/orders/payment/wishlist/profile/home

### Phase 6 - Stability/tests
- `lib/core/security/app_lock_service.dart`
- `test/core/security/app_lock_service_test.dart`
- `lib/features/payment/presentation/pages/sham_cash_payment_page.dart`
- Wishlist-related plugin/app integration files

### Phase 7 - Design consistency
- `pubspec.yaml`
- Typography/theme files under `lib/design_system/**` and app theme wiring
- High-impact UI files:
  - `lib/features/home/presentation/pages/home_page.dart`
  - `lib/features/product/presentation/pages/product_page.dart`
  - `lib/shared/widgets/product_card.dart`
  - `lib/features/orders/presentation/pages/order_status_page.dart`

## Notes
- This report is the comparison baseline for post-maintenance validation.
- Next step is critical security hardening for Flutter/Android, then WordPress API hardening.
