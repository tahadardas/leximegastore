import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../l10n/l10n.dart';
import '../../../../shared/widgets/error_state.dart';
import '../../../../shared/widgets/product_card.dart';
import '../../../../design_system/lexi_tokens.dart';
import '../../../../design_system/lexi_typography.dart';
import '../../../../shared/widgets/lexi_ui/lexi_app_bar.dart';
import '../../../../shared/widgets/lexi_ui/lexi_grid_skeleton.dart';
import '../controllers/wishlist_controller.dart';
import '../../../cart/presentation/controllers/cart_controller.dart';
import 'package:lexi_mega_store/core/utils/currency_formatter.dart';
import '../../../cart/domain/entities/cart_item.dart';

class WishlistPage extends ConsumerWidget {
  const WishlistPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final state = ref.watch(wishlistControllerProvider);

    return Scaffold(
      backgroundColor: LexiColors.neutral50,
      appBar: LexiAppBar(title: l10n.appWishlistTitle),
      body: RefreshIndicator(
        onRefresh: () =>
            ref.read(wishlistControllerProvider.notifier).refresh(),
        child: state.when(
          loading: () => const Padding(
            padding: EdgeInsets.all(LexiSpacing.s12),
            child: LexiGridSkeleton(),
          ),
          error: (error, _) => ErrorState(
            message: l10n.wishlistLoadFailed,
            onRetry: () =>
                ref.read(wishlistControllerProvider.notifier).refresh(),
          ),
          data: (products) {
            if (products.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const FaIcon(
                      FontAwesomeIcons.heartCrack,
                      size: 64,
                      color: LexiColors.neutral300,
                    ),
                    const SizedBox(height: LexiSpacing.s16),
                    Text(
                      l10n.wishlistEmptyTitle,
                      style: LexiTypography.h4.copyWith(
                        color: LexiColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: LexiSpacing.s8),
                    TextButton(
                      onPressed: () => context.goNamedSafe(AppRouteNames.home),
                      child: Text(l10n.wishlistBrowseProducts),
                    ),
                  ],
                ),
              );
            }

            return GridView.builder(
              padding: const EdgeInsets.all(LexiSpacing.s12),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 0.56,
                crossAxisSpacing: LexiSpacing.s12,
                mainAxisSpacing: LexiSpacing.s12,
              ),
              itemCount: products.length,
              itemBuilder: (context, index) {
                final product = products[index];
                final cItems =
                    ref.watch(cartControllerProvider).valueOrNull?.items ??
                    const <CartItem>[];
                final cKey = '${product.id}';
                final cQty =
                    cItems.where((e) => e.cartKey == cKey).firstOrNull?.qty ??
                    0;
                return ProductCard(
                  productId: product.id,
                  name: product.name,
                  price: CurrencyFormatter.formatAmountOrUnavailable(
                    product.price,
                  ),
                  oldPrice: product.hasDiscount
                      ? CurrencyFormatter.formatAmount(product.regularPrice)
                      : null,
                  imageUrl:
                      product.image.cardUrl ??
                      product.primaryImageUrl ??
                      product.primaryImage,
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
                  isWishlisted: true,
                  canAddToCart: product.inStock && product.price > 0,
                  cartQty: cQty,
                  onIncrement: () =>
                      ref.read(cartControllerProvider.notifier).increment(cKey),
                  onDecrement: () =>
                      ref.read(cartControllerProvider.notifier).decrement(cKey),
                  onTap: () => context.pushNamedIfNotCurrent(
                    AppRouteNames.product,
                    pathParameters: {'id': '${product.id}'},
                  ),
                  onWishlistToggle: () => ref
                      .read(wishlistControllerProvider.notifier)
                      .toggle(product.id, product: product),
                  onAddToCart: () async {
                    final item = CartItem(
                      productId: product.id,
                      name: product.name,
                      price: product.effectivePrice,
                      image: product.primaryImageUrl ?? product.primaryImage,
                      qty: 1,
                    );
                    await ref
                        .read(cartControllerProvider.notifier)
                        .addItem(item);
                  },
                );
              },
            );
          },
        ),
      ),
    );
  }
}
