String normalizeArabicDigits(String input) {
  if (input.isEmpty) {
    return input;
  }

  const arabicIndic = <String, String>{
    '٠': '0',
    '١': '1',
    '٢': '2',
    '٣': '3',
    '٤': '4',
    '٥': '5',
    '٦': '6',
    '٧': '7',
    '٨': '8',
    '٩': '9',
  };
  const easternArabicIndic = <String, String>{
    '۰': '0',
    '۱': '1',
    '۲': '2',
    '۳': '3',
    '۴': '4',
    '۵': '5',
    '۶': '6',
    '۷': '7',
    '۸': '8',
    '۹': '9',
  };

  var normalized = input;
  arabicIndic.forEach((from, to) {
    normalized = normalized.replaceAll(from, to);
  });
  easternArabicIndic.forEach((from, to) {
    normalized = normalized.replaceAll(from, to);
  });
  return normalized;
}

String normalizeOrderNumber(String input) {
  final normalizedDigits = normalizeArabicDigits(input);
  return normalizedDigits.replaceAll(RegExp(r'[^0-9]'), '');
}

String normalizeOrderLookupInput(String input) {
  var value = normalizeArabicDigits(input).trim();
  if (value.startsWith('#')) {
    value = value.substring(1).trimLeft();
  }
  value = value.replaceAll(RegExp(r'\s+'), '');
  return value;
}
