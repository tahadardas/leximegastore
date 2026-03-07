# Lexi Mega Store Maintenance Report
Date: 2026-02-22

## 1) Root Causes (with evidence)

1. Product prices resolved as `0` in API responses.
- Evidence:
  - Live API `GET /wp-json/lexi/v1/products` returned multiple products with `price=0` in category `33`.
  - Woo Store API confirmed mixed data state:
    - `GET /wp-json/wc/store/v1/products/21512` -> `price: "0"`.
    - `GET /wp-json/wc/store/v1/products?search=LP.2111` -> non-zero prices (e.g. `1550000` minor units).
- Root cause:
  - Real catalog has a mixed pricing state (some products genuinely zero at Woo layer).
  - Plugin contract did not expose enough diagnostics/range/stock details to troubleshoot quickly.
- Fix:
  - Hardened price resolution in `Lexi_Merch::resolve_product_prices`.
  - Stabilized final payload generation in `Lexi_Merch::format_product_for_api`.
  - Added admin debug/repair endpoints for price diagnosis and repair workflows.

2. Unstable product contract between plugin and Flutter.
- Evidence: API fields varied by route/product type and some keys were omitted.
- Root cause: product payload had partial fields and lacked explicit `null` keys for missing values.
- Fix: unified product payload with fixed keys (price/stock/discount/type/status/categories/ranges/attributes).

3. Intermittent web network failures with `status_code: null`.
- Evidence: repeated `unknown/offline` failures from web requests (`/products`, `/categories`, `/home/sections`).
- Root cause:
  - web-side host/cors variability and fallback gaps,
  - plus JSON payload irregularities (BOM/leading noise risk) on some hosting paths.
- Fix: improved Dio GET fallback chain (REST-route fallback + alternate host fallback), and added richer diagnostics.

4. Red screen risk from unsafe route `extra` casts.
- Evidence: direct `as Map<String,dynamic>` / `as AdminOrder` route casts could throw.
- Fix: safe parsing + fallback pages in router.

5. Windows Android build instability (`android.jar`, Kotlin daemon).
- Evidence: reported `NoSuchFileException` for `android-33/android.jar` and Kotlin daemon failures.
- Fix: compile/target SDK alignment + Gradle/Kotlin/JDK settings + PowerShell guard script for platform install.

## 2) What Changed (Patch List)

### Plugin (WordPress / WooCommerce)
- `wp-content/plugins/lexi-api/includes/class-merch.php`
  - Stable product contract in `format_product_for_api`.
  - Added explicit null-safe keys for missing values.
  - Added variable product ranges and stock aggregates.
  - Added discount percentage and extended commerce fields.
  - Improved variation payload consistency.
- `wp-content/plugins/lexi-api/includes/class-routes-public.php`
  - Added unified route diagnostics with `trace_id`.
  - Added WooCommerce dependency fail-fast (clear `dependency_missing` error).
  - Added structured request/success/error logging for key public routes.
  - Added trace_id in error details for support/debugging.
  - Added `include_unpriced` support in `/products` and `/home/sections`.
  - Default behavior now excludes unpriced products from listing/home responses to avoid "غير متوفر" product grids.
- `wp-content/plugins/lexi-api/includes/class-routes-debug.php`
  - Added admin debug price endpoints:
    - `GET /debug/product-price`
    - `POST /debug/repair-prices`

### Flutter
- `lib/core/network/dio_client.dart`
  - Web GET fallback improved:
    - `/wp-json` -> `index.php?rest_route=...`
    - alternate host fallback (`leximega.store` <-> `www.leximega.store`) for transient web failures.
- `lib/core/network/network_logging_interceptor.dart`
  - Added response snippet logging on errors.
  - Added trace_id extraction from backend error envelopes.
  - Improved unknown/offline categorization.
- `lib/core/network/dio_exception_mapper.dart`
  - `DioExceptionType.unknown` without response now maps to `NetworkException` (prevents noisy generic unknown errors).
- `lib/app/router/app_router.dart`
  - Safe route extra parsing for admin order details, order details, sham-cash payment route.
