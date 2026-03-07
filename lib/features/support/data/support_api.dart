import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../config/constants/endpoints.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/errors/app_failure.dart';
import '../../../core/network/dio_client.dart';
import '../domain/entities/support_attachment.dart';
import '../domain/entities/support_message.dart';
import '../domain/entities/support_ticket.dart';

final supportApiProvider = Provider<SupportApi>((ref) {
  return SupportApi(ref.watch(dioClientProvider));
});

class SupportTicketDetails {
  final SupportTicket ticket;
  final List<SupportMessage> messages;
  final List<SupportAttachment> attachments;

  const SupportTicketDetails({
    required this.ticket,
    required this.messages,
    required this.attachments,
  });
}

class SupportPollResult {
  final String status;
  final String statusLabelAr;
  final int lastMessageId;
  final List<SupportMessage> messages;
  final List<SupportAttachment> attachments;

  const SupportPollResult({
    required this.status,
    required this.statusLabelAr,
    required this.lastMessageId,
    required this.messages,
    required this.attachments,
  });
}

class SupportAdminInboxResult {
  final List<SupportTicket> tickets;
  final int page;
  final int perPage;
  final int total;
  final int totalPages;

  const SupportAdminInboxResult({
    required this.tickets,
    required this.page,
    required this.perPage,
    required this.total,
    required this.totalPages,
  });
}

class SupportApi {
  final DioClient _dio;

  SupportApi(this._dio);

  List<SupportTicket> _parseTickets(dynamic raw, {required String source}) {
    final items = <SupportTicket>[];
    for (final row in extractList(raw)) {
      if (row is! Map) continue;
      try {
        items.add(SupportTicket.fromJson(Map<String, dynamic>.from(row)));
      } catch (error, stackTrace) {
        if (kDebugMode) {
          debugPrint('[SUPPORT][PARSE][$source][ticket] $error');
          debugPrint(stackTrace.toString());
        }
      }
    }
    return items;
  }

  List<SupportMessage> _parseMessages(dynamic raw, {required String source}) {
    final items = <SupportMessage>[];
    for (final row in extractList(raw)) {
      if (row is! Map) continue;
      try {
        items.add(SupportMessage.fromJson(Map<String, dynamic>.from(row)));
      } catch (error, stackTrace) {
        if (kDebugMode) {
          debugPrint('[SUPPORT][PARSE][$source][message] $error');
          debugPrint(stackTrace.toString());
        }
      }
    }
    return items;
  }

  List<SupportAttachment> _parseAttachments(
    dynamic raw, {
    required String source,
  }) {
    final items = <SupportAttachment>[];
    for (final row in extractList(raw)) {
      if (row is! Map) continue;
      try {
        items.add(SupportAttachment.fromJson(Map<String, dynamic>.from(row)));
      } catch (error, stackTrace) {
        if (kDebugMode) {
          debugPrint('[SUPPORT][PARSE][$source][attachment] $error');
          debugPrint(stackTrace.toString());
        }
      }
    }
    return items;
  }

  Future<Map<String, dynamic>> createTicket({
    required String name,
    required String phone,
    String? email,
    required String subject,
    required String category,
    required String priority,
    String? message,
    String? deviceId,
  }) async {
    try {
      final response = await _dio.post(
        Endpoints.supportTickets(),
        data: {
          'name': name,
          'phone': phone,
          'email': (email ?? '').trim().isEmpty ? null : email,
          'subject': subject,
          'category': category,
          'priority': priority,
          if ((message ?? '').trim().isNotEmpty) 'message': message,
          'device_id': deviceId,
        },
        options: Options(extra: const {'requiresAuth': false}),
      );

      final data = extractMap(response.data);
      return data;
    } catch (e) {
      throw _mapError(e, fallback: 'تعذر إنشاء التذكرة حالياً.');
    }
  }

  Future<List<SupportTicket>> getMyTickets() async {
    try {
      final response = await _dio.get(Endpoints.supportMyTickets());
      final data = extractMap(response.data);
      return _parseTickets(
        data['tickets'] ?? data['items'] ?? response.data,
        source: 'support/my-tickets',
      );
    } catch (e) {
      throw _mapError(e, fallback: 'تعذر تحميل التذاكر.');
    }
  }

  Future<SupportTicketDetails> getTicketDetails({
    required int ticketId,
    required String token,
  }) async {
    try {
      final response = await _dio.get(
        Endpoints.supportTicket(ticketId),
        queryParameters: {'token': token},
        options: Options(extra: const {'requiresAuth': false}),
      );

      final data = extractMap(response.data);
      final ticketPayload = extractMap(data['ticket']);
      final ticket = SupportTicket.fromJson(
        ticketPayload.isNotEmpty ? ticketPayload : data,
      );
      final messages = _parseMessages(
        data['messages'],
        source: 'support/tickets/$ticketId',
      );
      final attachments = _parseAttachments(
        data['attachments'],
        source: 'support/tickets/$ticketId',
      );

      return SupportTicketDetails(
        ticket: ticket,
        messages: messages,
        attachments: attachments,
      );
    } catch (e) {
      throw _mapError(e, fallback: 'تعذر جلب بيانات التذكرة.');
    }
  }

