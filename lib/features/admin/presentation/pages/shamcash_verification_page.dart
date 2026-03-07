import '../../../../ui/widgets/lexi_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:quickalert/quickalert.dart';

import '../../../../core/utils/currency_formatter.dart';
import '../../../../design_system/lexi_tokens.dart';
import '../../domain/entities/shamcash_order.dart';
import '../controllers/shamcash_verification_controller.dart';

/// Page displaying ShamCash orders awaiting verification
class ShamCashVerificationPage extends ConsumerStatefulWidget {
  const ShamCashVerificationPage({super.key});

  @override
  ConsumerState<ShamCashVerificationPage> createState() =>
      _ShamCashVerificationPageState();
}

class _ShamCashVerificationPageState
    extends ConsumerState<ShamCashVerificationPage> {
  final ScrollController _scrollController = ScrollController();
  String _friendlyError([Object? error]) {
    final raw = (error ?? '').toString().toLowerCase();
    if (raw.contains('401') ||
        raw.contains('forbidden') ||
        raw.contains('unauthorized') ||
        raw.contains('rest_forbidden')) {
      return '\u0627\u0646\u062a\u0647\u062a\u0020\u062c\u0644\u0633\u0629\u0020\u0627\u0644\u0625\u062f\u0627\u0631\u0629\u002e\u0020\u064a\u0631\u062c\u0649\u0020\u062a\u0633\u062c\u064a\u0644\u0020\u0627\u0644\u062f\u062e\u0648\u0644\u0020\u0645\u0646\u0020\u062c\u062f\u064a\u062f\u002e';
    }
    if (raw.contains('connection') ||
        raw.contains('socketexception') ||
        raw.contains('xmlhttprequest') ||
        raw.contains('timeout')) {
      return '\u062a\u0639\u0630\u0631\u0020\u0627\u0644\u0627\u062a\u0635\u0627\u0644\u0020\u0628\u0627\u0644\u062e\u0627\u062f\u0645\u0020\u062d\u0627\u0644\u064a\u0627\u064b\u002e\u0020\u062d\u0627\u0648\u0644\u0020\u0645\u0631\u0629\u0020\u0623\u062e\u0631\u0649\u002e';
    }
    return '\u062d\u062f\u062b\u0020\u062e\u0637\u0623\u0020\u063a\u064a\u0631\u0020\u0645\u062a\u0648\u0642\u0639\u0020\u0623\u062b\u0646\u0627\u0621\u0020\u062a\u062d\u0645\u064a\u0644\u0020\u0627\u0644\u0637\u0644\u0628\u0627\u062a\u002e';
  }

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent * 0.9) {
      ref.read(shamCashVerificationProvider.notifier).loadMore();
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(shamCashVerificationProvider);

    return Scaffold(
      floatingActionButton: FloatingActionButton.small(
        heroTag: 'shamcash_refresh',
        onPressed: () =>
            ref.read(shamCashVerificationProvider.notifier).refresh(),
        child: const Icon(Icons.refresh),
      ),
      body: _buildBody(state),
    );
  }

  Widget _buildBody(ShamCashVerificationState state) {
    if (state.isLoading && state.orders.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state.error != null && state.orders.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(LexiSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.error_outline,
                size: 48,
                color: LexiColors.error,
              ),
              const SizedBox(height: 16),
              Text(_friendlyError(state.error), textAlign: TextAlign.center),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () =>
                    ref.read(shamCashVerificationProvider.notifier).refresh(),
                child: const Text(
                  '\u0625\u0639\u0627\u062f\u0629\u0020\u0627\u0644\u0645\u062d\u0627\u0648\u0644\u0629',
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (state.orders.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.check_circle_outline,
              size: 64,
              color: LexiColors.success,
            ),
            SizedBox(height: 16),
            Text(
              'لا توجد طلبات بانتظار التحقق',
              style: TextStyle(fontSize: 18),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        // Summary header
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(LexiSpacing.md),
          color: LexiColors.warning.withValues(alpha: 0.1),
          child: Text(
            '${state.total} طلب بانتظار التحقق',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: LexiColors.warning,
            ),
          ),
        ),
        // Orders list
        Expanded(
          child: ListView.separated(
            controller: _scrollController,
            padding: const EdgeInsets.all(LexiSpacing.md),
            itemCount: state.orders.length + (state.isLoading ? 1 : 0),
            separatorBuilder: (_, _) => const SizedBox(height: LexiSpacing.sm),
            itemBuilder: (context, index) {
              if (index == state.orders.length) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: CircularProgressIndicator(),
                  ),
                );
              }
              return _ShamCashOrderCard(
                order: state.orders[index],
                isProcessing: state.processingOrderId == state.orders[index].id,
                isApproving:
                    state.isApproving &&
                    state.processingOrderId == state.orders[index].id,
                isRejecting:
                    state.isRejecting &&
                    state.processingOrderId == state.orders[index].id,
                onApprove: (note) =>
                    _approveOrder(context, state.orders[index].id, note),
                onReject: (reason) =>
                    _rejectOrder(context, state.orders[index].id, reason),
              );
            },
          ),
        ),
      ],
    );
  }

  Future<void> _approveOrder(
    BuildContext context,
    int orderId,
    String? note,
  ) async {
    QuickAlert.show(
      context: context,
      type: QuickAlertType.loading,
      title: 'جاري التأكيد...',
      text: 'يرجى الانتظار',
      barrierDismissible: false,
    );

    final result = await ref
        .read(shamCashVerificationProvider.notifier)
        .approveOrder(orderId, note: note);

    if (!context.mounted) {
      return;
    }

    Navigator.of(context, rootNavigator: true).pop();
    if (!context.mounted) {
      return;
    }
    if (result != null) {
      QuickAlert.show(
        context: context,
        type: QuickAlertType.success,
        title: 'تم التأكيد',
        text: result.message,
      );
    } else {
      final state = ref.read(shamCashVerificationProvider);
      QuickAlert.show(
        context: context,
        type: QuickAlertType.error,
        title: 'خطأ',
        text: _friendlyError(state.error),
      );
    }
  }

  Future<void> _rejectOrder(
    BuildContext context,
    int orderId,
    String reason,
  ) async {
    QuickAlert.show(
      context: context,
      type: QuickAlertType.loading,
      title: 'جاري الرفض...',
      text: 'يرجى الانتظار',
      barrierDismissible: false,
    );

    final result = await ref
        .read(shamCashVerificationProvider.notifier)
        .rejectOrder(orderId, reason: reason);

    if (!context.mounted) {
      return;
    }

    Navigator.of(context, rootNavigator: true).pop();
    if (!context.mounted) {
      return;
    }
    if (result != null) {
      QuickAlert.show(
        context: context,
        type: QuickAlertType.success,
        title: 'تم الرفض',
        text: result.message,
      );
    } else {
      final state = ref.read(shamCashVerificationProvider);
      QuickAlert.show(
        context: context,
        type: QuickAlertType.error,
        title: 'خطأ',
        text: _friendlyError(state.error),
      );
    }
  }
}

