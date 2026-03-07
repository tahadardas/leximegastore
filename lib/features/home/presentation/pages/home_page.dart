import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../core/images/image_url_optimizer.dart';
import '../../../../core/logging/app_logger.dart';
import '../../../../core/session/app_session.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/utils/url_utils.dart';
import '../../../../shared/services/share_service.dart';
import '../../../../shared/ui/lexi_alert.dart';
import '../../../../shared/widgets/error_state.dart';
import '../../../../shared/widgets/lexi_network_image.dart';
import '../../../../shared/widgets/loading_body_stack.dart';
import '../../../../shared/widgets/product_card.dart';
import '../../../../design_system/lexi_tokens.dart';
import '../../../../design_system/lexi_typography.dart';
import '../../../../ui/widgets/lexi_safe_bottom.dart';
import '../../../../ui/widgets/offline_banner.dart';
import '../../../../shared/widgets/lexi_ui/lexi_drawer.dart';
import '../../../cart/domain/entities/cart_item.dart';
import '../../../cart/presentation/controllers/cart_controller.dart';
import '../../../categories/domain/entities/category_entity.dart';
import '../../../categories/presentation/controllers/categories_controller.dart';
import '../../../product/domain/entities/product_entity.dart';
import '../../../product/presentation/controllers/paginated_products_controller.dart';
import '../../../wishlist/presentation/controllers/wishlist_controller.dart';
import '../../../../core/ai/ai_tracker.dart';
import '../../domain/entities/home_ad_banner_entity.dart';
import '../../domain/entities/home_section_entity.dart';
import '../controllers/home_ad_banners_controller.dart';
import '../controllers/home_sections_controller.dart';
import '../widgets/ai_sections.dart';
import '../widgets/banner_carousel_widget.dart';
import '../widgets/featured_products_carousel_widget.dart';
import '../../../../features/notifications/presentation/widgets/notification_badge.dart';
import '../widgets/home_skeletons.dart';
import '../../../../shared/widgets/product_card_skeleton.dart';

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  static const double _homeTopBarHeight = 80;
  static const double _paginationThreshold = 420;
  static const int _nextPageSkeletonCount = 4;
  static const int _initialSkeletonCount = 8;
  static const PaginatedProductsQuery _homeProductsQuery =
      PaginatedProductsQuery.home();

  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final Set<String> _prefetchedUrls = <String>{};

  Timer? _flashTimer;
  Timer? _scrollDebounce;
  int _adBannerIndex = 0;
  Duration _flashRemaining = const Duration(hours: 5, minutes: 59, seconds: 59);

  @override
  void initState() {
    super.initState();
    _startFlashCountdown();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _flashTimer?.cancel();
    _scrollDebounce?.cancel();
    _scrollController
      ..removeListener(_onScroll)
      ..dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sectionsAsync = ref.watch(homeSectionsControllerProvider);
    final adBannersAsync = ref.watch(homeAdBannersControllerProvider);
    final categoriesAsync = ref.watch(categoriesControllerProvider);
    final wishlistIds = ref.watch(wishlistIdsProvider);
    final paginatedProductsState = ref.watch(
      paginatedProductsControllerProvider(_homeProductsQuery),
    );
    final cartItems =
        ref.watch(cartControllerProvider).valueOrNull?.items ?? const [];

    final sections = sectionsAsync.valueOrNull ?? const <HomeSectionEntity>[];
    final adBanners = _filterRenderableAdBanners(
      adBannersAsync.valueOrNull ?? const <HomeAdBannerEntity>[],
    );
    final categories = categoriesAsync.valueOrNull ?? const <CategoryEntity>[];
    final buckets = _buildMerchandising(sections);
    final isTopContentLoading =
        sectionsAsync.isLoading ||
        adBannersAsync.isLoading ||
        categoriesAsync.isLoading;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      _prefetchHomeVisuals(
        products: buckets.generalProducts.take(6).toList(growable: false),
        categories: categories,
        adBanners: adBanners,
      );
    });

    if (sectionsAsync.isLoading && sections.isEmpty) {
      return Scaffold(
        drawer: const LexiDrawer(),
        backgroundColor: LexiColors.background,
        body: Column(
          children: [
            LexiSafeBottom(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: LexiSpacing.s12,
                  vertical: LexiSpacing.s12,
                ),
                child: _HomeAppBar(
                  onMenuTap: () => _scaffoldKey.currentState?.openDrawer(),
                  onCartTap: () => context.goNamedSafe(AppRouteNames.cart),
                  onWishlistTap: () => context.push('/wishlist'),
                  onSubmitted: (value) {
                    if (value.isNotEmpty) {
                      context.push('/search?q=${Uri.encodeComponent(value)}');
                    }
                  },
                ),
              ),
            ),
            Expanded(
              child: CustomScrollView(
                slivers: [
                  SliverPadding(
                    padding: const EdgeInsetsDirectional.fromSTEB(
                      LexiSpacing.s12,
                      LexiSpacing.s12,
                      LexiSpacing.s12,
                      LexiSpacing.s12,
                    ),
                    sliver: SliverList(
                      delegate: SliverChildListDelegate([
                        const HomeBannerSkeleton(),
                        const SizedBox(height: LexiSpacing.s12),
                        const SizedBox(
                          height: 200,
                          child: HomeCategoryGridSkeleton(),
                        ),
                        const SizedBox(height: LexiSpacing.s12),
                        const HomeSectionSkeleton(),
                        const SizedBox(height: LexiSpacing.s12),
                        const HomeSectionSkeleton(),
                      ]),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    if (sectionsAsync.hasError && sections.isEmpty) {
      return Scaffold(
        drawer: const LexiDrawer(),
        backgroundColor: LexiColors.background,
        body: SafeArea(
          child: ErrorState(
            message: 'تعذر تحميل الصفحة الرئيسية. حاول مرة أخرى.',
            onRetry: () {
              unawaited(_refreshHomeContent());
            },
          ),
        ),
      );
    }

    return Scaffold(
      key: _scaffoldKey,
      drawer: const LexiDrawer(),
      backgroundColor: LexiColors.background,
      body: Column(
        children: [
          OfflineBanner(
            onRetry: () {
              unawaited(_refreshHomeContent());
            },
          ),
          Expanded(
            child: LoadingBodyStack(
              isLoading: isTopContentLoading,
              topInset: MediaQuery.paddingOf(context).top + _homeTopBarHeight,
              blockTouches: false,
              overlayColor: Colors.transparent,
              child: RefreshIndicator(
                color: LexiColors.primaryYellow,
                onRefresh: _refreshHomeContent,
                child: CustomScrollView(
                  controller: _scrollController,
                  physics: const AlwaysScrollableScrollPhysics(),
                  slivers: [
                    SliverAppBar(
                      pinned: true,
                      elevation: 0,
                      scrolledUnderElevation: 0,
                      automaticallyImplyLeading: false,
                      backgroundColor: LexiColors.background,
                      toolbarHeight: _homeTopBarHeight,
                      titleSpacing: 0,
                      title: _SearchHeader(
                        controller: _searchController,
                        onSubmitted: _submitSearch,
                        onSearchTap: () => context.push('/search'),
                        onMenuTap: () =>
                            _scaffoldKey.currentState?.openDrawer(),
                        onWishlistTap: () => context.push('/wishlist'),
                        onCartTap: () =>
                            context.goNamedSafe(AppRouteNames.cart),
                      ),
                    ),
                    SliverPadding(
                      padding: const EdgeInsetsDirectional.fromSTEB(
                        LexiSpacing.s12,
                        LexiSpacing.s12,
                        LexiSpacing.s12,
                        96,
                      ),
                      sliver: SliverList(
                        delegate: SliverChildListDelegate([
                          AnimationLimiter(
                            child: Column(
                              children: AnimationConfiguration.toStaggeredList(
                                duration: const Duration(milliseconds: 375),
                                childAnimationBuilder: (widget) =>
                                    SlideAnimation(
                                      horizontalOffset: 50.0,
                                      child: FadeInAnimation(child: widget),
                                    ),
                                children: [
                                  if (adBannersAsync.isLoading &&
                                      adBanners.isEmpty)
                                    const _SectionBlock(
                                      child: HomeBannerSkeleton(),
                                    ),
                                  if (adBanners.isNotEmpty) ...[
                                    _SectionBlock(
                                      child: BannerCarouselWidget(
                                        banners: adBanners,
                                        currentIndex: _adBannerIndex,
                                        onPageChanged: (value) {
                                          if (_adBannerIndex == value) {
                                            return;
                                          }
                                          setState(
                                            () => _adBannerIndex = value,
                                          );
                                        },
                                        onTapBanner: (banner) {
                                          unawaited(_openAdBannerLink(banner));
                                        },
                                      ),
                                    ),
                                    const SizedBox(height: LexiSpacing.s12),
                                  ],
                                  if (buckets.bannerProducts.isNotEmpty) ...[
                                    _SectionBlock(
                                      title: 'منتجات مميزة',
                                      child: FeaturedProductsCarouselWidget(
                                        products: buckets.bannerProducts,
                                        wishlistIds: wishlistIds,
                                        cartItems: cartItems,
                                        heroTagPrefix: 'home-featured-',
                                        onProductTap: (product) {
                                          context.push(
                                            '/product/${product.id}?hero=home-featured-${product.id}',
                                          );
                                        },
                                        onBrandTap: (product) async {
                                          if (product.brandName
                                              .trim()
                                              .isEmpty) {
                                            return;
                                          }
                                          context.push(
                                            AppRoutePaths.brandProductsFromCard(
                                              brandName: product.brandName,
                                              brandId: product.brandId,
                                            ),
                                          );
                                        },
                                        onWishlistTap: (p) async {
                                          await ref
                                              .read(
                                                wishlistControllerProvider
                                                    .notifier,
                                              )
                                              .toggle(p.id, product: p);
                                        },
                                        onAddToCartTap: _addProductToCart,
                                        onShareTap: _shareProduct,
                                        onCommentTap: _openReviewShortcut,
                                        onCartIncrement: (p) => ref
                                            .read(
                                              cartControllerProvider.notifier,
                                            )
                                            .increment('${p.id}'),
                                        onCartDecrement: (p) => ref
                                            .read(
                                              cartControllerProvider.notifier,
                                            )
                                            .decrement('${p.id}'),
                                      ),
                                    ),
                                    const SizedBox(height: LexiSpacing.s12),
                                  ],
                                  const AIForYouSection(),
                                  const SizedBox(height: LexiSpacing.s12),
                                  _SectionBlock(
                                    title: 'التصنيفات',
                                    child: categoriesAsync.when(
                                      loading: () =>
                                          const HomeCategoryGridSkeleton(),
                                      error: (_, _) => const _SectionText(
                                        text: 'تعذر تحميل التصنيفات حالياً.',
                                      ),
                                      data: (items) => _NoonCategoriesGrid(
                                        categories: items,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: LexiSpacing.s12),
                                  ...buckets.sections.map((section) {
                                    final isFlash =
                                        section.type == 'flash_deals' ||
                                        section.titleAr.contains('خصم');

                                    return Column(
                                      children: [
                                        _SectionBlock(
                                          title: section.titleAr,
                                          titleColor: isFlash
                                              ? LexiColors.discountRed
                                              : null,
                                          badgeText: isFlash
                                              ? _formatCountdown(
                                                  _flashRemaining,
                                                )
                                              : (section.titleAr == 'عروض اليوم'
                                                    ? 'خصم'
                                                    : (section.titleAr ==
                                                              'وصل حديثاً'
                                                          ? 'وصل حديثاً'
                                                          : '')),
                                          onViewAll:
                                              section.titleAr == 'عروض اليوم' ||
                                                  section.titleAr ==
                                                      'أفضل العروض' ||
                                                  section.titleAr ==
                                                      'منتجات مخفضة'
                                              ? () => context.go('/deals')
                                              : null,
                                          child: section.items.isEmpty
                                              ? const _SectionText(
                                                  text:
                                                      'لا توجد منتجات حالياً.',
                                                )
                                              : _HorizontalProductsStrip(
                                                  products: section.items,
                                                  wishlistIds: wishlistIds,
                                                  cartItems: cartItems,
                                                  highlightBadge: isFlash
                                                      ? 'خصم'
                                                      : null,
                                                  showSaleCountdown: isFlash,
                                                  heroTagPrefix:
                                                      'home-section-${section.id}-',
                                                  onProductTap: (p) => context
                                                      .push('/product/${p.id}'),
                                                  onWishlistTap: (p) async {
                                                    await ref
                                                        .read(
                                                          wishlistControllerProvider
                                                              .notifier,
                                                        )
                                                        .toggle(
                                                          p.id,
                                                          product: p,
                                                        );
                                                  },
                                                  onAddToCartTap:
                                                      _addProductToCart,
                                                  onShareTap: _shareProduct,
                                                  onCommentTap:
                                                      _openReviewShortcut,
                                                  onCartIncrement: (p) => ref
                                                      .read(
                                                        cartControllerProvider
                                                            .notifier,
                                                      )
                                                      .increment('${p.id}'),
                                                  onCartDecrement: (p) => ref
                                                      .read(
                                                        cartControllerProvider
                                                            .notifier,
                                                      )
                                                      .decrement('${p.id}'),
                                                ),
                                        ),
                                        const SizedBox(height: LexiSpacing.s12),
                                      ],
                                    );
                                  }),
                                ],
                              ),
                            ),
                          ),
                        ]),
                      ),
                    ),
                    ..._buildPaginatedProductsSlivers(
                      state: paginatedProductsState,
                      wishlistIds: wishlistIds,
                      cartItems: cartItems,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _onScroll() {
    if (!_scrollController.hasClients) {
      return;
    }
    if (_scrollController.position.extentAfter > _paginationThreshold) {
      return;
    }

    _scrollDebounce?.cancel();
    _scrollDebounce = Timer(const Duration(milliseconds: 140), () {
      if (!mounted) {
        return;
      }
      unawaited(
        ref
            .read(
              paginatedProductsControllerProvider(_homeProductsQuery).notifier,
            )
            .loadNextPage(),
      );
    });
  }

  Future<void> _refreshHomeContent() async {
    await ref.read(homeSectionsControllerProvider.notifier).refresh();
    await ref.read(homeAdBannersControllerProvider.notifier).refresh();
    await ref.read(categoriesControllerProvider.notifier).refresh();
    await ref
        .read(paginatedProductsControllerProvider(_homeProductsQuery).notifier)
        .refresh();
  }

  List<Widget> _buildPaginatedProductsSlivers({
    required PaginatedProductsState state,
    required Set<int> wishlistIds,
    required List<CartItem> cartItems,
  }) {
    final slivers = <Widget>[
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(
            LexiSpacing.s12,
            0,
            LexiSpacing.s12,
            LexiSpacing.s12,
          ),
          child: Text(
            'جميع المنتجات',
            style: LexiTypography.h3.copyWith(
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ),
    ];

    if (state.isLoadingInitial && state.items.isEmpty) {
      slivers.add(
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: LexiSpacing.s12),
          sliver: SliverGrid(
            delegate: SliverChildBuilderDelegate(
              (context, index) => const ProductCardSkeleton(),
              childCount: _initialSkeletonCount,
            ),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: LexiSpacing.s12,
              mainAxisSpacing: LexiSpacing.s12,
              childAspectRatio: 0.54,
            ),
          ),
        ),
      );
      slivers.add(const SliverToBoxAdapter(child: SizedBox(height: 96)));
      return slivers;
    }

    if (state.errorInitial != null && state.items.isEmpty) {
      slivers.add(
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(
              LexiSpacing.s12,
              0,
              LexiSpacing.s12,
              LexiSpacing.s12,
            ),
            child: Container(
              padding: const EdgeInsets.all(LexiSpacing.s12),
              decoration: BoxDecoration(
                color: LexiColors.white,
                borderRadius: BorderRadius.circular(LexiRadius.card),
                border: Border.all(color: LexiColors.gray200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'تعذر تحميل المنتجات.',
                    style: LexiTypography.body.copyWith(
                      color: LexiColors.darkBlack,
                    ),
                  ),
                  const SizedBox(height: LexiSpacing.s8),
                  Text(
                    _errorMessageOf(state.errorInitial),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: LexiTypography.caption.copyWith(
                      color: LexiColors.gray500,
                    ),
                  ),
                  const SizedBox(height: LexiSpacing.s8),
                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: TextButton.icon(
                      onPressed: () {
                        unawaited(
                          ref
                              .read(
                                paginatedProductsControllerProvider(
                                  _homeProductsQuery,
                                ).notifier,
                              )
                              .retryInitial(),
                        );
                      },
                      icon: const Icon(Icons.refresh),
                      label: const Text('إعادة المحاولة'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      slivers.add(const SliverToBoxAdapter(child: SizedBox(height: 96)));
      return slivers;
    }

    if (state.items.isEmpty) {
      slivers.add(
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(
              LexiSpacing.s12,
              0,
              LexiSpacing.s12,
              LexiSpacing.s12,
            ),
            child: const _SectionText(text: 'لا توجد منتجات متاحة حالياً.'),
          ),
        ),
      );
      slivers.add(const SliverToBoxAdapter(child: SizedBox(height: 96)));
      return slivers;
    }

    final itemCount =
        state.items.length + (state.isLoadingNext ? _nextPageSkeletonCount : 0);

    slivers.add(
      SliverPadding(
        padding: const EdgeInsets.symmetric(horizontal: LexiSpacing.s12),
        sliver: SliverGrid(
          delegate: SliverChildBuilderDelegate((context, index) {
            if (index >= state.items.length) {
              return const ProductCardSkeleton();
            }

            final product = state.items[index];
            final tag = 'home-grid-${product.id}';
            final pCartKey = '${product.id}';
            final pCartQty =
                cartItems
                    .where((e) => e.cartKey == pCartKey)
                    .firstOrNull
                    ?.qty ??
                0;
            return ProductCard(
              productId: product.id,
              heroTag: tag,
              name: product.name,
              descriptionSnippet: product.shortDescription.isNotEmpty
                  ? product.shortDescription
                  : product.description,
              price: CurrencyFormatter.formatAmountOrUnavailable(product.price),
              oldPrice: product.hasDiscount
                  ? CurrencyFormatter.formatAmount(product.regularPrice)
                  : null,
              imageUrls: product.effectiveCardImages,
              rating: product.rating,
              reviewsCount: product.reviewsCount,
              brandName: product.brandName,
              onBrandTap: product.brandName.trim().isNotEmpty
                  ? () {
                      context.push(
                        AppRoutePaths.brandProductsFromCard(
                          brandName: product.brandName,
                          brandId: product.brandId,
                        ),
                      );
                    }
                  : null,
              discountPercent: product.discountPercentage,
              badgeText: product.hasDiscount ? 'خصم' : null,
              isWishlisted: wishlistIds.contains(product.id),
              canAddToCart: product.inStock && product.price > 0,
              cartQty: pCartQty,
              onIncrement: () =>
                  ref.read(cartControllerProvider.notifier).increment(pCartKey),
              onDecrement: () =>
                  ref.read(cartControllerProvider.notifier).decrement(pCartKey),
              showSaleCountdown:
                  product.hasDiscount && product.saleEndDate != null,
              showAddToCartSuccessAlert: false,
              onTap: () => context.push('/product/${product.id}?hero=$tag'),
              onWishlistToggle: () async {
                await ref
                    .read(wishlistControllerProvider.notifier)
                    .toggle(product.id, product: product);
              },
              onAddToCart: () => _addProductToCart(product),
              onShare: () => _shareProduct(product),
              onComment: () => _openReviewShortcut(product),
              saleEndDate: product.saleEndDate,
              wishlistCount: product.wishlistCount,
            );
          }, childCount: itemCount),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: LexiSpacing.s12,
            mainAxisSpacing: LexiSpacing.s12,
            childAspectRatio: 0.51,
          ),
        ),
      ),
    );

    if (state.errorNext != null) {
      slivers.add(
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(
              LexiSpacing.s12,
              LexiSpacing.s12,
              LexiSpacing.s12,
              0,
            ),
            child: Center(
              child: TextButton.icon(
                onPressed: () {
                  unawaited(
                    ref
                        .read(
                          paginatedProductsControllerProvider(
                            _homeProductsQuery,
                          ).notifier,
                        )
                        .retryNext(),
                  );
                },
                icon: const Icon(Icons.refresh),
                label: const Text('تعذر تحميل المزيد. أعد المحاولة'),
              ),
            ),
          ),
        ),
      );
    } else if (!state.hasMore) {
      slivers.add(
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(
              LexiSpacing.s12,
              LexiSpacing.s12,
              LexiSpacing.s12,
              0,
            ),
            child: Center(
              child: Text(
                'لا توجد منتجات إضافية',
                style: LexiTypography.caption.copyWith(
                  color: LexiColors.gray500,
                ),
              ),
            ),
          ),
        ),
      );
    }

    slivers.add(const SliverToBoxAdapter(child: SizedBox(height: 96)));
    return slivers;
  }

  String _errorMessageOf(Object? error) {
    final text = (error ?? '').toString().trim();
    if (text.isEmpty) {
      return 'حاول مرة أخرى.';
    }
    return text;
  }

  void _startFlashCountdown() {
    _flashTimer?.cancel();
    _flashTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        if (_flashRemaining.inSeconds <= 0) {
          _flashRemaining = const Duration(hours: 5, minutes: 59, seconds: 59);
        } else {
          _flashRemaining -= const Duration(seconds: 1);
        }
      });
    });
  }

  String _formatCountdown(Duration value) {
    final hours = value.inHours.remainder(100).toString().padLeft(2, '0');
    final minutes = value.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = value.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$hours:$minutes:$seconds';
  }

  Future<void> _prefetchHomeVisuals({
    required List<ProductEntity> products,
    required List<CategoryEntity> categories,
    required List<HomeAdBannerEntity> adBanners,
  }) async {
    final urls = <String>{
      ...products
          .map(
            (p) =>
                normalizeNullableHttpUrl(p.primaryImageUrl ?? p.primaryImage),
          )
          .whereType<String>(),
      ...categories
          .map((c) => normalizeNullableHttpUrl(c.image))
          .whereType<String>()
          .take(8),
      ...adBanners
          .map((b) => normalizeNullableHttpUrl(b.imageUrl))
          .whereType<String>(),
    };

    for (final raw in urls) {
      if (!mounted) {
        return;
      }
      final url = ImageUrlOptimizer.optimize(raw, preferWebp: true);
      if (!_prefetchedUrls.add(url)) {
        continue;
      }
      try {
        if (!mounted) {
          return;
        }
        await precacheImage(
          CachedNetworkImageProvider(url),
          context,
          onError: (e, st) {
            // Silently handled below — prevents noisy framework error logging.
          },
        );
      } catch (error) {
        AppLogger.warn(
          'فشل prefetch صورة من الشريط الإعلاني',
          extra: {'path': Uri.tryParse(url)?.path ?? url},
        );
      }
    }
  }

  Future<void> _addProductToCart(ProductEntity product) async {
    final item = CartItem(
      productId: product.id,
      name: product.name,
      price: product.price,
      image: product.primaryImageUrl ?? product.primaryImage,
      qty: 1,
    );

    await ref.read(cartControllerProvider.notifier).addItem(item);
  }

  Future<void> _shareProduct(ProductEntity product) async {
    await ShareService.instance.shareProductById(
      productId: product.id,
      name: product.name,
      priceText: CurrencyFormatter.formatAmountOrUnavailable(product.price),
    );
  }

  Future<void> _openReviewShortcut(ProductEntity product) async {
    final isLoggedIn = ref.read(appSessionProvider).isLoggedIn;
    if (!isLoggedIn) {
      await LexiAlert.info(context, text: 'يرجى تسجيل الدخول لإضافة تعليق');
      return;
    }
    if (!mounted) {
      return;
    }
    context.push('/product/${product.id}?focus=reviews');
  }

  void _submitSearch(String value) {
    final query = value.trim();
    if (query.isEmpty) {
      return;
    }

    ref.read(aiTrackerProvider).search(query);

    final encoded = Uri.encodeComponent(query);
    context.push('/search/results?q=$encoded');
  }

  Future<void> _openAdBannerLink(HomeAdBannerEntity banner) async {
    final target = banner.linkUrl.trim();
    if (target.isEmpty) {
      return;
    }

    if (target.startsWith('/')) {
      if (!mounted) {
        return;
      }
      context.push(target);
      return;
    }

    final normalized = normalizeNullableHttpUrl(target) ?? target;
    final uri = Uri.tryParse(normalized);
    if (uri == null) {
      return;
    }

    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  _MerchandisingBuckets _buildMerchandising(List<HomeSectionEntity> sections) {
    final ordered = [...sections]
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    HomeSectionEntity? heroSection;
    for (final section in ordered) {
      if (section.type == 'hero_banner') {
        heroSection = section;
        break;
      }
    }
    final sectionsForDisplay = ordered
        .where((section) => section.type != 'hero_banner')
        .toList(growable: false);

    final allProducts = _flattenUniqueProducts(ordered);

    var bannerProducts = <ProductEntity>[];
    if (heroSection != null && heroSection.items.isNotEmpty) {
      bannerProducts = _uniqueById(
        heroSection.items,
      ).where(_isRenderablePromoBannerProduct).take(8).toList();
    }

    final generalProducts = _uniqueById(allProducts).take(24).toList();

    return _MerchandisingBuckets(
      bannerProducts: bannerProducts,
      sections: sectionsForDisplay,
      generalProducts: generalProducts,
    );
  }

  List<ProductEntity> _flattenUniqueProducts(List<HomeSectionEntity> sections) {
    final output = <ProductEntity>[];
    final seen = <int>{};

    for (final section in sections) {
      for (final product in section.items) {
        if (seen.add(product.id)) {
          output.add(product);
        }
      }
    }

    return output;
  }

  List<ProductEntity> _uniqueById(List<ProductEntity> input) {
    final seen = <int>{};
    final out = <ProductEntity>[];
    for (final item in input) {
      if (seen.add(item.id)) {
        out.add(item);
      }
    }
    return out;
  }

  List<HomeAdBannerEntity> _filterRenderableAdBanners(
    List<HomeAdBannerEntity> input,
  ) {
    return input.where(_isRenderableAdBanner).toList(growable: false);
  }

  bool _isRenderableAdBanner(HomeAdBannerEntity banner) {
    final image = normalizeNullableHttpUrl(banner.imageUrl);
    return image != null && image.trim().isNotEmpty;
  }

  bool _isRenderablePromoBannerProduct(ProductEntity product) {
    if (product.id <= 0) {
      return false;
    }
    if (product.name.trim().isEmpty) {
      return false;
    }
    final image = normalizeNullableHttpUrl(
      product.primaryImageUrl ?? product.primaryImage,
    );
    return image != null && image.trim().isNotEmpty;
  }
}

class _MerchandisingBuckets {
  final List<ProductEntity> bannerProducts;
  final List<HomeSectionEntity> sections;
  final List<ProductEntity> generalProducts;

  const _MerchandisingBuckets({
    required this.bannerProducts,
    required this.sections,
    required this.generalProducts,
  });
}

class _SearchHeader extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onSubmitted;
  final VoidCallback onSearchTap;
  final VoidCallback onMenuTap;
  final VoidCallback onWishlistTap;
  final VoidCallback onCartTap;

  const _SearchHeader({
    required this.controller,
    required this.onSubmitted,
    required this.onSearchTap,
    required this.onMenuTap,
    required this.onWishlistTap,
    required this.onCartTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(
        LexiSpacing.s12,
        LexiSpacing.s8,
        LexiSpacing.s12,
        LexiSpacing.s8,
      ),
      child: Row(
        children: [
          _TopIconButton(
            icon: FontAwesomeIcons.barsStaggered,
            onTap: onMenuTap,
            tooltip: 'القائمة',
          ),
          const SizedBox(width: LexiSpacing.s12),
          Expanded(
            child: Container(
              height: 48,
              decoration: BoxDecoration(
                color: LexiColors.white,
                borderRadius: BorderRadius.circular(100),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x0A000000),
                    blurRadius: 10,
                    offset: Offset(0, 2),
                  ),
                ],
                border: Border.all(
                  color: LexiColors.gray200.withValues(alpha: 0.6),
                  width: 1,
                ),
              ),
              child: TextField(
                controller: controller,
                readOnly: true,
                textInputAction: TextInputAction.search,
                onTap: onSearchTap,
                onSubmitted: onSubmitted,
                decoration: InputDecoration(
                  hintText: 'ابحث عن منتج...',
                  hintStyle: LexiTypography.body.copyWith(
                    color: LexiColors.gray500,
                  ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsetsDirectional.only(
                    start: 8,
                    end: 12,
                    top: 12,
                    bottom: 12,
                  ),
                  prefixIcon: const Icon(
                    Icons.search,
                    size: 20,
                    color: LexiColors.gray500,
                  ),
                  prefixIconConstraints: const BoxConstraints(
                    minWidth: 44,
                    minHeight: 44,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: LexiSpacing.s8),
          const NotificationBadge(),
          const SizedBox(width: LexiSpacing.s8),
          _TopIconButton(
            icon: FontAwesomeIcons.heart,
            onTap: onWishlistTap,
            tooltip: 'المفضلة',
          ),
          const SizedBox(width: LexiSpacing.s8),
          _TopIconButton(
            icon: FontAwesomeIcons.cartShopping,
            onTap: onCartTap,
            tooltip: 'السلة',
          ),
        ],
      ),
    );
  }
}

class _TopIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final String tooltip;

  const _TopIconButton({
    required this.icon,
    required this.onTap,
    required this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: LexiColors.white,
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Tooltip(
          message: tooltip,
          child: SizedBox(
            width: 44,
            height: 44,
            child: Center(
              child: FaIcon(icon, size: 18, color: LexiColors.darkBlack),
            ),
          ),
        ),
      ),
    );
  }
}

class _SectionBlock extends StatelessWidget {
  final String? title;
  final String? badgeText;
  final Color? titleColor;
  final VoidCallback? onViewAll;
  final Widget child;

  const _SectionBlock({
    this.title,
    this.badgeText,
    this.titleColor,
    this.onViewAll,
    required this.child,
  });

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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if ((title ?? '').trim().isNotEmpty) ...[
            Row(
              children: [
                Expanded(
                  child: Text(
                    title!,
                    style: LexiTypography.h3.copyWith(
                      color: titleColor ?? LexiColors.darkBlack,
                    ),
                  ),
                ),
                if ((badgeText ?? '').trim().isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: LexiSpacing.s8,
                      vertical: LexiSpacing.s4,
                    ),
                    decoration: BoxDecoration(
                      color:
                          (titleColor ?? LexiColors.primaryYellow) ==
                              LexiColors.discountRed
                          ? LexiColors.discountRed
                          : LexiColors.primaryYellow,
                      borderRadius: BorderRadius.circular(LexiRadius.button),
                    ),
                    child: Text(
                      badgeText!,
                      style: LexiTypography.caption.copyWith(
                        color:
                            (titleColor ?? LexiColors.primaryYellow) ==
                                LexiColors.discountRed
                            ? LexiColors.white
                            : LexiColors.darkBlack,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                if (onViewAll != null) ...[
                  const SizedBox(width: LexiSpacing.s8),
                  TextButton(
                    onPressed: onViewAll,
                    child: const Text('عرض الكل'),
                  ),
                ],
              ],
            ),
            const SizedBox(height: LexiSpacing.s12),
          ],
          child,
        ],
      ),
    );
  }
}

class _NoonCategoriesGrid extends StatelessWidget {
  final List<CategoryEntity> categories;

  const _NoonCategoriesGrid({required this.categories});

  @override
  Widget build(BuildContext context) {
    final display = categories
        .where((c) => c.parentId == 0 && (c.count > 0 || c.childrenCount > 0))
        .toList();

    if (display.isEmpty) {
      return const _SectionText(text: 'لا توجد فئات نشطة حالياً.');
    }

    return SizedBox(
      height: 130,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics(),
        ),
        padding: const EdgeInsetsDirectional.only(
          start: LexiSpacing.s4,
          end: LexiSpacing.s4,
        ),
        itemCount: display.length,
        separatorBuilder: (_, _) => const SizedBox(width: LexiSpacing.s8),
        itemBuilder: (context, index) {
          final category = display[index];
          return InkWell(
            onTap: () {
              context.push(
                '/categories/${category.id}/products?title=${Uri.encodeComponent(category.name)}',
              );
            },
            borderRadius: BorderRadius.circular(LexiRadius.button),
            child: SizedBox(
              width: 84,
              child: Column(
                children: [
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: LexiColors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.04),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.all(2),
                    child: Container(
                      decoration: BoxDecoration(
                        color: LexiColors.gray50,
                        shape: BoxShape.circle,
                      ),
                      child: ClipOval(
                        child: (category.image ?? '').trim().isEmpty
                            ? Center(
                                child: FaIcon(
                                  FontAwesomeIcons.shapes,
                                  size: 18,
                                  color: LexiColors.primaryYellow.withValues(
                                    alpha: 0.8,
                                  ),
                                ),
                              )
                            : LexiNetworkImage(
                                imageUrl: category.image,
                                fit: BoxFit.cover,
                              ),
                      ),
                    ),
                  ),
                  const SizedBox(height: LexiSpacing.s8),
                  SizedBox(
                    height: 44,
                    child: Text(
                      category.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: LexiTypography.caption.copyWith(
                        color: LexiColors.darkBlack,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _HorizontalProductsStrip extends StatelessWidget {
  final List<ProductEntity> products;
  final Set<int> wishlistIds;
  final List<CartItem> cartItems;
  final String? highlightBadge;
  final bool showSaleCountdown;
  final String heroTagPrefix;
  final ValueChanged<ProductEntity> onProductTap;
  final Future<void> Function(ProductEntity product) onWishlistTap;
  final Future<void> Function(ProductEntity product) onAddToCartTap;
  final Future<void> Function(ProductEntity product) onShareTap;
  final Future<void> Function(ProductEntity product) onCommentTap;
  final void Function(ProductEntity product)? onCartIncrement;
  final void Function(ProductEntity product)? onCartDecrement;

  const _HorizontalProductsStrip({
    required this.products,
    required this.wishlistIds,
    this.cartItems = const [],
    this.highlightBadge,
    this.showSaleCountdown = false,
    required this.heroTagPrefix,
    required this.onProductTap,
    required this.onWishlistTap,
    required this.onAddToCartTap,
    required this.onShareTap,
    required this.onCommentTap,
    this.onCartIncrement,
    this.onCartDecrement,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 375,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: products.length.clamp(0, 14).toInt(),
        separatorBuilder: (_, _) => const SizedBox(width: LexiSpacing.s12),
        itemBuilder: (context, index) {
          final product = products[index];
          final tag = '$heroTagPrefix${product.id}';
          final cKey = '${product.id}';
          final cQty =
              cartItems.where((e) => e.cartKey == cKey).firstOrNull?.qty ?? 0;
          return SizedBox(
            width: 214,
            child: ProductCard(
              productId: product.id,
              heroTag: tag,
              name: product.name,
              descriptionSnippet: product.shortDescription.isNotEmpty
                  ? product.shortDescription
                  : product.description,
              price: CurrencyFormatter.formatAmountOrUnavailable(product.price),
              oldPrice: product.hasDiscount
                  ? CurrencyFormatter.formatAmount(product.regularPrice)
                  : null,
              imageUrls: product.effectiveCardImages,
              rating: product.rating,
              reviewsCount: product.reviewsCount,
              brandName: product.brandName,
              onBrandTap: product.brandName.trim().isNotEmpty
                  ? () {
                      context.push(
                        AppRoutePaths.brandProductsFromCard(
                          brandName: product.brandName,
                          brandId: product.brandId,
                        ),
                      );
                    }
                  : null,
              discountPercent: product.discountPercentage,
              badgeText: highlightBadge,
              showSaleCountdown: showSaleCountdown,
              isWishlisted: wishlistIds.contains(product.id),
              canAddToCart: product.inStock && product.price > 0,
              cartQty: cQty,
              onIncrement: onCartIncrement != null
                  ? () => onCartIncrement!(product)
                  : null,
              onDecrement: onCartDecrement != null
                  ? () => onCartDecrement!(product)
                  : null,
              showAddToCartSuccessAlert: false,
              onTap: () => context.push('/product/${product.id}?hero=$tag'),
              onWishlistToggle: () => onWishlistTap(product),
              onAddToCart: () => onAddToCartTap(product),
              onShare: () => onShareTap(product),
              onComment: () => onCommentTap(product),
              saleEndDate: product.saleEndDate,
              wishlistCount: product.wishlistCount,
            ),
          );
        },
      ),
    );
  }
}

// ignore: unused_element
class _GeneralProductsGrid extends StatelessWidget {
  final List<ProductEntity> products;
  final Set<int> wishlistIds;
  final String heroTagPrefix;
  final ValueChanged<ProductEntity> onProductTap;
  final Future<void> Function(ProductEntity product) onWishlistTap;
  final Future<void> Function(ProductEntity product) onAddToCartTap;
  final Future<void> Function(ProductEntity product) onShareTap;
  final Future<void> Function(ProductEntity product) onCommentTap;

  const _GeneralProductsGrid({
    required this.products,
    required this.wishlistIds,
    required this.heroTagPrefix,
    required this.onProductTap,
    required this.onWishlistTap,
    required this.onAddToCartTap,
    required this.onShareTap,
    required this.onCommentTap,
  });

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      itemCount: products.length,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: LexiSpacing.s12,
        mainAxisSpacing: LexiSpacing.s12,
        childAspectRatio: 0.51,
      ),
      itemBuilder: (context, index) {
        final product = products[index];
        final tag = '$heroTagPrefix${product.id}';
        return ProductCard(
          productId: product.id,
          heroTag: tag,
          name: product.name,
          descriptionSnippet: product.shortDescription.isNotEmpty
              ? product.shortDescription
              : product.description,
          price: CurrencyFormatter.formatAmountOrUnavailable(product.price),
          oldPrice: product.hasDiscount
              ? CurrencyFormatter.formatAmount(product.regularPrice)
              : null,
          imageUrls: product.effectiveCardImages,
          rating: product.rating,
          reviewsCount: product.reviewsCount,
          brandName: product.brandName,
          onBrandTap: product.brandName.trim().isNotEmpty
              ? () {
                  context.push(
                    AppRoutePaths.brandProductsFromCard(
                      brandName: product.brandName,
                      brandId: product.brandId,
                    ),
                  );
                }
              : null,
          discountPercent: product.discountPercentage,
          badgeText: product.hasDiscount ? 'خصم' : null,
          isWishlisted: wishlistIds.contains(product.id),
          canAddToCart: product.inStock && product.price > 0,
          showAddToCartSuccessAlert: false,
          onTap: () => context.push('/product/${product.id}?hero=$tag'),
          onWishlistToggle: () => onWishlistTap(product),
          onAddToCart: () => onAddToCartTap(product),
          onShare: () => onShareTap(product),
          onComment: () => onCommentTap(product),
          saleEndDate: product.saleEndDate,
          wishlistCount: product.wishlistCount,
        );
      },
    );
  }
}

class _SectionText extends StatelessWidget {
  final String text;

  const _SectionText({required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: LexiSpacing.s8),
      child: Text(text, style: LexiTypography.body),
    );
  }
}

class _HomeAppBar extends StatelessWidget {
  final VoidCallback onMenuTap;
  final VoidCallback onCartTap;
  final VoidCallback onWishlistTap;
  final ValueChanged<String> onSubmitted;

  const _HomeAppBar({
    required this.onMenuTap,
    required this.onCartTap,
    required this.onWishlistTap,
    required this.onSubmitted,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        IconButton(
          onPressed: onMenuTap,
          icon: const Icon(Icons.menu, color: LexiColors.brandBlack),
        ),
        const SizedBox(width: LexiSpacing.s8),
        Expanded(
          child: Container(
            height: 48,
            decoration: BoxDecoration(
              color: LexiColors.white,
              borderRadius: BorderRadius.circular(LexiRadius.full),
              border: Border.all(color: LexiColors.neutral200),
            ),
            child: TextField(
              textInputAction: TextInputAction.search,
              onSubmitted: onSubmitted,
              decoration: InputDecoration(
                hintText: 'ابحث عن المنتجات...',
                hintStyle: LexiTypography.bodySm,
                prefixIcon: const Icon(
                  Icons.search,
                  color: LexiColors.neutral500,
                  size: 20,
                ),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: LexiSpacing.md,
                  vertical: LexiSpacing.s12,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: LexiSpacing.s8),
        IconButton(
          onPressed: onWishlistTap,
          icon: const FaIcon(
            FontAwesomeIcons.heart,
            size: 20,
            color: LexiColors.brandBlack,
          ),
        ),
        Stack(
          children: [
            IconButton(
              onPressed: onCartTap,
              icon: const FaIcon(
                FontAwesomeIcons.bagShopping,
                size: 20,
                color: LexiColors.brandBlack,
              ),
            ),
            const Positioned(top: 4, right: 4, child: NotificationBadge()),
          ],
        ),
      ],
    );
  }
}
