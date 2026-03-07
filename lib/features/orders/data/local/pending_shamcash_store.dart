import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

final pendingShamCashStoreProvider = Provider<PendingShamCashStore>((ref) {
  return PendingShamCashStore();
});

class PendingShamCashOrder {
  final String orderId;
  final double amount;
  final String currency;
  final String phone;
  final String accountName;
  final String qrValue;
  final String barcodeValue;
  final String instructionsAr;
  final String uploadEndpoint;
  final String createdAt;

  const PendingShamCashOrder({
    required this.orderId,
    required this.amount,
    required this.currency,
    required this.phone,
    required this.accountName,
    required this.qrValue,
    required this.barcodeValue,
    required this.instructionsAr,
    required this.uploadEndpoint,
    required this.createdAt,
  });

  factory PendingShamCashOrder.fromJson(Map<String, dynamic> json) {
    return PendingShamCashOrder(
      orderId: (json['order_id'] ?? '').toString(),
      amount: double.tryParse((json['amount'] ?? '').toString()) ?? 0.0,
      currency: (json['currency'] ?? '').toString(),
      phone: (json['phone'] ?? '').toString(),
      accountName: (json['account_name'] ?? '').toString(),
      qrValue: (json['qr_value'] ?? '').toString(),
      barcodeValue: (json['barcode_value'] ?? '').toString(),
      instructionsAr: (json['instructions_ar'] ?? '').toString(),
      uploadEndpoint: (json['upload_endpoint'] ?? '').toString(),
      createdAt: (json['created_at'] ?? '').toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'order_id': orderId,
      'amount': amount,
      'currency': currency,
      'phone': phone,
      'account_name': accountName,
      'qr_value': qrValue,
      'barcode_value': barcodeValue,
      'instructions_ar': instructionsAr,
      'upload_endpoint': uploadEndpoint,
      'created_at': createdAt,
    };
  }
}

class PendingShamCashStore {
  static const _storageKey = 'pending_shamcash_orders_v1';

  Future<List<PendingShamCashOrder>> getAll() async {
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
          .map(PendingShamCashOrder.fromJson)
          .where((e) => e.orderId.trim().isNotEmpty)
          .toList();
    } catch (_) {
      return const [];
    }
  }

  Future<void> save(PendingShamCashOrder order) async {
    final normalizedOrderId = order.orderId.trim();
    if (normalizedOrderId.isEmpty) {
      return;
    }

    final all = await getAll();
    final withoutCurrent = all.where((e) => e.orderId != normalizedOrderId);
    final updated = <PendingShamCashOrder>[order, ...withoutCurrent];

    // keep only last 20 to avoid bloat
    if (updated.length > 20) {
      updated.removeRange(20, updated.length);
    }

    final prefs = await SharedPreferences.getInstance();
    final payload = jsonEncode(updated.map((e) => e.toJson()).toList());
    await prefs.setString(_storageKey, payload);
  }

  Future<void> remove(String orderId) async {
    final normalizedOrderId = orderId.trim();
    if (normalizedOrderId.isEmpty) {
      return;
    }

    final all = await getAll();
    final updated = all.where((e) => e.orderId != normalizedOrderId).toList();

    final prefs = await SharedPreferences.getInstance();
    final payload = jsonEncode(updated.map((e) => e.toJson()).toList());
    await prefs.setString(_storageKey, payload);
  }

  Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_storageKey);
  }
}
