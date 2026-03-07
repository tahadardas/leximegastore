import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../core/ai/ai_tracker.dart';
import '../../../../core/ai/ai_reco_api.dart';
import '../../../../core/images/image_url_optimizer.dart';
import '../../../../core/logging/app_logger.dart';
import '../../../../core/session/app_session.dart';
import '../../../cart/domain/entities/cart_item.dart';
import '../../../../core/utils/color_swatch_mapper.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/utils/url_utils.dart';
import '../../../../shared/services/share_service.dart';
import '../../../../shared/widgets/product_card.dart';
import '../../../../shared/widgets/error_state.dart';
import '../../../../shared/widgets/lexi_ui/lexi_skeleton.dart';
import '../../../../shared/widgets/lexi_ui/lexi_horizontal_strip_skeleton.dart';
import '../../../../shared/ui/lexi_alert.dart';
import '../../../../shared/widgets/lexi_network_image.dart';
import '../../../../design_system/lexi_tokens.dart';
import '../../../../design_system/lexi_typography.dart';
import '../../../../ui/widgets/lexi_safe_bottom.dart';
import '../../../cart/presentation/controllers/cart_controller.dart';
import '../../../wishlist/presentation/controllers/wishlist_controller.dart';
import '../../domain/entities/product_entity.dart';
import '../../domain/entities/product_extras.dart';
import '../controllers/product_details_controller.dart';
import '../controllers/product_extras_controller.dart'
    hide similarProductsProvider;

class ProductPage extends ConsumerStatefulWidget {
  final int productId;
  final String? heroTag;

  const ProductPage({super.key, required this.productId, this.heroTag});

  @override
  ConsumerState<ProductPage> createState() => _ProductPageState();
}

class _ProductPageState extends ConsumerState<ProductPage> {
  int _imageIndex = 0;
  ProductVariationOption? _selectedVariation;
  final ScrollController _scrollController = ScrollController();
  BuildContext? _reviewsSectionContext;
  final Set<String> _prefetchedGalleryUrls = <String>{};
  bool _didScheduleReviewsFocus = false;

