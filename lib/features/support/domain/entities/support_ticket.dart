import 'support_message.dart';
import '../../../../core/utils/text_normalizer.dart';

class SupportTicket {
  final int id;
  final String ticketNumber;
  final String subject;
  final String status;
  final String statusLabel;
  final String updatedAt;
  final String createdAt;
  final String chatToken;
  final String phone;
  final int unreadCount;
  final String? lastMessageAt;
  final String statusLabelAr;

  final String priority;
  final String priorityLabelAr;
  final String category;
  final String categoryLabelAr;
  final int? assignedUserId;
  final List<String> tags;
  final String name; // Requester Name
  final bool firstResponseOverdue;
  final bool resolutionOverdue;

  const SupportTicket({
    required this.id,
    required this.ticketNumber,
    required this.subject,
    required this.status,
    required this.statusLabel,
    required this.updatedAt,
    required this.createdAt,
    required this.chatToken,
    required this.phone,
    this.unreadCount = 0,
    this.lastMessageAt,
    this.statusLabelAr = '',
    this.priority = 'normal',
    this.priorityLabelAr = 'عادي',
    this.category = 'general',
    this.categoryLabelAr = 'عام',
    this.assignedUserId,
    this.tags = const [],
    this.name = '',
    this.firstResponseOverdue = false,
    this.resolutionOverdue = false,
  });

  factory SupportTicket.fromJson(Map<String, dynamic> json) {
    int toInt(dynamic value) {
      if (value is int) return value;
      if (value is num) return value.toInt();
      if (value is String) return int.tryParse(value.trim()) ?? 0;
      return 0;
    }

    bool toBool(dynamic value) {
      if (value is bool) return value;
      if (value is num) return value.toInt() == 1;
      if (value is String) {
        final normalized = value.trim().toLowerCase();
        return normalized == '1' ||
            normalized == 'true' ||
            normalized == 'yes' ||
            normalized == 'on';
      }
      return false;
    }

    List<String> parseTags(dynamic value) {
      if (value is List) {
        return value
            .map((e) => TextNormalizer.normalize(e).trim())
            .where((e) => e.isNotEmpty)
            .toList(growable: false);
      }
      if (value is String) {
        return value
            .split(',')
            .map((e) => TextNormalizer.normalize(e).trim())
            .where((e) => e.isNotEmpty)
            .toList(growable: false);
      }
      return const <String>[];
    }

    final assigned = toInt(json['assigned_user_id']);

    return SupportTicket(
      id: toInt(json['id']),
      ticketNumber: (json['ticket_number'] ?? '').toString(),
      subject: TextNormalizer.normalize(json['subject']),
      status: (json['status'] ?? '').toString(),
      statusLabel: TextNormalizer.normalize(
        json['status_label_ar'] ?? json['status_label'],
      ),
      updatedAt: (json['updated_at'] ?? '').toString(),
      createdAt: (json['created_at'] ?? '').toString(),
      chatToken: (json['chat_token'] ?? '').toString(),
      phone: (json['phone'] ?? '').toString(),
      unreadCount: toInt(json['unread_count']),
      lastMessageAt: (json['last_message_at'] ?? '').toString(),
      statusLabelAr: TextNormalizer.normalize(json['status_label_ar']),
      priority: (json['priority'] ?? 'normal').toString(),
      priorityLabelAr: TextNormalizer.normalize(
        json['priority_label_ar'] ?? 'عادي',
      ),
      category: (json['category'] ?? 'general').toString(),
      categoryLabelAr: TextNormalizer.normalize(
        json['category_label_ar'] ?? 'عام',
      ),
      assignedUserId: assigned > 0 ? assigned : null,
      tags: parseTags(json['tags'] ?? json['tags_text']),
      name: TextNormalizer.normalize(json['name'] ?? json['requester_name']),
      firstResponseOverdue: toBool(json['first_response_overdue']),
      resolutionOverdue: toBool(json['resolution_overdue']),
    );
  }

  SupportTicket copyWith({
    int? id,
    String? ticketNumber,
    String? subject,
    String? status,
    String? statusLabel,
    String? updatedAt,
    String? createdAt,
    String? chatToken,
    String? phone,
    int? unreadCount,
    String? lastMessageAt,
    String? statusLabelAr,
    String? priority,
    String? priorityLabelAr,
    String? category,
    String? categoryLabelAr,
    int? assignedUserId,
    List<String>? tags,
    String? name,
    bool? firstResponseOverdue,
    bool? resolutionOverdue,
  }) {
    return SupportTicket(
      id: id ?? this.id,
      ticketNumber: ticketNumber ?? this.ticketNumber,
      subject: subject ?? this.subject,
      status: status ?? this.status,
      statusLabel: statusLabel ?? this.statusLabel,
      updatedAt: updatedAt ?? this.updatedAt,
      createdAt: createdAt ?? this.createdAt,
      chatToken: chatToken ?? this.chatToken,
      phone: phone ?? this.phone,
      unreadCount: unreadCount ?? this.unreadCount,
      lastMessageAt: lastMessageAt ?? this.lastMessageAt,
      statusLabelAr: statusLabelAr ?? this.statusLabelAr,
      priority: priority ?? this.priority,
      priorityLabelAr: priorityLabelAr ?? this.priorityLabelAr,
      category: category ?? this.category,
      categoryLabelAr: categoryLabelAr ?? this.categoryLabelAr,
      assignedUserId: assignedUserId ?? this.assignedUserId,
      tags: tags ?? this.tags,
      name: name ?? this.name,
      firstResponseOverdue: firstResponseOverdue ?? this.firstResponseOverdue,
      resolutionOverdue: resolutionOverdue ?? this.resolutionOverdue,
    );
  }
}

class TicketDetails {
  final SupportTicket ticket;
  final List<SupportMessage> messages;
  final int slaFirstResponseMinutes;
  final int slaResolutionMinutes;

  const TicketDetails({
    required this.ticket,
    required this.messages,
    this.slaFirstResponseMinutes = 60,
    this.slaResolutionMinutes = 1440,
  });

  // Factory from full payload which contains ticket fields + messages array
  factory TicketDetails.fromJson(Map<String, dynamic> json) {
    final messagesList = json['messages'] is List
        ? (json['messages'] as List)
        : const [];

    // Construct ticket part from the root json
    final ticket = SupportTicket.fromJson(json);

    return TicketDetails(
      ticket: ticket,
      messages: messagesList
          .whereType<Map>()
          .map((e) => SupportMessage.fromJson(Map<String, dynamic>.from(e)))
          .toList(growable: false),
      slaFirstResponseMinutes:
          int.tryParse('${json['sla_first_response_minutes'] ?? 60}') ?? 60,
      slaResolutionMinutes:
          int.tryParse('${json['sla_resolution_minutes'] ?? 1440}') ?? 1440,
    );
  }
}
