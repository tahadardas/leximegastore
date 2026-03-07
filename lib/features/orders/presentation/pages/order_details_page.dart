import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/auth/auth_session_controller.dart';
import '../../../../core/utils/color_swatch_mapper.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../ui/widgets/lexi_safe_bottom.dart';
import '../../../../shared/services/share_service.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/lexi_network_image.dart';
import '../../../../shared/widgets/lexi_ui/lexi_app_bar.dart';
import '../../../../features/cart/presentation/controllers/cart_controller.dart';
import '../../../../design_system/lexi_tokens.dart';
import '../../../../design_system/lexi_typography.dart';
import '../../data/repositories/order_repository_impl.dart';
import '../../domain/entities/order.dart';
import '../utils/invoice_pdf_exporter.dart';

final _orderDetailsProvider = FutureProvider.family.autoDispose<Order, int>((
  ref,
  orderId,
) async {
  final repo = ref.read(orderRepositoryProvider);
  return repo.myOrderDetails(orderId);
});

class OrderDetailsPage extends ConsumerWidget {
  final Order order;

  const OrderDetailsPage({super.key, required this.order});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final orderId = int.tryParse(order.id) ?? 0;
    if (orderId <= 0) {
      return _OrderDetailsBody(order: order);
    }

    final asyncOrder = ref.watch(_orderDetailsProvider(orderId));
    return asyncOrder.when(
      data: (fullOrder) {
        final resolvedOrder = _preferCompleteOrder(
          baseOrder: order,
          fetchedOrder: fullOrder,
        );
        return _OrderDetailsBody(order: resolvedOrder);
      },
      loading: () {
        if (order.items.isNotEmpty) {
          return _OrderDetailsBody(order: order);
        }
        return Scaffold(
          appBar: LexiAppBar(title: 'تفاصيل الطلب #${order.orderNumber}'),
          body: const Center(child: CircularProgressIndicator()),
        );
      },
      error: (err, stack) {
        if (order.items.isNotEmpty) {
          return _OrderDetailsBody(order: order);
        }
        return Scaffold(
          appBar: LexiAppBar(title: 'تفاصيل الطلب #${order.orderNumber}'),
          body: Center(child: Text('حدث خطأ: $err')),
        );
      },
    );
  }

  Order _preferCompleteOrder({
    required Order baseOrder,
    required Order fetchedOrder,
  }) {
    if (fetchedOrder.items.isEmpty && baseOrder.items.isNotEmpty) {
      return fetchedOrder.copyWith(
        items: baseOrder.items,
        itemCount: fetchedOrder.itemCount ?? baseOrder.itemCount,
      );
    }

    if (fetchedOrder.items.length < baseOrder.items.length) {
      return fetchedOrder.copyWith(
        items: baseOrder.items,
        itemCount: fetchedOrder.itemCount ?? baseOrder.itemCount,
      );
    }

    if ((fetchedOrder.orderNumber.trim().isEmpty ||
            fetchedOrder.id.trim().isEmpty) &&
        (baseOrder.orderNumber.trim().isNotEmpty ||
            baseOrder.id.trim().isNotEmpty)) {
      return fetchedOrder.copyWith(
        id: fetchedOrder.id.trim().isEmpty ? baseOrder.id : fetchedOrder.id,
        orderNumber: fetchedOrder.orderNumber.trim().isEmpty
            ? baseOrder.orderNumber
            : fetchedOrder.orderNumber,
      );
    }

    return fetchedOrder;
  }
}

class OrderDetailsByIdPage extends ConsumerWidget {
  final int orderId;

