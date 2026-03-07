import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../app/theme/lexi_theme.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../shared/ui/lexi_alert.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../core/utils/color_swatch_mapper.dart';
import '../../../../shared/widgets/lexi_network_image.dart';
import '../../domain/entities/admin_courier_assignment.dart';
import '../../domain/entities/admin_order.dart';
import '../controllers/admin_orders_controller.dart';

class AdminOrderDetailsPage extends ConsumerWidget {
  final AdminOrder order;

  const AdminOrderDetailsPage({super.key, required this.order});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final orderAsync = ref.watch(adminOrderDetailsProvider(order.id));

    return Scaffold(
      body: orderAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => Center(child: Text('تعذر تحميل الطلب: $e')),
        data: (currentOrder) {
          final itemCount = currentOrder.items.fold<int>(
            0,
            (sum, item) => sum + item.qty,
          );
          final proofUrl = (currentOrder.paymentProof?.imageUrl ?? '').trim();

          return SingleChildScrollView(
            padding: const EdgeInsets.all(LexiSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSection(
                  context,
                  title: 'ملخص الطلب',
                  child: Column(
                    children: [
                      _DetailRow(
                        label: 'رقم الطلب',
                        value: '#${currentOrder.orderNumber}',
                      ),
                      const SizedBox(height: LexiSpacing.sm),
                      _DetailRow(
                        label: 'التاريخ',
                        value: _formatDate(currentOrder.date),
                      ),
                      const SizedBox(height: LexiSpacing.sm),
                      _DetailRow(
                        label: 'الحالة',
                        value: _statusLabel(currentOrder.status),
                      ),
                      const SizedBox(height: LexiSpacing.sm),
                      _DetailRow(
                        label: 'طريقة الدفع',
                        value: _paymentLabel(currentOrder.paymentMethod),
                      ),
                      const SizedBox(height: LexiSpacing.sm),
                      _DetailRow(label: 'عدد المنتجات', value: '$itemCount'),
                      const SizedBox(height: LexiSpacing.sm),
                      _DetailRow(
                        label: 'المجموع الفرعي',
                        value: CurrencyFormatter.formatAmount(
                          currentOrder.subtotal,
                        ),
                      ),
                      const SizedBox(height: LexiSpacing.sm),
                      _DetailRow(
                        label: 'الشحن',
                        value: CurrencyFormatter.formatAmount(
                          currentOrder.shippingCost,
                        ),
                      ),
                      const SizedBox(height: LexiSpacing.sm),
                      _DetailRow(
                        label: 'الإجمالي',
                        value: CurrencyFormatter.formatAmount(
                          currentOrder.total,
                        ),
                        isEmphasis: true,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: LexiSpacing.lg),
                _buildSection(
                  context,
                  title: 'بيانات العميل',
                  child: Column(
                    children: [
                      _DetailRow(
                        label: 'الاسم',
                        value:
                            '${currentOrder.billing.firstName} ${currentOrder.billing.lastName}',
                      ),
                      const SizedBox(height: LexiSpacing.sm),
                      _DetailRow(
                        label: 'الهاتف',
                        value: currentOrder.billing.phone,
                      ),
                      const SizedBox(height: LexiSpacing.sm),
                      _DetailRow(
                        label: 'البريد',
                        value: currentOrder.billing.email,
                      ),
                      const SizedBox(height: LexiSpacing.sm),
                      _DetailRow(
                        label: 'العنوان',
                        value:
                            '${currentOrder.billing.city}, ${currentOrder.billing.address1}',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: LexiSpacing.lg),
                _buildCourierAssignmentSection(context, ref, currentOrder),
                if (currentOrder.deliveryLocation != null) ...[
                  const SizedBox(height: LexiSpacing.lg),
                  _buildDeliveryLocationSection(context, currentOrder),
                ],
                const SizedBox(height: LexiSpacing.lg),
                _buildSection(
                  context,
                  title: 'المنتجات (${currentOrder.items.length})',
                  child: Column(
                    children: [
                      for (var i = 0; i < currentOrder.items.length; i++) ...[
                        _OrderItemTile(item: currentOrder.items[i]),
                        if (i < currentOrder.items.length - 1)
                          const Divider(height: 20),
                      ],
                    ],
                  ),
                ),
                if ((currentOrder.customerNote ?? '').trim().isNotEmpty) ...[
                  const SizedBox(height: LexiSpacing.lg),
                  _buildSection(
                    context,
                    title: 'ملاحظة العميل',
                    child: Text(currentOrder.customerNote!.trim()),
                  ),
                ],
                const SizedBox(height: LexiSpacing.lg),
                if (currentOrder.paymentMethod == 'sham_cash' ||
                    currentOrder.paymentMethod == 'sham-cash' ||
                    currentOrder.paymentMethod == 'shamcash') ...[
                  _buildSection(
                    context,
                    title: 'إثبات الدفع (شام كاش)',
                    child: Column(
                      children: [
                        if (proofUrl.isNotEmpty)
                          GestureDetector(
                            onTap: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => Scaffold(
                                    appBar: AppBar(),
                                    body: Center(
                                      child: InteractiveViewer(
                                        child: LexiNetworkImage(
                                          imageUrl: proofUrl,
                                          fit: BoxFit.contain,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            },
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(
                                LexiRadius.md,
                              ),
                              child: LexiNetworkImage(
                                imageUrl: proofUrl,
                                height: 220,
                                fit: BoxFit.cover,
                                errorWidget: Container(
                                  height: 220,
                                  color: Colors.grey[300],
                                  child: const Center(
                                    child: Icon(Icons.broken_image),
                                  ),
                                ),
                              ),
                            ),
                          )
                        else
                          Container(
                            padding: const EdgeInsets.all(LexiSpacing.md),
                            decoration: BoxDecoration(
                              color: LexiColors.lightGray,
                              borderRadius: BorderRadius.circular(
                                LexiRadius.md,
                              ),
                            ),
                            child: const Text(
                              'لم يتم رفع إيصال الدفع بعد.',
                              textAlign: TextAlign.center,
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: LexiSpacing.lg),
                ],
                _ActionButtons(
                  order: currentOrder,
                  isAssignedToCourier: _hasCourier(ref, currentOrder.id),
                ),
                const SizedBox(height: LexiSpacing.md),
                AppButton(
                  label: 'إرسال رسالة عبر البريد',
                  icon: Icons.email_outlined,
                  type: AppButtonType.secondary,
                  onPressed: () => _showEmailDialog(context, ref, currentOrder),
                ),
                const SizedBox(height: LexiSpacing.sm),
                AppButton(
                  label: 'إرسال تفاصيل الطلب عبر واتساب',
                  icon: Icons.chat_outlined,
                  type: AppButtonType.outline,
                  onPressed: () => _sendOrderOnWhatsApp(context, currentOrder),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  bool _hasCourier(WidgetRef ref, int orderId) {
    final assignmentAsync = ref.watch(
      adminOrderCourierAssignmentProvider(orderId),
    );
    final assignment = assignmentAsync.asData?.value;
    return assignment != null &&
        assignment.isAssigned &&
        assignment.agent != null;
  }

  Widget _buildDeliveryLocationSection(BuildContext context, AdminOrder order) {
    final location = order.deliveryLocation!;
    final hasCoordinates = location.lat != null && location.lng != null;

    return _buildSection(
      context,
      title: 'موقع التسليم',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _DetailRow(
            label: 'العنوان',
            value: location.fullAddress.trim().isNotEmpty
                ? location.fullAddress.trim()
                : '${order.billing.city}, ${order.billing.address1}'.trim(),
          ),
          if (location.city.trim().isNotEmpty) ...[
            const SizedBox(height: LexiSpacing.sm),
            _DetailRow(label: 'المدينة', value: location.city.trim()),
          ],
          if (location.area.trim().isNotEmpty) ...[
            const SizedBox(height: LexiSpacing.sm),
            _DetailRow(label: 'المنطقة', value: location.area.trim()),
          ],
          if (location.street.trim().isNotEmpty) ...[
            const SizedBox(height: LexiSpacing.sm),
            _DetailRow(label: 'الشارع', value: location.street.trim()),
          ],
          if (location.building.trim().isNotEmpty) ...[
            const SizedBox(height: LexiSpacing.sm),
            _DetailRow(label: 'البناء', value: location.building.trim()),
          ],
          if ((location.notes).trim().isNotEmpty) ...[
            const SizedBox(height: LexiSpacing.sm),
            _DetailRow(label: 'ملاحظات', value: location.notes.trim()),
          ],
          if (hasCoordinates) ...[
            const SizedBox(height: LexiSpacing.sm),
            _DetailRow(
              label: 'الإحداثيات',
              value:
                  '${location.lat!.toStringAsFixed(6)}, ${location.lng!.toStringAsFixed(6)}',
            ),
          ],
          const SizedBox(height: LexiSpacing.md),
          Row(
            children: [
              Expanded(
                child: AppButton(
                  label: 'الانتقال',
                  icon: Icons.navigation_outlined,
                  type: AppButtonType.primary,
                  onPressed: () => _launchMapsUrl(
                    context,
                    location.mapsNavigateUrl,
                    fallbackUrl: location.mapsOpenUrl,
                  ),
                ),
              ),
              const SizedBox(width: LexiSpacing.sm),
              Expanded(
                child: AppButton(
                  label: 'فتح الخريطة',
                  icon: Icons.map_outlined,
                  type: AppButtonType.secondary,
                  onPressed: () => _launchMapsUrl(
                    context,
                    location.mapsOpenUrl,
                    fallbackUrl: location.mapsNavigateUrl,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCourierAssignmentSection(
    BuildContext context,
    WidgetRef ref,
    AdminOrder currentOrder,
  ) {
    final assignmentAsync = ref.watch(
      adminOrderCourierAssignmentProvider(currentOrder.id),
    );
    final couriersAsync = ref.watch(adminCouriersProvider);

    return _buildSection(
      context,
      title: 'إسناد مندوب التوصيل',
      child: assignmentAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'تعذر تحميل بيانات الإسناد الحالية.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: LexiSpacing.sm),
            AppButton(
              label: 'إعادة المحاولة',
              icon: Icons.refresh,
              type: AppButtonType.outline,
              onPressed: () {
                ref.invalidate(
                  adminOrderCourierAssignmentProvider(currentOrder.id),
                );
                ref.invalidate(adminCouriersProvider);
              },
            ),
          ],
        ),
        data: (assignment) {
          final courier = assignment.agent;
          final hasCourier = assignment.isAssigned && courier != null;
          final couriers =
              couriersAsync.asData?.value ?? const <AdminCourier>[];
          final availableCouriers = couriers
              .where((item) => item.isAvailable)
              .toList(growable: false);

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _DetailRow(
                label: 'المندوب',
                value: hasCourier ? courier.displayName : 'غير مسند',
              ),
              if (hasCourier) ...[
                const SizedBox(height: LexiSpacing.sm),
                _DetailRow(
                  label: 'الهاتف',
                  value: courier.phone.trim().isEmpty ? '--' : courier.phone,
                ),
                const SizedBox(height: LexiSpacing.sm),
                _DetailRow(
                  label: 'الحالة',
                  value: courier.isAvailable ? 'متوفر' : 'غير متوفر',
                ),
                const SizedBox(height: LexiSpacing.sm),
                _DetailRow(
                  label: 'حالة التوصيل',
                  value: assignment.deliveryState.trim().isEmpty
                      ? '--'
                      : assignment.deliveryState.trim(),
                ),
              ],
              if (assignment.assignedAt.trim().isNotEmpty) ...[
                const SizedBox(height: LexiSpacing.sm),
                _DetailRow(
                  label: 'وقت الإسناد',
                  value: _formatDate(assignment.assignedAt),
                ),
              ],
              const SizedBox(height: LexiSpacing.md),
              AppButton(
                label: hasCourier ? 'تغيير المندوب' : 'إسناد لمندوب متوفر',
                icon: Icons.local_shipping_outlined,
                type: hasCourier
                    ? AppButtonType.secondary
                    : AppButtonType.primary,
                onPressed: availableCouriers.isEmpty
                    ? null
                    : () => _showAssignCourierSheet(
                        context,
                        ref,
                        currentOrder,
                        availableCouriers,
                      ),
              ),
              if (hasCourier) ...[
                const SizedBox(height: LexiSpacing.sm),
                AppButton(
                  label: 'إلغاء إسناد الطلب',
                  icon: Icons.person_remove_alt_1_outlined,
                  type: AppButtonType.secondary,
                  onPressed: () async {
                    var confirmed = false;
                    await LexiAlert.confirm(
                      context,
                      text: 'هل تريد إلغاء إسناد هذا الطلب من المندوب الحالي؟',
                      confirmText: 'نعم',
                      cancelText: 'إلغاء',
                      onConfirm: () async {
                        confirmed = true;
                      },
                    );
                    if (!confirmed || !context.mounted) {
                      return;
                    }
                    await _assignCourier(
                      context,
                      ref,
                      currentOrder.id,
                      unassign: true,
                    );
                  },
                ),
              ],
              if (availableCouriers.isEmpty) ...[
                const SizedBox(height: LexiSpacing.sm),
                Text(
                  'لا يوجد مندوبون متوفرون حالياً.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  Future<void> _showAssignCourierSheet(
    BuildContext context,
    WidgetRef ref,
    AdminOrder order,
    List<AdminCourier> availableCouriers,
  ) async {
    if (availableCouriers.isEmpty) {
      await LexiAlert.warning(context, text: 'لا يوجد مندوبون متوفرون حالياً.');
      return;
    }

    final selectedCourierId = await showModalBottomSheet<int>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        return SafeArea(
          child: ListView.separated(
            shrinkWrap: true,
            padding: const EdgeInsets.all(LexiSpacing.md),
            itemCount: availableCouriers.length,
            separatorBuilder: (context, index) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final courier = availableCouriers[index];
              final subtitleParts = <String>[
                if (courier.phone.trim().isNotEmpty) courier.phone.trim(),
                if (courier.activeOrdersCount > 0)
                  'طلبات فعالة: ${courier.activeOrdersCount}',
              ];

              return ListTile(
                leading: const Icon(Icons.local_shipping_outlined),
                title: Text(courier.displayName),
                subtitle: subtitleParts.isEmpty
                    ? null
                    : Text(subtitleParts.join(' • ')),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.of(sheetContext).pop(courier.id),
              );
            },
          ),
        );
      },
    );

    if (selectedCourierId == null || !context.mounted) {
      return;
    }

    await _assignCourier(context, ref, order.id, courierId: selectedCourierId);
  }

  Future<void> _assignCourier(
    BuildContext context,
    WidgetRef ref,
    int orderId, {
    int? courierId,
    bool unassign = false,
  }) async {
    try {
      await ref
          .read(adminOrdersControllerProvider.notifier)
          .assignOrderCourier(
            orderId: orderId,
            courierId: courierId,
            unassign: unassign,
          );
      if (!context.mounted) {
        return;
      }
      await LexiAlert.success(
        context,
        text: unassign ? 'تم إلغاء الإسناد بنجاح.' : 'تم إسناد الطلب بنجاح.',
      );
    } catch (e) {
      if (!context.mounted) {
        return;
      }
      await LexiAlert.error(context, text: 'تعذر تحديث الإسناد: $e');
    }
  }

  Future<void> _launchMapsUrl(
    BuildContext context,
    String primaryUrl, {
    String? fallbackUrl,
  }) async {
    final primary = primaryUrl.trim();
    if (primary.isNotEmpty) {
      final launchedPrimary = await launchUrl(
        Uri.parse(primary),
        mode: LaunchMode.externalApplication,
      );
      if (launchedPrimary) {
        return;
      }
    }

    final fallback = (fallbackUrl ?? '').trim();
    if (fallback.isNotEmpty) {
      final launchedFallback = await launchUrl(
        Uri.parse(fallback),
        mode: LaunchMode.platformDefault,
      );
      if (launchedFallback) {
        return;
      }
    }

    if (!context.mounted) {
      return;
    }
    await LexiAlert.error(context, text: 'تعذر فتح الخريطة على هذا الجهاز.');
  }

  Future<void> _showEmailDialog(
    BuildContext context,
    WidgetRef ref,
    AdminOrder currentOrder,
  ) async {
    final subjectController = TextEditingController(
      text: 'تحديث بخصوص طلبك #${currentOrder.orderNumber}',
    );
    final messageController = TextEditingController();
    bool asCustomerNote = true;
    bool sending = false;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('إرسال رسالة للعميل'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: subjectController,
                      decoration: const InputDecoration(labelText: 'العنوان'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: messageController,
                      decoration: const InputDecoration(
                        labelText: 'نص الرسالة',
                        alignLabelWithHint: true,
                      ),
                      minLines: 4,
                      maxLines: 7,
                    ),
                    const SizedBox(height: 12),
                    CheckboxListTile(
                      value: asCustomerNote,
                      contentPadding: EdgeInsets.zero,
                      title: const Text('حفظها أيضًا كملاحظة للعميل'),
                      onChanged: (v) =>
                          setState(() => asCustomerNote = v ?? true),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: sending
                      ? null
                      : () => Navigator.pop(dialogContext),
                  child: const Text('إلغاء'),
                ),
                ElevatedButton.icon(
                  onPressed: sending
                      ? null
                      : () async {
                          final subject = subjectController.text.trim();
                          final message = messageController.text.trim();
                          if (message.isEmpty) {
                            await LexiAlert.error(
                              context,
                              text: 'يرجى كتابة نص الرسالة.',
                            );
                            return;
                          }

                          setState(() => sending = true);
                          try {
                            await ref
                                .read(adminOrdersControllerProvider.notifier)
                                .notifyOrderCustomer(
                                  currentOrder.id,
                                  subject: subject,
                                  message: message,
                                  asCustomerNote: asCustomerNote,
                                );

                            if (!context.mounted) {
                              return;
                            }

                            Navigator.pop(dialogContext);
                            await LexiAlert.success(
                              context,
                              text: 'تم إرسال الرسالة بنجاح.',
                            );
                          } catch (e) {
                            if (!context.mounted) {
                              return;
                            }
                            await LexiAlert.error(
                              context,
                              text: 'فشل إرسال الرسالة: $e',
                            );
                          } finally {
                            if (context.mounted) {
                              setState(() => sending = false);
                            }
                          }
                        },
                  icon: sending
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.send),
                  label: const Text('إرسال'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _sendOrderOnWhatsApp(
    BuildContext context,
    AdminOrder currentOrder,
  ) async {
    final normalizedPhone = _normalizeWhatsAppPhone(currentOrder.billing.phone);
    if (normalizedPhone.isEmpty) {
      await LexiAlert.error(
        context,
        text: 'رقم هاتف العميل غير صالح لإرسال واتساب.',
      );
      return;
    }

    final message = _buildWhatsAppMessage(currentOrder);
    final uri = Uri.parse(
      'https://wa.me/$normalizedPhone?text=${Uri.encodeComponent(message)}',
    );

    final launched = await launchUrl(uri, mode: LaunchMode.platformDefault);
    if (launched) {
      return;
    }

    if (!context.mounted) {
      return;
    }

    await LexiAlert.error(context, text: 'تعذر فتح واتساب على هذا الجهاز.');
  }

  String _normalizeWhatsAppPhone(String raw) {
    var digits = raw.replaceAll(RegExp(r'[^0-9+]'), '');
    if (digits.isEmpty) {
      return '';
    }

    if (digits.startsWith('+')) {
      digits = digits.substring(1);
    }

    if (digits.startsWith('00')) {
      digits = digits.substring(2);
    }

    if (digits.startsWith('963')) {
      return digits;
    }

    if (digits.startsWith('0') && digits.length >= 9) {
      return '963${digits.substring(1)}';
    }

    return digits;
  }

  String _buildWhatsAppMessage(AdminOrder order) {
    final buffer = StringBuffer();
    buffer.writeln('مرحباً، هذه تفاصيل طلبك من Lexi Mega Store:');
    buffer.writeln('رقم الطلب: #${order.orderNumber}');
    buffer.writeln('الحالة: ${_statusLabel(order.status)}');
    buffer.writeln('التاريخ: ${_formatDate(order.date)}');
    buffer.writeln('طريقة الدفع: ${_paymentLabel(order.paymentMethod)}');
    buffer.writeln(
      'الاسم: ${order.billing.firstName} ${order.billing.lastName}',
    );
    buffer.writeln('الهاتف: ${order.billing.phone}');
    buffer.writeln('العنوان: ${order.billing.city}, ${order.billing.address1}');
    buffer.writeln('');
    buffer.writeln('المنتجات:');

    for (final item in order.items) {
      final lineTotal = CurrencyFormatter.formatAmount(item.total);
      final unitPrice = CurrencyFormatter.formatAmount(item.price);
      buffer.writeln('- ${item.name} | ${item.qty} × $unitPrice = $lineTotal');
    }

    buffer.writeln('');
    buffer.writeln(
      'المجموع الفرعي: ${CurrencyFormatter.formatAmount(order.subtotal)}',
    );
    buffer.writeln(
      'الشحن: ${CurrencyFormatter.formatAmount(order.shippingCost)}',
    );
    buffer.writeln('الإجمالي: ${CurrencyFormatter.formatAmount(order.total)}');

    if ((order.customerNote ?? '').trim().isNotEmpty) {
      buffer.writeln('');
      buffer.writeln('ملاحظة العميل: ${order.customerNote!.trim()}');
    }

    buffer.writeln('');
    buffer.writeln('شكراً لتسوقك من Lexi Mega Store.');
    return buffer.toString();
  }

  Widget _buildSection(
    BuildContext context, {
    required String title,
    required Widget child,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: LexiSpacing.sm),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(LexiSpacing.md),
          decoration: BoxDecoration(
            color: LexiColors.white,
            borderRadius: BorderRadius.circular(LexiRadius.md),
            border: Border.all(color: LexiColors.outline),
          ),
          child: child,
        ),
      ],
    );
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null || dateStr.trim().isEmpty) {
      return '--';
    }
    try {
      return DateFormat('yyyy-MM-dd HH:mm').format(DateTime.parse(dateStr));
    } catch (_) {
      return dateStr;
    }
  }

  String _paymentLabel(String method) {
    switch (method.toLowerCase().trim()) {
      case 'cod':
        return 'الدفع عند الاستلام';
      case 'shamcash':
      case 'sham_cash':
      case 'sham-cash':
        return 'شام كاش';
      default:
        return method;
    }
  }

  String _statusLabel(String status) {
    final normalized = status.toLowerCase().trim();
    if (normalized == 'pending-verification' || normalized == 'on-hold') {
      return 'بانتظار التحقق من الدفع';
    }

    switch (status.toLowerCase().trim()) {
      case 'pending-verification':
      case 'on-hold':
        return 'بانتظار التحقق';
      case 'processing':
        return 'قيد المعالجة';
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
}

class _OrderItemTile extends StatelessWidget {
  final AdminOrderItem item;

  const _OrderItemTile({required this.item});

  @override
  Widget build(BuildContext context) {
    final totalLabel = CurrencyFormatter.formatAmount(item.total);
    final unitPriceLabel = CurrencyFormatter.formatAmount(item.price);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Container(
            width: 64,
            height: 64,
            color: LexiColors.lightGray,
            child: item.image.trim().isEmpty
                ? const Icon(Icons.image_not_supported, size: 20)
                : LexiNetworkImage(
                    imageUrl: item.image,
                    fit: BoxFit.cover,
                    errorWidget: const Icon(
                      Icons.image_not_supported,
                      size: 20,
                    ),
                  ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.name,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              if (item.variationLabel != null &&
                  item.variationLabel!.isNotEmpty) ...[
                Row(
                  children: [
                    if (ColorSwatchMapper.map(item.variationLabel!) !=
                        null) ...[
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: ColorSwatchMapper.map(item.variationLabel!),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: LexiColors.outline,
                            width: 0.5,
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                    ],
                    Text(
                      item.variationLabel!,
                      style: const TextStyle(
                        fontSize: 12,
                        color: LexiColors.secondaryText,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
              ],
              Text('رمز المنتج: ${item.sku.isEmpty ? '-' : item.sku}'),
              const SizedBox(height: 2),
              Text('الكمية: ${item.qty} × $unitPriceLabel'),
              const SizedBox(height: 2),
              Text('الإجمالي: $totalLabel'),
            ],
          ),
        ),
      ],
    );
  }
}

class _ActionButtons extends ConsumerWidget {
  final AdminOrder order;
  final bool isAssignedToCourier;

  const _ActionButtons({required this.order, this.isAssignedToCourier = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (order.status == 'on-hold' || order.status == 'pending-verification') {
      return Row(
        children: [
          Expanded(
            child: AppButton(
              label: 'تأكيد الدفع',
              type: AppButtonType.primary,
              onPressed: () async {
                await ref
                    .read(adminOrdersControllerProvider.notifier)
                    .updateOrderStatus(
                      order.id,
                      'processing',
                      note: 'تم تأكيد الدفع من لوحة التحكم',
                    );
              },
            ),
          ),
          const SizedBox(width: LexiSpacing.md),
          Expanded(
            child: AppButton(
              label: 'رفض الطلب',
              type: AppButtonType.secondary,
              onPressed: () async {
                await ref
                    .read(adminOrdersControllerProvider.notifier)
                    .updateOrderStatus(
                      order.id,
                      'cancelled',
                      note: 'تم رفض الطلب من لوحة التحكم',
                    );
              },
            ),
          ),
        ],
      );
    }

    if (order.status == 'processing' && !isAssignedToCourier) {
      return AppButton(
        label: 'تسليم الطلب (مكتمل)',
        type: AppButtonType.primary,
        onPressed: () async {
          await ref
              .read(adminOrdersControllerProvider.notifier)
              .updateOrderStatus(
                order.id,
                'completed',
                note: 'تم توصيل الطلب بنجاح',
              );
        },
      );
    }

    return const SizedBox.shrink();
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isEmphasis;

  const _DetailRow({
    required this.label,
    required this.value,
    this.isEmphasis = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: LexiColors.secondaryText),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: isEmphasis ? LexiColors.black : null,
            ),
          ),
        ),
      ],
    );
  }
}
