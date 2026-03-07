import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../core/session/app_session.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../shared/services/share_service.dart';
import '../../../../design_system/lexi_tokens.dart';
import '../../../../design_system/lexi_typography.dart';
import '../../../../shared/ui/lexi_alert.dart';
import '../../../../shared/widgets/error_state.dart';
import '../../../../shared/widgets/lexi_ui/lexi_app_bar.dart';
import '../../../../shared/widgets/lexi_ui/lexi_grid_skeleton.dart';
import '../../../../shared/widgets/product_card.dart';
import '../../../../shared/widgets/product_card_skeleton.dart';
import '../../../../ui/widgets/offline_banner.dart';
import '../../../cart/domain/entities/cart_item.dart';
import '../../../cart/presentation/controllers/cart_controller.dart';
import '../../domain/entities/product_entity.dart';
import '../../../wishlist/presentation/controllers/wishlist_controller.dart';
import '../controllers/paginated_products_controller.dart';
import '../widgets/offers_masonry_grid.dart';

enum ProductsListingFilterType { home, category, brand, deals }

class ProductsListingPage extends ConsumerStatefulWidget {
  final String title;
  final ProductsListingFilterType filterType;
  final int? filterId;
  final String? filterName;
  final String initialSort;
  final String initialSearch;
  final String? shortDescription;

  const ProductsListingPage({
    super.key,
    required this.title,
    required this.filterType,
    this.filterId,
    this.filterName,
    this.initialSort = '',
    this.initialSearch = '',
    this.shortDescription,
  });

  @override
  ConsumerState<ProductsListingPage> createState() =>
      _ProductsListingPageState();
}