/// Card displaying a single ShamCash order
class _ShamCashOrderCard extends StatelessWidget {
  final ShamCashOrder order;
  final bool isProcessing;
  final bool isApproving;
  final bool isRejecting;
  final Future<void> Function(String? note) onApprove;
  final Future<void> Function(String reason) onReject;

  const _ShamCashOrderCard({
    required this.order,
    this.isProcessing = false,
    this.isApproving = false,
    this.isRejecting = false,
    required this.onApprove,
    required this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(LexiRadius.lg),
        side: const BorderSide(color: LexiColors.warning, width: 2),
      ),
      child: Padding(
        padding: const EdgeInsets.all(LexiSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '#${order.orderNumber}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: LexiColors.warning.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    order.statusLabelAr,
                    style: const TextStyle(
                      color: LexiColors.warning,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: LexiSpacing.sm),

            // Customer info
            _InfoRow(
              icon: Icons.person_outline,
              label: 'العميل',
              value: order.customerName,
            ),
            const SizedBox(height: 4),
            _InfoRow(
              icon: Icons.phone_outlined,
              label: 'الهاتف',
              value: order.customerPhone,
            ),
            const SizedBox(height: 4),
            _InfoRow(
              icon: Icons.calendar_today_outlined,
              label: 'التاريخ',
              value: _formatDate(order.dateCreated),
            ),
            const SizedBox(height: 4),
            _InfoRow(
              icon: Icons.attach_money,
              label: 'المبلغ',
              value: CurrencyFormatter.formatAmount(order.total),
              isBold: true,
            ),

            // Proof image
            if (order.proof?.imageUrl != null) ...[
              const SizedBox(height: LexiSpacing.md),
              const Text(
                'إيصال الدفع:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              GestureDetector(
                onTap: () => _showProofImage(context, order.proof!.imageUrl!),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(LexiRadius.md),
                  child: Hero(
                    tag: 'proof_${order.id}',
                    child: LexiImage(
                      imageUrl: order.proof!.imageUrl!,
                      height: 150,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      borderRadius: BorderRadius.circular(LexiRadius.md),
                    ),
                  ),
                ),
              ),
            ],

            // Proof note
            if (order.proof?.note != null && order.proof!.note!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'ملاحظة: ${order.proof!.note}',
                  style: const TextStyle(fontSize: 12),
                ),
              ),
            ],

