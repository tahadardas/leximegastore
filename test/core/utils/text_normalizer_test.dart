import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:lexi_mega_store/core/utils/text_normalizer.dart';

void main() {
  group('TextNormalizer', () {
    test('returns empty string for null', () {
      expect(TextNormalizer.normalize(null), '');
    });

    test('fixes single mojibake Arabic text', () {
      const original = 'كل المنتجات';
      final corrupted = _corruptOnce(original);

      expect(TextNormalizer.normalize(corrupted), original);
    });

    test('fixes double mojibake Arabic text', () {
      const original = 'كل المنتجات';
      final corrupted = _corruptOnce(_corruptOnce(original));

      expect(TextNormalizer.normalize(corrupted), original);
    });

    test('keeps valid text unchanged', () {
      const original = 'حقيبة مدرسية';

      expect(TextNormalizer.normalize(original), original);
    });
  });
}

String _corruptOnce(String text) => latin1.decode(utf8.encode(text));
