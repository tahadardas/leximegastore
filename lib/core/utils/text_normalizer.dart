import 'dart:convert';

class TextNormalizer {
  static final RegExp _likelyMojibake = RegExp(
    // Covers common Arabic mojibake sequences such as:
    // Ø§Ù„..., ø§ù„..., Ã˜..., Â..., â...
    r'(?:Ã.|Â.|Ø.|Ù.|ø.|ù.|â..|±|\uFFFD)',
    caseSensitive: false,
  );
  static final RegExp _arabicChars = RegExp(r'[\u0600-\u06FF]');
  static final Set<int> _suspiciousRunes = 'ØÙÃÂÐðâÊËÌÍÎÏÒÓÔÕÖ×ÚÛÜÝÞßœ€šŸøù±'
      .runes
      .toSet();

  static const Map<int, int> _cp1252PunctToByte = <int, int>{
    0x20AC: 0x80, // €
    0x201A: 0x82, // ‚
    0x0192: 0x83, // ƒ
    0x201E: 0x84, // „
    0x2026: 0x85, // …
    0x2020: 0x86, // †
    0x2021: 0x87, // ‡
    0x02C6: 0x88, // ˆ
    0x2030: 0x89, // ‰
    0x0160: 0x8A, // Š
    0x2039: 0x8B, // ‹
    0x0152: 0x8C, // Œ
    0x017D: 0x8E, // Ž
    0x2018: 0x91, // ‘
    0x2019: 0x92, // ’
    0x201C: 0x93, // “
    0x201D: 0x94, // ”
    0x2022: 0x95, // •
    0x2013: 0x96, // –
    0x2014: 0x97, // —
    0x02DC: 0x98, // ˜
    0x2122: 0x99, // ™
    0x0161: 0x9A, // š
    0x203A: 0x9B, // ›
    0x0153: 0x9C, // œ
    0x017E: 0x9E, // ž
    0x0178: 0x9F, // Ÿ
  };

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
    for (var i = 0; i < 3; i++) {
      if (!_likelyMojibake.hasMatch(current) &&
          _suspiciousScore(current) == 0) {
        break;
      }

      final candidates = <String?>[
        _decodeLatin1Utf8(current),
        _decodeWithCp1252PunctMap(current),
      ];
      final bestCandidate = _pickBestCandidate(current, candidates);
      if (bestCandidate == null || bestCandidate == current) {
        break;
      }
      current = bestCandidate;
    }

    return current;
  }

  static String? _pickBestCandidate(String base, List<String?> candidates) {
    final baseSuspicious = _suspiciousScore(base);
    final baseArabic = _arabicScore(base);

    String? best;
    var bestSuspicious = baseSuspicious;
    var bestArabic = baseArabic;

    for (final candidate in candidates) {
      if (candidate == null ||
          candidate.isEmpty ||
          candidate.contains('\uFFFD')) {
        continue;
      }

      final candidateSuspicious = _suspiciousScore(candidate);
      final candidateArabic = _arabicScore(candidate);
      final improvesSuspicious = candidateSuspicious < baseSuspicious;
      final improvesArabic = candidateArabic > baseArabic;

      if (!improvesSuspicious && !improvesArabic) {
        continue;
      }

      final betterThanBest =
          best == null ||
          candidateSuspicious < bestSuspicious ||
          (candidateSuspicious == bestSuspicious &&
              candidateArabic > bestArabic);
      if (!betterThanBest) {
        continue;
      }

      best = candidate;
      bestSuspicious = candidateSuspicious;
      bestArabic = candidateArabic;
    }

    return best;
  }

  static String? _decodeLatin1Utf8(String text) {
    try {
      return utf8.decode(latin1.encode(text));
    } catch (_) {
      return null;
    }
  }

  static String? _decodeWithCp1252PunctMap(String text) {
    final mapped = String.fromCharCodes(
      text.runes.map((rune) => _cp1252PunctToByte[rune] ?? rune),
    );
    try {
      return utf8.decode(latin1.encode(mapped));
    } catch (_) {
      return null;
    }
  }

  static int _suspiciousScore(String text) {
    var score = 0;
    for (final rune in text.runes) {
      if (_suspiciousRunes.contains(rune)) {
        score++;
      }
    }
    score += '\uFFFD'.allMatches(text).length * 2;
    return score;
  }

  static int _arabicScore(String text) => _arabicChars.allMatches(text).length;
}
