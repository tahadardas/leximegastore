import 'package:flutter/foundation.dart';

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
    return NotificationEntity(
      id: json['id'] as int? ?? 0,
      type: NotificationType.fromString(json['type'] as String? ?? ''),
      titleAr: TextNormalizer.normalize(json['title_ar']),
      bodyAr: TextNormalizer.normalize(json['body_ar']),
      orderId: json['order_id'] as int?,
      isRead: json['is_read'] as bool? ?? false,
      createdAt: json['created_at'] != null
          ? DateTime.parse(
              !(json['created_at'] as String).endsWith('Z') &&
                      !(json['created_at'] as String).contains('+')
                  ? '${(json['created_at'] as String).replaceAll(' ', 'T')}Z'
                  : json['created_at'] as String,
            )
          : DateTime.now(),
      data: json['data'] as Map<String, dynamic>?,
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
      page: meta['page'] as int? ?? 1,
      perPage: meta['per_page'] as int? ?? 20,
      total: meta['total'] as int? ?? 0,
      unreadCount: meta['unread_count'] as int? ?? 0,
    );
  }

  /// Convenience getter for notifications list
  List<NotificationEntity> get notifications => items;

  /// Whether there are more pages to load
  bool get hasMore => items.length < total;
}
