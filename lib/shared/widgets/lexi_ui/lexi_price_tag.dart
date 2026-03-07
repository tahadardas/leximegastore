import 'package:flutter/material.dart';

import '../../../../core/utils/currency_formatter.dart';
import '../../../../design_system/lexi_typography.dart';

class LexiPriceTag extends StatelessWidget {
  final double price;
  final String currency;
  final TextStyle? style;
  final bool showCurrency;
  final int decimalDigits;

  const LexiPriceTag({
    super.key,
    required this.price,
    this.currency = CurrencyFormatter.sypSymbol,
    this.style,
    this.showCurrency = true,
    this.decimalDigits = 0,
  });

  @override
  Widget build(BuildContext context) {
    final amountText = CurrencyFormatter.formatAmount(
      price,
      withSymbol: false,
      decimalDigits: decimalDigits,
    );

    return Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: '$amountText ',
            style: style ?? LexiTypography.priceMd,
          ),
          if (showCurrency)
            TextSpan(
              text: currency,
              style: (style ?? LexiTypography.priceMd).copyWith(
                fontSize: (style?.fontSize ?? 16) * 0.7,
                fontWeight: FontWeight.normal,
              ),
            ),
        ],
      ),
    );
  }
}
