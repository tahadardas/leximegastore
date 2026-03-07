import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/color_swatch_mapper.dart';
import '../../design_system/lexi_tokens.dart';
import '../../design_system/lexi_typography.dart';
import '../../features/cart/domain/entities/cart_item.dart';
import '../../features/product/domain/entities/product_entity.dart';
import '../../features/product/domain/entities/product_extras.dart';
import '../../features/product/presentation/controllers/product_extras_controller.dart';
import 'app_button.dart';

class VariationPickerDialog extends ConsumerStatefulWidget {
  final ProductEntity product;

  const VariationPickerDialog({super.key, required this.product});

  static Future<CartItem?> show(BuildContext context, ProductEntity product) {
    return showModalBottomSheet<CartItem>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => VariationPickerDialog(product: product),
    );
  }

  @override
  ConsumerState<VariationPickerDialog> createState() =>
      _VariationPickerDialogState();
}

class _VariationPickerDialogState extends ConsumerState<VariationPickerDialog> {
  ProductVariationOption? _selectedVariation;

  @override
  Widget build(BuildContext context) {
    final extrasAsync = ref.watch(
      productDetailsExtrasProvider(widget.product.id),
    );

    return Container(
      decoration: const BoxDecoration(
        color: LexiColors.white,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(LexiRadius.sheet),
        ),
      ),
      padding: EdgeInsets.only(
        top: LexiSpacing.s24,
        left: LexiSpacing.s20,
        right: LexiSpacing.s20,
        bottom: MediaQuery.of(context).padding.bottom + LexiSpacing.s20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'اختر اللون / التنوع',
                      style: LexiTypography.h4.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.product.name,
                      style: LexiTypography.bodyMd.copyWith(
                        color: LexiColors.textSecondary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close),
              ),
            ],
          ),
          const SizedBox(height: LexiSpacing.s24),
          extrasAsync.when(
            data: (extras) {
              final variations = extras.variations
                  .where((v) => v.inStock)
                  .toList();

              if (variations.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: LexiSpacing.s40),
                  child: Center(
                    child: Text(
                      'عذراً، لا يوجد تنوعات متوفرة حالياً لهذه المنتجات.',
                    ),
                  ),
                );
              }

              return Column(
                children: [
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: variations.map((v) {
                      final isSelected = _selectedVariation?.id == v.id;
                      final swatchColor = ColorSwatchMapper.map(
                        v.color.isNotEmpty ? v.color : v.label,
                      );

                      return GestureDetector(
                        onTap: () => setState(() => _selectedVariation = v),
                        child: AnimatedContainer(
                          duration: LexiDurations.fast,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? LexiColors.brandPrimary.withValues(alpha: 0.1)
                                : LexiColors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isSelected
                                  ? LexiColors.brandPrimary
                                  : LexiColors.neutral200,
                              width: isSelected ? 2 : 1,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (swatchColor != null) ...[
                                Container(
                                  width: 18,
                                  height: 18,
                                  decoration: BoxDecoration(
                                    color: swatchColor,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: LexiColors.neutral300,
                                      width: 0.5,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                              ],
                              Text(
                                v.label,
                                style: LexiTypography.bodyMd.copyWith(
                                  fontWeight: isSelected
                                      ? FontWeight.w800
                                      : FontWeight.w600,
                                  color: isSelected
                                      ? LexiColors.brandPrimary
                                      : LexiColors.textPrimary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: LexiSpacing.s32),
                  AppButton(
                    label: 'إضافة إلى السلة',
                    isLoading: false,
                    onPressed: _selectedVariation == null
                        ? null
                        : () {
                            final variant = _selectedVariation!;
                            final item = CartItem(
                              productId: widget.product.id,
                              variationId: variant.id,
                              name: widget.product.name,
                              variationLabel: variant.label,
                              price: variant.price > 0
                                  ? variant.price
                                  : widget.product.price,
                              image:
                                  variant.imageUrl ??
                                  widget.product.primaryImage,
                              qty: 1,
                            );
                            Navigator.pop(context, item);
                          },
                  ),
                ],
              );
            },
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: LexiSpacing.s40),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (err, _) => Padding(
              padding: const EdgeInsets.symmetric(vertical: LexiSpacing.s40),
              child: Center(child: Text('خطأ في جلب البيانات: $err')),
            ),
          ),
        ],
      ),
    );
  }
}