  @override
  void initState() {
    super.initState();
    ref.read(aiTrackerProvider).viewProduct(widget.productId);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(
      productDetailsControllerProvider(widget.productId.toString()),
    );
    final extrasAsync = ref.watch(
      productDetailsExtrasProvider(widget.productId),
    );
    final extras = extrasAsync.valueOrNull ?? const ProductDetailsExtras();
    final wishlistIds = ref.watch(wishlistIdsProvider);
    final isWishlisted = wishlistIds.contains(widget.productId);
    final focusReviews =
        GoRouterState.of(context).uri.queryParameters['focus'] == 'reviews';

    if (focusReviews && !_didScheduleReviewsFocus) {
      _didScheduleReviewsFocus = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _focusReviewsSection();
      });
    }

    if (_selectedVariation == null && extras.variations.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _selectedVariation != null) {
          return;
        }
        setState(() => _selectedVariation = extras.variations.first);
      });
    }

    return Scaffold(
      backgroundColor: LexiColors.neutral50,
      appBar: AppBar(
        title: const Text('تفاصيل المنتج'),
        actions: state.hasValue
            ? [
                IconButton(
                  tooltip: 'مشاركة',
                  onPressed: () => _shareProduct(state.value!),
                  icon: const FaIcon(FontAwesomeIcons.shareNodes, size: 17),
                ),
                IconButton(
                  tooltip: 'المفضلة',
                  onPressed: () async {
                    HapticFeedback.lightImpact();
                    await ref
                        .read(wishlistControllerProvider.notifier)
                        .toggle(widget.productId, product: state.valueOrNull);
                  },
                  icon: FaIcon(
                    isWishlisted
                        ? FontAwesomeIcons.solidHeart
                        : FontAwesomeIcons.heart,
                    size: 17,
                    color: isWishlisted
                        ? LexiColors.error
                        : LexiColors.textPrimary,
                  ),
                ),
                const SizedBox(width: 4),
              ]
            : null,
      ),
      body: state.when(
        data: (product) => _buildContent(product, extrasAsync),
        loading: () => const _ProductPageSkeleton(),
        error: (error, stackTrace) => ErrorState(
          message: 'تعذر تحميل تفاصيل المنتج حالياً.',
          onRetry: () {
            ref.invalidate(
              productDetailsControllerProvider(widget.productId.toString()),
            );
            ref.invalidate(productDetailsExtrasProvider(widget.productId));
            ref.invalidate(similarProductsProvider(widget.productId));
          },
        ),
      ),
      bottomNavigationBar: state.hasValue
          ? _buildStickyActions(state.value!)
          : null,
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Widget _buildContent(
    ProductEntity product,
    AsyncValue<ProductDetailsExtras> extrasAsync,
  ) {
    final extras = extrasAsync.valueOrNull ?? const ProductDetailsExtras();
    final imageList = _resolvedGallery(product, _selectedVariation);
    final selectedPrice = _selectedVariation?.price ?? product.price;
    final selectedRegularPrice =
        _selectedVariation?.regularPrice ?? product.regularPrice;
    final selectedSalePrice =
        _selectedVariation?.salePrice ?? product.salePrice;
    final hasDiscount =
        selectedSalePrice != null && selectedSalePrice < selectedRegularPrice;
    final salePriceValue = selectedSalePrice ?? selectedPrice;
    final effectivePrice = hasDiscount ? salePriceValue : selectedPrice;
    final double savings = hasDiscount
        ? (selectedRegularPrice - salePriceValue)
        : 0.0;
    final similarAsync = ref.watch(similarProductsProvider(widget.productId));
    final bundlesAsync = ref.watch(bundlesProductsProvider(widget.productId));
    final isLoggedIn = ref.watch(appSessionProvider).isLoggedIn;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      _prefetchGalleryImages(imageList);
    });

    return CustomScrollView(
      controller: _scrollController,
      physics: const BouncingScrollPhysics(
        parent: AlwaysScrollableScrollPhysics(),
      ),
      slivers: [
        SliverToBoxAdapter(
          child: _ProductGallery(
            productId: product.id,
            images: imageList,
            initialIndex: _imageIndex,
            onImageChanged: (value) => setState(() => _imageIndex = value),
            discountBadge: hasDiscount
                ? 'خصم ${_discountPercent(selectedRegularPrice, salePriceValue)}%'
                : null,
            heroTag: widget.heroTag,
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.all(LexiSpacing.s12),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              _WhiteBlock(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(product.name, style: LexiTypography.h2),
                    const SizedBox(height: LexiSpacing.s8),
                    Row(
                      children: [
                        const FaIcon(
                          FontAwesomeIcons.solidStar,
                          size: 14,
                          color: LexiColors.warning,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '${product.rating.toStringAsFixed(1)} (${product.reviewsCount} تقييم)',
                          style: LexiTypography.body,
                        ),
                      ],
                    ),
                    const SizedBox(height: LexiSpacing.s12),
                    _PriceCommercialBlock(
                      currentPrice: effectivePrice,
                      regularPrice: selectedRegularPrice,
                      savings: savings,
                      hasDiscount: hasDiscount,
                    ),
                  ],
                ),
              ),
              if (extras.variations.isNotEmpty) ...[
                const SizedBox(height: LexiSpacing.s12),
                _WhiteBlock(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('اختر نوع المنتج', style: LexiTypography.h3),
                      const SizedBox(height: LexiSpacing.s12),
                      Wrap(
                        spacing: LexiSpacing.s12,
                        runSpacing: LexiSpacing.s12,
                        children: extras.variations.where((v) => v.inStock).map(
                          (option) {
                            final selected =
                                _selectedVariation?.id == option.id;
                            return _VariationTile(
                              option: option,
                              selected: selected,
                              onTap: () {
                                setState(() {
                                  _selectedVariation = option;
                                  _imageIndex = 0;
                                });
                              },
                            );
                          },
                        ).toList(),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: LexiSpacing.s12),
              _WhiteBlock(
                child: _TrustSection(
                  currentValue: effectivePrice,
                  freeShippingThreshold: 250000,
                ),
              ),
              const SizedBox(height: LexiSpacing.s12),
              bundlesAsync.when(
                data: (items) {
                  if (items.isEmpty) return const SizedBox.shrink();
                  return Column(
                    children: [
                      _WhiteBlock(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const FaIcon(
                                  FontAwesomeIcons.layerGroup,
                                  color: LexiColors.primaryPurple,
                                  size: 16,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'منتجات قد تعجبك',
                                  style: LexiTypography.h3,
                                ),
                              ],
                            ),
                            const SizedBox(height: LexiSpacing.s12),
                            SizedBox(
                              height: 318,
                              child: ListView.separated(
                                scrollDirection: Axis.horizontal,
                                itemCount: items.length,
                                separatorBuilder: (context, index) =>
                                    const SizedBox(width: LexiSpacing.s8),
                                itemBuilder: (context, index) {
                                  final p = items[index];
                                  final wishlistIds = ref.watch(
                                    wishlistIdsProvider,
                                  );

                                  return SizedBox(
                                    width: 206,
                                    child: ProductCard(
                                      productId: p.id,
                                      heroTag: 'bundle-${p.id}',
                                      name: p.name,
                                      descriptionSnippet:
                                          p.shortDescription.isNotEmpty
                                          ? p.shortDescription
                                          : p.description,
                                      price: CurrencyFormatter.formatAmount(
                                        p.price,
                                      ),
                                      oldPrice: p.hasDiscount
                                          ? CurrencyFormatter.formatAmount(
                                              p.regularPrice,
                                            )
                                          : null,
                                      imageUrls: p.effectiveCardImages,
                                      rating: p.rating,
                                      reviewsCount: p.reviewsCount,
                                      brandName: p.brandName,
                                      onBrandTap: p.brandName.trim().isNotEmpty
                                          ? () {
                                              context.push(
                                                AppRoutePaths.brandProductsFromCard(
                                                  brandName: p.brandName,
                                                  brandId: p.brandId,
                                                ),
                                              );
                                            }
                                          : null,
                                      discountPercent: p.discountPercentage,
                                      isWishlisted: wishlistIds.contains(p.id),
                                      canAddToCart: p.inStock && p.price > 0,
                                      onTap: () =>
                                          context.pushNamedIfNotCurrent(
                                            AppRouteNames.product,
                                            pathParameters: {'id': '${p.id}'},
                                          ),
                                      onShare: () async {
                                        await ShareService.instance
                                            .shareProductById(
                                              productId: p.id,
                                              name: p.name,
                                              priceText:
                                                  CurrencyFormatter.formatAmountOrUnavailable(
                                                    p.price,
                                                  ),
                                            );
                                      },
                                      onComment: () async {
                                        if (!ref
                                            .read(appSessionProvider)
                                            .isLoggedIn) {
                                          await LexiAlert.info(
                                            context,
                                            text:
                                                'يرجى تسجيل الدخول لإضافة تعليق',
                                          );
                                          return;
                                        }
                                        if (!context.mounted) {
                                          return;
                                        }
                                        context.pushNamedIfNotCurrent(
                                          AppRouteNames.product,
                                          pathParameters: {'id': '${p.id}'},
                                          queryParameters: const {
                                            'focus': 'reviews',
                                          },
                                        );
                                      },
                                      wishlistCount: p.wishlistCount,
                                      onWishlistToggle: () async {
                                        await ref
                                            .read(
                                              wishlistControllerProvider
                                                  .notifier,
                                            )
                                            .toggle(p.id, product: p);
                                      },
                                      onAddToCart: () async {
                                        await ref
                                            .read(
                                              cartControllerProvider.notifier,
                                            )
                                            .addItem(
                                              CartItem(
                                                productId: p.id,
                                                name: p.name,
                                                price: p.effectivePrice,
                                                regularPrice:
                                                    p.regularPrice >
                                                        p.effectivePrice
                                                    ? p.regularPrice
                                                    : null,
                                                image:
                                                    p.primaryImageUrl ??
                                                    p.primaryImage,
                                                qty: 1,
                                              ),
                                            );
                                      },
                                    ),
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: LexiSpacing.s12),
                    ],
                  );
                },
                error: (e, s) => const SizedBox.shrink(),
                loading: () => const SizedBox.shrink(),
              ),
              _WhiteBlock(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('الوصف', style: LexiTypography.h3),
                    const SizedBox(height: LexiSpacing.s8),
                    Html(
                      data: product.description.isNotEmpty
                          ? product.description
                          : product.shortDescription,
                      style: {
                        'body': Style(
                          fontFamily: LexiTypography.fontFamily,
                          fontSize: FontSize(14),
                          color: LexiColors.neutral700,
                          lineHeight: LineHeight(1.55),
                          margin: Margins.zero,
                          padding: HtmlPaddings.zero,
                        ),
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: LexiSpacing.s12),
              Builder(
                builder: (context) {
                  _reviewsSectionContext = context;
                  return _WhiteBlock(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                'تقييمات العملاء',
                                style: LexiTypography.h3,
                              ),
                            ),
                            TextButton.icon(
                              onPressed: () =>
                                  _onAddReviewPressed(isLoggedIn: isLoggedIn),
                              icon: FaIcon(
                                isLoggedIn
                                    ? FontAwesomeIcons.commentDots
                                    : FontAwesomeIcons.rightToBracket,
                                size: 12,
                              ),
                              label: Text(
                                isLoggedIn
                                    ? 'أضف تقييمك'
                                    : 'سجّل للدخول للتقييم',
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: LexiSpacing.s8),
                        extrasAsync.when(
                          data: (value) {
                            if (value.reviews.isEmpty) {
                              return Text(
                                'لا توجد تقييمات حتى الآن.',
                                style: LexiTypography.body,
                              );
                            }
                            return Column(
                              children: value.reviews
                                  .map((e) => _ReviewTile(review: e))
                                  .toList(),
                            );
                          },
                          loading: () => const _ReviewsSkeleton(),
                          error: (error, stackTrace) => Text(
                            'تعذر تحميل التقييمات حالياً.',
                            style: LexiTypography.body,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
              const SizedBox(height: LexiSpacing.s12),
              _WhiteBlock(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('منتجات مشابهة', style: LexiTypography.h3),
                    const SizedBox(height: LexiSpacing.s12),
                    similarAsync.when(
                      loading: () => const _SimilarProductsSkeleton(),
                      error: (error, stackTrace) => Text(
                        'تعذر تحميل المنتجات المشابهة حالياً.',
                        style: LexiTypography.body,
                      ),
                      data: (items) {
                        final filtered = items
                            .where((item) => item.id != widget.productId)
                            .toList();
                        if (filtered.isEmpty) {
                          return Text(
                            'لا توجد منتجات مشابهة حالياً.',
                            style: LexiTypography.body,
                          );
                        }

                        final wishlistIds = ref.watch(wishlistIdsProvider);

                        return SizedBox(
                          height: 318,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: filtered.length,
                            separatorBuilder: (context, index) =>
                                const SizedBox(width: LexiSpacing.s8),
                            itemBuilder: (context, index) {
                              final p = filtered[index];
                              return SizedBox(
                                width: 206,
                                child: ProductCard(
                                  productId: p.id,
                                  heroTag: 'similar-${p.id}',
                                  wishlistCount: p.wishlistCount,
                                  name: p.name,
                                  descriptionSnippet:
                                      p.shortDescription.isNotEmpty
                                      ? p.shortDescription
                                      : p.description,
                                  price: CurrencyFormatter.formatAmount(
                                    p.price,
                                  ),
                                  oldPrice: p.hasDiscount
                                      ? CurrencyFormatter.formatAmount(
                                          p.regularPrice,
                                        )
                                      : null,
                                  imageUrls: p.effectiveCardImages,
                                  rating: p.rating,
                                  reviewsCount: p.reviewsCount,
                                  brandName: p.brandName,
                                  onBrandTap: p.brandName.trim().isNotEmpty
                                      ? () {
                                          context.push(
                                            AppRoutePaths.brandProductsFromCard(
                                              brandName: p.brandName,
                                              brandId: p.brandId,
                                            ),
                                          );
                                        }
                                      : null,
                                  discountPercent: p.discountPercentage,
                                  isWishlisted: wishlistIds.contains(p.id),
                                  canAddToCart: p.inStock && p.price > 0,
                                  onTap: () => context.pushNamedIfNotCurrent(
                                    AppRouteNames.product,
                                    pathParameters: {'id': '${p.id}'},
                                  ),
                                  onShare: () async {
                                    await ShareService.instance.shareProductById(
                                      productId: p.id,
                                      name: p.name,
                                      priceText:
                                          CurrencyFormatter.formatAmountOrUnavailable(
                                            p.price,
                                          ),
                                    );
                                  },
                                  onComment: () async {
                                    if (!ref
                                        .read(appSessionProvider)
                                        .isLoggedIn) {
                                      await LexiAlert.info(
                                        context,
                                        text: 'يرجى تسجيل الدخول لإضافة تعليق',
                                      );
                                      return;
                                    }
                                    if (!context.mounted) {
                                      return;
                                    }
                                    context.pushNamedIfNotCurrent(
                                      AppRouteNames.product,
                                      pathParameters: {'id': '${p.id}'},
                                      queryParameters: const {
                                        'focus': 'reviews',
                                      },
                                    );
                                  },
                                  onWishlistToggle: () async {
                                    await ref
                                        .read(
                                          wishlistControllerProvider.notifier,
                                        )
                                        .toggle(p.id, product: p);
                                  },
                                  onAddToCart: () async {
                                    await ref
                                        .read(cartControllerProvider.notifier)
                                        .addItem(
                                          CartItem(
                                            productId: p.id,
                                            name: p.name,
                                            price: p.effectivePrice,
                                            regularPrice:
                                                p.regularPrice >
                                                    p.effectivePrice
                                                ? p.regularPrice
                                                : null,
                                            image:
                                                p.primaryImageUrl ??
                                                p.primaryImage,
                                            qty: 1,
                                          ),
                                        );
                                  },
                                ),
                              );
                            },
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 120),
            ]),
          ),
        ),
      ],
    );
  }

  Widget _buildStickyActions(ProductEntity product) {
    final selectedPrice = _selectedVariation?.price ?? product.price;
    final selectedRegularPrice =
        _selectedVariation?.regularPrice ?? product.regularPrice;
    final selectedSalePrice =
        _selectedVariation?.salePrice ?? product.salePrice;
    final hasDiscount =
        selectedSalePrice != null && selectedSalePrice < selectedRegularPrice;
    final finalPrice = hasDiscount ? selectedSalePrice : selectedPrice;
    final hasPrice = finalPrice > 0;
    final isOutOfStock = _selectedVariation != null
        ? !_selectedVariation!.inStock
        : !product.inStock;
    final isUnavailableForPurchase = isOutOfStock || !hasPrice;

    // --- Cart quantity lookup ---
    final cartState = ref.watch(cartControllerProvider).valueOrNull;
    final cartKey = _selectedVariation != null
        ? '${product.id}_${_selectedVariation!.id}'
        : '${product.id}';
    final cartItem = cartState?.items
        .where((e) => e.cartKey == cartKey)
        .firstOrNull;
    final inCartQty = cartItem?.qty ?? 0;

    return LexiSafeBottom(
      keyboardAware: false,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Container(
          padding: const EdgeInsetsDirectional.fromSTEB(
            LexiSpacing.s12,
            LexiSpacing.s8,
            LexiSpacing.s12,
            LexiSpacing.s8,
          ),
          decoration: BoxDecoration(
            color: LexiColors.white,
            boxShadow: LexiShadows.card,
          ),
          child: Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 50,
                  child: inCartQty > 0
                      ? _buildInlineCounter(inCartQty, cartKey)
                      : ElevatedButton.icon(
                          onPressed: isUnavailableForPurchase
                              ? null
                              : () => _addToCartAndMaybeCheckout(
                                  product: product,
                                  checkoutNow: false,
                                ),
                          icon: const FaIcon(
                            FontAwesomeIcons.cartPlus,
                            size: 14,
                          ),
                          label: const Text('أضف للسلة'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: LexiColors.brandPrimary,
                            foregroundColor: LexiColors.textPrimary,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(
                                LexiRadius.button,
                              ),
                            ),
                          ),
                        ),
                ),
              ),
              const SizedBox(width: LexiSpacing.s8),
              Expanded(
                child: SizedBox(
                  height: 50,
                  child: ElevatedButton.icon(
                    onPressed: isUnavailableForPurchase
                        ? null
                        : () => _addToCartAndMaybeCheckout(
                            product: product,
                            checkoutNow: true,
                          ),
                    icon: const FaIcon(FontAwesomeIcons.bolt, size: 14),
                    label: Text(
                      isOutOfStock
                          ? 'غير متوفر'
                          : !hasPrice
                          ? 'السعر غير متاح'
                          : 'أضف مقابل ${CurrencyFormatter.formatAmount(finalPrice)}',
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: LexiColors.textPrimary,
                      foregroundColor: LexiColors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(LexiRadius.button),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Inline +/- counter for the sticky bottom bar.
  Widget _buildInlineCounter(int qty, String cartKey) {
    return Container(
      decoration: BoxDecoration(
        color: LexiColors.brandPrimary,
        borderRadius: BorderRadius.circular(LexiRadius.button),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          IconButton(
            onPressed: () {
              HapticFeedback.lightImpact();
              ref.read(cartControllerProvider.notifier).decrement(cartKey);
            },
            icon: FaIcon(
              qty == 1 ? FontAwesomeIcons.trashCan : FontAwesomeIcons.minus,
              size: 16,
              color: qty == 1 ? LexiColors.discountRed : LexiColors.textPrimary,
            ),
          ),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 180),
            transitionBuilder: (child, anim) =>
                ScaleTransition(scale: anim, child: child),
            child: Text(
              '$qty',
              key: ValueKey<int>(qty),
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: LexiColors.textPrimary,
              ),
            ),
          ),
          IconButton(
            onPressed: () {
              HapticFeedback.lightImpact();
              ref.read(cartControllerProvider.notifier).increment(cartKey);
            },
            icon: const FaIcon(
              FontAwesomeIcons.plus,
              size: 16,
              color: LexiColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _addToCartAndMaybeCheckout({
    required ProductEntity product,
    required bool checkoutNow,
  }) async {
    HapticFeedback.mediumImpact();

    final selectedPrice = _selectedVariation?.price ?? product.price;
    final selectedRegularPrice =
        _selectedVariation?.regularPrice ?? product.regularPrice;

    if (selectedPrice <= 0) {
      if (mounted) {
        await LexiAlert.warning(
          context,
          text: 'يرجى اختيار نوع المنتج قبل المتابعة.',
        );
      }
      return;
    }
    final cartItem = CartItem(
      productId: product.id,
      variationId: _selectedVariation?.id,
      variationLabel: _selectedVariation?.label,
      name: product.name,
      price: selectedPrice,
      regularPrice: selectedRegularPrice > selectedPrice
          ? selectedRegularPrice
          : null,
      image:
          _selectedVariation?.imageUrl ??
          product.primaryImageUrl ??
          product.primaryImage,
      qty: 1,
    );

    await ref.read(cartControllerProvider.notifier).addItem(cartItem);
    if (!mounted) {
      return;
    }

    if (checkoutNow) {
      context.pushNamedIfNotCurrent(AppRouteNames.checkout);
      return;
    }
  }

  List<String> _resolvedGallery(
    ProductEntity product,
    ProductVariationOption? selectedVariation,
  ) {
    final result = <String>[
      if ((selectedVariation?.imageUrl ?? '').trim().isNotEmpty)
        selectedVariation!.imageUrl!,
      ...product.images,
    ];

    final unique = <String>[];
    final seen = <String>{};
    for (final item in result) {
      final key = item.trim();
      if (key.isEmpty || seen.contains(key)) {
        continue;
      }
      seen.add(key);
      unique.add(key);
    }
    return unique;
  }

  int _discountPercent(double regularPrice, double salePrice) {
    if (regularPrice <= 0 || salePrice >= regularPrice) {
      return 0;
    }
    return (((regularPrice - salePrice) / regularPrice) * 100).round();
  }

  void _shareProduct(ProductEntity product) {
    ShareService.instance.shareProductById(
      productId: product.id,
      name: product.name,
      priceText: CurrencyFormatter.formatAmountOrUnavailable(product.price),
    );
  }

  Future<void> _prefetchGalleryImages(List<String> images) async {
    for (final item in images) {
      if (!mounted) {
        return;
      }
      final normalized = normalizeNullableHttpUrl(item);
      if (normalized == null) {
        continue;
      }
      final optimized = ImageUrlOptimizer.optimize(
        normalized,
        preferWebp: true,
      );
      if (!_prefetchedGalleryUrls.add(optimized)) {
        continue;
      }
      try {
        if (!mounted) {
          return;
        }
        await precacheImage(
          CachedNetworkImageProvider(optimized),
          context,
          onError: (e, st) {
            // Silently handled below — prevents noisy framework error logging.
          },
        );
      } catch (error) {
        AppLogger.warn(
          'فشل prefetch صورة في صفحة المنتج',
          extra: {'path': Uri.tryParse(optimized)?.path ?? optimized},
        );
      }
    }
  }

  Future<void> _onAddReviewPressed({required bool isLoggedIn}) async {
    if (!isLoggedIn) {
      await LexiAlert.confirm(
        context,
        title: 'إزالة من المفضلة؟',
        text: 'سيتم حذف المنتج من قائمة المفضلة لديك.',
        confirmText: 'إزالة المنتج',
        cancelText: 'إلغاء',
        onConfirm: () async {
          if (!mounted) {
            return;
          }
          context.go('/login');
        },
      );
      return;
    }

    await _openAddReviewSheet();
  }

  Future<void> _focusReviewsSection() async {
    if (!mounted) {
      return;
    }
    final reviewsContext = _reviewsSectionContext;
    if (reviewsContext == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _focusReviewsSection();
        }
      });
      return;
    }
    await Scrollable.ensureVisible(
      reviewsContext,
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeOutCubic,
      alignment: 0.06,
    );
  }

  Future<void> _openAddReviewSheet() async {
    final formKey = GlobalKey<FormState>();
    final controller = TextEditingController();
    int rating = 5;
    bool isSubmitting = false;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      showDragHandle: true,
      builder: (context) {
        final viewInsetsBottom = MediaQuery.of(context).viewInsets.bottom;
        return SafeArea(
          top: false,
          child: Padding(
            padding: EdgeInsets.only(bottom: viewInsetsBottom),
            child: StatefulBuilder(
              builder: (context, setSheetState) {
                Future<void> submitReview() async {
                  if (isSubmitting || !formKey.currentState!.validate()) {
                    return;
                  }
                  setSheetState(() => isSubmitting = true);
                  final error = await ref
                      .read(productExtrasApiProvider)
                      .submitReview(
                        productId: widget.productId,
                        rating: rating,
                        review: controller.text,
                      );

                  if (!mounted) {
                    return;
                  }

                  if (error != null) {
                    await LexiAlert.error(
                      this.context,
                      text: 'تعذر إرسال المراجعة حالياً. حاول لاحقاً.',
                    );
                    if (mounted) {
                      setSheetState(() => isSubmitting = false);
                    }
                    return;
                  }

                  Navigator.of(this.context).pop();
                  await LexiAlert.success(
                    this.context,
                    text: 'تم إرسال مراجعتك بنجاح.',
                  );
                  ref.invalidate(
                    productDetailsExtrasProvider(widget.productId),
                  );
                  ref.invalidate(
                    productDetailsControllerProvider(
                      widget.productId.toString(),
                    ),
                  );
                }

                return LexiSafeBottom(
                  keyboardAware: false,
                  child: Container(
                    decoration: const BoxDecoration(
                      color: LexiColors.white,
                      borderRadius: BorderRadius.vertical(
                        top: Radius.circular(LexiRadius.bottomSheet),
                      ),
                    ),
                    padding: const EdgeInsetsDirectional.fromSTEB(
                      LexiSpacing.s16,
                      LexiSpacing.s16,
                      LexiSpacing.s16,
                      LexiSpacing.s16,
                    ),
                    child: Form(
                      key: formKey,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('أضف مراجعة جديدة', style: LexiTypography.h3),
                          const SizedBox(height: LexiSpacing.s12),
                          Row(
                            children: List.generate(5, (index) {
                              final value = index + 1;
                              return IconButton(
                                onPressed: isSubmitting
                                    ? null
                                    : () => setSheetState(() => rating = value),
                                icon: FaIcon(
                                  value <= rating
                                      ? FontAwesomeIcons.solidStar
                                      : FontAwesomeIcons.star,
                                  color: LexiColors.warning,
                                  size: 18,
                                ),
                              );
                            }),
                          ),
                          TextFormField(
                            controller: controller,
                            maxLines: 4,
                            textInputAction: TextInputAction.done,
                            onFieldSubmitted: (_) => submitReview(),
                            decoration: const InputDecoration(
                              labelText: 'اكتب تعليقك عن المنتج',
                              border: OutlineInputBorder(),
                            ),
                            validator: (value) {
                              if ((value ?? '').trim().isEmpty) {
                                return 'يرجى كتابة التعليق';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: LexiSpacing.s16),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: isSubmitting ? null : submitReview,
                              child: isSubmitting
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Text('إرسال'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        );
      },
    );

    controller.dispose();
  }
}

class _ProductGallery extends StatefulWidget {
  final int productId;
  final List<String> images;
  final int initialIndex;
  final String? discountBadge;
  final String? heroTag;
  final ValueChanged<int> onImageChanged;

  const _ProductGallery({
    required this.productId,
    required this.images,
    required this.initialIndex,
    required this.onImageChanged,
    this.discountBadge,
    this.heroTag,
  });

  @override
  State<_ProductGallery> createState() => _ProductGalleryState();
}

class _ProductGalleryState extends State<_ProductGallery> {
  late final PageController _controller;
  int _current = 0;

  @override
  void initState() {
    super.initState();
    _current = widget.initialIndex;
    _controller = PageController(initialPage: _current);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        AspectRatio(
          aspectRatio:
              1.0, // 1:1 perfect square matching most product image uploads
          child: Container(
            color: LexiColors.white,
            child: widget.images.isEmpty
                ? const Center(
                    child: FaIcon(
                      FontAwesomeIcons.image,
                      size: 56,
                      color: LexiColors.neutral300,
                    ),
                  )
                : PageView.builder(
                    controller: _controller,
                    physics: const ClampingScrollPhysics(),
                    dragStartBehavior: DragStartBehavior.down,
                    itemCount: widget.images.length,
                    onPageChanged: (value) {
                      setState(() => _current = value);
                      widget.onImageChanged(value);
                    },
                    itemBuilder: (context, index) {
                      final image = GestureDetector(
                        onTap: () => _openZoomableGallery(context, index),
                        child: LexiNetworkImage(
                          imageUrl: widget.images[index],
                          fit: BoxFit
                              .contain, // Fit tightly inside the 1:1 square
                        ),
                      );

                      if (index == 0) {
                        return Hero(
                          tag:
                              widget.heroTag ??
                              'product-hero-${widget.productId}',
                          child: image,
                        );
                      }
                      return image;
                    },
                  ),
          ),
        ),
        if ((widget.discountBadge ?? '').trim().isNotEmpty)
          Positioned(
            top: LexiSpacing.s16,
            left: LexiSpacing.s16,
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: LexiSpacing.s12,
                vertical: LexiSpacing.s4,
              ),
              decoration: BoxDecoration(
                color: LexiColors.error,
                borderRadius: BorderRadius.circular(LexiRadius.button),
              ),
              child: Text(
                widget.discountBadge!,
                style: LexiTypography.caption.copyWith(
                  color: LexiColors.white,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        if (widget.images.length > 1)
          Positioned(
            left: 0,
            right: 0,
            bottom: LexiSpacing.s12,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(widget.images.length, (index) {
                final active = _current == index;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: active ? 18 : 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: active
                        ? LexiColors.brandPrimary
                        : LexiColors.neutral300,
                    borderRadius: BorderRadius.circular(99),
                  ),
                );
              }),
            ),
          ),
      ],
    );
  }

  void _openZoomableGallery(BuildContext context, int initialIndex) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => _ZoomableGalleryPage(
          images: widget.images,
          initialIndex: initialIndex,
        ),
      ),
    );
  }
}

class _ZoomableGalleryPage extends StatefulWidget {
  final List<String> images;
  final int initialIndex;

  const _ZoomableGalleryPage({
    required this.images,
    required this.initialIndex,
  });

  @override
  State<_ZoomableGalleryPage> createState() => _ZoomableGalleryPageState();
}

class _ZoomableGalleryPageState extends State<_ZoomableGalleryPage> {
  late final PageController _controller;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _controller = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          PageView.builder(
            controller: _controller,
            itemCount: widget.images.length,
            onPageChanged: (index) => setState(() => _currentIndex = index),
            itemBuilder: (context, index) {
              return InteractiveViewer(
                minScale: 0.5,
                maxScale: 4.0,
                child: Center(
                  child: LexiNetworkImage(
                    imageUrl: widget.images[index],
                    fit: BoxFit.contain,
                  ),
                ),
              );
            },
          ),
          Positioned(
            top: 40,
            right: 16,
            child: IconButton(
              icon: const Icon(Icons.close, color: Colors.white, size: 30),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),
          Positioned(
            bottom: 30,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(widget.images.length, (index) {
                final active = _currentIndex == index;
                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: active ? 10 : 6,
                  height: active ? 10 : 6,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: active ? Colors.white : Colors.white24,
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }
}

class _PriceCommercialBlock extends StatelessWidget {
  final double currentPrice;
  final double regularPrice;
  final double savings;
  final bool hasDiscount;

  const _PriceCommercialBlock({
    required this.currentPrice,
    required this.regularPrice,
    required this.savings,
    required this.hasDiscount,
  });

  @override
  Widget build(BuildContext context) {
    final hasPrice = currentPrice > 0;
    final showDiscount =
        hasPrice && hasDiscount && regularPrice > 0 && savings > 0;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(LexiSpacing.s12),
      decoration: BoxDecoration(
        color: LexiColors.neutral50,
        borderRadius: BorderRadius.circular(LexiRadius.card),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            CurrencyFormatter.formatAmountOrUnavailable(currentPrice),
            style: LexiTypography.h1,
          ),
          if (showDiscount) ...[
            const SizedBox(height: LexiSpacing.s4),
            Text(
              CurrencyFormatter.formatAmount(regularPrice),
              style: LexiTypography.body.copyWith(
                color: LexiColors.neutral500,
                decoration: TextDecoration.lineThrough,
                decorationThickness: 1.6,
              ),
            ),
            const SizedBox(height: LexiSpacing.s4),
            Row(
              children: [
                Text(
                  'وفّر ${CurrencyFormatter.formatAmount(savings)}',
                  style: LexiTypography.body.copyWith(
                    color: LexiColors.success,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(width: LexiSpacing.s8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: LexiSpacing.s8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: LexiColors.error,
                    borderRadius: BorderRadius.circular(LexiRadius.button),
                  ),
                  child: Text(
                    'خصم',
                    style: LexiTypography.caption.copyWith(
                      color: LexiColors.white,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
          ],
          if (!hasPrice) ...[
            const SizedBox(height: LexiSpacing.s8),
            Text(
              'السعر غير متاح حالياً، قد يتغير بعد اختيار نوع المنتج أو الكمية.',
              style: LexiTypography.caption.copyWith(
                color: LexiColors.neutral500,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _VariationTile extends StatelessWidget {
  final ProductVariationOption option;
  final bool selected;
  final VoidCallback? onTap;

  const _VariationTile({
    required this.option,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorName = _extractColorName(option);
    final swatchColor = _mapSwatchColor(colorName);
    final isUnknownColor = swatchColor == null;
    final displayColor = swatchColor ?? LexiColors.neutral300;
    final contrastColor = displayColor.computeLuminance() > 0.55
        ? LexiColors.textPrimary
        : LexiColors.white;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(LexiRadius.button),
      child: SizedBox(
        width: 56,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Opacity(
              opacity: option.inStock ? 1 : 0.4,
              child: AnimatedScale(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOut,
                scale: selected ? 1.05 : 1,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOut,
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: displayColor,
                    border: Border.all(
                      color: selected
                          ? LexiColors.brandPrimary
                          : LexiColors.neutral300,
                      width: selected ? 2.5 : 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: LexiColors.brandBlack.withValues(alpha: 0.08),
                        blurRadius: 8,
                        offset: Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      if (isUnknownColor)
                        Center(
                          child: Text(
                            _initialLetter(colorName),
                            style: LexiTypography.caption.copyWith(
                              color: contrastColor,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      if (!option.inStock)
                        Center(
                          child: Transform.rotate(
                            angle: -0.78,
                            child: Container(
                              width: 46,
                              height: 2,
                              decoration: BoxDecoration(
                                color: LexiColors.error,
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              colorName,
              maxLines: 1,
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              style: LexiTypography.caption.copyWith(
                fontSize: 11,
                color: LexiColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _extractColorName(ProductVariationOption option) {
  final base = option.color.trim().isNotEmpty
      ? option.color.trim()
      : option.label.trim();
  if (base.isEmpty) {
    return 'لون';
  }

  final lower = base.toLowerCase();
  if (!lower.contains('color') && !lower.contains('لون')) {
    return base;
  }

  if (base.contains(':')) {
    final afterColon = base.split(':').last.trim();
    if (afterColon.isNotEmpty) {
      return afterColon;
    }
  }

  final cleaned = base
      .replaceAll(RegExp('color', caseSensitive: false), '')
      .replaceAll('لون', '')
      .replaceAll(':', '')
      .trim();
  return cleaned.isEmpty ? base : cleaned;
}

Color? _mapSwatchColor(String rawName) {
  return ColorSwatchMapper.map(rawName);
}

String _initialLetter(String text) {
  final value = text.trim();
  if (value.isEmpty) {
    return '?';
  }
  return value.substring(0, 1).toUpperCase();
}

class _TrustSection extends StatelessWidget {
  final double currentValue;
  final double freeShippingThreshold;

  const _TrustSection({
    required this.currentValue,
    required this.freeShippingThreshold,
  });

  @override
  Widget build(BuildContext context) {
    final progress = (currentValue / freeShippingThreshold)
        .clamp(0, 1)
        .toDouble();
    final left = (freeShippingThreshold - currentValue).clamp(
      0,
      double.infinity,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _TrustBadge(
              icon: FontAwesomeIcons.shieldHalved,
              text: 'دفع آمن 100%',
            ),
          ],
        ),
        const SizedBox(height: LexiSpacing.s12),
        Text(
          'شحن مجاني فوق ${CurrencyFormatter.formatAmount(freeShippingThreshold)}',
          style: LexiTypography.title.copyWith(fontSize: 13),
        ),
        const SizedBox(height: LexiSpacing.s8),
        ClipRRect(
          borderRadius: BorderRadius.circular(99),
          child: LinearProgressIndicator(
            minHeight: 8,
            value: progress,
            color: LexiColors.success,
            backgroundColor: LexiColors.neutral200,
          ),
        ),
        const SizedBox(height: LexiSpacing.s8),
        Text(
          left <= 0
              ? 'ممتاز! أنت مؤهل الآن للشحن المجاني.'
              : 'أضف بقيمة ${CurrencyFormatter.formatAmount(left)} لتحصل على شحن مجاني.',
          style: LexiTypography.caption,
        ),
      ],
    );
  }
}

class _TrustBadge extends StatelessWidget {
  final IconData icon;
  final String text;

  const _TrustBadge({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: LexiSpacing.s8,
          vertical: LexiSpacing.s8,
        ),
        decoration: BoxDecoration(
          color: LexiColors.neutral50,
          borderRadius: BorderRadius.circular(LexiRadius.button),
          border: Border.all(color: LexiColors.neutral200),
        ),
        child: Row(
          children: [
            FaIcon(icon, size: 12, color: LexiColors.textPrimary),
            const SizedBox(width: LexiSpacing.s8),
            Expanded(
              child: Text(
                text,
                style: LexiTypography.caption.copyWith(
                  color: LexiColors.textPrimary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WhiteBlock extends StatelessWidget {
  final Widget child;

  const _WhiteBlock({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(LexiSpacing.s12),
      decoration: BoxDecoration(
        color: LexiColors.white,
        borderRadius: BorderRadius.circular(LexiRadius.card),
        boxShadow: LexiShadows.card,
      ),
      child: child,
    );
  }
}

class _ReviewTile extends StatelessWidget {
  final ProductReviewItem review;

  const _ReviewTile({required this.review});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: LexiSpacing.s8),
      padding: const EdgeInsets.all(LexiSpacing.s12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(LexiRadius.button),
        border: Border.all(color: LexiColors.neutral200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  review.author.isEmpty ? 'عميل' : review.author,
                  style: LexiTypography.title,
                ),
              ),
              Row(
                children: List.generate(5, (index) {
                  final active = index < review.rating;
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 1),
                    child: FaIcon(
                      active
                          ? FontAwesomeIcons.solidStar
                          : FontAwesomeIcons.star,
                      size: 11,
                      color: LexiColors.warning,
                    ),
                  );
                }),
              ),
            ],
          ),
          const SizedBox(height: LexiSpacing.s8),
          Text(review.content, style: LexiTypography.body),
        ],
      ),
    );
  }
}

class _ProductPageSkeleton extends StatelessWidget {
  const _ProductPageSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(LexiSpacing.s12),
      children: [
        const LexiSkeleton(height: 340, borderRadius: LexiRadius.card),
        const SizedBox(height: LexiSpacing.s12),
        ...List.generate(4, (_) {
          return const Padding(
            padding: EdgeInsets.only(bottom: LexiSpacing.s12),
            child: LexiSkeleton(height: 110, borderRadius: LexiRadius.card),
          );
        }),
      ],
    );
  }
}

class _ReviewsSkeleton extends StatelessWidget {
  const _ReviewsSkeleton();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(2, (_) {
        return const Padding(
          padding: EdgeInsets.only(bottom: LexiSpacing.s8),
          child: LexiSkeleton(height: 82, borderRadius: LexiRadius.button),
        );
      }),
    );
  }
}

class _SimilarProductsSkeleton extends StatelessWidget {
  const _SimilarProductsSkeleton();

  @override
  Widget build(BuildContext context) {
    return const LexiHorizontalStripSkeleton(height: 318, itemWidth: 206);
  }
}
