import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/lexi_theme.dart';
import '../../../../core/session/app_session.dart';
import '../../../../shared/widgets/app_button.dart';

class OrderSuccessPage extends ConsumerStatefulWidget {
  final String orderId;
  final String? phone;

  const OrderSuccessPage({super.key, required this.orderId, this.phone});

  @override
  ConsumerState<OrderSuccessPage> createState() => _OrderSuccessPageState();
}

class _OrderSuccessPageState extends ConsumerState<OrderSuccessPage> {
  bool _isSharing = false;

  Future<void> _handleShareReceipt() async {
    final phone = (widget.phone ?? '').trim();
    final isLoggedIn = ref.read(appSessionProvider).isLoggedIn;
    if (phone.isEmpty && !isLoggedIn) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_arabicPhoneRequiredMessage())));
      return;
    }

    setState(() => _isSharing = true);
    try {
      final uri = Uri(
        path: '/orders/${widget.orderId}/invoice',
        queryParameters: {
          'type': 'provisional',
          if (phone.isNotEmpty) 'phone': phone,
        },
      );
      await context.push<void>(uri.toString());
    } finally {
      if (mounted) {
        setState(() => _isSharing = false);
      }
    }
  }

  String _arabicPhoneRequiredMessage() =>
      '\u0631\u0642\u0645 \u0627\u0644\u0647\u0627\u062a\u0641 \u0645\u0637\u0644\u0648\u0628 \u0644\u0639\u0631\u0636 \u0641\u0627\u062a\u0648\u0631\u0629 \u0637\u0644\u0628 \u0627\u0644\u0636\u064a\u0641.';

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
