import 'dart:convert';

class NotificationChannels {
  static const customerDefaultId = 'customer_default';
  static const courierAssignmentId = 'courier_assignment';
}

class NotificationActions {
  static const accept = 'courier_accept';
  static const decline = 'courier_decline';
}

class NotificationTypes {
  static const courierAssignment = 'courier_assignment';
}

class CourierAssignmentPayload {
  final int orderId;
  final String amountDue;
  final String customerName;
  final String address;
  final String customerPhone;
  final int ttlSeconds;
  final String deepLink;
  final DateTime receivedAt;

  const CourierAssignmentPayload({
    required this.orderId,
    required this.amountDue,
    required this.customerName,
    required this.address,
    required this.customerPhone,
    required this.ttlSeconds,
    required this.deepLink,
    required this.receivedAt,
  });

  DateTime get expiresAt => receivedAt.add(Duration(seconds: ttlSeconds));
  bool get isExpired => DateTime.now().isAfter(expiresAt);

  factory CourierAssignmentPayload.fromMap(
    Map<String, dynamic> data, {
    DateTime? receivedAt,
  }) {
    final parsedOrderId = int.tryParse('${data['order_id'] ?? ''}') ?? 0;
    final parsedTtl = int.tryParse('${data['ttl_seconds'] ?? ''}') ?? 90;
    final parsedReceivedAt = DateTime.tryParse('${data['received_at'] ?? ''}');

    return CourierAssignmentPayload(
      orderId: parsedOrderId,
      amountDue: '${data['amount_due'] ?? ''}'.trim(),
      customerName: '${data['customer_name'] ?? ''}'.trim(),
      address: '${data['address'] ?? ''}'.trim(),
      customerPhone: '${data['customer_phone'] ?? ''}'.trim(),
      ttlSeconds: parsedTtl > 0 ? parsedTtl : 90,
      deepLink: '${data['deep_link'] ?? ''}'.trim(),
      receivedAt: parsedReceivedAt ?? receivedAt ?? DateTime.now(),
    );
  }

  factory CourierAssignmentPayload.fromJson(String raw) {
    final decoded = jsonDecode(raw);
    if (decoded is! Map) {
      return CourierAssignmentPayload.fromMap(const <String, dynamic>{});
    }
    return CourierAssignmentPayload.fromMap(
      decoded.map((key, value) => MapEntry(key.toString(), value)),
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'type': NotificationTypes.courierAssignment,
      'order_id': orderId,
      'amount_due': amountDue,
      'customer_name': customerName,
      'address': address,
      'customer_phone': customerPhone,
      'ttl_seconds': ttlSeconds,
      'deep_link': deepLink,
      'received_at': receivedAt.toIso8601String(),
    };
  }

  String toJson() => jsonEncode(toMap());
}
