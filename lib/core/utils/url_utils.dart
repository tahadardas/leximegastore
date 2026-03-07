String normalizeHttpUrl(
  String url, {
  String baseUrl = 'https://leximega.store',
}) {
  var value = url.trim();
  if (value.isEmpty) {
    return '';
  }

  if (value.startsWith('//')) {
    value = 'https:$value';
  } else if (value.startsWith('/')) {
    value = '$baseUrl$value';
  } else if (value.startsWith('http://')) {
    value = value.replaceFirst('http://', 'https://');
  }

  // Some payloads contain already encoded Arabic filenames. Re-encoding those
  // values creates invalid URLs like:
  //   %D8.. -> %25D8.. -> %2525D8..
  // which breaks image proxy fetches.
  if (_looksOverEncoded(value)) {
    value = _decodeOverEncodedPercentBytes(value);
  }

  final parsed = Uri.tryParse(value);
  if (parsed == null) {
    return value;
  }

  return parsed.toString();
}

String? normalizeNullableHttpUrl(
  String? url, {
  String baseUrl = 'https://leximega.store',
}) {
  if (url == null) {
    return null;
  }

  final normalized = normalizeHttpUrl(url, baseUrl: baseUrl);
  return normalized.isEmpty ? null : normalized;
}

final RegExp _overEncodedPercentPattern = RegExp(r'%25([0-9a-fA-F]{2})');

bool _looksOverEncoded(String value) {
  return _overEncodedPercentPattern.hasMatch(value);
}

String _decodeOverEncodedPercentBytes(String value) {
  var current = value;
  for (var i = 0; i < 4; i++) {
    final next = current.replaceAllMapped(_overEncodedPercentPattern, (match) {
      final byte = match.group(1);
      if (byte == null) {
        return match.group(0) ?? '';
      }
      return '%${byte.toUpperCase()}';
    });
    if (next == current) {
      break;
    }
    current = next;
  }
  return current;
}