            // Action buttons
            const SizedBox(height: LexiSpacing.md),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: isProcessing
                        ? null
                        : () => _showApproveDialog(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: LexiColors.success,
                      foregroundColor: Colors.white,
                    ),
                    icon: isApproving
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.check),
                    label: const Text('تأكيد'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: isProcessing
                        ? null
                        : () => _showRejectDialog(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: LexiColors.error,
                      foregroundColor: Colors.white,
                    ),
                    icon: isRejecting
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.close),
                    label: const Text('رفض'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(String dateStr) {
    try {
      final date = DateTime.parse(dateStr);
      return DateFormat('yyyy/MM/dd HH:mm').format(date);
    } catch (_) {
      return dateStr;
    }
  }

  void _showProofImage(BuildContext context, String imageUrl) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _ProofImagePage(imageUrl: imageUrl, orderId: order.id),
      ),
    );
  }

  void _showApproveDialog(BuildContext context) {
    final noteController = TextEditingController();

    QuickAlert.show(
      context: context,
      type: QuickAlertType.confirm,
      title: 'تأكيد الدفع',
      text: 'هل أنت متأكد من تأكيد دفع الطلب #${order.orderNumber}؟',
      confirmBtnText: 'تأكيد',
      cancelBtnText: 'إلغاء',
      confirmBtnColor: LexiColors.success,
      widget: Column(
        children: [
          const SizedBox(height: 16),
          TextField(
            controller: noteController,
            decoration: const InputDecoration(
              labelText: 'ملاحظة (اختياري)',
              border: OutlineInputBorder(),
            ),
            maxLines: 2,
          ),
        ],
      ),
      onConfirmBtnTap: () async {
        if (!context.mounted) {
          return;
        }
        await onApprove(
          noteController.text.isEmpty ? null : noteController.text,
        );
      },
    );
  }

  void _showRejectDialog(BuildContext context) {
    final reasonController = TextEditingController();

    QuickAlert.show(
      context: context,
      type: QuickAlertType.warning,
      title: 'رفض الدفع',
      text: 'يرجى كتابة سبب الرفض:',
      confirmBtnText: 'رفض',
      cancelBtnText: 'إلغاء',
      confirmBtnColor: LexiColors.error,
      widget: Column(
        children: [
          const SizedBox(height: 16),
          TextField(
            controller: reasonController,
            decoration: const InputDecoration(
              labelText: 'سبب الرفض *',
              border: OutlineInputBorder(),
              hintText: 'مثال: الإيصال غير واضح',
            ),
            maxLines: 3,
            autofocus: true,
          ),
        ],
      ),
      onConfirmBtnTap: () async {
        final reason = reasonController.text.trim();
        if (reason.length < 5) {
          if (!context.mounted) {
            return;
          }
          QuickAlert.show(
            context: context,
            type: QuickAlertType.error,
            title: 'خطأ',
            text: 'يرجى كتابة سبب الرفض (5 أحرف على الأقل)',
          );
          return;
        }
        if (!context.mounted) {
          return;
        }
        await onReject(reason);
      },
    );
  }
}

/// Info row with icon and label
class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final bool isBold;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    this.isBold = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.grey[600]),
        const SizedBox(width: 8),
        Text(
          '$label: ',
          style: TextStyle(color: Colors.grey[600], fontSize: 13),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              fontSize: 13,
            ),
            textAlign: TextAlign.end,
          ),
        ),
      ],
    );
  }
}

/// Full-screen proof image viewer
class _ProofImagePage extends StatelessWidget {
  final String imageUrl;
  final int orderId;

  const _ProofImagePage({required this.imageUrl, required this.orderId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text('إيصال الطلب #$orderId'),
      ),
      body: Center(
        child: InteractiveViewer(
          minScale: 0.5,
          maxScale: 4.0,
          child: Hero(
            tag: 'proof_$orderId',
            child: LexiImage(
              imageUrl: imageUrl,
              fit: BoxFit.contain,
              errorWidget: const Icon(
                Icons.error,
                color: Colors.white,
                size: 48,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