class _ProductsListingPageState extends ConsumerState<ProductsListingPage>
    with AutomaticKeepAliveClientMixin {
  static const int _perPage = 20;
  static const double _paginationThreshold = 200;
  static const int _nextPageSkeletonCount = 4;

  static const Map<String, String> _sortOptions = <String, String>{
    'manual': '\u0627\u0644\u0623\u0641\u0636\u0644',
    'newest': '\u0627\u0644\u0623\u062d\u062f\u062b',
    'price_asc':
        '\u0627\u0644\u0633\u0639\u0631: \u0627\u0644\u0623\u0642\u0644',
    'price_desc':
        '\u0627\u0644\u0633\u0639\u0631: \u0627\u0644\u0623\u0639\u0644\u0649',
    'top_rated':
        '\u0627\u0644\u0623\u0639\u0644\u0649 \u062a\u0642\u064a\u064a\u0645\u0627\u064b',
    'flash_deals':
        '\u0627\u0644\u0639\u0631\u0648\u0636 \u0627\u0644\u0633\u0631\u064a\u0639\u0629',
    'on_sale': '\u0643\u0644 \u0627\u0644\u0639\u0631\u0648\u0636',
  };

  static final NumberFormat _productsCountFormatter =
      NumberFormat.decimalPattern('ar');

  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();
  Timer? _scrollDebounce;

  late String _selectedSort;
  late String _appliedSearch;
  bool _showScrollTop = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _selectedSort = _resolveInitialSort();
    _appliedSearch = widget.initialSearch.trim();
    _searchController.text = widget.initialSearch;
    _scrollController.addListener(_onScroll);
  }

  @override
  void didUpdateWidget(covariant ProductsListingPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    final filterChanged =
        oldWidget.filterType != widget.filterType ||
        oldWidget.filterId != widget.filterId ||
        oldWidget.filterName != widget.filterName;
    final sortChanged = oldWidget.initialSort != widget.initialSort;
    final searchChanged = oldWidget.initialSearch != widget.initialSearch;
    if (!filterChanged && !sortChanged && !searchChanged) {
      return;
    }

    _selectedSort = _resolveInitialSort();
    _appliedSearch = widget.initialSearch.trim();
    if (_searchController.text != widget.initialSearch) {
      _searchController.text = widget.initialSearch;
    }
    setState(() {});
  }

  @override
  void dispose() {
    _scrollDebounce?.cancel();
    _scrollController
      ..removeListener(_onScroll)
      ..dispose();
    _searchController.dispose();
    super.dispose();
  }

  int? get _resolvedCategoryId {
    if (widget.filterType != ProductsListingFilterType.category) {
      return null;
    }
    final id = widget.filterId ?? 0;
    return id > 0 ? id : null;
  }

  int? get _resolvedBrandId {
    if (widget.filterType != ProductsListingFilterType.brand) {
      return null;
    }
    final id = widget.filterId ?? 0;
    return id > 0 ? id : null;
  }

  String get _resolvedBrandName {
    if (widget.filterType != ProductsListingFilterType.brand) {
      return '';
    }
    return (widget.filterName ?? '').trim();
  }

  bool get _showHeaderCard =>
      widget.filterType == ProductsListingFilterType.brand;

  PaginatedProductsQuery get _productsQuery => PaginatedProductsQuery(
    perPage: _perPage,
    search: _effectiveSearch(),
    categoryId: _resolvedCategoryId,
    brandId: _resolvedBrandId,
    brandName: _resolvedBrandName.isEmpty ? null : _resolvedBrandName,
    sort: _selectedSort,
  );

  String _resolveInitialSort() {
    final incoming = widget.initialSort.trim();
    if (incoming.isNotEmpty && _sortOptions.containsKey(incoming)) {
      return incoming;
    }
    switch (widget.filterType) {
      case ProductsListingFilterType.home:
        return 'newest';
      case ProductsListingFilterType.deals:
        return 'flash_deals';
      case ProductsListingFilterType.category:
      case ProductsListingFilterType.brand:
        return 'manual';
    }
  }

  String? _effectiveSearch() {
    final value = _appliedSearch.trim();
    return value.isEmpty ? null : value;
  }

  void _onScroll() {
    if (!_scrollController.hasClients) {
      return;
    }

    final shouldShow = _scrollController.offset > 700;
    if (shouldShow != _showScrollTop && mounted) {
      setState(() => _showScrollTop = shouldShow);
    }

    if (_scrollController.position.extentAfter > _paginationThreshold) {
      return;
    }

    _scrollDebounce?.cancel();
    _scrollDebounce = Timer(const Duration(milliseconds: 120), () {
      if (!mounted) {
        return;
      }
      final state = ref.read(
        paginatedProductsControllerProvider(_productsQuery),
      );
      if (state.isLoadingInitial || state.isLoadingNext || !state.hasMore) {
        return;
      }
      unawaited(
        ref
            .read(paginatedProductsControllerProvider(_productsQuery).notifier)
            .loadNextPage(),
      );
    });
  }

  Future<void> _refreshProducts() async {
    await ref
        .read(paginatedProductsControllerProvider(_productsQuery).notifier)
        .refresh();
  }

  void _applySearch() {
    final next = _searchController.text.trim();
    if (next == _appliedSearch) {
      unawaited(_refreshProducts());
      return;
    }
    _appliedSearch = next;
    setState(() {});
  }

  String _totalProductsLabel(PaginatedProductsState state) {
    final total = state.totalItems;
    if (total > 0) {
      return '${_productsCountFormatter.format(total)} \u0645\u0646\u062a\u062c';
    }
    if (state.isLoadingInitial) {
      return '\u062c\u0627\u0631\u064d \u062a\u062d\u0645\u064a\u0644 \u0627\u0644\u0645\u0646\u062a\u062c\u0627\u062a...';
    }
    if (state.items.isNotEmpty) {
      return '${_productsCountFormatter.format(state.items.length)} \u0645\u0646\u062a\u062c';
    }
    return '0 \u0645\u0646\u062a\u062c';
  }

  Future<void> _scrollToTop() async {
    if (!_scrollController.hasClients) {
      return;
    }
    await _scrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 360),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final productsState = ref.watch(
      paginatedProductsControllerProvider(_productsQuery),
    );
    final wishlistIds = ref.watch(wishlistIdsProvider);
    final cartItems =
        ref.watch(cartControllerProvider).valueOrNull?.items ??
        const <CartItem>[];
    final appBarTitle = widget.title;

    return Scaffold(
      backgroundColor: LexiColors.neutral100,
      appBar: LexiAppBar(title: appBarTitle),
      floatingActionButton: _showScrollTop
          ? FloatingActionButton.small(
              onPressed: _scrollToTop,
              backgroundColor: LexiColors.brandPrimary,
              foregroundColor: LexiColors.darkBlack,
              child: const Icon(Icons.arrow_upward_rounded),
            )
          : null,
      body: Column(
        children: [
          OfflineBanner(onRetry: _refreshProducts),
          if (_showHeaderCard) _buildHeaderCard(productsState),
          _buildSortBar(),
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(
              LexiSpacing.md,
              0,
              LexiSpacing.md,
              LexiSpacing.sm,
            ),
            child: TextField(
              controller: _searchController,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => _applySearch(),
              decoration: InputDecoration(
                hintText:
                    '\u0627\u0628\u062d\u062b \u062f\u0627\u062e\u0644 \u0627\u0644\u0645\u0646\u062a\u062c\u0627\u062a',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: IconButton(
                  onPressed: _applySearch,
                  icon: const Icon(Icons.tune_rounded),
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(LexiRadius.md),
                ),
              ),
            ),
          ),
          Expanded(
            child: _buildProductsBody(
              state: productsState,
              wishlistIds: wishlistIds,
              cartItems: cartItems,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderCard(PaginatedProductsState state) {
    final totalLabel = _totalProductsLabel(state);
    final description = (widget.shortDescription ?? '').trim();

    return Container(
      width: double.infinity,
      padding: const EdgeInsetsDirectional.fromSTEB(
        LexiSpacing.md,
        LexiSpacing.md,
        LexiSpacing.md,
        0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Text(
                  widget.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: LexiTypography.h2.copyWith(
                    fontWeight: FontWeight.w800,
                    color: LexiColors.darkBlack,
                  ),
                ),
              ),
              if (state.isLoadingInitial)
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2.5),
                ),
            ],
          ),
          const SizedBox(height: LexiSpacing.xs),
          Text(
            totalLabel,
            style: LexiTypography.body.copyWith(
              color: LexiColors.neutral600,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (description.isNotEmpty) ...[
            const SizedBox(height: LexiSpacing.s8),
            Text(
              description,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: LexiTypography.bodyMd.copyWith(
                color: LexiColors.neutral600,
                height: 1.5,
              ),
            ),
          ],
          const SizedBox(height: LexiSpacing.md),
        ],
      ),
    );
  }

  Widget _buildSortBar() {
    return SizedBox(
      height: 52,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsetsDirectional.fromSTEB(
          LexiSpacing.md,
          0,
          LexiSpacing.md,
          LexiSpacing.sm,
        ),
        child: Row(
          children: _sortOptions.entries
              .map((entry) {
                final selected = _selectedSort == entry.key;
                return Padding(
                  padding: const EdgeInsetsDirectional.only(
                    end: LexiSpacing.s8,
                  ),
                  child: ChoiceChip(
                    label: Text(entry.value),
                    selected: selected,
                    onSelected: (_) {
                      if (selected) {
                        return;
                      }
                      setState(() => _selectedSort = entry.key);
                    },
                    selectedColor: LexiColors.brandPrimary,
                    backgroundColor: LexiColors.white,
                    labelStyle: LexiTypography.caption.copyWith(
                      color: selected
                          ? LexiColors.darkBlack
                          : LexiColors.neutral700,
                      fontWeight: FontWeight.w700,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(LexiRadius.full),
                      side: BorderSide(
                        color: selected
                            ? LexiColors.brandPrimary
                            : LexiColors.neutral300,
                      ),
                    ),
                  ),
                );
              })
              .toList(growable: false),
        ),
      ),
    );
  }

  Widget _buildProductsBody({
    required PaginatedProductsState state,
    required Set<int> wishlistIds,
    required List<CartItem> cartItems,
  }) {
    if (state.isLoadingInitial && state.items.isEmpty) {
      return const LexiGridSkeleton();
    }

    if (state.errorInitial != null && state.items.isEmpty) {
      return ErrorState(
        message:
            '\u062a\u0639\u0630\u0631 \u062a\u062d\u0645\u064a\u0644 \u0627\u0644\u0645\u0646\u062a\u062c\u0627\u062a \u062d\u0627\u0644\u064a\u0627\u064b.',
        error: state.errorInitial!,
        technicalDetails: 'source: products/listing',
        onRetry: _refreshProducts,
      );
    }

    if (state.items.isEmpty) {
      return const Center(
        child: Text(
          '\u0644\u0627 \u062a\u0648\u062c\u062f \u0645\u0646\u062a\u062c\u0627\u062a',
        ),
      );
    }

    final itemCount =
        state.items.length + (state.isLoadingNext ? _nextPageSkeletonCount : 0);
    final isDealsLayout = widget.filterType == ProductsListingFilterType.deals;

    Future<void> onShareProduct(ProductEntity product) async {
      await ShareService.instance.shareProductById(
        productId: product.id,
        name: product.name,
        priceText: CurrencyFormatter.formatAmountOrUnavailable(product.price),
      );
    }

    Future<void> onCommentProduct(ProductEntity product) async {
      final isLoggedIn = ref.read(appSessionProvider).isLoggedIn;
      if (!isLoggedIn) {
        await LexiAlert.info(
          context,
          text:
              '\u0633\u062c\u0651\u0644 \u0627\u0644\u062f\u062e\u0648\u0644 \u0623\u0648\u0644\u0627\u064b \u0644\u0625\u0636\u0627\u0641\u0629 \u062a\u0639\u0644\u064a\u0642',
        );
        return;
      }
      if (!context.mounted) {
        return;
      }
      context.push('/product/${product.id}?focus=reviews');
    }

    Future<void> onToggleWishlist(ProductEntity product) async {
      await ref
          .read(wishlistControllerProvider.notifier)
          .toggle(product.id, product: product);
    }

    Future<void> onAddProductToCart(ProductEntity product) async {
      final item = CartItem(
        productId: product.id,
        name: product.name,
        price: product.effectivePrice,
        regularPrice: product.regularPrice > product.effectivePrice
            ? product.regularPrice
            : null,
        image: product.primaryImageUrl ?? product.primaryImage,
        qty: 1,
      );
      await ref.read(cartControllerProvider.notifier).addItem(item);
    }

    Future<void> onOpenBrand(ProductEntity product) async {
      if (product.brandName.trim().isEmpty) {
        return;
      }
      context.push(
        AppRoutePaths.brandProductsFromCard(
          brandName: product.brandName,
          brandId: product.brandId,
        ),
      );
    }

    return Column(
      children: [
        Expanded(
          child: isDealsLayout
              ? OffersMasonryGrid(
                  controller: _scrollController,
                  products: state.items,
                  wishlistIds: wishlistIds,
                  cartItems: cartItems,
                  isLoadingMore: state.isLoadingNext,
                  loadingPlaceholdersCount: _nextPageSkeletonCount,
                  onRefresh: _refreshProducts,
                  onProductTap: (product) =>
                      context.push('/product/${product.id}'),
                  onBrandTap: onOpenBrand,
                  onWishlistTap: onToggleWishlist,
                  onAddToCartTap: onAddProductToCart,
                  onShareTap: onShareProduct,
                  onCommentTap: onCommentProduct,
                  onCartIncrement: (p) => ref
                      .read(cartControllerProvider.notifier)
                      .increment('${p.id}'),
                  onCartDecrement: (p) => ref
                      .read(cartControllerProvider.notifier)
                      .decrement('${p.id}'),
                )
              : RefreshIndicator(
                  color: LexiColors.brandPrimary,
                  onRefresh: _refreshProducts,
                  child: GridView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsetsDirectional.fromSTEB(
                      LexiSpacing.md,
                      0,
                      LexiSpacing.md,
                      20,
                    ),
                    itemCount: itemCount,
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: LexiSpacing.md,
                          mainAxisSpacing: LexiSpacing.md,
                          childAspectRatio: 0.51,
                        ),
                    itemBuilder: (context, index) {
                      if (index >= state.items.length) {
                        return const ProductCardSkeleton();
                      }
                      final product = state.items[index];
                      final cKey = '${product.id}';
                      final cQty =
                          cartItems
                              .where((e) => e.cartKey == cKey)
                              .firstOrNull
                              ?.qty ??
                          0;
                      return ProductCard(
                        productId: product.id,
                        heroTag: 'products-grid-${product.id}',
                        name: product.name,
                        descriptionSnippet: product.shortDescription.isNotEmpty
                            ? product.shortDescription
                            : product.description,
                        price: CurrencyFormatter.formatAmountOrUnavailable(
                          product.price,
                        ),
                        oldPrice: product.hasDiscount
                            ? CurrencyFormatter.formatAmount(
                                product.regularPrice,
                              )
                            : null,
                        imageUrls: product.effectiveCardImages,
                        rating: product.rating,
                        reviewsCount: product.reviewsCount,
                        brandName: product.brandName,
                        onBrandTap: product.brandName.trim().isNotEmpty
                            ? () => onOpenBrand(product)
                            : null,
                        badgeText: product.hasDiscount
                            ? '\u062e\u0635\u0645 ${product.discountPercentage}%'
                            : null,
                        isWishlisted: wishlistIds.contains(product.id),
                        canAddToCart: product.inStock && product.price > 0,
                        cartQty: cQty,
                        onIncrement: () => ref
                            .read(cartControllerProvider.notifier)
                            .increment(cKey),
                        onDecrement: () => ref
                            .read(cartControllerProvider.notifier)
                            .decrement(cKey),
                        onTap: () => context.push('/product/${product.id}'),
                        onShare: () => onShareProduct(product),
                        onComment: () => onCommentProduct(product),
                        onWishlistToggle: () => onToggleWishlist(product),
                        onAddToCart: () => onAddProductToCart(product),
                        wishlistCount: product.wishlistCount,
                      );
                    },
                  ),
                ),
        ),
        if (state.errorNext != null)
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(
              LexiSpacing.md,
              LexiSpacing.sm,
              LexiSpacing.md,
              LexiSpacing.lg,
            ),
            child: TextButton.icon(
              onPressed: () {
                unawaited(
                  ref
                      .read(
                        paginatedProductsControllerProvider(
                          _productsQuery,
                        ).notifier,
                      )
                      .retryNext(),
                );
              },
              icon: const Icon(Icons.refresh),
              label: const Text(
                '\u0641\u0634\u0644 \u062a\u062d\u0645\u064a\u0644 \u0627\u0644\u0645\u0632\u064a\u062f. \u062d\u0627\u0648\u0644 \u0645\u062c\u062f\u062f\u064b\u0627',
              ),
            ),
          ),
      ],
    );
  }
}
