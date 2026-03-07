class OrderTrackEvent {
  final String type;
  final String messageAr;
  final String createdAt;

  const OrderTrackEvent({
    required this.type,
    required this.messageAr,
    required this.createdAt,
  });

  factory OrderTrackEvent.fromJson(Map<String, dynamic> json) {
    return OrderTrackEvent(
      type: (json['type'] ?? '').toString(),
      messageAr: (json['message_ar'] ?? '').toString(),
      createdAt: (json['created_at'] ?? '').toString(),
    );
  }
}

class OrderTrackInboxItem {
  final String title;
  final String message;
  final String createdAt;

  const OrderTrackInboxItem({
    required this.title,
    required this.message,
    required this.createdAt,
  });

  factory OrderTrackInboxItem.fromJson(Map<String, dynamic> json) {
    return OrderTrackInboxItem(
      title: (json['title'] ?? '').toString(),
      message: (json['message'] ?? '').toString(),
      createdAt: (json['created_at'] ?? '').toString(),
    );
  }
}

class OrderTrackInfo {
  final String orderId;
  final String orderNumber;
  final String status;
  final String statusLabelAr;
  final String lastDecision;
  final String? adminNoteAr;
  final List<OrderTrackEvent> timeline;
  final List<OrderTrackInboxItem> inbox;

  const OrderTrackInfo({
    required this.orderId,
    required this.orderNumber,
    required this.status,
    required this.statusLabelAr,
    required this.lastDecision,
    required this.timeline,
    required this.inbox,
    this.adminNoteAr,
  });

  factory OrderTrackInfo.fromJson(Map<String, dynamic> json) {
    final timelineRaw = json['timeline'];
    final timeline = <OrderTrackEvent>[];
    if (timelineRaw is List) {
      for (final item in timelineRaw) {
        if (item is Map<String, dynamic>) {
          timeline.add(OrderTrackEvent.fromJson(item));
        } else if (item is Map) {
          timeline.add(
            OrderTrackEvent.fromJson(
              item.map((key, value) => MapEntry(key.toString(), value)),
            ),
          );
        }
      }
    }

    final inboxRaw = json['inbox'];
    final inbox = <OrderTrackInboxItem>[];
    if (inboxRaw is List) {
      for (final item in inboxRaw) {
        if (item is Map<String, dynamic>) {
          inbox.add(OrderTrackInboxItem.fromJson(item));
        } else if (item is Map) {
          inbox.add(
            OrderTrackInboxItem.fromJson(
              item.map((key, value) => MapEntry(key.toString(), value)),
            ),
          );
        }
      }
    }

    final rawStatus = (json['status'] ?? '').toString();
    final status = _normalizeStatus(rawStatus);
    final apiStatusLabel = (json['status_label_ar'] ?? '').toString().trim();
    final statusLabelAr =
        apiStatusLabel.isEmpty ||
            apiStatusLabel.toLowerCase() == rawStatus.toLowerCase()
        ? _statusLabelArFallback(status)
        : apiStatusLabel;
    final adminNote = (json['admin_note_ar'] ?? '').toString().trim();
    return OrderTrackInfo(
      orderId: (json['order_id'] ?? '').toString(),
      orderNumber: (json['order_number'] ?? '').toString(),
      status: status,
      statusLabelAr: statusLabelAr,
      lastDecision: (json['last_decision'] ?? 'pending').toString(),
      adminNoteAr: adminNote.isEmpty ? null : adminNote,
      timeline: timeline,
      inbox: inbox,
    );
  }

  static String _normalizeStatus(String value) {
    final status = value.trim().toLowerCase().replaceAll('_', '-');
    if (status == 'pending-verification' ||
        status == 'pending-verificat' ||
        status == 'on-hold') {
      return 'pending-verification';
    }
    return status;
  }

  static String _statusLabelArFallback(String status) {
    if (status == 'pending-verification') {
      return 'بانتظار التحقق من الدفع';
    }

    switch (status) {
      case 'pending-verification':
        return 'بانتظار التحقق';
      case 'pending':
        return 'قيد الانتظار';
      case 'processing':
        return 'قيد المعالجة';
      case 'completed':
        return 'مكتمل';
      case 'cancelled':
        return 'ملغي';
      case 'failed':
        return 'فاشل';
      default:
        return status;
    }
  }
}
