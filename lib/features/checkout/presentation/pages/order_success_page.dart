import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/lexi_theme.dart';
import '../../../../shared/services/share_service.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../orders/data/repositories/order_repository_impl.dart';

class OrderSuccessPage extends ConsumerStatefulWidget {
  final String orderId;

  const OrderSuccessPage({super.key, required this.orderId});

  @override
  ConsumerState<OrderSuccessPage> createState() => _OrderSuccessPageState();
}

class _OrderSuccessPageState extends ConsumerState<OrderSuccessPage> {
  bool _isSharing = false;

  Future<void> _handleShareReceipt() async {
    setState(() => _isSharing = true);
    try {
      final orderIdInt = int.tryParse(widget.orderId);
      if (orderIdInt == null) return;

      final order = await ref
          .read(orderRepositoryProvider)
          .myOrderDetails(orderIdInt);
      await ShareService.instance.shareOrderToWhatsApp(order);
    } catch (e) {
      // If full details fetch fails or WhatsApp fails, fallback to provisional invoice URL
      if (mounted) {
        context.push('/orders/${widget.orderId}/invoice?type=provisional');
      }
    } finally {
      if (mounted) {
        setState(() => _isSharing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: LexiColors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(LexiSpacing.lg),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),
              const Icon(
                Icons.check_circle_outline,
                size: 100,
                color: LexiColors.primary,
              ),
              const SizedBox(height: LexiSpacing.md),
              Text(
                'تم الطلب بنجاح!',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: LexiColors.black,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: LexiSpacing.xs),
              Text(
                'رقم الطلب: #${widget.orderId}',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: LexiColors.secondaryText,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: LexiSpacing.sm),
              Text(
                'سيتم توصيل طلبك قريباً.\nالدفع عند الاستلام.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: LexiColors.secondaryText,
                ),
                textAlign: TextAlign.center,
              ),
              const Spacer(),
              AppButton(
                label: 'تتبع الطلب',
                icon: Icons.local_shipping_outlined,
                onPressed: () {
                  context.go('/orders/status?order_number=${widget.orderId}');
                },
              ),
              const SizedBox(height: LexiSpacing.md),
              AppButton(
                label: 'إيصال الطلب',
                type: AppButtonType.secondary,
                icon: Icons.receipt_long,
                isLoading: _isSharing,
                onPressed: _handleShareReceipt,
              ),
              const SizedBox(height: LexiSpacing.md),
              TextButton(
                onPressed: () => context.go('/'),
                style: TextButton.styleFrom(
                  foregroundColor: LexiColors.secondaryText,
                ),
                child: const Text('العودة للرئيسية'),
              ),
              const SizedBox(height: LexiSpacing.lg),
            ],
          ),
        ),
      ),
    );
  }
}
