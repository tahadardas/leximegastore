import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart' as intl;

import '../../../../../design_system/lexi_tokens.dart';
import '../../../../../design_system/lexi_typography.dart';
import '../../../../../shared/widgets/lexi_ui/lexi_ui.dart';
import '../../domain/entities/admin_review.dart';
import '../controllers/admin_reviews_controller.dart';

class AdminReviewsPage extends StatelessWidget {
  const AdminReviewsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        body: Column(
          children: [
            Material(
              color: LexiColors.brandWhite,
              child: const TabBar(
                labelColor: LexiColors.brandPrimary,
                unselectedLabelColor: LexiColors.brandGrey,
                indicatorColor: LexiColors.brandPrimary,
                tabs: [
                  Tab(text: 'قيد الانتظار'),
                  Tab(text: 'تمت الموافقة'),
                  Tab(text: 'المحذوفات'),
                ],
              ),
            ),
            const Expanded(
              child: TabBarView(
                children: [
                  _ReviewsList(status: 'pending'),
                  _ReviewsList(status: 'approved'),
                  _ReviewsList(status: 'trash'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReviewsList extends ConsumerWidget {
  final String status;

  const _ReviewsList({required this.status});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reviewsState = ref.watch(adminReviewsControllerProvider(status));

    return reviewsState.when(
      data: (reviews) => RefreshIndicator(
        onRefresh: () =>
            ref.read(adminReviewsControllerProvider(status).notifier).refresh(),
        child: reviews.isEmpty
            ? _BuildEmptyState(status: status)
            : ListView.builder(
                padding: const EdgeInsets.all(LexiSpacing.lg),
                itemCount: reviews.length,
                itemBuilder: (context, index) {
                  return _ReviewCard(
                    review: reviews[index],
                    currentStatus: status,
                  );
                },
              ),
      ),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, stack) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: LexiColors.error),
            const SizedBox(height: LexiSpacing.md),
            Text('حدث خطأ: $err'),
            LexiButton(
              label: 'إعادة المحاولة',
              onPressed: () => ref
                  .read(adminReviewsControllerProvider(status).notifier)
                  .refresh(),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReviewCard extends ConsumerWidget {
  final AdminReview review;
  final String currentStatus;

  const _ReviewCard({required this.review, required this.currentStatus});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return LexiCard(
      margin: const EdgeInsets.only(bottom: LexiSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(review.author, style: LexiTypography.bodyBold),
                    Text(
                      review.authorEmail,
                      style: LexiTypography.bodySmall.copyWith(
                        color: LexiColors.brandGrey,
                      ),
                    ),
                  ],
                ),
              ),
              _BuildRating(rating: review.rating),
            ],
          ),
          const SizedBox(height: LexiSpacing.sm),
          Text(
            'على منتج: ${review.productName}',
            style: LexiTypography.bodySmallBold.copyWith(
              color: LexiColors.brandPrimary,
            ),
          ),
          const SizedBox(height: LexiSpacing.md),
          Text(review.content, style: LexiTypography.body),
          const SizedBox(height: LexiSpacing.md),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                intl.DateFormat('yyyy-MM-dd HH:mm').format(review.createdAt),
                style: LexiTypography.bodySmall.copyWith(
                  color: LexiColors.brandGrey,
                ),
              ),
              Row(
                children: [
                  if (currentStatus != 'approved')
                    Padding(
                      padding: const EdgeInsets.only(left: LexiSpacing.sm),
                      child: LexiButton(
                        label: 'موافقة',
                        onPressed: () => _updateStatus(ref, 'approved'),
                        size: LexiButtonSize.small,
                      ),
                    ),
                  if (currentStatus == 'approved')
                    Padding(
                      padding: const EdgeInsets.only(left: LexiSpacing.sm),
                      child: LexiButton(
                        label: 'إلغاء الموافقة',
                        onPressed: () => _updateStatus(ref, 'pending'),
                        variant: LexiButtonVariant.outline,
                        size: LexiButtonSize.small,
                      ),
                    ),
                  if (currentStatus != 'trash')
                    LexiButton(
                      label: 'حذف',
                      onPressed: () => _updateStatus(ref, 'trash'),
                      variant: LexiButtonVariant.outline,
                      size: LexiButtonSize.small,
                    ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _updateStatus(WidgetRef ref, String newStatus) async {
    try {
      await ref
          .read(adminReviewsControllerProvider(currentStatus).notifier)
          .updateStatus(review.id, newStatus);
    } catch (e) {
      // Error is handled by controller/riverpod state usually, but we could show a snackbar here
    }
  }
}

class _BuildRating extends StatelessWidget {
  final int rating;
  const _BuildRating({required this.rating});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(5, (index) {
        return Icon(
          index < rating ? Icons.star_rounded : Icons.star_outline_rounded,
          color: LexiColors.brandSecondary,
          size: 16,
        );
      }),
    );
  }
}

class _BuildEmptyState extends StatelessWidget {
  final String status;
  const _BuildEmptyState({required this.status});

  @override
  Widget build(BuildContext context) {
    String message = 'لا يوجد تقييمات';
    if (status == 'pending') message = 'لا يوجد تقييمات بانتظار المراجعة';
    if (status == 'approved') message = 'لا يوجد تقييمات تمت الموافقة عليها';
    if (status == 'trash') message = 'سلة المحذوفات فارغة';

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.rate_review_outlined,
            size: 64,
            color: LexiColors.brandGrey.withValues(alpha: 0.5),
          ),
          const SizedBox(height: LexiSpacing.lg),
          Text(message, style: LexiTypography.h4),
        ],
      ),
    );
  }
}