  Future<SupportMessage> sendMessage({
    required int ticketId,
    required String token,
    required String message,
  }) async {
    try {
      final response = await _dio.post(
        Endpoints.supportTicketMessages(ticketId),
        data: {'token': token, 'message': message},
        options: Options(extra: const {'requiresAuth': false}),
      );

      final data = extractMap(response.data);
      final messageData = extractMap(data['message']);
      return SupportMessage.fromJson(messageData);
    } catch (e) {
      throw _mapError(e, fallback: 'تعذر إرسال الرسالة.');
    }
  }

  Future<SupportAttachment> uploadAttachment({
    required int ticketId,
    required String token,
    required List<int> bytes,
    required String fileName,
    required String mimeType,
    int? messageId,
  }) async {
    try {
      final formData = FormData.fromMap({
        'token': token,
        if (messageId != null && messageId > 0) 'message_id': messageId,
        'file': MultipartFile.fromBytes(
          bytes,
          filename: fileName,
          contentType: DioMediaType.parse(mimeType),
        ),
      });

      final response = await _dio.post(
        Endpoints.supportTicketAttachments(ticketId),
        data: formData,
        options: Options(
          contentType: 'multipart/form-data',
          extra: const {'requiresAuth': false},
        ),
      );

      final data = extractMap(response.data);
      final attachmentMap = extractMap(data['attachment']);
      return SupportAttachment.fromJson(attachmentMap);
    } catch (e) {
      throw _mapError(e, fallback: 'تعذر رفع المرفق.');
    }
  }

  Future<Map<String, dynamic>> closeTicket({
    required int ticketId,
    required String token,
    int? rating,
    String? feedback,
  }) async {
    try {
      final response = await _dio.post(
        Endpoints.supportTicketClose(ticketId),
        data: {
          'token': token,
          'rating': ?rating,
          if ((feedback ?? '').trim().isNotEmpty) 'feedback': feedback,
        },
        options: Options(extra: const {'requiresAuth': false}),
      );

      return extractMap(response.data);
    } catch (e) {
      throw _mapError(e, fallback: 'تعذر إغلاق التذكرة حالياً.');
    }
  }

  Future<SupportPollResult> poll({
    required int ticketId,
    required String token,
    required int sinceId,
  }) async {
    try {
      final response = await _dio.get(
        Endpoints.supportTicketPoll(ticketId),
        queryParameters: {'token': token, 'since_id': sinceId},
        options: Options(extra: const {'requiresAuth': false}),
      );

      final data = extractMap(response.data);
      final messages = _parseMessages(
        data['messages'],
        source: 'support/tickets/$ticketId/poll',
      );
      final attachments = _parseAttachments(
        data['attachments'],
        source: 'support/tickets/$ticketId/poll',
      );

      int toInt(dynamic v) {
        if (v is int) return v;
        if (v is num) return v.toInt();
        if (v is String) return int.tryParse(v) ?? 0;
        return 0;
      }

      return SupportPollResult(
        status: (data['status'] ?? '').toString(),
        statusLabelAr: (data['status_label_ar'] ?? '').toString(),
        lastMessageId: toInt(data['last_message_id']),
        messages: messages,
        attachments: attachments,
      );
    } catch (e) {
      throw _mapError(e, fallback: 'تعذر تحديث المحادثة.');
    }
  }

  Future<SupportAdminInboxResult> getAdminTickets({
    String status = '',
    String priority = '',
    String category = '',
    String assigned = '',
    String q = '',
    int page = 1,
    int perPage = 20,
  }) async {
    try {
      final response = await _dio.get(
        Endpoints.adminSupportTickets(),
        queryParameters: {
          if (status.trim().isNotEmpty) 'status': status,
          if (priority.trim().isNotEmpty) 'priority': priority,
          if (category.trim().isNotEmpty) 'category': category,
          if (assigned.trim().isNotEmpty) 'assigned': assigned,
          if (q.trim().isNotEmpty) 'q': q,
          'page': page,
          'per_page': perPage,
        },
      );

      final data = extractMap(response.data);
      int toInt(dynamic v) {
        if (v is int) return v;
        if (v is num) return v.toInt();
        if (v is String) return int.tryParse(v) ?? 0;
        return 0;
      }

      final tickets = _parseTickets(
        data['tickets'] ?? data['items'] ?? response.data,
        source: 'admin/support/tickets',
      );

      return SupportAdminInboxResult(
        tickets: tickets,
        page: toInt(data['page']) > 0 ? toInt(data['page']) : page,
        perPage: toInt(data['per_page']) > 0
            ? toInt(data['per_page'])
            : perPage,
        total: toInt(data['total']),
        totalPages: toInt(data['total_pages']) > 0
            ? toInt(data['total_pages'])
            : 1,
      );
    } catch (e) {
      throw _mapError(e, fallback: 'تعذر جلب صندوق الدعم.');
    }
  }

