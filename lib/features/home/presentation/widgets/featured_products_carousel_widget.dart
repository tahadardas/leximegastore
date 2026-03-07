import 'package:carousel_slider/carousel_slider.dart';
import 'package:flutter/material.dart';

import '../../../../core/utils/currency_formatter.dart';
import '../../../../design_system/lexi_tokens.dart';
import '../../../../features/cart/domain/entities/cart_item.dart';
import '../../../../features/product/domain/entities/product_entity.dart';
import '../../../../shared/widgets/product_card.dart';

class FeaturedProductsCarouselWidget extends StatelessWidget {
  final List<ProductEntity> products;
  final Set<int> wishlistIds;
  final List<CartItem> cartItems;
  final String heroTagPrefix;
  final ValueChanged<ProductEntity> onProductTap;
  final Future<void> Function(ProductEntity product) onWishlistTap;
  final Future<void> Function(ProductEntity product) onAddToCartTap;
  final Future<void> Function(ProductEntity product) onShareTap;
  final Future<void> Function(ProductEntity product) onCommentTap;
  final Future<void> Function(ProductEntity product)? onBrandTap;
  final void Function(ProductEntity product)? onCartIncrement;
  final void Function(ProductEntity product)? onCartDecrement;

  const FeaturedProductsCarouselWidget({
    super.key,
    required this.products,
    required this.wishlistIds,
    this.cartItems = const [],
    required this.heroTagPrefix,
    required this.onProductTap,
    required this.onWishlistTap,
    required this.onAddToCartTap,
    required this.onShareTap,
    required this.onCommentTap,
    this.onBrandTap,
    this.onCartIncrement,
    this.onCartDecrement,
  });

  @override
  Widget build(BuildContext context) {
    if (products.isEmpty) {
      return const SizedBox.shrink();
    }

    final displayProducts = products.take(10).toList(growable: false);

    return LayoutBuilder(
      builder: (context, constraints) {
        final viewportFraction = _viewportFractionForWidth(
          constraints.maxWidth,
        );

        return CarouselSlider.builder(
          itemCount: displayProducts.length,
          options: CarouselOptions(
            height: 345,
            viewportFraction: viewportFraction,
            padEnds: false,
            disableCenter: true,
            enableInfiniteScroll: displayProducts.length > 2,
            autoPlay: false,
            enlargeCenterPage: false,
          ),
          itemBuilder: (context, index, realIndex) {
            final product = displayProducts[index];
            final heroTag = '$heroTagPrefix${product.id}';
            final cKey = '${product.id}';
            final cQty =
                cartItems.where((e) => e.cartKey == cKey).firstOrNull?.qty ?? 0;

            return Padding(
              padding: const EdgeInsetsDirectional.only(end: LexiSpacing.s12),
              child: ProductCard(
                productId: product.id,
                heroTag: heroTag,
                name: product.name,
                descriptionSnippet: product.shortDescription.isNotEmpty
                    ? product.shortDescription
                    : product.description,
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
                badgeText: product.hasDiscount ? 'خصم' : null,
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
                onTap: () => onProductTap(product),
                onWishlistToggle: () => onWishlistTap(product),
                onAddToCart: () => onAddToCartTap(product),
                onShare: () => onShareTap(product),
                onComment: () => onCommentTap(product),
                saleEndDate: product.saleEndDate,
                wishlistCount: product.wishlistCount,
              ),
            );
          },
        );
      },
    );
  }

  double _viewportFractionForWidth(double width) {
    if (width >= 1200) {
      return 0.24;
    }
    if (width >= 900) {
      return 0.31;
    }
    if (width >= 700) {
      return 0.38;
    }
    return 0.58;
  }
}
