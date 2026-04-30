import 'package:flutter/foundation.dart';

import '../../../../core/utils/safe_parsers.dart';
import '../../../../core/utils/text_normalizer.dart';

/// Notification type enum
enum NotificationType {
  orderCreated('order_created'),
  orderApproved('order_approved'),
  orderRejected('order_rejected'),
  orderStatusChanged('order_status_changed'),
  unknown('unknown');

  final String value;
  const NotificationType(this.value);

  static NotificationType fromString(String value) {
    return NotificationType.values.firstWhere(
      (e) => e.value == value,
      orElse: () => NotificationType.unknown,
    );
  }
}

/// Notification audience enum
enum NotificationAudience {
  admin('admin'),
  customer('customer');

  final String value;
  const NotificationAudience(this.value);
}

/// Notification entity
@immutable
class NotificationEntity {
  final int id;
  final NotificationType type;
  final String titleAr;
  final String bodyAr;
  final int? orderId;
  final bool isRead;
  final DateTime createdAt;
  final Map<String, dynamic>? data;

  const NotificationEntity({
    required this.id,
    required this.type,
    required this.titleAr,
    required this.bodyAr,
    this.orderId,
    required this.isRead,
    required this.createdAt,
    this.data,
  });

  factory NotificationEntity.fromJson(Map<String, dynamic> json) {
    final createdAtRaw = (json['created_at'] ?? '').toString().trim();
    final createdAt = _parseNotificationDate(createdAtRaw);
    return NotificationEntity(
      id: parseInt(json['id']),
      type: NotificationType.fromString((json['type'] ?? '').toString()),
      titleAr: TextNormalizer.normalize(json['title_ar']),
      bodyAr: TextNormalizer.normalize(json['body_ar']),
      orderId: parseIntNullable(json['order_id']),
      isRead: parseBool(json['is_read']),
      createdAt: createdAt,
      data: json['data'] is Map
          ? Map<String, dynamic>.from(json['data'] as Map)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type.value,
      'title_ar': titleAr,
      'body_ar': bodyAr,
      'order_id': orderId,
      'is_read': isRead,
      'created_at': createdAt.toIso8601String(),
      'data': data,
    };
  }

  NotificationEntity copyWith({
    int? id,
    NotificationType? type,
    String? titleAr,
    String? bodyAr,
    int? orderId,
    bool? isRead,
    DateTime? createdAt,
    Map<String, dynamic>? data,
  }) {
    return NotificationEntity(
      id: id ?? this.id,
      type: type ?? this.type,
      titleAr: titleAr ?? this.titleAr,
      bodyAr: bodyAr ?? this.bodyAr,
      orderId: orderId ?? this.orderId,
      isRead: isRead ?? this.isRead,
      createdAt: createdAt ?? this.createdAt,
      data: data ?? this.data,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is NotificationEntity && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}

/// Notifications page result
class NotificationsPage {
  final List<NotificationEntity> items;
  final int page;
  final int perPage;
  final int total;
  final int unreadCount;

  const NotificationsPage({
    required this.items,
    required this.page,
    required this.perPage,
    required this.total,
    required this.unreadCount,
  });

  factory NotificationsPage.empty({int page = 1, int perPage = 20}) {
    return NotificationsPage(
      items: const [],
      page: page,
      perPage: perPage,
      total: 0,
      unreadCount: 0,
    );
  }

  factory NotificationsPage.fromJson(Map<String, dynamic> json) {
    final dataList = json['data'] as List? ?? [];
    final meta = json['meta'] as Map<String, dynamic>? ?? {};

    return NotificationsPage(
      items: dataList
          .map((e) => NotificationEntity.fromJson(e as Map<String, dynamic>))
          .toList(),
      page: parseInt(meta['page']) > 0 ? parseInt(meta['page']) : 1,
      perPage: parseInt(meta['per_page']) > 0 ? parseInt(meta['per_page']) : 20,
      total: parseInt(meta['total']),
      unreadCount: parseInt(meta['unread_count']),
    );
  }

  /// Convenience getter for notifications list
  List<NotificationEntity> get notifications => items;

  /// Whether there are more pages to load
  bool get hasMore => items.length < total;
}

DateTime _parseNotificationDate(String value) {
  if (value.isEmpty) {
    return DateTime.now();
  }

  final normalized = (!value.endsWith('Z') && !value.contains('+'))
      ? '${value.replaceAll(' ', 'T')}Z'
      : value;

  try {
    return DateTime.parse(normalized);
  } catch (_) {
    return DateTime.now();
  }
}
