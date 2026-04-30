import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Provider for a unique device ID that persists across app sessions.
/// Used for identifying guest customers for notifications and analytics.
final deviceIdProvider = FutureProvider<String>((ref) async {
  const key = 'lexi_device_id_v2';
  final prefs = await SharedPreferences.getInstance();

  final existing = (prefs.getString(key) ?? '').trim();
  if (existing.isNotEmpty) {
    return existing;
  }

  final newId = _generateDeviceId();
  await prefs.setString(key, newId);
  return newId;
});

String _generateDeviceId() {
  final random = Random.secure();
  final partA = DateTime.now().microsecondsSinceEpoch.toRadixString(36);
  // Using 1 << 31 (2^31) is safe on both VM and Web/JS.
  // 1 << 32 overflows to 0 in JS bitwise ops, causing RangeError in nextInt(0).
  final partB = random.nextInt(1 << 31).toRadixString(36);
  final partC = random.nextInt(1 << 31).toRadixString(36);
  return '$partA-$partB-$partC';
}
