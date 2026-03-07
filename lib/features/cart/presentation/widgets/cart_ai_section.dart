import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../core/ai/ai_reco_api.dart';
import '../../../../core/session/app_session.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../shared/services/share_service.dart';
import '../../../../shared/ui/lexi_alert.dart';
import '../../../../shared/widgets/product_card.dart';
import '../../../../design_system/lexi_tokens.dart';
import '../../../../design_system/lexi_typography.dart';
import '../../../wishlist/presentation/controllers/wishlist_controller.dart';
import '../../domain/entities/cart_item.dart';
import '../controllers/cart_controller.dart';

class CartAISection extends ConsumerWidget {
  const CartAISection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // We can use Trending or specific cart-based logic here.
    // For now, using Trending as a "You might also like" generic section.
    final asyncData = ref.watch(trendingProductsProvider);

    return asyncData.when(
      data: (products) {
        if (products.isEmpty) {
          return const SizedBox.shrink();
        }
        // Take top 10
        final displayProducts = products.take(10).toList();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: LexiSpacing.s12),
              child: Text('قد يعجبك أيضاً', style: LexiTypography.h4),
            ),
            const SizedBox(height: LexiSpacing.s12),
            SizedBox(
              height: 318,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(
                  horizontal: LexiSpacing.s12,
                ),
                itemCount: displayProducts.length,
                separatorBuilder: (context, index) =>
                    const SizedBox(width: LexiSpacing.s12),
                itemBuilder: (context, index) {
                  final p = displayProducts[index];
                  final wishlistIds = ref.watch(wishlistIdsProvider);
                  final isWishlisted = wishlistIds.contains(p.id);
                  final cItems =
                      ref.watch(cartControllerProvider).valueOrNull?.items ??
                      const <CartItem>[];
                  final cKey = '${p.id}';
                  final cQty =
                      cItems.where((e) => e.cartKey == cKey).firstOrNull?.qty ??
                      0;

                  return SizedBox(
                    width: 206,
                    child: ProductCard(
                      productId: p.id,
                      heroTag: 'cart-ai-${p.id}',
                      name: p.name,
                      descriptionSnippet: p.shortDescription.isNotEmpty
                          ? p.shortDescription
                          : p.description,
                      price: CurrencyFormatter.formatAmountOrUnavailable(
                        p.price,
                      ),
                      oldPrice: p.hasDiscount
                          ? CurrencyFormatter.formatAmount(p.regularPrice)
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
                      isWishlisted: isWishlisted,
                      canAddToCart: p.inStock && p.price > 0,
                      cartQty: cQty,
                      onIncrement: () => ref
                          .read(cartControllerProvider.notifier)
                          .increment(cKey),
                      onDecrement: () => ref
                          .read(cartControllerProvider.notifier)
                          .decrement(cKey),
                      onTap: () => context.push('/product/${p.id}'),
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
                        if (!ref.read(appSessionProvider).isLoggedIn) {
                          await LexiAlert.info(
                            context,
                            text: 'يرجى تسجيل الدخول لإضافة تعليق',
                          );
                          return;
                        }
                        if (!context.mounted) return;
                        context.push('/product/${p.id}?focus=reviews');
                      },
                      onWishlistToggle: () async {
                        await ref
                            .read(wishlistControllerProvider.notifier)
                            .toggle(p.id, product: p);
                      },
                      wishlistCount: p.wishlistCount,
                      onAddToCart: () async {
                        await ref
                            .read(cartControllerProvider.notifier)
                            .addItem(
                              CartItem(
                                productId: p.id,
                                name: p.name,
                                price: p.effectivePrice,
                                image: p.primaryImageUrl ?? p.primaryImage,
                                qty: 1,
                              ),
                            );
                      },
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: LexiSpacing.s24),
          ],
        );
      },
      error: (e, s) => const SizedBox.shrink(),
      loading: () => const SizedBox.shrink(),
    );
  }
}
