import 'dart:convert';

class TextNormalizer {
  static final RegExp _likelyMojibake = RegExp(
    // Covers common Arabic mojibake sequences such as:
    // Ø§Ù„..., ø§ù„..., Ã˜..., Â..., â...
    r'(?:Ã.|Â.|Ø.|Ù.|ø.|ù.|â..|±|\uFFFD)',
    caseSensitive: false,
  );
  static final RegExp _arabicChars = RegExp(r'[\u0600-\u06FF]');

  static String normalize(dynamic value) {
    if (value == null) {
      return '';
    }
    return _repairMojibake(value.toString());
  }

  static String _repairMojibake(String input) {
    if (input.isEmpty) {
      return input;
    }

    var current = input;
    for (var i = 0; i < 2; i++) {
      if (!_likelyMojibake.hasMatch(current)) {
        break;
      }

      try {
        final candidate = utf8.decode(latin1.encode(current));
        if (_arabicScore(candidate) <= _arabicScore(current)) {
          break;
        }
        current = candidate;
      } catch (_) {
        break;
      }
    }

    return current;
  }

  static int _arabicScore(String text) => _arabicChars.allMatches(text).length;
}
