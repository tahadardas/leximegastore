import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'search_query_normalizer.dart';

final recentSearchStoreProvider = Provider<RecentSearchStore>((ref) {
  return const RecentSearchStore();
});

class RecentSearchStore {
  static const _key = 'lexi_recent_searches_v1';
  static const _maxItems = 20;

  const RecentSearchStore();

  Future<List<String>> read() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getStringList(_key) ?? const <String>[];
      return _sanitize(list);
    } catch (_) {
      return const <String>[];
    }
  }

  Future<List<String>> add(String query) async {
    final value = sanitizeSearchDisplayText(query);
    if (value.isEmpty) {
      return read();
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      final current = _sanitize(prefs.getStringList(_key) ?? const <String>[]);

      final normalized = normalizeSearchQueryKey(value);
      final withoutDuplicate = current
          .where((item) => normalizeSearchQueryKey(item) != normalized)
          .toList(growable: true);

      withoutDuplicate.insert(0, value);
      final next = withoutDuplicate.take(_maxItems).toList(growable: false);
      await prefs.setStringList(_key, next);
      return next;
    } catch (_) {
      return read();
    }
  }

  Future<List<String>> remove(String query) async {
    final normalized = normalizeSearchQueryKey(query);
    try {
      final prefs = await SharedPreferences.getInstance();
      final current = _sanitize(prefs.getStringList(_key) ?? const <String>[]);
      final next = current
          .where((item) => normalizeSearchQueryKey(item) != normalized)
          .toList(growable: false);

      await prefs.setStringList(_key, next);
      return next;
    } catch (_) {
      return read();
    }
  }

  Future<void> clear() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_key);
    } catch (_) {
      // History clear is best effort.
    }
  }

  List<String> _sanitize(List<String> raw) {
    final seen = <String>{};
    final output = <String>[];
    for (final item in raw) {
      final value = sanitizeSearchDisplayText(item);
      if (value.isEmpty) {
        continue;
      }
      final key = normalizeSearchQueryKey(value);
      if (seen.contains(key)) {
        continue;
      }
      seen.add(key);
      output.add(value);
      if (output.length >= _maxItems) {
        break;
      }
    }
    return output;
  }
}
