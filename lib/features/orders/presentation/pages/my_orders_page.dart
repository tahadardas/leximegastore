import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/utils/relative_time.dart';
import '../../../../l10n/l10n.dart';
import '../../../../design_system/lexi_tokens.dart';
import '../../../../design_system/lexi_typography.dart';
import '../../../../shared/widgets/error_state.dart';
import '../../../../shared/widgets/lexi_ui/lexi_app_bar.dart';
import '../../../../shared/widgets/lexi_ui/lexi_card.dart';
import '../../domain/entities/order.dart';
import '../controllers/my_orders_controller.dart';

class MyOrdersPage extends ConsumerStatefulWidget {
  const MyOrdersPage({super.key});

  @override
  ConsumerState<MyOrdersPage> createState() => _MyOrdersPageState();
}

class _MyOrdersPageState extends ConsumerState<MyOrdersPage> {
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(myOrdersControllerProvider.notifier).loadInitial();
    });
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_onScroll)
      ..dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) {
      return;
    }
    final max = _scrollController.position.maxScrollExtent;
    final current = _scrollController.position.pixels;
    if (current >= max - 220) {
      ref.read(myOrdersControllerProvider.notifier).loadMore();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final state = ref.watch(myOrdersControllerProvider);
    return Scaffold(
      backgroundColor: LexiColors.background,
      appBar: LexiAppBar(title: l10n.appMyOrdersTitle),
      body: RefreshIndicator(
        onRefresh: () =>
            ref.read(myOrdersControllerProvider.notifier).refresh(),
        child: _buildBody(context, state),
      ),
    );
  }

  Widget _buildBody(BuildContext context, MyOrdersState state) {
    if (state.isLoadingInitial && state.items.isEmpty) {
      return const _OrdersLoadingList();
    }

    if (state.error != null && state.items.isEmpty) {
      return ErrorState(
        message: context.l10n.ordersLoadFailed,
        onRetry: () =>
            ref.read(myOrdersControllerProvider.notifier).loadInitial(),
        error: state.error,
      );
    }

    if (state.items.isEmpty) {
      return _EmptyOrdersState(onStartShopping: () => context.go('/'));
    }

    return ListView.separated(
      controller: _scrollController,
      cacheExtent: 600,
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(LexiSpacing.s16),
      itemCount: state.items.length + (state.isStale ? 1 : 0),
      separatorBuilder: (_, _) => const SizedBox(height: LexiSpacing.s12),
      itemBuilder: (context, index) {
        if (state.isStale && index == 0) {
          return Container(
            padding: const EdgeInsets.all(LexiSpacing.s12),
            decoration: BoxDecoration(
              color: Colors.amber.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(LexiRadius.card),
              border: Border.all(color: Colors.amber.shade700),
            ),
            child: Text(
              'تعذر تحديث الطلبات الآن. يتم عرض آخر نسخة متاحة.',
              style: LexiTypography.bodySm.copyWith(
                color: Colors.amber.shade900,
                fontWeight: FontWeight.w700,
              ),
            ),
          );
        }

        final itemIndex = state.isStale ? index - 1 : index;
        final order = state.items[itemIndex];
        return RepaintBoundary(
          child: _OrderListTile(
            order: order,
            onTap: () => context.push('/orders/details', extra: order),
          ),
        );
      },
    );
  }
}

class _OrdersLoadingList extends StatelessWidget {
  const _OrdersLoadingList();

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(LexiSpacing.s16),
      itemCount: 6,
      separatorBuilder: (_, _) => const SizedBox(height: LexiSpacing.s12),
      itemBuilder: (_, _) {
        return LexiCard(
          padding: const EdgeInsets.all(LexiSpacing.s16),
          child: const SizedBox(
            height: 84,
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          ),
        );
      },
    );
  }
}

class _EmptyOrdersState extends StatelessWidget {
  final VoidCallback onStartShopping;

