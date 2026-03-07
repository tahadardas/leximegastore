import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../app/theme/lexi_theme.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../shared/widgets/lexi_ui/lexi_app_bar.dart';
import '../../data/local/pending_shamcash_store.dart';

class PendingShamCashOrdersPage extends ConsumerStatefulWidget {
  const PendingShamCashOrdersPage({super.key});

  @override
  ConsumerState<PendingShamCashOrdersPage> createState() =>
      _PendingShamCashOrdersPageState();
}

class _PendingShamCashOrdersPageState
    extends ConsumerState<PendingShamCashOrdersPage> {
  var _isLoading = true;
  var _orders = <PendingShamCashOrder>[];

  @override
  void initState() {
    super.initState();
    _loadOrders();
  }

  Future<void> _loadOrders() async {
    final store = ref.read(pendingShamCashStoreProvider);
    final all = await store.getAll();
    if (!mounted) return;
    setState(() {
      _orders = all;
      _isLoading = false;
    });
  }

  void _onOrderTapped(PendingShamCashOrder order) {
    context.pushNamed(
      AppRouteNames.shamCashPayment,
      extra: {
        'orderId': order.orderId,
        'amount': order.amount,
        'currency': order.currency,
        'phone': order.phone,
        'accountName': order.accountName,
        'qrValue': order.qrValue,
        'barcodeValue': order.barcodeValue,
        'instructionsAr': order.instructionsAr,
        'uploadEndpoint': order.uploadEndpoint,
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: LexiColors.lightGray,
      appBar: const LexiAppBar(title: 'طلبات شام كاش غير المكتملة'),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: LexiColors.primary),
            )
          : _orders.isEmpty
          ? _buildEmptyState()
          : _buildList(),
    );
  }

  Widget _buildList() {
    return ListView.builder(
      padding: const EdgeInsets.all(LexiSpacing.md),
      itemCount: _orders.length,
      itemBuilder: (context, index) {
        final order = _orders[index];
        final amountDisplay = CurrencyFormatter.formatAmount(
          order.amount,
          symbol: order.currency,
        );

        return Card(
          elevation: 2,
          margin: const EdgeInsets.only(bottom: LexiSpacing.md),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(LexiRadius.md),
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.all(LexiSpacing.md),
            leading: Container(
              padding: const EdgeInsets.all(LexiSpacing.sm),
              decoration: BoxDecoration(
                color: LexiColors.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.receipt_long_outlined,
                color: LexiColors.primary,
              ),
            ),
            title: Text(
              'رقم الطلب: #${order.orderId}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: LexiSpacing.xs),
              child: Text(
                'المبلغ: $amountDisplay',
                style: const TextStyle(
                  color: LexiColors.black,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () => _onOrderTapped(order),
          ),
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(LexiSpacing.xl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.check_circle_outline,
              size: 80,
              color: LexiColors.outline,
            ),
            const SizedBox(height: LexiSpacing.lg),
            const Text(
              'لا يوجد طلبات شام كاش غير مكتملة',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: LexiColors.black,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: LexiSpacing.sm),
            const Text(
              'جميع طلباتك المرفوعة عبر شام كاش تم إرفاق الإيصال بها.',
              style: TextStyle(color: LexiColors.secondaryText),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