  const OrderDetailsByIdPage({super.key, required this.orderId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (orderId <= 0) {
      return Scaffold(
        appBar: const LexiAppBar(title: 'تفاصيل الطلب'),
        body: const Center(child: Text('رقم الطلب غير صالح.')),
      );
    }

    final asyncOrder = ref.watch(_orderDetailsProvider(orderId));
    return asyncOrder.when(
      data: (order) => _OrderDetailsBody(order: order),
      loading: () => Scaffold(
        appBar: LexiAppBar(title: 'تفاصيل الطلب #$orderId'),
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (err, stack) => Scaffold(
        appBar: LexiAppBar(title: 'تفاصيل الطلب #$orderId'),
        body: Center(child: Text('تعذر تحميل تفاصيل الطلب: $err')),
      ),
    );
  }
}

class _OrderDetailsBody extends ConsumerStatefulWidget {
  final Order order;

  const _OrderDetailsBody({required this.order});

  @override
  ConsumerState<_OrderDetailsBody> createState() => _OrderDetailsBodyState();
}

class _OrderDetailsBodyState extends ConsumerState<_OrderDetailsBody> {
  bool _isActionLoading = false;

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('dd/MM/yyyy HH:mm', 'ar');
    final status = widget.order.status.toLowerCase().trim();
    final isCompleted = status == 'completed';
    final canPerformActions = status == 'shipped' || status == 'processing';

    return Scaffold(
      backgroundColor: LexiColors.neutral50,
      appBar: LexiAppBar(
        title: 'تفاصيل الطلب #${widget.order.orderNumber}',
        actions: [
          IconButton(
            tooltip: 'مشاركة تتبع الطلب',
            onPressed: () async {
              await ShareService.instance.shareOrderDetails(
                order: widget.order,
              );
            },
            icon: const Icon(Icons.share_outlined),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(LexiSpacing.s16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(LexiSpacing.s16),
              decoration: BoxDecoration(
                color: LexiColors.white,
                borderRadius: BorderRadius.circular(LexiRadius.card),
                border: Border.all(color: LexiColors.neutral200, width: 1.0),
                boxShadow: LexiShadows.cardLow,
              ),
              child: Column(
                children: [
                  _InfoRow(
                    label: 'حالة الطلب',
                    value: _statusLabel(status),
                    valueColor: _getStatusColor(status),
                    isStatus: true,
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Divider(height: 1, color: LexiColors.neutral200),
                  ),
                  _InfoRow(
                    label: 'تاريخ الطلب',
                    value: dateFormat.format(widget.order.date),
                  ),
                  const SizedBox(height: 8),
                  _InfoRow(label: 'رقم الفاتورة', value: widget.order.id),
                ],
              ),
            ),

            const SizedBox(height: LexiSpacing.s24),

            // Order Items
            Text(
              'المنتجات (${widget.order.resolvedItemCount})',
              style: LexiTypography.h4.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: LexiSpacing.s12),
            Container(
              decoration: BoxDecoration(
                color: LexiColors.white,
                borderRadius: BorderRadius.circular(LexiRadius.card),
                boxShadow: LexiShadows.cardLow,
              ),
              child: ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: widget.order.items.length,
                separatorBuilder: (context, idx) =>
                    const Divider(height: 1, color: LexiColors.neutral200),
                itemBuilder: (context, index) {
                  final item = widget.order.items[index];
                  // Determine unit label
                  String unitLabel = '';
                  if (item.unitType == 'carton' || item.unitType == 'كارتونة') {
                    unitLabel = 'كارتونة';
                    if ((item.piecesCount ?? 0) > 0) {
                      unitLabel += ' (${item.piecesCount} قطعة)';
                    }
                  } else if (item.unitType == 'piece' ||
                      item.unitType == 'قطعة') {
                    unitLabel = 'قطعة';
                  }

                  return Padding(
                    padding: const EdgeInsets.all(LexiSpacing.s12),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 60,
                          height: 60,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: LexiColors.neutral200),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: item.image.isEmpty
                                ? const Icon(
                                    Icons.image_not_supported,
                                    color: LexiColors.neutral500,
                                  )
                                : LexiNetworkImage(
                                    imageUrl: item.image,
                                    fit: BoxFit.cover,
                                  ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.name,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: LexiTypography.bodyMd.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              if (item.variationLabel != null &&
                                  item.variationLabel!.isNotEmpty) ...[
                                const SizedBox(height: 2),
                                Row(
                                  children: [
                                    if (ColorSwatchMapper.map(
                                          item.variationLabel!,
                                        ) !=
                                        null) ...[
                                      Container(
                                        width: 10,
                                        height: 10,
                                        decoration: BoxDecoration(
                                          color: ColorSwatchMapper.map(
                                            item.variationLabel!,
                                          ),
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                            color: LexiColors.neutral300,
                                            width: 0.5,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                    ],
                                    Text(
                                      item.variationLabel!,
                                      style: LexiTypography.caption.copyWith(
                                        color: LexiColors.textSecondary,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  if (unitLabel.isNotEmpty)
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                        vertical: 2,
                                      ),
                                      margin: const EdgeInsets.only(left: 6),
                                      decoration: BoxDecoration(
                                        color: LexiColors.neutral200,
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        unitLabel,
                                        style: LexiTypography.caption.copyWith(
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  Text(
                                    '${item.qty} × ${CurrencyFormatter.formatAmount(item.price)}',
                                    style: LexiTypography.caption.copyWith(
                                      color: LexiColors.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              CurrencyFormatter.formatAmount(item.lineTotal),
                              style: LexiTypography.bodyMd.copyWith(
                                fontWeight: FontWeight.w900,
                                color: LexiColors.brandPrimary,
                              ),
                            ),
                            if ((item.discount ?? 0) > 0)
                              Text(
                                'خصم: ${CurrencyFormatter.formatAmount(item.discount ?? 0)}',
                                style: LexiTypography.caption.copyWith(
                                  color: LexiColors.error,
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),

            const SizedBox(height: LexiSpacing.s24),

            // Financial Summary
            Container(
              padding: const EdgeInsets.all(LexiSpacing.s16),
              decoration: BoxDecoration(
                color: LexiColors.white,
                borderRadius: BorderRadius.circular(LexiRadius.card),
                boxShadow: LexiShadows.cardLow,
              ),
              child: Column(
                children: [
                  _SummaryRow(
                    label: 'المجموع الفرعي',
                    value: CurrencyFormatter.formatAmount(
                      widget.order.subtotal,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _SummaryRow(
                    label: 'تكلفة الشحن',
                    value: CurrencyFormatter.formatAmount(
                      widget.order.shippingCost,
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Divider(height: 1, color: LexiColors.neutral200),
                  ),
                  _SummaryRow(
                    label: 'الإجمالي الكلي',
                    value: CurrencyFormatter.formatAmount(widget.order.total),
                    isBold: true,
                    fontSize: 20,
                  ),
                ],
              ),
            ),

            const SizedBox(height: LexiSpacing.s32),

            // Actions
            if (canPerformActions) ...[
              AppButton(
                label: 'تم استلام الطلب بنجاح',
                icon: Icons.check_circle_outline,
                isLoading: _isActionLoading,
                onPressed: _handleConfirmReceived,
              ),
              const SizedBox(height: LexiSpacing.s12),
              AppButton(
                label: 'رفض استلام الطلب',
                icon: Icons.highlight_off_outlined,
                type: AppButtonType.outline,
                textColor: LexiColors.error,
                isLoading: _isActionLoading,
                onPressed: _showRefusalDialog,
              ),
              const SizedBox(height: LexiSpacing.s24),
              const Divider(height: 1, color: LexiColors.neutral300),
              const SizedBox(height: LexiSpacing.s24),
            ],

            AppButton(
              label: 'عرض الفاتورة الإلكترونية',
              icon: Icons.receipt_long_outlined,
              type: AppButtonType.outline,
              onPressed: () {
                final phone = widget.order.billing?.phone.trim() ?? '';
                final uri = Uri(
                  path: '/orders/${widget.order.id}/invoice',
                  queryParameters: {
                    'type': _invoiceType(status),
                    if (phone.isNotEmpty) 'phone': phone,
                  },
                );
                context.push(uri.toString(), extra: widget.order);
              },
            ),
            const SizedBox(height: LexiSpacing.s12),
            if (isCompleted) ...[
              AppButton(
                label: 'تصدير بصيغة PDF',
                icon: Icons.picture_as_pdf_outlined,
                type: AppButtonType.outline,
                onPressed: () => _exportPdf(context),
              ),
              const SizedBox(height: LexiSpacing.s12),
            ],
            if (ref.watch(authSessionControllerProvider).state.role !=
                'delivery_agent') ...[
              AppButton(
                label: 'إعادة طلب هذه المنتجات',
                icon: Icons.replay_outlined,
                type: AppButtonType.outline,
                onPressed: () async {
                  for (final item in widget.order.items) {
                    await ref
                        .read(cartControllerProvider.notifier)
                        .addItem(item);
                  }
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    lexiFloatingSnackBar(
                      context,
                      content: const Text('تمت إضافة جميع المنتجات إلى السلة'),
                      backgroundColor: LexiColors.success,
                    ),
                  );
                },
              ),
              const SizedBox(height: LexiSpacing.s12),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _handleConfirmReceived() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تأكيد الاستلام'),
        content: const Text('هل أنت متأكد أنك استلمت الطلب بنجاح؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('تأكيد'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isActionLoading = true);
    try {
      final repo = ref.read(orderRepositoryProvider);
      await repo.confirmReceived(int.parse(widget.order.id));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        lexiFloatingSnackBar(
          context,
          content: const Text('تم تأكيد استلام الطلب'),
          backgroundColor: LexiColors.success,
        ),
      );
      // Refresh order details if needed, or just pop/go back
      context.pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        lexiFloatingSnackBar(
          context,
          content: Text('حدث خطأ: $e'),
          backgroundColor: LexiColors.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _isActionLoading = false);
    }
  }

  Future<void> _showRefusalDialog() async {
    final reasonController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final refused = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('رفض استلام الطلب'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('يرجى ذكر سبب رفض استلام الطلب (إجباري):'),
              const SizedBox(height: 16),
              TextFormField(
                controller: reasonController,
                maxLines: 3,
                decoration: const InputDecoration(
                  hintText: 'مثلاً: المنتجات تالفة، الطلب غير مكتمل...',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'يرجى إدخال سبب الرفض';
                  }
                  return null;
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء'),
          ),
          TextButton(
            onPressed: () {
              if (formKey.currentState?.validate() ?? false) {
                Navigator.pop(context, true);
              }
            },
            child: const Text(
              'تأكيد الرفض',
              style: TextStyle(color: LexiColors.error),
            ),
          ),
        ],
      ),
    );

    if (refused != true) return;

    setState(() => _isActionLoading = true);
    try {
      final repo = ref.read(orderRepositoryProvider);
      await repo.refuseOrder(
        int.parse(widget.order.id),
        reasonController.text.trim(),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        lexiFloatingSnackBar(
          context,
          content: const Text('تم تسجيل رفض استلام الطلب'),
          backgroundColor: LexiColors.warning,
        ),
      );
      context.pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        lexiFloatingSnackBar(
          context,
          content: Text('حدث خطأ: $e'),
          backgroundColor: LexiColors.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _isActionLoading = false);
    }
  }

  Future<void> _exportPdf(BuildContext context) async {
    try {
      await InvoicePdfExporter.exportCompletedOrder(widget.order);
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        lexiFloatingSnackBar(
          context,
          content: Text('تعذر تصدير الفاتورة: $e'),
          backgroundColor: LexiColors.error,
        ),
      );
    }
  }

  String _invoiceType(String status) {
    if (status == 'processing' || status == 'completed') return 'final';
    return 'provisional';
  }

  String _statusLabel(String status) {
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

  Color _getStatusColor(String status) {
    switch (status) {
      case 'completed':
      case 'delivered':
        return LexiColors.success;
      case 'processing':
      case 'shipped':
        return LexiColors.warning;
      case 'cancelled':
      case 'failed':
      case 'refunded':
        return LexiColors.error;
      default:
        return LexiColors.neutral500;
    }
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;
  final bool isStatus;

  const _InfoRow({
    required this.label,
    required this.value,
    this.valueColor,
    this.isStatus = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: LexiTypography.bodyMd.copyWith(
            color: LexiColors.textSecondary,
          ),
        ),
        if (isStatus)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: (valueColor ?? LexiColors.neutral500).withValues(
                alpha: 0.1,
              ),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              value,
              style: LexiTypography.caption.copyWith(
                color: valueColor,
                fontWeight: FontWeight.w900,
              ),
            ),
          )
        else
          Text(
            value,
            style: LexiTypography.bodyMd.copyWith(
              fontWeight: FontWeight.w700,
              color: LexiColors.textPrimary,
            ),
          ),
      ],
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isBold;
  final double? fontSize;

  const _SummaryRow({
    required this.label,
    required this.value,
    this.isBold = false,
    this.fontSize,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: LexiTypography.bodyMd.copyWith(
            color: isBold ? LexiColors.textPrimary : LexiColors.textSecondary,
            fontWeight: isBold ? FontWeight.w900 : FontWeight.w600,
            fontSize: fontSize,
          ),
        ),
        Text(
          value,
          style: LexiTypography.bodyMd.copyWith(
            color: isBold ? LexiColors.brandPrimary : LexiColors.textPrimary,
            fontWeight: isBold ? FontWeight.w900 : FontWeight.w700,
            fontSize: fontSize,
          ),
        ),
      ],
    );
  }
}
