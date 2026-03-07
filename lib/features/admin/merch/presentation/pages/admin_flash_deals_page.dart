import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart' as intl;

import '../../../../../core/utils/currency_formatter.dart';
import '../../../../../design_system/lexi_tokens.dart';
import '../../../../../design_system/lexi_typography.dart';
import '../../../../../shared/widgets/lexi_countdown_timer.dart';
import '../../../../../shared/widgets/lexi_ui/lexi_ui.dart';
import '../../../../../ui/widgets/lexi_image.dart';
import '../../domain/entities/admin_merch_product.dart';
import '../controllers/admin_flash_deals_controller.dart';

class AdminFlashDealsPage extends ConsumerWidget {
  const AdminFlashDealsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dealsState = ref.watch(adminFlashDealsControllerProvider);

    return Scaffold(
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/admin/merch/deals/new'),
        child: const Icon(Icons.add_rounded),
      ),
      body: dealsState.when(
        data: (deals) => RefreshIndicator(
          onRefresh: () =>
              ref.read(adminFlashDealsControllerProvider.notifier).refresh(),
          child: deals.isEmpty
              ? _BuildEmptyDeals(
                  onAdd: () => context.push('/admin/merch/deals/new'),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(LexiSpacing.lg),
                  itemCount: deals.length,
                  itemBuilder: (context, index) {
                    final deal = deals[index];
                    return _DealCard(deal: deal);
                  },
                ),
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.error_outline,
                size: 48,
                color: LexiColors.error,
              ),
              const SizedBox(height: LexiSpacing.md),
              Text('حدث خطأ: $err'),
              LexiButton(
                label: 'إعادة المحاولة',
                onPressed: () => ref
                    .read(adminFlashDealsControllerProvider.notifier)
                    .refresh(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DealCard extends ConsumerWidget {
  final AdminMerchProduct deal;

  const _DealCard({required this.deal});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final endsAt = deal.dateOnSaleTo;
    final startsAt = deal.dateOnSaleFrom;
    final remains = endsAt != null
        ? endsAt.difference(DateTime.now())
        : Duration.zero;

    return LexiCard(
      margin: const EdgeInsets.only(bottom: LexiSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (deal.featuredImage != null)
                LexiImage(
                  imageUrl: deal.featuredImage!,
                  width: 60,
                  height: 60,
                  borderRadius: BorderRadius.circular(LexiSpacing.sm),
                ),
              const SizedBox(width: LexiSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      deal.name,
                      style: LexiTypography.h4,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: LexiSpacing.xs),
                    Wrap(
                      spacing: LexiSpacing.xs,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          CurrencyFormatter.formatAmount(deal.salePrice ?? 0),
                          style: LexiTypography.bodyBold.copyWith(
                            color: LexiColors.error,
                          ),
                        ),
                        Text(
                          CurrencyFormatter.formatAmount(deal.regularPrice),
                          style: LexiTypography.bodySmall.copyWith(
                            decoration: TextDecoration.lineThrough,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: LexiSpacing.sm),
              LexiButton(
                label: 'إلغاء',
                onPressed: () => _confirmCancel(context, ref),
                variant: LexiButtonVariant.outline,
                size: LexiButtonSize.small,
              ),
            ],
          ),
          const Divider(height: LexiSpacing.xl),
          Wrap(
            spacing: LexiSpacing.md,
            runSpacing: LexiSpacing.sm,
            alignment: WrapAlignment.spaceBetween,
            children: [
              _InfoItem(
                icon: Icons.calendar_today_rounded,
                label: 'يبدأ',
                value: startsAt != null
                    ? intl.DateFormat('yyyy/MM/dd HH:mm').format(startsAt)
                    : '-',
              ),
              _InfoItem(
                icon: Icons.timer_outlined,
                label: 'ينتهي',
                value: endsAt != null
                    ? intl.DateFormat('yyyy/MM/dd HH:mm').format(endsAt)
                    : '-',
              ),
            ],
          ),
          if (endsAt != null && remains.isNegative)
            Container(
              margin: const EdgeInsets.only(top: LexiSpacing.md),
              padding: const EdgeInsets.all(LexiSpacing.xs),
              width: double.infinity,
              decoration: BoxDecoration(
                color: LexiColors.error.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(LexiSpacing.xs),
              ),
              child: const Text(
                'العرض منتهي',
                textAlign: TextAlign.center,
                style: TextStyle(color: LexiColors.error, fontSize: 12),
              ),
            ),
          if (endsAt != null && !remains.isNegative)
            Container(
              margin: const EdgeInsets.only(top: LexiSpacing.md),
              padding: const EdgeInsets.symmetric(
                horizontal: LexiSpacing.sm,
                vertical: LexiSpacing.xs,
              ),
              decoration: BoxDecoration(
                color: LexiColors.brandPrimary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(LexiRadius.sm),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.flash_on_rounded, size: 16),
                  const SizedBox(width: LexiSpacing.xs),
                  Text('الوقت المتبقي:', style: LexiTypography.bodySmallBold),
                  const SizedBox(width: LexiSpacing.xs),
                  LexiCountdownTimer(
                    endTime: endsAt,
                    boxColor: LexiColors.darkBlack,
                    textStyle: LexiTypography.caption.copyWith(
                      color: LexiColors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  void _confirmCancel(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('إلغاء العرض؟'),
        content: Text('هل أنت متأكد من إلغاء العرض على "${deal.name}"؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('رجوع'),
          ),
          TextButton(
            onPressed: () {
              ref
                  .read(adminFlashDealsControllerProvider.notifier)
                  .cancelDeal(deal.id);
              Navigator.pop(context);
            },
            child: const Text(
              'نعم، إلغاء',
              style: TextStyle(color: LexiColors.error),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoItem({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 14, color: LexiColors.brandGrey),
        const SizedBox(width: LexiSpacing.xs),
        Text('$label: ', style: LexiTypography.bodySmall),
        Text(value, style: LexiTypography.bodySmallBold),
      ],
    );
  }
}

class _BuildEmptyDeals extends StatelessWidget {
  final VoidCallback onAdd;

  const _BuildEmptyDeals({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.flash_off_rounded,
            size: 64,
            color: LexiColors.brandGrey.withValues(alpha: 0.5),
          ),
          const SizedBox(height: LexiSpacing.lg),
          Text('لا يوجد عروض فلاش نشطة حالياً', style: LexiTypography.h4),
          const SizedBox(height: LexiSpacing.md),
          LexiButton(label: 'إضافة عرض جديد', onPressed: onAdd),
        ],
      ),
    );
  }
}
