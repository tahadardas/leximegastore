import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:flutter/services.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../core/errors/arabic_error_mapper.dart';
import '../../../../core/utils/color_swatch_mapper.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../shared/widgets/error_state.dart';
import '../../../../shared/widgets/lexi_network_image.dart';
import '../../../../shared/widgets/lexi_ui/lexi_drawer.dart';
import '../../../../ui/lexi_design/lexi_colors.dart';
import '../../../../ui/lexi_design/lexi_radius.dart';
import '../../../../ui/lexi_design/lexi_shadows.dart';
import '../../../../ui/lexi_design/lexi_spacing.dart';
import '../../../../ui/lexi_design/lexi_typography.dart';
import '../../../../ui/widgets/lexi_safe_bottom.dart';
import '../../../shipping/presentation/controllers/shipping_controller.dart';
import '../../domain/entities/cart_item.dart';
import '../controllers/cart_controller.dart';
import '../widgets/cart_ai_section.dart';
import '../../../../core/ai/ai_tracker.dart';

class CartPage extends ConsumerStatefulWidget {
  const CartPage({super.key});

  @override
  ConsumerState<CartPage> createState() => _CartPageState();
}

class _CartPageState extends ConsumerState<CartPage> {
  final TextEditingController _couponController = TextEditingController();

