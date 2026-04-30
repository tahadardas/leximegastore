import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../config/constants/endpoints.dart';
import '../../../core/device/device_id_provider.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/logging/app_logger.dart';
import '../../../core/session/app_session.dart';
import '../../../core/utils/safe_parsers.dart';
import '../domain/entities/notification_entity.dart';

final notificationApiProvider = Provider<NotificationApi>((ref) {
  return NotificationApi(
    ref.watch(dioClientProvider),
    ref.watch(appSessionProvider),
    ref,
  );
});

class NotificationApi {
  final DioClient _client;
  final AppSession _session;
  final Ref _ref;
  String? _adminAccessSignature;
  bool _adminAccessBlocked = false;

  NotificationApi(this._client, this._session, this._ref);

  bool get _useCustomerAuth => !kIsWeb && _session.isLoggedIn;

  String? get _deviceIdOrNull {
    final id = _ref.read(deviceIdProvider).valueOrNull?.trim() ?? '';
    return id.isEmpty ? null : id;
  }

  Future<String?> _getDeviceId() async {
    final syncId = _deviceIdOrNull;
    if (syncId != null) return syncId;

    try {
      final id = (await _ref.read(deviceIdProvider.future)).trim();
      return id.isEmpty ? null : id;
    } catch (e, s) {
      unawaited(AppLogger.error('Failed to get device ID', e, s));
      return null;
    }
  }

  bool get _canTryAdmin => _session.isAdmin && _session.hasStoredToken;

  bool get _canTryCustomer {
    // Customer notifications should use one identity consistently:
    // - authenticated session (non-web, logged-in users)
    // - device_id (guests / web fallback)
    if (_useCustomerAuth) {
      return _session.hasStoredToken;
    }
    return _deviceIdOrNull != null;
  }

  bool _isAuthOrForbiddenStatus(int? statusCode) {
    return statusCode == 401 || statusCode == 403;
  }

  void _syncAdminAccessSignature() {
    final role = (_session.role ?? '').trim().toLowerCase();
    final token = (_session.token ?? '').trim();
    final signature = '$role|$token';
    if (_adminAccessSignature == signature) {
      return;
    }
    _adminAccessSignature = signature;
    _adminAccessBlocked = false;
  }

  void _blockAdminAccessIfNeeded(
    NotificationAudience audience,
    int? statusCode,
  ) {
    if (audience != NotificationAudience.admin) {
      return;
    }
    if (!_isAuthOrForbiddenStatus(statusCode)) {
      return;
    }
    _adminAccessBlocked = true;
    AppLogger.warn(
      'Admin notifications polling disabled for current session after HTTP $statusCode',
    );
  }

  /// Get notifications for current user
  Future<NotificationsPage> getNotifications({
    required NotificationAudience audience,
    int page = 1,
    int perPage = 20,
    CancelToken? cancelToken,
  }) async {
    final queryParams = <String, dynamic>{
      'audience': audience.value,
      'page': page,
      'per_page': perPage,
    };

    if (audience == NotificationAudience.admin) {
      _syncAdminAccessSignature();
      if (_adminAccessBlocked) {
        return NotificationsPage.empty(page: page, perPage: perPage);
      }
    }

    if (audience == NotificationAudience.admin && !_canTryAdmin) {
      return NotificationsPage.empty(page: page, perPage: perPage);
    }

    // Customer audience: choose exactly one identity source.
    if (audience == NotificationAudience.customer) {
      if (!_useCustomerAuth) {
        final deviceId = await _getDeviceId();
        if (deviceId != null) {
          queryParams['device_id'] = deviceId;
        } else {
          AppLogger.warn('Skipping notification fetch: No Device ID for guest');
          return NotificationsPage.empty(page: page, perPage: perPage);
        }
      } else if (!_canTryCustomer) {
        AppLogger.warn(
          'Skipping notification fetch: Requires Auth but no token',
        );
        return NotificationsPage.empty(page: page, perPage: perPage);
      }
    }

    // Keep admin protected, and use auth for logged-in customer on non-web.
    final requiresAuth =
        audience == NotificationAudience.admin ||
        (audience == NotificationAudience.customer && _useCustomerAuth);

    if (requiresAuth && !_session.hasStoredToken) {
      AppLogger.warn('Skipping notification fetch: Requires Auth but no token');
      return NotificationsPage.empty(page: page, perPage: perPage);
    }

    try {
      final response = await _client.get(
        Endpoints.notifications(),
        queryParameters: queryParams,
        options: Options(
          extra: {'requiresAuth': requiresAuth},
          validateStatus: (status) => status != null && status < 500,
        ),
        cancelToken: cancelToken,
      );

      if (_isAuthOrForbiddenStatus(response.statusCode)) {
        _blockAdminAccessIfNeeded(audience, response.statusCode);
        return NotificationsPage.empty(page: page, perPage: perPage);
      }

      return NotificationsPage.fromJson(response.data);
    } on DioException catch (e) {
      if (_isAuthOrForbiddenStatus(e.response?.statusCode)) {
        _blockAdminAccessIfNeeded(audience, e.response?.statusCode);
        return NotificationsPage.empty(page: page, perPage: perPage);
      }
      rethrow;
    }
  }

