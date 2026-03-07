import 'package:flutter/material.dart';

import '../../design_system/lexi_tokens.dart';

class ColorSwatchMapper {
  static Color? map(String rawName) {
    final normalized = rawName.trim().toLowerCase();
    if (normalized.isEmpty) return null;

    if (_containsAny(normalized, ['أحمر', 'احمر', 'red'])) {
      return Colors.red;
    }
    if (_containsAny(normalized, ['أزرق', 'ازرق', 'blue'])) {
      return Colors.blue;
    }
    if (_containsAny(normalized, ['أسود', 'اسود', 'black'])) {
      return Colors.black;
    }
    if (_containsAny(normalized, ['أبيض', 'ابيض', 'white'])) {
      return Colors.white;
    }
    if (_containsAny(normalized, ['أخضر', 'اخضر', 'green'])) {
      return Colors.green;
    }
    if (_containsAny(normalized, ['وردي', 'زهري', 'pink'])) {
      return Colors.pink;
    }
    if (_containsAny(normalized, ['ذهبي', 'gold', 'golden'])) {
      return LexiColors.brandPrimary;
    }
    if (_containsAny(normalized, ['فضي', 'silver'])) {
      return const Color(0xFFC0C0C0);
    }
    if (_containsAny(normalized, ['رمادي', 'رصاصي', 'grey', 'gray'])) {
      return Colors.grey;
    }
    if (_containsAny(normalized, ['بني', 'brown'])) {
      return Colors.brown;
    }
    if (_containsAny(normalized, ['برتقالي', 'orange'])) {
      return Colors.orange;
    }
    if (_containsAny(normalized, ['بنفسجي', 'ليلكي', 'purple', 'violet'])) {
      return Colors.purple;
    }
    if (_containsAny(normalized, ['أصفر', 'اصفر', 'yellow'])) {
      return Colors.yellow;
    }
    if (_containsAny(normalized, ['كحلي', 'navy'])) {
      return const Color(0xFF000080);
    }
    if (_containsAny(normalized, ['سماوي', 'cyan', 'sky blue'])) {
      return Colors.cyan;
    }
    if (_containsAny(normalized, ['تركوازي', 'turquoise'])) {
      return const Color(0xFF40E0D0);
    }
    if (_containsAny(normalized, ['بيج', 'beige'])) {
      return const Color(0xFFF5F5DC);
    }
    if (_containsAny(normalized, ['عنابي', 'maroon'])) {
      return const Color(0xFF800000);
    }
    if (_containsAny(normalized, ['زيتي', 'olive'])) {
      return const Color(0xFF808000);
    }
    if (_containsAny(normalized, ['كريمي', 'cream'])) {
      return const Color(0xFFFFFDD0);
    }

    return null;
  }

  static bool _containsAny(String value, List<String> candidates) {
    for (final candidate in candidates) {
      if (value.contains(candidate.toLowerCase())) {
        return true;
      }
    }
    return false;
  }
}
