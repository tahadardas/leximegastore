import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/lexi_theme.dart';
import '../../../../l10n/l10n.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/lexi_ui/lexi_app_bar.dart';

class PaymentPage extends StatelessWidget {
  const PaymentPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      backgroundColor: LexiColors.lightGray,
      appBar: LexiAppBar(title: l10n.appPaymentTitle),
      body: Padding(
        padding: const EdgeInsets.all(LexiSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const FaIcon(
              FontAwesomeIcons.moneyBillWave,
              size: 58,
              color: LexiColors.primary,
            ),
            const SizedBox(height: LexiSpacing.md),
            Text(
              l10n.paymentInfoIntro,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: LexiSpacing.sm),
            Text(
              l10n.paymentInfoSteps,
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: LexiColors.secondaryText),
            ),
            const SizedBox(height: LexiSpacing.lg),
            AppButton(
              label: l10n.paymentGoToCart,
              icon: Icons.shopping_cart_outlined,
              onPressed: () => context.go('/cart'),
            ),
          ],
        ),
      ),
    );
  }
}