  const _EmptyOrdersState({required this.onStartShopping});

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(LexiSpacing.s24),
      children: [
        const SizedBox(height: LexiSpacing.s24),
        Icon(
          Icons.inventory_2_outlined,
          size: 54,
          color: LexiColors.textMuted.withValues(alpha: 0.8),
        ),
        const SizedBox(height: LexiSpacing.s12),
        Text(
          context.l10n.ordersEmptyTitle,
          textAlign: TextAlign.center,
          style: LexiTypography.h3,
        ),
        const SizedBox(height: LexiSpacing.s8),
        Text(
          context.l10n.ordersEmptyDesc,
          textAlign: TextAlign.center,
          style: LexiTypography.bodyMd.copyWith(
            color: LexiColors.textSecondary,
          ),
        ),
        const SizedBox(height: LexiSpacing.s16),
        Center(
          child: ElevatedButton.icon(
            onPressed: onStartShopping,
            icon: const Icon(Icons.storefront_outlined, size: 18),
            label: Text(context.l10n.ordersStartShopping),
          ),
        ),
      ],
    );
  }
}

class _OrderListTile extends StatelessWidget {
  final Order order;
  final VoidCallback onTap;

  const _OrderListTile({required this.order, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final status = order.status.toLowerCase().trim();
    final dateText = formatRelativeTime(order.date);
    final statusColor = _getStatusColor(status);

    return LexiCard(
      padding: const EdgeInsets.all(LexiSpacing.s16),
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.l10n.ordersNumberPrefix(order.orderNumber),
                      style: LexiTypography.labelLg.copyWith(
                        color: LexiColors.textPrimary,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: LexiSpacing.s4),
                    Text(
                      dateText,
                      style: LexiTypography.bodySm.copyWith(
                        color: LexiColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: LexiSpacing.s8,
                  vertical: LexiSpacing.s4,
                ),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(LexiRadius.button),
                ),
                child: Text(
                  _statusLabel(status),
                  style: LexiTypography.caption.copyWith(
                    color: statusColor,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: LexiSpacing.s12),
            child: Divider(height: 1, color: LexiColors.borderSubtle),
          ),
          if (order.items.isNotEmpty) ...[
            Text(
              order.items
                  .map((i) {
                    final color = i.variationLabel?.isNotEmpty ?? false
                        ? ' (${i.variationLabel})'
                        : '';
                    return '${i.name}$color';
                  })
                  .join('، '),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: LexiTypography.bodySm.copyWith(
                color: LexiColors.textSecondary,
              ),
            ),
            const SizedBox(height: LexiSpacing.s12),
          ],
          Row(
            children: [
              Expanded(
                child: Text(
                  context.l10n.ordersTotalLabel(
                    CurrencyFormatter.formatAmount(order.total),
                  ),
                  style: LexiTypography.labelMd.copyWith(
                    color: LexiColors.brandPrimary,
                  ),
                ),
              ),
              Text(
                context.l10n.ordersItemsCountLabel(order.resolvedItemCount),
                style: LexiTypography.bodySm.copyWith(
                  color: LexiColors.textSecondary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static String _statusLabel(String status) {
    if (status == 'pending-verification' || status == 'on-hold') {
      return 'بانتظار التحقق من الدفع';
    }

    switch (status) {
      case 'pending-verification':
      case 'on-hold':
        return 'بانتظار التحقق';
      case 'processing':
        return 'قيد المعالجة';
      case 'shipped':
        return 'تم الشحن';
      case 'delivered':
        return 'تم التوصيل';
      case 'completed':
        return 'مكتمل';
      case 'cancelled':
        return 'ملغي';
      case 'failed':
        return 'فشل';
      case 'refunded':
        return 'مسترجع';
      default:
        return status;
    }
  }

  static Color _getStatusColor(String status) {
    switch (status) {
      case 'completed':
      case 'delivered':
        return LexiColors.success;
      case 'processing':
      case 'shipped':
        return LexiColors.brandPrimary;
      case 'cancelled':
      case 'failed':
      case 'refunded':
        return LexiColors.error;
      default:
        return LexiColors.textMuted;
    }
  }
}
