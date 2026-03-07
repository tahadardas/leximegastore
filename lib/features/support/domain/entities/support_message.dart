import '../../../../core/utils/text_normalizer.dart';

class SupportMessage {
  final int id;
  final int ticketId;
  final String senderType;
  final int senderUserId;
  final String message;
  final bool isInternal;
  final String createdAt;

  const SupportMessage({
    required this.id,
    required this.ticketId,
    required this.senderType,
    required this.senderUserId,
    required this.message,
    required this.isInternal,
    required this.createdAt,
  });

  factory SupportMessage.fromJson(Map<String, dynamic> json) {
    int toInt(dynamic v) {
      if (v is int) return v;
      if (v is String) return int.tryParse(v) ?? 0;
      if (v is num) return v.toInt();
      return 0;
    }

    return SupportMessage(
      id: toInt(json['id']),
      ticketId: toInt(json['ticket_id']),
      senderType: (json['sender_type'] ?? '').toString(),
      senderUserId: toInt(json['sender_user_id']),
      message: TextNormalizer.normalize(json['message']),
      isInternal:
          json['is_internal'] == true ||
          (json['is_internal'] is num &&
              (json['is_internal'] as num).toInt() == 1),
      createdAt: (json['created_at'] ?? '').toString(),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'ticket_id': ticketId,
    'sender_type': senderType,
    'sender_user_id': senderUserId,
    'message': message,
    'is_internal': isInternal,
    'created_at': createdAt,
  };
}
