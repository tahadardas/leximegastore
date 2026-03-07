import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

final pendingDeliveryActionsStoreProvider =
    Provider<PendingDeliveryActionsStore>((ref) {
      return PendingDeliveryActionsStore();
    });

class PendingDeliveryAction {
  final int orderId;
  final String status;
  final String? collectedAmount;
  final String? currency;
  final String? note;
  final String createdAt;

  const PendingDeliveryAction({
    required this.orderId,
    required this.status,
    this.collectedAmount,
    this.currency,
    this.note,
    required this.createdAt,
  });

  factory PendingDeliveryAction.fromJson(Map<String, dynamic> json) {
    return PendingDeliveryAction(
      orderId: (json['order_id'] ?? 0) as int,
      status: (json['status'] ?? '').toString(),
      collectedAmount: json['collected_amount']?.toString(),
      currency: json['currency']?.toString(),
      note: json['note']?.toString(),
      createdAt: (json['created_at'] ?? '').toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'order_id': orderId,
      if (status.isNotEmpty) 'status': status,
      if (collectedAmount != null) 'collected_amount': collectedAmount,
      if (currency != null) 'currency': currency,
      if (note != null && note!.trim().isNotEmpty) 'note': note,
      'created_at': createdAt,
    };
  }
}

class PendingDeliveryActionsStore {
  static const _storageKey = 'pending_delivery_actions_v1';

  Future<List<PendingDeliveryAction>> getAll() async {
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
          .map(PendingDeliveryAction.fromJson)
          .where((e) => e.orderId > 0)
          .toList();
    } catch (_) {
      return const [];
    }
  }

  Future<void> save(PendingDeliveryAction action) async {
    if (action.orderId <= 0) {
      return;
    }

    final all = await getAll();
    final withoutCurrent = all.where((e) => e.orderId != action.orderId);
    final updated = <PendingDeliveryAction>[action, ...withoutCurrent];

    if (updated.length > 50) {
      updated.removeRange(50, updated.length);
    }

    final prefs = await SharedPreferences.getInstance();
    final payload = jsonEncode(updated.map((e) => e.toJson()).toList());
    await prefs.setString(_storageKey, payload);
  }

  Future<void> remove(int orderId) async {
    if (orderId <= 0) {
      return;
    }

    final all = await getAll();
    final updated = all.where((e) => e.orderId != orderId).toList();

    final prefs = await SharedPreferences.getInstance();
    final payload = jsonEncode(updated.map((e) => e.toJson()).toList());
    await prefs.setString(_storageKey, payload);
  }

  Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_storageKey);
  }
}