  Future<SupportTicketDetails> getAdminTicketDetails(int ticketId) async {
    try {
      final response = await _dio.get(Endpoints.adminSupportTicket(ticketId));
      final data = extractMap(response.data);
      final ticketPayload = extractMap(data['ticket']);
      final ticket = SupportTicket.fromJson(
        ticketPayload.isNotEmpty ? ticketPayload : data,
      );
      final messages = _parseMessages(
        data['messages'],
        source: 'admin/support/tickets/$ticketId',
      );
      final attachments = _parseAttachments(
        data['attachments'],
        source: 'admin/support/tickets/$ticketId',
      );

      return SupportTicketDetails(
        ticket: ticket,
        messages: messages,
        attachments: attachments,
      );
    } catch (e) {
      throw _mapError(e, fallback: 'تعذر جلب تفاصيل التذكرة.');
    }
  }

  Future<void> adminReply({
    required int ticketId,
    required String message,
    bool asNote = false,
  }) async {
    try {
      await _dio.post(
        Endpoints.adminSupportTicketReply(ticketId),
        data: {'message': message, 'as_note': asNote},
      );
    } catch (e) {
      throw _mapError(e, fallback: 'تعذر إرسال الرد.');
    }
  }

  Future<void> adminNote({required int ticketId, required String note}) async {
    try {
      await _dio.post(
        Endpoints.adminSupportTicketNote(ticketId),
        data: {'note': note},
      );
    } catch (e) {
      throw _mapError(e, fallback: 'تعذر حفظ الملاحظة.');
    }
  }

  Future<void> adminAssign({
    required int ticketId,
    required int assignedUserId,
  }) async {
    try {
      await _dio.patch(
        Endpoints.adminSupportTicketAssign(ticketId),
        data: {'assigned_user_id': assignedUserId},
      );
    } catch (e) {
      throw _mapError(e, fallback: 'تعذر تعيين الموظف.');
    }
  }

  Future<void> adminUpdateTicket({
    required int ticketId,
    String? status,
    String? priority,
    String? category,
    String? tags,
  }) async {
    try {
      await _dio.patch(
        Endpoints.adminSupportTicket(ticketId),
        data: {
          if ((status ?? '').trim().isNotEmpty) 'status': status,
          if ((priority ?? '').trim().isNotEmpty) 'priority': priority,
          if ((category ?? '').trim().isNotEmpty) 'category': category,
          if ((tags ?? '').trim().isNotEmpty) 'tags': tags,
        },
      );
    } catch (e) {
      throw _mapError(e, fallback: 'تعذر تحديث التذكرة.');
    }
  }

  Future<List<String>> getCannedReplies() async {
    try {
      final response = await _dio.get(Endpoints.adminSupportCanned());
      final data = extractMap(response.data);
      return extractList(data['items']).map((e) => e.toString()).toList();
    } catch (e) {
      throw _mapError(e, fallback: 'تعذر جلب الردود الجاهزة.');
    }
  }

  Future<List<String>> saveCannedReplies(List<String> items) async {
    try {
      final response = await _dio.post(
        Endpoints.adminSupportCanned(),
        data: {'items': items},
      );
      final data = extractMap(response.data);
      return extractList(data['items']).map((e) => e.toString()).toList();
    } catch (e) {
      throw _mapError(e, fallback: 'تعذر حفظ الردود الجاهزة.');
    }
  }

  Future<Map<String, dynamic>> getAnalytics({String range = '7d'}) async {
    try {
      final response = await _dio.get(
        Endpoints.adminSupportAnalytics(),
        queryParameters: {'range': range},
      );
      return extractMap(response.data);
    } catch (e) {
      throw _mapError(e, fallback: 'تعذر تحميل إحصائيات الدعم.');
    }
  }

  AppFailure _mapError(Object error, {required String fallback}) {
    if (error is AppFailure) {
      return error;
    }
    if (error is AppException) {
      return AppFailure(error.message);
    }
    if (error is DioException) {
      final data = error.response?.data;
      if (data is Map && data['error'] is Map) {
        final message = (data['error']['message'] ?? '').toString().trim();
        if (message.isNotEmpty) {
          return AppFailure(message);
        }
      }
      if (data is Map && data['message'] != null) {
        final message = data['message'].toString().trim();
        if (message.isNotEmpty) {
          return AppFailure(message);
        }
      }
    }
    return AppFailure(fallback);
  }
}
