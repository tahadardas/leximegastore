class CouponModel {
  final String code;
  final bool isValid;
  final double discountAmount;
  final String discountType;
  final String message;
  final String? description;

  const CouponModel({
    required this.code,
    required this.isValid,
    required this.discountAmount,
    required this.discountType,
    required this.message,
    this.description,
  });

  factory CouponModel.fromJson(Map<String, dynamic> json) {
    final source = _unwrapData(json);
    final discount = _asDouble(source['discount_amount'] ?? source['amount']);
    final validValue = source['valid'];
    final isValid = validValue == null ? discount > 0 : _asBool(validValue);
    final message = _asString(source['message']);

    return CouponModel(
      code: _asString(source['code']),
      isValid: isValid,
      discountAmount: discount,
      discountType: _asString(source['discount_type'], fallback: 'fixed_cart'),
      message: message.isNotEmpty
          ? message
          : (isValid ? 'تم تطبيق القسيمة بنجاح.' : 'القسيمة غير صالحة.'),
      description: _asNullableString(source['description']),
    );
  }

  static Map<String, dynamic> _unwrapData(Map<String, dynamic> json) {
    final data = json['data'];
    if (data is Map) {
      return Map<String, dynamic>.from(
        data.map((key, value) => MapEntry(key.toString(), value)),
      );
    }
    return json;
  }

  static String _asString(dynamic value, {String fallback = ''}) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? fallback : text;
  }

  static String? _asNullableString(dynamic value) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? null : text;
  }

  static double _asDouble(dynamic value) {
    if (value is num) {
      return value.toDouble();
    }
    final rawText = value?.toString().trim() ?? '';
    if (rawText.isEmpty) {
      return 0;
    }

    var normalized = rawText.replaceAll(RegExp(r'[^0-9,.\-]'), '');
    if (normalized.isEmpty) {
      return 0;
    }

    final hasComma = normalized.contains(',');
    final hasDot = normalized.contains('.');

    if (hasComma && hasDot) {
      final lastComma = normalized.lastIndexOf(',');
      final lastDot = normalized.lastIndexOf('.');
      if (lastComma > lastDot) {
        normalized = normalized.replaceAll('.', '').replaceAll(',', '.');
      } else {
        normalized = normalized.replaceAll(',', '');
      }
    } else if (hasComma) {
      final thousandsOnly = RegExp(
        r'^-?\d{1,3}(,\d{3})+$',
      ).hasMatch(normalized);
      normalized = thousandsOnly
          ? normalized.replaceAll(',', '')
          : normalized.replaceAll(',', '.');
    } else if (hasDot &&
        RegExp(r'^-?\d{1,3}(\.\d{3})+$').hasMatch(normalized)) {
      normalized = normalized.replaceAll('.', '');
    }

    return double.tryParse(normalized) ?? 0;
  }

  static bool _asBool(dynamic value) {
    if (value is bool) {
      return value;
    }
    if (value is num) {
      return value != 0;
    }
    final text = value?.toString().trim().toLowerCase() ?? '';
    if (text == 'true' || text == '1' || text == 'yes') {
      return true;
    }
    if (text == 'false' || text == '0' || text == 'no') {
      return false;
    }
    return false;
  }
}