  /// Get unread count
  Future<int> getUnreadCount({
    required NotificationAudience audience,
    CancelToken? cancelToken,
  }) async {
    final queryParams = <String, dynamic>{'audience': audience.value};

    if (audience == NotificationAudience.admin) {
      _syncAdminAccessSignature();
      if (_adminAccessBlocked) {
        return 0;
      }
    }

    if (audience == NotificationAudience.admin && !_canTryAdmin) {
      return 0;
    }

    // Customer audience: choose exactly one identity source.
    if (audience == NotificationAudience.customer) {
      if (!_useCustomerAuth) {
        final deviceId = await _getDeviceId();
        if (deviceId != null) {
          queryParams['device_id'] = deviceId;
        } else {
          AppLogger.warn('Skipping unread-count fetch: No Device ID for guest');
          return 0;
        }
      } else if (!_canTryCustomer) {
        AppLogger.warn(
          'Skipping unread-count fetch: Requires Auth but no token',
        );
        return 0;
      }
    }

    // Keep admin protected, and use auth for logged-in customer on non-web.
    final requiresAuth =
        audience == NotificationAudience.admin ||
        (audience == NotificationAudience.customer && _useCustomerAuth);

    if (requiresAuth && !_session.hasStoredToken) {
      AppLogger.warn('Skipping unread-count fetch: Requires Auth but no token');
      return 0;
    }

    try {
      final response = await _client.get(
        Endpoints.notificationsUnreadCount(),
        queryParameters: queryParams,
        options: Options(
          extra: {'requiresAuth': requiresAuth},
          validateStatus: (status) => status != null && status < 500,
        ),
        cancelToken: cancelToken,
      );

      if (_isAuthOrForbiddenStatus(response.statusCode)) {
        _blockAdminAccessIfNeeded(audience, response.statusCode);
        return 0;
      }

      final payload = extractMap(response.data);
      final unreadRaw =
          payload['unread_count'] ??
          extractMap(payload['data'])['unread_count'];
      final unreadCount = parseInt(unreadRaw);
      return unreadCount < 0 ? 0 : unreadCount;
    } on DioException catch (e) {
      if (_isAuthOrForbiddenStatus(e.response?.statusCode)) {
        _blockAdminAccessIfNeeded(audience, e.response?.statusCode);
        return 0;
      }
      rethrow;
    }
  }

  /// Mark notifications as read
  Future<int> markRead({
    required List<int> ids,
    required NotificationAudience audience,
    CancelToken? cancelToken,
  }) async {
    final body = <String, dynamic>{'ids': ids, 'audience': audience.value};

    final requiresAuth =
        audience == NotificationAudience.admin ||
        (audience == NotificationAudience.customer && _useCustomerAuth);

    if (audience == NotificationAudience.customer && !_useCustomerAuth) {
      final deviceId = await _getDeviceId();
      if (deviceId == null) {
        AppLogger.warn('Skipping mark-read: No Device ID for guest');
        return 0;
      }
      body['device_id'] = deviceId;
    }

    if (requiresAuth && !_session.hasStoredToken) {
      AppLogger.warn('Skipping mark-read: Requires Auth but no token');
      return 0;
    }

    final response = await _client.post(
      Endpoints.notificationsMarkRead(),
      data: body,
      options: Options(extra: {'requiresAuth': requiresAuth}),
      cancelToken: cancelToken,
    );

    final payload = extractMap(response.data);
    final updatedRaw =
        payload['updated_count'] ??
        extractMap(payload['data'])['updated_count'];
    final updatedCount = parseInt(updatedRaw);
    return updatedCount < 0 ? 0 : updatedCount;
  }

  /// Mark all notifications as read
  Future<int> markAllRead({
    required NotificationAudience audience,
    CancelToken? cancelToken,
  }) async {
    final body = <String, dynamic>{'audience': audience.value};
    final requiresAuth =
        audience == NotificationAudience.admin ||
        (audience == NotificationAudience.customer && _useCustomerAuth);

    if (audience == NotificationAudience.customer && !_useCustomerAuth) {
      final deviceId = await _getDeviceId();
      if (deviceId == null) {
        AppLogger.warn('Skipping mark-all-read: No Device ID for guest');
        return 0;
      }
      body['device_id'] = deviceId;
    }

    if (requiresAuth && !_session.hasStoredToken) {
      AppLogger.warn('Skipping mark-all-read: Requires Auth but no token');
      return 0;
    }

    final response = await _client.post(
      Endpoints.notificationsMarkAllRead(),
      data: body,
      options: Options(extra: {'requiresAuth': requiresAuth}),
      cancelToken: cancelToken,
    );

    final payload = extractMap(response.data);
    final updatedRaw =
        payload['updated_count'] ??
        extractMap(payload['data'])['updated_count'];
    final updatedCount = parseInt(updatedRaw);
    return updatedCount < 0 ? 0 : updatedCount;
  }

  /// Admin: Approve or reject order
  Future<Map<String, dynamic>> adminOrderDecision({
    required int orderId,
    required String decision,
    String? note,
    CancelToken? cancelToken,
  }) async {
    final body = <String, dynamic>{
      'decision': decision,
      if (note != null && note.isNotEmpty) 'note': note,
    };

    final response = await _client.post(
      Endpoints.adminOrderDecision(orderId),
      data: body,
      options: Options(extra: const {'requiresAuth': true}),
      cancelToken: cancelToken,
    );

    final map = extractMap(response.data);
    final payload = map['data'] is Map<String, dynamic>
        ? map['data'] as Map<String, dynamic>
        : const <String, dynamic>{};

    return {
      'success': map['success'] as bool? ?? false,
      'message': map['message'] as String? ?? '',
      'order_id': payload['order_id'] as int?,
      'decision': payload['decision'] as String?,
    };
  }

  /// Attach device_id to an order (for guest orders)
  Future<bool> attachDeviceToOrder({
    required int orderId,
    required String deviceId,
    CancelToken? cancelToken,
  }) async {
    try {
      await _client.post(
        Endpoints.orderAttachDevice(orderId),
        data: {'device_id': deviceId},
        options: Options(extra: const {'requiresAuth': false}),
        cancelToken: cancelToken,
      );
      return true;
    } catch (_) {
      return false;
    }
  }
}
