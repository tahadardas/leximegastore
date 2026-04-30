import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

final cacheStoreProvider = Provider<CacheStore>((ref) {
  return CacheStore.instance;
});

class CachedJsonEntry {
  final Map<String, dynamic> data;
  final DateTime savedAt;

  const CachedJsonEntry({required this.data, required this.savedAt});
}

class CacheStore {
  static const String _boxName = 'lexi_cache_box_v1';
  static final CacheStore instance = CacheStore._();

  Box<dynamic>? _box;

  CacheStore._();

  Future<void> init() async {
    _box ??= await Hive.openBox<dynamic>(_boxName);
  }

  Future<void> saveJson(
    String key,
    Map<String, dynamic> data,
    DateTime savedAt,
  ) async {
    await init();
    await _box!.put(key, <String, dynamic>{
      'data': _jsonSafe(data),
      'saved_at': savedAt.toIso8601String(),
    });
  }

  Future<CachedJsonEntry?> readJson(String key) async {
    await init();
    final raw = _box!.get(key);
    if (raw is! Map) {
      return null;
    }

    final map = raw.map((k, v) => MapEntry(k.toString(), v));
    final dataRaw = map['data'];
    if (dataRaw is! Map) {
      return null;
    }

    final savedAtRaw = (map['saved_at'] ?? '').toString().trim();
    final savedAt = DateTime.tryParse(savedAtRaw);
    if (savedAt == null) {
      return null;
    }

    return CachedJsonEntry(
      data: dataRaw.map((k, v) => MapEntry(k.toString(), v)),
      savedAt: savedAt,
    );
  }

  Future<bool> isFresh(String key, Duration ttl) async {
    final item = await readJson(key);
    if (item == null) {
      return false;
    }
    return DateTime.now().difference(item.savedAt) <= ttl;
  }

  Future<void> delete(String key) async {
    await init();
    await _box!.delete(key);
  }

  Future<void> deleteByPrefix(String prefix) async {
    await init();
    final normalizedPrefix = prefix.trim();
    if (normalizedPrefix.isEmpty) {
      return;
    }

    final keys = _box!.keys
        .where((key) => key.toString().startsWith(normalizedPrefix))
        .toList(growable: false);
    if (keys.isEmpty) {
      return;
    }
    await _box!.deleteAll(keys);
  }

  Future<void> clear() async {
    await init();
    await _box!.clear();
  }

  Map<String, dynamic> _jsonSafe(Map<String, dynamic> data) {
    return jsonDecode(jsonEncode(data)) as Map<String, dynamic>;
  }
}
