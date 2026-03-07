import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/lexi_theme.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/lexi_ui/lexi_app_bar.dart';

class PendingOrdersPage extends StatelessWidget {
  final String? orderId;

  const PendingOrdersPage({super.key, this.orderId});

  @override
  Widget build(BuildContext context) {
    final hasOrderId = orderId != null && orderId!.trim().isNotEmpty;

    return Scaffold(
      backgroundColor: LexiColors.lightGray,
      appBar: const LexiAppBar(title: 'الطلبات المعلقة'),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(LexiSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.all(LexiSpacing.lg),
                decoration: BoxDecoration(
                  color: LexiColors.white,
                  borderRadius: BorderRadius.circular(LexiRadius.lg),
                  border: Border.all(color: LexiColors.outline),
                ),
                child: Column(
                  children: [
                    const FaIcon(
                      FontAwesomeIcons.clockRotateLeft,
                      size: 60,
                      color: LexiColors.primary,
                    ),
                    const SizedBox(height: LexiSpacing.md),
                    const Text(
                      'تم إرسال طلبك بنجاح',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: LexiColors.black,
                      ),
                    ),
                    const SizedBox(height: LexiSpacing.sm),
                    if (hasOrderId)
                      Text(
                        'رقم الطلب: #${orderId!.trim()}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: LexiColors.secondaryText,
                        ),
                      ),
                    const SizedBox(height: LexiSpacing.md),
                    const Text(
                      'سيظهر طلبك ضمن صفحة الطلبات المعلقة حتى يتم التحقق من الدفع من قبل الإدارة.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 16,
                        height: 1.6,
                        color: LexiColors.black,
                      ),
                    ),
                    const SizedBox(height: LexiSpacing.sm),
                    const Text(
                      'سيصلك إشعار فور صدور القرار (قبول أو رفض).',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        color: LexiColors.secondaryText,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: LexiSpacing.lg),
              AppButton(
                label: 'عرض حالة الطلب',
                icon: Icons.visibility_outlined,
                onPressed: () {
                  final id = orderId?.trim();
                  if (id != null && id.isNotEmpty) {
                    context.go('/orders/status?order_number=$id');
                    return;
                  }
                  context.go('/track-order');
                },
              ),
              const SizedBox(height: LexiSpacing.md),
              AppButton(
                label: 'العودة إلى الرئيسية',
                type: AppButtonType.secondary,
                icon: Icons.home_outlined,
                onPressed: () => context.go('/'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
