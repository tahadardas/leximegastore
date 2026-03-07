# UI Packages Integration (Noon-like Upgrade)

## Added dependencies

- `carousel_slider`
  - Used for home hero banners and featured products horizontal carousel.
- `flutter_staggered_grid_view`
  - Used only for Offers (`/deals`) listing layout.

## Where `carousel_slider` is used

### 1) Home top banners

- Widget: `BannerCarouselWidget`
- File: `lib/features/home/presentation/widgets/banner_carousel_widget.dart`
- Integrated in: `lib/features/home/presentation/pages/home_page.dart`
- Behavior:
  - Full-width banner with rounded corners.
  - Stable aspect ratio (`16/7`) to prevent layout jumps.
  - Gentle autoplay (`5s`) when multiple banners exist.
  - Dot indicator reflects active slide.
  - Tap callback is delegated to existing navigation/link logic.

### 2) Featured products carousel

- Widget: `FeaturedProductsCarouselWidget`
- File: `lib/features/home/presentation/widgets/featured_products_carousel_widget.dart`
- Integrated in: `lib/features/home/presentation/pages/home_page.dart`
- Behavior:
  - Horizontal product carousel (max 10 items).
  - Reuses `ProductCard` for consistency (single product card source).
  - Responsive viewport fraction for phone/tablet widths.
  - Keeps existing product actions (open product, wishlist, add to cart, share, comment).

## Where `flutter_staggered_grid_view` is used

### Offers page only

- Widget: `OffersMasonryGrid`
- File: `lib/features/product/presentation/widgets/offers_masonry_grid.dart`
- Integrated in: `lib/features/product/presentation/pages/products_listing_page.dart`
  - Activated only when `filterType == ProductsListingFilterType.deals`.
- Behavior:
  - Uses `MasonryGridView.builder`.
  - Responsive columns:
    - 2 columns on phones
    - 3 columns on medium tablets
    - 4 columns on large tablets
  - Supports pagination (appends loading skeleton tiles).
  - Keeps existing action handlers and state-management flow untouched.

## Design and architecture constraints honored

- No app rewrite; only targeted UI refactors.
- No navigation/business logic rewrite.
- RTL remains supported through existing `Directionality` + `EdgeInsetsDirectional` usage.
- Regular product listing grid remains unchanged for better comparison use-cases.
- No glassmorphism global style introduced.
- No `flutter_zoom_drawer` introduced.

## Performance notes

- Carousels are contained widgets with stable heights/aspect ratios to reduce layout shifts.
- Product content still uses existing image/loading stack and card behavior.
- Masonry layout is enabled only on Offers page to avoid global render cost.
- Existing pagination controller and scroll listeners were kept; only UI renderer changed for deals.
