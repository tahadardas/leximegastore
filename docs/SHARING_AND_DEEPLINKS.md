# Sharing And Deeplinks

## Link Standards

### Product Sharing Standard (Primary)

Product links shared from the app use:

`https://leximega.store/product/{id-or-slug}`

Rules:

- No query-based product share URLs.
- Prefer direct product path to avoid browser-first fallback redirects.
- App deep-link routing supports both numeric ids and slugs.

### Canonical Entity Sharing Contract (Non-Product)

Other entity types still use:

`https://leximega.store/s/{type}/{id}`

Supported types:

- `p`: product
- `o`: order
- `i`: invoice
- `c`: category
- `b`: brand
- `t`: support ticket

### SEO Product Links (Direct Universal/App Links)

The app handles website product URLs directly:

`https://leximega.store/product/{id-or-slug}`

When the app is installed, this link opens the app and routes to product
details. If the path segment is a slug, it is resolved to numeric product id
in-app before routing.

## Flutter Implementation

## Share Service

Single share service:

- `lib/shared/services/share_service.dart`

The app uses `share_plus` only.

## Deep Link Service

Deep-link bootstrap:

- `lib/core/deeplink/share_deep_link_service.dart`

Key behavior:

- Handles `/s/{type}/{id}` links.
- Handles `/product/{id-or-slug}` and `/index.php/product/{id-or-slug}` links.
- Waits until first app frame before routing (safe after boot sequence).
- Deduplicates repeated incoming links.
- For private links (`o`, `i`, `t`), stores pending route and redirects to login.
- After authentication, pending route is opened once.

## Product Slug Resolution

Slug resolver route:

- `lib/features/product/presentation/pages/product_deep_link_resolver_page.dart`

Flow:

1. Open `/product/{id-or-slug}`.
2. Resolve slug to numeric id via repository/data source.
3. Navigate to existing `/product/{id}` page.

Data source resolution order:

1. `/wp-json/wc/store/v1/products?slug={slug}`
2. `/wp-json/wp/v2/product?slug={slug}`
3. `/wp-json/lexi/v1/products?search={slug}`

## Android App Links

Manifest:

- `android/app/src/main/AndroidManifest.xml`

`intent-filter` (`android:autoVerify="true"`) now covers:

- `/s/`
- `/index.php/s/`
- `/product/`
- `/index.php/product/`

for both:

- `leximega.store`
- `www.leximega.store`

Digital Asset Links endpoint:

- `https://leximega.store/.well-known/assetlinks.json`

served by:

- `wp-content/plugins/lexi-api/includes/class-android-app-links.php`

Verification commands:

- `adb shell pm verify-app-links --re-verify com.leximegastore.app`
- `adb shell pm get-app-links com.leximegastore.app`

Release SHA256 fingerprint example command:

- `keytool -list -v -keystore <release-keystore.jks> -alias <alias> -storepass <store-pass> -keypass <key-pass>`

## iOS Universal Links

Entitlements:

- `ios/Runner/Runner.entitlements`

Xcode project:

- `ios/Runner.xcodeproj/project.pbxproj`
- `CODE_SIGN_ENTITLEMENTS = Runner/Runner.entitlements` for Debug/Release/Profile.

AASA endpoint:

- `https://leximega.store/apple-app-site-association`
- `https://leximega.store/.well-known/apple-app-site-association`

served by:

- `wp-content/plugins/lexi-api/includes/class-ios-app-links.php`

Important:

- Set real `TEAMID.bundle.id` in WordPress option:
  - `lexi_ios_universal_links_app_ids`
- Default placeholder exists and must be replaced in production.

Validation hint (device/simulator logs):

- `log stream --predicate 'subsystem == "com.apple.swcd"' --info`

## WordPress Fallback

Canonical share fallback handler:

- `wp-content/plugins/lexi-api/includes/class-share-links.php`

`/s/{type}/{id}` behavior:

- Product/category/brand -> public storefront URLs.
- Order/invoice/ticket -> login-protected account pages.

SEO product links `/product/{slug}` remain normal WordPress product permalinks
for devices without app installed.

For direct numeric product URLs (`/product/{id}`), WordPress fallback redirects to
resolved permalink when possible, otherwise to the shop listing.

## Routing Delay And Safety

There is no intermediate browser redirect inside the app path.

Startup behavior:

1. Native OS validates host-path (App Links / Universal Links).
2. App receives URI.
3. DeepLinkService waits until first frame (boot-safe point).
4. Router navigation runs once (deduped).
5. Product slug resolves in-app and forwards to product details page.

## Debugging Checklist

If link opens browser instead of app:

1. Confirm installed app build uses same domain/host as manifest/entitlements.
2. Confirm `https://leximega.store/.well-known/assetlinks.json` is reachable and
   includes production package + SHA256 release fingerprint.
3. Confirm `https://leximega.store/apple-app-site-association` is reachable with
   `Content-Type: application/json`.
4. Confirm no domain mismatch (`www` vs non-`www`) between link and config.
5. Reinstall app after changing manifest/entitlements/association files.
6. On Android, verify domain state:
   - `adb shell pm get-app-links com.leximegastore.app`

## Flow Diagram

`Incoming URL -> DeepLinkService -> (optional login gate) -> slug resolver -> /product/{id} -> ProductDetails`