  @override
  void dispose() {
    _couponController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cartAsync = ref.watch(cartControllerProvider);

    return Scaffold(
      drawer: const LexiDrawer(),
      backgroundColor: LexiCommercialColors.background,
      appBar: AppBar(
        title: const Text('سلة المشتريات'),
        actions: [
          cartAsync.whenOrNull(
                data: (cart) => cart.isNotEmpty
                    ? IconButton(
                        tooltip: 'إفراغ السلة',
                        onPressed: () => _confirmClear(context, ref),
                        icon: const FaIcon(FontAwesomeIcons.trashCan, size: 16),
                      )
                    : null,
              ) ??
              const SizedBox.shrink(),
          const SizedBox(width: 4),
        ],
      ),
      body: cartAsync.when(
        loading: () =>
            const _CartLoadingSkeleton(key: ValueKey('cart_loading')),
        error: (error, stackTrace) => ErrorState(
          key: const ValueKey('cart_error'),
          message: 'تعذر تحميل السلة حالياً. حاول مجددًا.',
          onRetry: () => ref.invalidate(cartControllerProvider),
        ),
        data: (cart) {
          if (cart.isEmpty) {
            return const _EmptyCartCommercial(key: ValueKey('cart_empty'));
          }

          return SafeArea(
            child: Column(
              key: const ValueKey('cart_content'),
              children: [
                Expanded(
                  child: ListView.separated(
                    padding: const EdgeInsetsDirectional.fromSTEB(
                      LexiCommercialSpacing.s12,
                      LexiCommercialSpacing.s12,
                      LexiCommercialSpacing.s12,
                      8,
                    ),
                    itemCount: cart.items.length + 1,
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: LexiCommercialSpacing.s8),
                    itemBuilder: (context, index) {
                      if (index == cart.items.length) {
                        return const CartAISection();
                      }
                      final item = cart.items[index];
                      return _CartItemCard(item: item);
                    },
                  ),
                ),
                _CartCheckoutPanel(
                  cart: cart,
                  couponController: _couponController,
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _confirmClear(BuildContext context, WidgetRef ref) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('إفراغ السلة'),
        content: const Text('هل تريد حذف جميع المنتجات من السلة؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('إلغاء'),
          ),
          TextButton(
            onPressed: () {
              ref.read(cartControllerProvider.notifier).clearCart();
              Navigator.of(ctx).pop();
            },
            style: TextButton.styleFrom(
              foregroundColor: LexiCommercialColors.discountRed,
            ),
            child: const Text('إفراغ'),
          ),
        ],
      ),
    );
  }
}

class _EmptyCartCommercial extends StatelessWidget {
  const _EmptyCartCommercial({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(LexiCommercialSpacing.s24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 116,
              height: 116,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: LexiCommercialColors.gray100,
                border: Border.all(color: LexiCommercialColors.gray200),
              ),
              child: const Center(
                child: FaIcon(
                  FontAwesomeIcons.cartShopping,
                  size: 38,
                  color: LexiCommercialColors.gray500,
                ),
              ),
            ),
            const SizedBox(height: LexiCommercialSpacing.s16),
            Text('سلتك فارغة الآن', style: LexiCommercialTypography.h2),
            const SizedBox(height: LexiCommercialSpacing.s8),
            Text(
              'ابدأ التسوق وأضف المنتجات التي تعجبك.',
              style: LexiCommercialTypography.body,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: LexiCommercialSpacing.s16),
            SizedBox(
              width: 180,
              child: ElevatedButton.icon(
                onPressed: () => context.goNamedSafe(AppRouteNames.home),
                icon: const FaIcon(FontAwesomeIcons.bagShopping, size: 14),
                label: const Text('ابدأ التسوق'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CartItemCard extends ConsumerWidget {
  final CartItem item;

  const _CartItemCard({required this.item});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Dismissible(
      key: ValueKey('cart-item-${item.cartKey}'),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: AlignmentDirectional.centerEnd,
        padding: const EdgeInsets.symmetric(
          horizontal: LexiCommercialSpacing.s16,
        ),
        decoration: BoxDecoration(
          color: LexiCommercialColors.discountRed,
          borderRadius: BorderRadius.circular(LexiCommercialRadius.card),
        ),
        child: const FaIcon(
          FontAwesomeIcons.trashCan,
          color: LexiCommercialColors.white,
          size: 16,
        ),
      ),
      onDismissed: (_) {
        HapticFeedback.mediumImpact();
        ref.read(cartControllerProvider.notifier).removeItem(item.cartKey);
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            lexiFloatingSnackBar(
              context,
              content: const Text('تمت إزالة المنتج من السلة'),
              backgroundColor: LexiCommercialColors.darkBlack,
            ),
          );
      },
      child: Container(
        padding: const EdgeInsets.all(LexiCommercialSpacing.s12),
        decoration: BoxDecoration(
          color: LexiCommercialColors.white,
          borderRadius: BorderRadius.circular(LexiCommercialRadius.card),
          boxShadow: LexiCommercialShadows.card,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(LexiCommercialRadius.button),
              child: Container(
                width: 84,
                height: 84,
                color: LexiCommercialColors.gray100,
                child: item.image.isNotEmpty
                    ? LexiNetworkImage(
                        imageUrl: item.image,
                        width: 84,
                        height: 84,
                        fit: BoxFit.cover,
                        errorWidget: const Center(
                          child: FaIcon(
                            FontAwesomeIcons.image,
                            size: 16,
                            color: LexiCommercialColors.gray500,
                          ),
                        ),
                      )
                    : const Center(
                        child: FaIcon(
                          FontAwesomeIcons.image,
                          size: 16,
                          color: LexiCommercialColors.gray500,
                        ),
                      ),
              ),
            ),
            const SizedBox(width: LexiCommercialSpacing.s12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: LexiCommercialTypography.title,
                  ),
                  const SizedBox(height: LexiCommercialSpacing.s4),
                  if (item.variationLabel != null) ...[
                    Row(
                      children: [
                        if (ColorSwatchMapper.map(item.variationLabel!) !=
                            null) ...[
                          Container(
                            width: 12,
                            height: 12,
                            decoration: BoxDecoration(
                              color: ColorSwatchMapper.map(
                                item.variationLabel!,
                              ),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: LexiCommercialColors.gray300,
                                width: 0.5,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                        ],
                        Text(
                          item.variationLabel!,
                          style: LexiCommercialTypography.caption.copyWith(
                            color: LexiCommercialColors.gray700,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: LexiCommercialSpacing.s4),
                  ],
                  Text(
                    CurrencyFormatter.formatAmount(item.price),
                    style: LexiCommercialTypography.caption,
                  ),
                  const SizedBox(height: LexiCommercialSpacing.s12),
                  Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: LexiCommercialSpacing.s8,
                    runSpacing: LexiCommercialSpacing.s4,
                    children: [
                      _QtyStepper(item: item),
                      Text(
                        CurrencyFormatter.formatAmount(item.lineTotal),
                        style: LexiCommercialTypography.title.copyWith(
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            IconButton(
              onPressed: () => ref
                  .read(cartControllerProvider.notifier)
                  .removeItem(item.cartKey),
              tooltip: 'إزالة',
              icon: const FaIcon(
                FontAwesomeIcons.trash,
                size: 13,
                color: LexiCommercialColors.discountRed,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QtyStepper extends ConsumerWidget {
  final CartItem item;

  const _QtyStepper({required this.item});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      decoration: BoxDecoration(
        color: LexiCommercialColors.gray50,
        borderRadius: BorderRadius.circular(LexiCommercialRadius.full),
        border: Border.all(color: LexiCommercialColors.gray200),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _StepperButton(
            icon: item.qty > 1
                ? FontAwesomeIcons.minus
                : FontAwesomeIcons.trash,
            iconColor: item.qty > 1
                ? LexiCommercialColors.darkBlack
                : LexiCommercialColors.discountRed,
            onTap: () => ref
                .read(cartControllerProvider.notifier)
                .decrement(item.cartKey),
          ),
          Container(
            constraints: const BoxConstraints(minWidth: 34),
            alignment: Alignment.center,
            child: Text('${item.qty}', style: LexiCommercialTypography.title),
          ),
          _StepperButton(
            icon: FontAwesomeIcons.plus,
            onTap: () => ref
                .read(cartControllerProvider.notifier)
                .increment(item.cartKey),
          ),
        ],
      ),
    );
  }
}

class _StepperButton extends StatelessWidget {
  final IconData icon;
  final Color? iconColor;
  final VoidCallback onTap;

  const _StepperButton({
    required this.icon,
    required this.onTap,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: 30,
          height: 30,
          child: Center(
            child: FaIcon(
              icon,
              size: 11,
              color: iconColor ?? LexiCommercialColors.darkBlack,
            ),
          ),
        ),
      ),
    );
  }
}

class _CartCheckoutPanel extends ConsumerWidget {
  final CartState cart;
  final TextEditingController couponController;

  const _CartCheckoutPanel({
    required this.cart,
    required this.couponController,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final shippingCostAsync = ref.watch(shippingCostProvider);
    final selectedCity = ref.watch(selectedCityProvider);
    final shippingCost = shippingCostAsync.valueOrNull ?? 0.0;
    final total = cart.total + shippingCost;
    final canCheckout = !shippingCostAsync.isLoading;

    const freeShippingThreshold = 250000.0;
    final freeShippingProgress = (cart.subtotal / freeShippingThreshold)
        .clamp(0, 1)
        .toDouble();
    final missingForFreeShipping = (freeShippingThreshold - cart.subtotal)
        .clamp(0, double.infinity)
        .toDouble();

    return Container(
      padding: const EdgeInsetsDirectional.fromSTEB(
        LexiCommercialSpacing.s12,
        LexiCommercialSpacing.s12,
        LexiCommercialSpacing.s12,
        LexiCommercialSpacing.s8,
      ),
      decoration: BoxDecoration(
        color: LexiCommercialColors.white,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(LexiCommercialRadius.bottomSheet),
        ),
        boxShadow: LexiCommercialShadows.card,
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _FreeShippingBanner(
              progress: freeShippingProgress,
              missing: missingForFreeShipping,
              threshold: freeShippingThreshold,
            ),
            const SizedBox(height: LexiCommercialSpacing.s12),
            _CouponInput(controller: couponController),
            const SizedBox(height: LexiCommercialSpacing.s12),
            Container(
              padding: const EdgeInsets.all(LexiCommercialSpacing.s12),
              decoration: BoxDecoration(
                color: LexiCommercialColors.gray50,
                borderRadius: BorderRadius.circular(LexiCommercialRadius.card),
                border: Border.all(color: LexiCommercialColors.gray200),
              ),
              child: Column(
                children: [
                  _SummaryRow(
                    label: 'المجموع الفرعي (${cart.totalQty} عنصر)',
                    value: CurrencyFormatter.formatAmount(cart.subtotal),
                  ),
                  if (cart.discountAmount > 0)
                    Padding(
                      padding: const EdgeInsets.only(
                        top: LexiCommercialSpacing.s8,
                      ),
                      child: _SummaryRow(
                        label: 'خصم القسيمة',
                        value:
                            '- ${CurrencyFormatter.formatAmount(cart.discountAmount)}',
                        textColor: LexiCommercialColors.discountRed,
                      ),
                    ),
                  const SizedBox(height: LexiCommercialSpacing.s8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('الشحن', style: LexiCommercialTypography.body),
                      if (shippingCostAsync.isLoading)
                        const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      else
                        Text(
                          selectedCity == null
                              ? 'سيتم تحديده في الدفع'
                              : CurrencyFormatter.formatAmount(shippingCost),
                          style: LexiCommercialTypography.body.copyWith(
                            color: LexiCommercialColors.successGreen,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                    ],
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(
                      vertical: LexiCommercialSpacing.s8,
                    ),
                    child: Divider(height: 1),
                  ),
                  _SummaryRow(
                    label: 'الإجمالي',
                    value: CurrencyFormatter.formatAmount(total),
                    bold: true,
                  ),
                ],
              ),
            ),
            const SizedBox(height: LexiCommercialSpacing.s12),
            DecoratedBox(
              decoration: BoxDecoration(boxShadow: LexiCommercialShadows.cta),
              child: SizedBox(
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: canCheckout
                      ? () {
                          ref
                              .read(aiTrackerProvider)
                              .checkoutStart(total: total);
                          context.pushNamedIfNotCurrent(AppRouteNames.checkout);
                        }
                      : null,
                  icon: const FaIcon(FontAwesomeIcons.arrowLeftLong, size: 13),
                  label: const Text('إتمام الطلب'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FreeShippingBanner extends StatelessWidget {
  final double progress;
  final double missing;
  final double threshold;

  const _FreeShippingBanner({
    required this.progress,
    required this.missing,
    required this.threshold,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(LexiCommercialSpacing.s12),
      decoration: BoxDecoration(
        color: LexiCommercialColors.gray50,
        borderRadius: BorderRadius.circular(LexiCommercialRadius.card),
        border: Border.all(color: LexiCommercialColors.gray200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'الشحن المجاني عند ${CurrencyFormatter.formatAmount(threshold)}',
            style: LexiCommercialTypography.title.copyWith(fontSize: 13),
          ),
          const SizedBox(height: LexiCommercialSpacing.s8),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              minHeight: 8,
              value: progress,
              color: LexiCommercialColors.successGreen,
              backgroundColor: LexiCommercialColors.gray200,
            ),
          ),
          const SizedBox(height: LexiCommercialSpacing.s8),
          Text(
            missing <= 0
                ? 'رائع! طلبك أصبح مؤهلاً للشحن المجاني.'
                : 'أضف ${CurrencyFormatter.formatAmount(missing)} لتحصل على شحن مجاني.',
            style: LexiCommercialTypography.caption,
          ),
        ],
      ),
    );
  }
}

class _CouponInput extends ConsumerWidget {
  final TextEditingController controller;

  const _CouponInput({required this.controller});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cartState = ref.watch(cartControllerProvider);
    final isApplying = cartState.valueOrNull?.isCouponApplying ?? false;
    final appliedCoupon = cartState.valueOrNull?.appliedCoupon;

    if (appliedCoupon != null) {
      return Container(
        padding: const EdgeInsets.all(LexiCommercialSpacing.s12),
        decoration: BoxDecoration(
          color: LexiCommercialColors.successGreen.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(LexiCommercialRadius.card),
          border: Border.all(color: LexiCommercialColors.successGreen),
        ),
        child: Row(
          children: [
            const FaIcon(
              FontAwesomeIcons.circleCheck,
              size: 16,
              color: LexiCommercialColors.successGreen,
            ),
            const SizedBox(width: LexiCommercialSpacing.s12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'قسيمة: ${appliedCoupon.code}',
                    style: LexiCommercialTypography.title.copyWith(
                      color: LexiCommercialColors.successGreen,
                    ),
                  ),
                  if (appliedCoupon.description != null)
                    Text(
                      appliedCoupon.description!,
                      style: LexiCommercialTypography.caption.copyWith(
                        color: LexiCommercialColors.successGreen,
                      ),
                    ),
                ],
              ),
            ),
            IconButton(
              onPressed: () {
                ref.read(cartControllerProvider.notifier).removeCoupon();
                controller.clear();
              },
              icon: const FaIcon(
                FontAwesomeIcons.xmark,
                size: 16,
                color: LexiCommercialColors.discountRed,
              ),
              tooltip: 'إزالة القسيمة',
            ),
          ],
        ),
      );
    }

    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: controller,
            textInputAction: TextInputAction.done,
            enabled: !isApplying,
            decoration: const InputDecoration(
              hintText: 'أدخل كود القسيمة',
              prefixIcon: Padding(
                padding: EdgeInsets.only(top: 14),
                child: FaIcon(
                  FontAwesomeIcons.ticket,
                  size: 14,
                  color: LexiCommercialColors.gray500,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: LexiCommercialSpacing.s8),
        SizedBox(
          width: 100,
          height: 46,
          child: ElevatedButton(
            onPressed: isApplying
                ? null
                : () async {
                    final code = controller.text.trim();
                    if (code.isEmpty) return;

                    FocusScope.of(context).unfocus();
                    try {
                      await ref
                          .read(cartControllerProvider.notifier)
                          .applyCoupon(code);

                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          lexiFloatingSnackBar(
                            context,
                            content: const Text('تم تطبيق القسيمة بنجاح!'),
                            backgroundColor: LexiCommercialColors.successGreen,
                          ),
                        );
                      }
                    } catch (e) {
                      if (context.mounted) {
                        final message = ArabicErrorMapper.map(
                          e,
                          fallback: 'تعذر تطبيق القسيمة حالياً. حاول مرة أخرى.',
                        );
                        ScaffoldMessenger.of(context).showSnackBar(
                          lexiFloatingSnackBar(
                            context,
                            content: Text(message),
                            backgroundColor: LexiCommercialColors.discountRed,
                          ),
                        );
                      }
                    }
                  },
            style: ElevatedButton.styleFrom(
              backgroundColor: LexiCommercialColors.darkBlack,
              foregroundColor: LexiCommercialColors.white,
              padding: const EdgeInsets.symmetric(
                horizontal: LexiCommercialSpacing.s12,
              ),
            ),
            child: isApplying
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                : const Text('تطبيق'),
          ),
        ),
      ],
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? textColor;
  final bool bold;

  const _SummaryRow({
    required this.label,
    required this.value,
    this.bold = false,
    this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    final style =
        (bold ? LexiCommercialTypography.h3 : LexiCommercialTypography.body)
            .copyWith(color: textColor);

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: style),
        Text(value, style: style),
      ],
    );
  }
}

class _CartLoadingSkeleton extends StatelessWidget {
  const _CartLoadingSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(LexiCommercialSpacing.s12),
      children: [
        ...List.generate(4, (index) {
          return Padding(
            padding: const EdgeInsets.only(bottom: LexiCommercialSpacing.s8),
            child: Container(
              key: ValueKey('skeleton_item_$index'),
              height: 116,
              decoration: BoxDecoration(
                color: LexiCommercialColors.gray100,
                borderRadius: BorderRadius.circular(LexiCommercialRadius.card),
              ),
            ),
          );
        }),
        const SizedBox(height: LexiCommercialSpacing.s12),
        Container(
          height: 220,
          decoration: BoxDecoration(
            color: LexiCommercialColors.gray100,
            borderRadius: BorderRadius.circular(LexiCommercialRadius.card),
          ),
        ),
      ],
    );
  }
}
