import 'package:json_annotation/json_annotation.dart';

double parseDouble(dynamic v) {
  if (v == null) return 0.0;
  if (v is double) return v;
  if (v is int) return v.toDouble();
  if (v is num) return v.toDouble();
  if (v is bool) return v ? 1.0 : 0.0;

  if (v is String) {
    final normalized = _normalizeNumberString(v);
    if (normalized.isEmpty) return 0.0;
    return double.tryParse(normalized) ?? 0.0;
  }

  return 0.0;
}

int parseInt(dynamic v) {
  if (v == null) return 0;
  if (v is int) return v;
  if (v is num) return v.toInt();
  if (v is bool) return v ? 1 : 0;

  if (v is String) {
    final normalized = _normalizeNumberString(v);
    if (normalized.isEmpty) return 0;

    final asDouble = double.tryParse(normalized);
    if (asDouble != null) return asDouble.toInt();
  }

  return 0;
}

double? parseDoubleNullable(dynamic v) {
  if (v == null) return null;
  if (v is String && v.trim().isEmpty) return null;

  final parsed = parseDouble(v);
  return (parsed == 0.0 &&
          v != 0 &&
          v != 0.0 &&
          v != '0' &&
          v != '0.0' &&
          v != '0.00')
      ? null
      : parsed;
}

int? parseIntNullable(dynamic v) {
  if (v == null) return null;
  if (v is String && v.trim().isEmpty) return null;
  final parsed = parseInt(v);
  return (parsed == 0 && v != 0 && v != '0') ? null : parsed;
}

bool parseBool(dynamic v) {
  if (v == null) return false;
  if (v is bool) return v;
  if (v is num) return v != 0;

  if (v is String) {
    final normalized = v.trim().toLowerCase();
    if (normalized.isEmpty) return false;

    switch (normalized) {
      case '1':
      case 'true':
      case 'yes':
      case 'y':
      case 'on':
      case 'instock':
        return true;
      case '0':
      case 'false':
      case 'no':
      case 'n':
      case 'off':
      case 'outofstock':
        return false;
      default:
        return false;
    }
  }

  return false;
}

class BoolParser implements JsonConverter<bool, dynamic> {
  const BoolParser();

  @override
  bool fromJson(dynamic json) => parseBool(json);

  @override
  dynamic toJson(bool object) => object;
}

String _normalizeNumberString(String input) {
  var s = input.trim();
  if (s.isEmpty) return '';

  const arabicIndicDigits = <String, String>{
    '\u0660': '0',
    '\u0661': '1',
    '\u0662': '2',
    '\u0663': '3',
    '\u0664': '4',
    '\u0665': '5',
    '\u0666': '6',
    '\u0667': '7',
    '\u0668': '8',
    '\u0669': '9',
    '\u06F0': '0',
    '\u06F1': '1',
    '\u06F2': '2',
    '\u06F3': '3',
    '\u06F4': '4',
    '\u06F5': '5',
    '\u06F6': '6',
    '\u06F7': '7',
    '\u06F8': '8',
    '\u06F9': '9',
  };

  arabicIndicDigits.forEach((from, to) {
    s = s.replaceAll(from, to);
  });

  s = s
      .replaceAll('\u066B', '.') // Arabic decimal separator
      .replaceAll('\u066C', ',') // Arabic thousands separator
      .replaceAll('\u060C', ',') // Arabic comma
      .replaceAll(RegExp(r'\s+'), '');

  // Keep only number-relevant symbols.
  s = s.replaceAll(RegExp(r'[^0-9,.\-]'), '');
  if (s.isEmpty || s == '-') return '';

  final isNegative = s.startsWith('-');
  s = s.replaceAll('-', '');
  if (s.isEmpty) return '';

  final hasDot = s.contains('.');
  final hasComma = s.contains(',');

  if (hasDot && hasComma) {
    // Mixed separators: last separator is decimal, the other is grouping.
    final lastDot = s.lastIndexOf('.');
    final lastComma = s.lastIndexOf(',');
    final decimalSep = lastDot > lastComma ? '.' : ',';
    final thousandsSep = decimalSep == '.' ? ',' : '.';
    s = s.replaceAll(thousandsSep, '');
    if (decimalSep == ',') {
      s = s.replaceAll(',', '.');
    }
  } else if (hasDot || hasComma) {
    // Single separator type: infer thousands vs decimal.
    final sep = hasDot ? '.' : ',';
    final parts = s.split(sep);
    if (parts.length > 2) {
      final last = parts.removeLast();
      final left = parts.join();
      s = last.length <= 2 ? '$left.$last' : '$left$last';
    } else {
      final left = parts[0];
      final right = parts.length > 1 ? parts[1] : '';
      if (right.isEmpty) {
        s = left;
      } else if (right.length == 3 && left.isNotEmpty) {
        s = '$left$right';
      } else {
        s = '$left.$right';
      }
    }
  }

  // Keep only one decimal point.
  s = s.replaceAll(RegExp(r'[^0-9.]'), '');
  final firstDot = s.indexOf('.');
  if (firstDot != -1) {
    final intPart = s.substring(0, firstDot + 1);
    final fracPart = s.substring(firstDot + 1).replaceAll('.', '');
    s = '$intPart$fracPart';
  }

  if (s.isEmpty || s == '.') return '';
  if (isNegative && s != '0') return '-$s';
  return s;
}
