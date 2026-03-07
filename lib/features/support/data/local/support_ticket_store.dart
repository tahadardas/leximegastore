import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/storage/secure_store.dart';

final supportTicketStoreProvider = Provider<SupportTicketStore>((ref) {
  return SupportTicketStore(ref.watch(secureStoreProvider));
});

class LocalSupportTicket {
  final int ticketId;
  final String ticketNumber;
  final String chatToken;
  final String subject;
  final String status;
  final String statusLabelAr;
  final String phone;
  final String updatedAt;
  final String createdAt;

  const LocalSupportTicket({
    required this.ticketId,
    required this.ticketNumber,
    required this.chatToken,
    required this.subject,
    required this.status,
    required this.statusLabelAr,
    required this.phone,
    required this.updatedAt,
    required this.createdAt,
  });

  factory LocalSupportTicket.fromJson(Map<String, dynamic> json) {
    int toInt(dynamic v) {
      if (v is int) return v;
      if (v is String) return int.tryParse(v) ?? 0;
      if (v is num) return v.toInt();
      return 0;
    }

    return LocalSupportTicket(
      ticketId: toInt(json['ticket_id']),
      ticketNumber: (json['ticket_number'] ?? '').toString(),
      chatToken: (json['chat_token'] ?? '').toString(),
      subject: (json['subject'] ?? '').toString(),
      status: (json['status'] ?? '').toString(),
      statusLabelAr: (json['status_label_ar'] ?? '').toString(),
      phone: (json['phone'] ?? '').toString(),
      updatedAt: (json['updated_at'] ?? '').toString(),
      createdAt: (json['created_at'] ?? '').toString(),
    );
  }

  Map<String, dynamic> toJson() => {
    'ticket_id': ticketId,
    'ticket_number': ticketNumber,
    'chat_token': chatToken,
    'subject': subject,
    'status': status,
    'status_label_ar': statusLabelAr,
    'phone': phone,
    'updated_at': updatedAt,
    'created_at': createdAt,
  };

  LocalSupportTicket copyWith({
    String? subject,
    String? status,
    String? statusLabelAr,
    String? updatedAt,
  }) {
    return LocalSupportTicket(
      ticketId: ticketId,
      ticketNumber: ticketNumber,
      chatToken: chatToken,
      subject: subject ?? this.subject,
      status: status ?? this.status,
      statusLabelAr: statusLabelAr ?? this.statusLabelAr,
      phone: phone,
      updatedAt: updatedAt ?? this.updatedAt,
      createdAt: createdAt,
    );
  }
}

class SupportTicketStore {
  static const _fallbackNow = '1970-01-01T00:00:00.000Z';

  final SecureStore _secureStore;

  SupportTicketStore(this._secureStore);

  Future<List<LocalSupportTicket>> getAll() async {
    final raw = await _secureStore.getSupportTicketsJson();
    if (raw == null || raw.trim().isEmpty) {
      return const [];
    }

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) {
        return const [];
      }

      final list = decoded
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .map(LocalSupportTicket.fromJson)
          .where((e) => e.ticketId > 0 && e.chatToken.trim().isNotEmpty)
          .toList();

      list.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      return list;
    } catch (_) {
      return const [];
    }
  }

  Future<void> save(LocalSupportTicket ticket) async {
    final all = await getAll();
    final filtered = all.where((e) => e.ticketId != ticket.ticketId).toList();
    filtered.add(ticket);
    filtered.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

    final payload = jsonEncode(filtered.map((e) => e.toJson()).toList());
    await _secureStore.setSupportTicketsJson(payload);
  }

  Future<void> saveFromCreateResponse({
    required int ticketId,
    required String ticketNumber,
    required String chatToken,
    required String subject,
    required String status,
    required String statusLabelAr,
    required String phone,
  }) async {
    final now = DateTime.now().toIso8601String();
    await save(
      LocalSupportTicket(
        ticketId: ticketId,
        ticketNumber: ticketNumber,
        chatToken: chatToken,
        subject: subject,
        status: status,
        statusLabelAr: statusLabelAr,
        phone: phone,
        updatedAt: now,
        createdAt: now,
      ),
    );
  }

  Future<void> updateTicketStatus({
    required int ticketId,
    required String status,
    required String statusLabelAr,
  }) async {
    final all = await getAll();
    final idx = all.indexWhere((e) => e.ticketId == ticketId);
    if (idx < 0) return;

    final updated = all[idx].copyWith(
      status: status,
      statusLabelAr: statusLabelAr,
      updatedAt: DateTime.now().toIso8601String(),
    );
    all[idx] = updated;

    final payload = jsonEncode(all.map((e) => e.toJson()).toList());
    await _secureStore.setSupportTicketsJson(payload);
  }

  Future<LocalSupportTicket?> getById(int ticketId) async {
    final all = await getAll();
    for (final t in all) {
      if (t.ticketId == ticketId) {
        return t;
      }
    }
    return null;
  }

  Future<void> remove(int ticketId) async {
    final all = await getAll();
    all.removeWhere((e) => e.ticketId == ticketId);

    if (all.isEmpty) {
      await _secureStore.deleteSupportTicketsJson();
      return;
    }

    final payload = jsonEncode(all.map((e) => e.toJson()).toList());
    await _secureStore.setSupportTicketsJson(payload);
  }

  Future<void> clearAll() async {
    await _secureStore.deleteSupportTicketsJson();
  }

  Future<void> ensureUpdatedAt(LocalSupportTicket ticket) async {
    final updated = ticket.updatedAt.trim().isEmpty
        ? ticket.copyWith(updatedAt: _fallbackNow)
        : ticket;
    await save(updated);
  }
}
