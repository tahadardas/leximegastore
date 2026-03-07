import 'package:intl/intl.dart';

/// Unified money formatting for Lexi app prices.
abstract class CurrencyFormatter {
  static const String sypSymbol = 'ل.س';

  static final Map<int, NumberFormat> _formatCache = {};

  static String formatAmount(
    num? value, {
    int decimalDigits = 0,
    bool withSymbol = true,
    String symbol = sypSymbol,
  }) {
    final amount = value ?? 0;
    final formatter = _formatCache.putIfAbsent(
      decimalDigits,
      () => NumberFormat.currency(
        locale: 'en_US',
        symbol: '',
        decimalDigits: decimalDigits,
      ),
    );

    final number = formatter.format(amount).trim();
    if (!withSymbol) {
      return number;
    }
    return '$number $symbol';
  }

  static String formatAmountOrUnavailable(
    num? value, {
    int decimalDigits = 0,
    bool withSymbol = true,
    String symbol = sypSymbol,
    String unavailableText = 'غير متوفر',
  }) {
    if (value == null || value <= 0) {
      return unavailableText;
    }
    return formatAmount(
      value,
      decimalDigits: decimalDigits,
      withSymbol: withSymbol,
      symbol: symbol,
    );
  }
}
