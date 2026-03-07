import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/device/device_id_provider.dart';
import '../../../core/session/app_session.dart';
import '../domain/entities/notification_entity.dart';
import 'notification_api.dart';

/// Repository for notifications - handles business logic
final notificationRepositoryProvider = Provider<NotificationRepository>((ref) {
  return NotificationRepository(
    ref.watch(notificationApiProvider),
    ref.watch(appSessionProvider),
    ref.watch(deviceIdProvider),
  );
});

class NotificationRepository {
  final NotificationApi _api;
  final AppSession _session;
  final AsyncValue<String> _deviceIdValue;

  NotificationRepository(this._api, this._session, this._deviceIdValue);

  bool get isAdmin => _session.isAdmin;
  bool get isLoggedIn => _session.isLoggedIn;
  String? get deviceId => _deviceIdValue.valueOrNull;

  /// Get customer notifications
  Future<NotificationsPage> getCustomerNotifications({
    int page = 1,
    int perPage = 20,
    CancelToken? cancelToken,
  }) {
    return _api.getNotifications(
      audience: NotificationAudience.customer,
      page: page,
      perPage: perPage,
      cancelToken: cancelToken,
    );
  }

  /// Get admin notifications
  Future<NotificationsPage> getAdminNotifications({
    int page = 1,
    int perPage = 20,
    CancelToken? cancelToken,
  }) {
    return _api.getNotifications(
      audience: NotificationAudience.admin,
      page: page,
      perPage: perPage,
      cancelToken: cancelToken,
    );
  }

  /// Get unread count for customer
  Future<int> getCustomerUnreadCount({CancelToken? cancelToken}) {
    return _api.getUnreadCount(
      audience: NotificationAudience.customer,
      cancelToken: cancelToken,
    );
  }

  /// Get unread count for admin
  Future<int> getAdminUnreadCount({CancelToken? cancelToken}) {
    return _api.getUnreadCount(
      audience: NotificationAudience.admin,
      cancelToken: cancelToken,
    );
  }

  /// Mark customer notifications as read
  Future<int> markCustomerRead({
    required List<int> ids,
    CancelToken? cancelToken,
  }) {
    return _api.markRead(
      ids: ids,
      audience: NotificationAudience.customer,
      cancelToken: cancelToken,
    );
  }

  /// Mark admin notifications as read
  Future<int> markAdminRead({
    required List<int> ids,
    CancelToken? cancelToken,
  }) {
    return _api.markRead(
      ids: ids,
      audience: NotificationAudience.admin,
      cancelToken: cancelToken,
    );
  }

  /// Mark all customer notifications as read
  Future<int> markAllCustomerRead({CancelToken? cancelToken}) {
    return _api.markAllRead(
      audience: NotificationAudience.customer,
      cancelToken: cancelToken,
    );
  }

  /// Mark all admin notifications as read
  Future<int> markAllAdminRead({CancelToken? cancelToken}) {
    return _api.markAllRead(
      audience: NotificationAudience.admin,
      cancelToken: cancelToken,
    );
  }

  /// Admin: Approve or reject order
  Future<Map<String, dynamic>> adminOrderDecision({
    required int orderId,
    required String decision,
    String? note,
    CancelToken? cancelToken,
  }) {
    return _api.adminOrderDecision(
      orderId: orderId,
      decision: decision,
      note: note,
      cancelToken: cancelToken,
    );
  }

  /// Attach device to order (for guest orders)
  Future<bool> attachDeviceToOrder({
    required int orderId,
    CancelToken? cancelToken,
  }) async {
    final devId = deviceId;
    if (devId == null) return false;
    return _api.attachDeviceToOrder(
      orderId: orderId,
      deviceId: devId,
      cancelToken: cancelToken,
    );
  }
}
