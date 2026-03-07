import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

final trackedOrderStoreProvider = Provider<TrackedOrderStore>((ref) {
  return TrackedOrderStore();
});

class TrackedOrder {
  final String orderId;
  final String createdAt;

  const TrackedOrder({
    required this.orderId,
    required this.createdAt,
  });

  factory TrackedOrder.fromJson(Map<String, dynamic> json) {
    return TrackedOrder(
      orderId: (json['order_id'] ?? '').toString(),
      createdAt: (json['created_at'] ?? '').toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {'order_id': orderId, 'created_at': createdAt};
  }
}

class TrackedOrderStore {
  static const _storageKey = 'tracked_orders_v2';

  Future<List<TrackedOrder>> getAll() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);
    if (raw == null || raw.trim().isEmpty) {
      return const [];
    }

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) {
        return const [];
      }
      return decoded
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .map(TrackedOrder.fromJson)
          .where(
            (e) => e.orderId.trim().isNotEmpty,
          )
          .toList();
    } catch (_) {
      return const [];
    }
  }

  Future<void> save({required String orderId}) async {
    final normalizedOrderId = orderId.trim();
    if (normalizedOrderId.isEmpty) {
      return;
    }

    final all = await getAll();
    final withoutCurrent = all.where((e) => e.orderId != normalizedOrderId);
    final updated = <TrackedOrder>[
      ...withoutCurrent,
      TrackedOrder(
        orderId: normalizedOrderId,
        createdAt: DateTime.now().toIso8601String(),
      ),
    ];

    final prefs = await SharedPreferences.getInstance();
    final payload = jsonEncode(updated.map((e) => e.toJson()).toList());
    await prefs.setString(_storageKey, payload);
  }

  Future<TrackedOrder?> getLatest() async {
    final all = await getAll();
    if (all.isEmpty) {
      return null;
    }
    all.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return all.first;
  }
}
