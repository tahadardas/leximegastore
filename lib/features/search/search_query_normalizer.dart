String sanitizeSearchDisplayText(String raw) {
  return raw.replaceAll(RegExp(r'\s+'), ' ').trim();
}

String normalizeSearchQueryKey(String raw) {
  final cleaned = sanitizeSearchDisplayText(raw).toLowerCase();
  if (cleaned.isEmpty) {
    return '';
  }

  final withoutArabicMarks = cleaned
      .replaceAll(RegExp('[\u0610-\u061A]'), '')
      .replaceAll(RegExp('[\u064B-\u065F]'), '')
      .replaceAll(RegExp('[\u0670]'), '')
      .replaceAll(RegExp('[\u06D6-\u06ED]'), '')
      .replaceAll('ـ', '');

  return withoutArabicMarks.replaceAll(RegExp('[\u0300-\u036f]'), '');
}