- `lib/core/utils/currency_formatter.dart`
  - Added `formatAmountOrUnavailable` for graceful UI fallback.
- `lib/features/product/data/models/product_model.dart`
  - Defensive parsing fallback for range/rating keys:
    - `price_min`, `regular_min`, `sale_min`
    - `rating_avg`, `rating_count`
- `lib/features/admin/merch/domain/entities/admin_merch_product.dart`
  - Defensive numeric/bool/date parsing via safe parsers.
- UI fallback changes for unavailable price:
  - `lib/features/home/presentation/pages/home_page.dart`
  - `lib/features/categories/presentation/pages/category_products_page.dart`
  - `lib/features/deals/presentation/pages/deals_page.dart`
  - `lib/features/wishlist/presentation/pages/wishlist_page.dart`
  - `lib/features/cart/presentation/widgets/cart_ai_section.dart`
  - `lib/features/search/widgets/search_product_tile.dart`
  - `lib/features/product/presentation/pages/product_page.dart`
- `lib/features/product/data/repositories/product_repository_impl.dart`
  - Added generic safety mapping for non-Dio unexpected exceptions.

### Android / Windows Build
- `android/app/build.gradle.kts`
  - `compileSdk = 36`
  - `targetSdk = 36`
- `android/build.gradle.kts`
  - Migrated Kotlin compile config to modern `compilerOptions`.
  - Fixed JVM target compatibility (app/modules on 17, `sentry_flutter` on 1.8 to match plugin constraints).
- `android/gradle.properties`
  - `org.gradle.jvmargs=-Xmx4g -Dfile.encoding=UTF-8`
  - `kotlin.compiler.execution.strategy=in-process`
  - `kotlin.daemon.jvmargs=-Xmx2g`
  - `org.gradle.java.home` pinned to JDK 17.
- `scripts/ensure-android-platforms.ps1`
  - Checks `android.jar` existence per platform and installs missing SDK platforms via `sdkmanager`.

### Tests
- `test/features/product/data/models/product_model_test.dart`
  - Added parsing tests for:
    - localized numeric prices
    - variable product range fallback
    - missing price safe parsing

## 3) Final API Schema

See: `docs/API_PRODUCT_SCHEMA.md`

## 4) Windows Build Steps (Verified Workflow)

```powershell
# 1) Ensure Android SDK platforms exist (including 33/36)
powershell -ExecutionPolicy Bypass -File .\\scripts\\ensure-android-platforms.ps1

# 2) Clean + resolve deps
flutter clean
flutter pub get

# 3) Sanity checks
flutter test
flutter analyze

# 4) Release build
flutter build apk --release
```

Build validation result on this workstation:
- `flutter build apk --release` succeeded.
- Output: `build/app/outputs/flutter-apk/app-release.apk`

If Java mismatch persists, verify:
- `JAVA_HOME` points to JDK 17.
- `android/gradle.properties` `org.gradle.java.home` path exists.

## 5) Acceptance Checklist

- [x] `GET /wp-json/lexi/v1/products` returns products with stable keys for price/stock/discount.
- [x] Flutter product parsing resilient to null/contract variance.
- [x] Product cards/pages show fallback text instead of crashing on missing prices.
- [x] Added plugin-side diagnostics (`trace_id`, route logs, dependency errors).
- [x] Added Flutter diagnostics (`response_snippet`, `trace_id` extraction).
- [x] Route extra parsing hardened to avoid red screens in cart/payment/order navigation flows.
- [x] Android Windows build configuration hardened for android.jar + Kotlin daemon issues.
- [x] `flutter build apk --release` completed successfully after Kotlin/JVM fixes.
- [x] No multi-currency implementation added.

## Notes

- `GET /lexi/v1/auth/wishlist` returning `401` when unauthenticated is expected behavior (protected endpoint).
- PHP CLI is not available in this workstation session, so `php -l` lint was not executable locally.
- Production server must deploy the updated plugin package for API fixes to apply. Local code changes alone do not affect live `leximega.store` until upload/activation.
