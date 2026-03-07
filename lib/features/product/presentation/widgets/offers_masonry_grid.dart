import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';

import '../../../../core/utils/currency_formatter.dart';
import '../../../../design_system/lexi_tokens.dart';
import '../../../../features/cart/domain/entities/cart_item.dart';
import '../../../../shared/widgets/product_card.dart';
import '../../../../shared/widgets/product_card_skeleton.dart';
import '../../domain/entities/product_entity.dart';

class OffersMasonryGrid extends StatelessWidget {
  final ScrollController controller;
  final List<ProductEntity> products;
  final Set<int> wishlistIds;
  final bool isLoadingMore;
  final int loadingPlaceholdersCount;
  final Future<void> Function() onRefresh;
  final ValueChanged<ProductEntity> onProductTap;
  final Future<void> Function(ProductEntity product) onWishlistTap;
  final Future<void> Function(ProductEntity product) onAddToCartTap;
  final Future<void> Function(ProductEntity product) onShareTap;
  final Future<void> Function(ProductEntity product) onCommentTap;
  final Future<void> Function(ProductEntity product)? onBrandTap;
  final List<CartItem> cartItems;
  final void Function(ProductEntity product)? onCartIncrement;
  final void Function(ProductEntity product)? onCartDecrement;

  const OffersMasonryGrid({
    super.key,
    required this.controller,
    required this.products,
    required this.wishlistIds,
    required this.isLoadingMore,
    required this.loadingPlaceholdersCount,
    required this.onRefresh,
    required this.onProductTap,
    required this.onWishlistTap,
    required this.onAddToCartTap,
    required this.onShareTap,
    required this.onCommentTap,
    this.onBrandTap,
    this.cartItems = const [],
    this.onCartIncrement,
    this.onCartDecrement,
  });

  @override
  Widget build(BuildContext context) {
    final itemCount =
        products.length + (isLoadingMore ? loadingPlaceholdersCount : 0);

    return RefreshIndicator(
      color: LexiColors.brandPrimary,
      onRefresh: onRefresh,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final columns = _columnsForWidth(constraints.maxWidth);

          return MasonryGridView.builder(
            controller: controller,
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            padding: const EdgeInsetsDirectional.fromSTEB(
              LexiSpacing.md,
              0,
              LexiSpacing.md,
              20,
            ),
            gridDelegate: SliverSimpleGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: columns,
            ),
            mainAxisSpacing: LexiSpacing.md,
            crossAxisSpacing: LexiSpacing.md,
            itemCount: itemCount,
            itemBuilder: (context, index) {
              final cardHeight = _cardHeightFor(
                index,
                constraints.maxWidth,
                context,
              );
              if (index >= products.length) {
                return SizedBox(
                  height: cardHeight,
                  child: const ProductCardSkeleton(),
                );
              }

              final product = products[index];
              final cKey = '${product.id}';
              final cQty =
                  cartItems.where((e) => e.cartKey == cKey).firstOrNull?.qty ??
                  0;
              return SizedBox(
                height: cardHeight,
                child: ProductCard(
                  productId: product.id,
                  heroTag: 'offers-masonry-${product.id}',
                  name: product.name,
                  descriptionSnippet: null,
                  price: CurrencyFormatter.formatAmountOrUnavailable(
                    product.price,
                  ),
                  oldPrice: product.hasDiscount
                      ? CurrencyFormatter.formatAmount(product.regularPrice)
                      : null,
                  imageUrls: product.effectiveCardImages,
                  rating: product.rating,
                  reviewsCount: product.reviewsCount,
                  brandName: product.brandName,
                  onBrandTap: onBrandTap == null
                      ? null
                      : () => onBrandTap!(product),
                  discountPercent: product.discountPercentage,
                  badgeText: product.hasDiscount ? '\u062e\u0635\u0645' : null,
                  isWishlisted: wishlistIds.contains(product.id),
                  canAddToCart: product.inStock && product.price > 0,
                  cartQty: cQty,
                  onIncrement: onCartIncrement != null
                      ? () => onCartIncrement!(product)
                      : null,
                  onDecrement: onCartDecrement != null
                      ? () => onCartDecrement!(product)
                      : null,
                  onTap: () => onProductTap(product),
                  onWishlistToggle: () => onWishlistTap(product),
                  onAddToCart: () => onAddToCartTap(product),
                  onShare: () => onShareTap(product),
                  onComment: () => onCommentTap(product),
                  showSaleCountdown:
                      product.hasDiscount && product.saleEndDate != null,
                  saleEndDate: product.saleEndDate,
                  wishlistCount: product.wishlistCount,
                ),
              );
            },
          );
        },
      ),
    );
  }

  int _columnsForWidth(double width) {
    if (width >= 1200) {
      return 4;
    }
    if (width >= 800) {
      return 3;
    }
    return 2;
  }

  double _cardHeightFor(int index, double maxWidth, BuildContext context) {
    final textScale = MediaQuery.textScalerOf(context).scale(1).clamp(1.0, 1.3);
    final base = switch (maxWidth) {
      >= 1400 => 450.0,
      >= 1000 => 430.0,
      >= 760 => 408.0,
      _ => 394.0,
    };
    final stagger = index.isEven ? 0.0 : 12.0;
    return (base * textScale) + stagger;
  }
}
