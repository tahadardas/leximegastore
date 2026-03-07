import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:synchronized/synchronized.dart';

import '../../../core/auth/auth_session_controller.dart';
import '../../../core/session/app_session.dart';
import '../domain/entities/notification_entity.dart';
import 'notification_repository.dart';

class NotificationsRealtimeSnapshot {
  final List<NotificationEntity> customerItems;
  final List<NotificationEntity> adminItems;
  final int customerUnreadCount;
  final int adminUnreadCount;
  final bool isLoading;
  final bool isStale;
  final Object? error;
  final DateTime? updatedAt;

  const NotificationsRealtimeSnapshot({
    this.customerItems = const <NotificationEntity>[],
    this.adminItems = const <NotificationEntity>[],
    this.customerUnreadCount = 0,
    this.adminUnreadCount = 0,
    this.isLoading = false,
    this.isStale = false,
    this.error,
    this.updatedAt,
  });

  int get totalUnreadCount => customerUnreadCount + adminUnreadCount;

  NotificationsRealtimeSnapshot copyWith({
    List<NotificationEntity>? customerItems,
    List<NotificationEntity>? adminItems,
    int? customerUnreadCount,
    int? adminUnreadCount,
    bool? isLoading,
    bool? isStale,
    Object? error = _noValue,
    DateTime? updatedAt,
  }) {
    return NotificationsRealtimeSnapshot(
      customerItems: customerItems ?? this.customerItems,
      adminItems: adminItems ?? this.adminItems,
      customerUnreadCount: customerUnreadCount ?? this.customerUnreadCount,
      adminUnreadCount: adminUnreadCount ?? this.adminUnreadCount,
      isLoading: isLoading ?? this.isLoading,
      isStale: isStale ?? this.isStale,
      error: identical(error, _noValue) ? this.error : error,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

const Object _noValue = Object();

class NotificationsRealtimeService {
  static const Duration defaultInterval = Duration(seconds: 30);

  final NotificationRepository Function() _repoGetter;
  final AppSession Function() _sessionGetter;
  final Duration _interval;
  final bool _enableInternalTimer;
  final Lock _refreshLock = Lock();

  StreamController<NotificationsRealtimeSnapshot>? _controller;
  Timer? _timer;
  NotificationsRealtimeSnapshot _snapshot =
      const NotificationsRealtimeSnapshot();
  bool _disposed = false;

  NotificationsRealtimeService({
    required NotificationRepository Function() repoGetter,
    required AppSession Function() sessionGetter,
    Duration interval = defaultInterval,
    bool enableInternalTimer = false,
  }) : _repoGetter = repoGetter,
       _sessionGetter = sessionGetter,
       _interval = interval,
       _enableInternalTimer = enableInternalTimer;

  NotificationsRealtimeSnapshot get snapshot => _snapshot;

  Stream<NotificationsRealtimeSnapshot> get stream {
    _controller ??= StreamController<NotificationsRealtimeSnapshot>.broadcast(
      onListen: _onListen,
      onCancel: _onCancel,
    );
    return _controller!.stream;
  }

  Future<void> prime() async {
    if (_disposed) {
      return;
    }
    if (_snapshot.updatedAt != null || _snapshot.isLoading) {
      return;
    }
    await refreshNow(soft: false);
  }

  Future<void> refreshNow({bool soft = true}) async {
    if (_disposed) {
      return;
    }

    await _refreshLock.synchronized(() async {
      if (_disposed) {
        return;
      }

      final session = _sessionGetter();
      if (!session.isLoggedIn) {
        _emit(const NotificationsRealtimeSnapshot());
        return;
      }

      final hasCached =
          _snapshot.customerItems.isNotEmpty || _snapshot.adminItems.isNotEmpty;
      if (!soft || !hasCached) {
        _emit(
          _snapshot.copyWith(isLoading: true, isStale: hasCached, error: null),
        );
      }

      try {
        final repo = _repoGetter();

        final customerFuture = repo.getCustomerNotifications(
          page: 1,
          perPage: 30,
        );
        final adminFuture = session.isAdmin
            ? repo.getAdminNotifications(page: 1, perPage: 30)
            : Future.value(NotificationsPage.empty(page: 1, perPage: 30));

        final customerPage = await customerFuture;
        final adminPage = await adminFuture;

        _emit(
          NotificationsRealtimeSnapshot(
            customerItems: customerPage.notifications,
            adminItems: adminPage.notifications,
            customerUnreadCount: customerPage.unreadCount,
            adminUnreadCount: adminPage.unreadCount,
            isLoading: false,
            isStale: false,
            error: null,
            updatedAt: DateTime.now(),
          ),
        );
      } catch (error) {
        final hasAnyCached =
            _snapshot.customerItems.isNotEmpty ||
            _snapshot.adminItems.isNotEmpty;
        if (hasAnyCached) {
          _emit(
            _snapshot.copyWith(isLoading: false, isStale: true, error: error),
          );
          return;
        }

        _emit(
          NotificationsRealtimeSnapshot(
            customerItems: const <NotificationEntity>[],
            adminItems: const <NotificationEntity>[],
            customerUnreadCount: 0,
            adminUnreadCount: 0,
            isLoading: false,
            isStale: false,
            error: error,
            updatedAt: _snapshot.updatedAt,
          ),
        );
      }
    });
  }

  Future<void> markCustomerRead(int notificationId) async {
    if (notificationId <= 0) {
      return;
    }

    final index = _snapshot.customerItems.indexWhere(
      (item) => item.id == notificationId,
    );
    if (index == -1) {
      return;
    }

    final target = _snapshot.customerItems[index];
    if (target.isRead) {
      return;
    }

    final nextItems = _snapshot.customerItems
        .map(
          (item) =>
              item.id == notificationId ? item.copyWith(isRead: true) : item,
        )
        .toList(growable: false);
    _emit(
      _snapshot.copyWith(
        customerItems: nextItems,
        customerUnreadCount: _snapshot.customerUnreadCount > 0
            ? _snapshot.customerUnreadCount - 1
            : 0,
      ),
    );

    try {
      await _repoGetter().markCustomerRead(ids: <int>[notificationId]);
    } catch (_) {
      await refreshNow(soft: false);
    }
  }

  Future<void> markAdminRead(int notificationId) async {
    if (notificationId <= 0) {
      return;
    }

    final index = _snapshot.adminItems.indexWhere(
      (item) => item.id == notificationId,
    );
    if (index == -1) {
      return;
    }

    final target = _snapshot.adminItems[index];
    if (target.isRead) {
      return;
    }

    final nextItems = _snapshot.adminItems
        .map(
          (item) =>
              item.id == notificationId ? item.copyWith(isRead: true) : item,
        )
        .toList(growable: false);
    _emit(
      _snapshot.copyWith(
        adminItems: nextItems,
        adminUnreadCount: _snapshot.adminUnreadCount > 0
            ? _snapshot.adminUnreadCount - 1
            : 0,
      ),
    );

    try {
      await _repoGetter().markAdminRead(ids: <int>[notificationId]);
    } catch (_) {
      await refreshNow(soft: false);
    }
  }

  Future<void> markAllCustomerRead() async {
    _emit(
      _snapshot.copyWith(
        customerItems: _snapshot.customerItems
            .map((item) => item.copyWith(isRead: true))
            .toList(growable: false),
        customerUnreadCount: 0,
      ),
    );

    try {
      await _repoGetter().markAllCustomerRead();
    } catch (_) {
      await refreshNow(soft: false);
    }
  }

  Future<void> markAllAdminRead() async {
    _emit(
      _snapshot.copyWith(
        adminItems: _snapshot.adminItems
            .map((item) => item.copyWith(isRead: true))
            .toList(growable: false),
        adminUnreadCount: 0,
      ),
    );

    try {
      await _repoGetter().markAllAdminRead();
    } catch (_) {
      await refreshNow(soft: false);
    }
  }

  void clear() {
    if (_disposed) {
      return;
    }
    _emit(const NotificationsRealtimeSnapshot());
  }

  void _onListen() {
    if (_disposed) {
      return;
    }

    final controller = _controller;
    if (controller != null && !controller.isClosed) {
      controller.add(_snapshot);
    }

    if (_enableInternalTimer) {
      _timer ??= Timer.periodic(_interval, (_) {
        unawaited(refreshNow());
      });
    }

    if (_snapshot.updatedAt == null && !_snapshot.isLoading) {
      unawaited(refreshNow());
    }
  }

  void _onCancel() {
    if (_disposed) {
      return;
    }
    if (_controller?.hasListener == true) {
      return;
    }
    _timer?.cancel();
    _timer = null;
  }

  void _emit(NotificationsRealtimeSnapshot next) {
    _snapshot = next;
    final controller = _controller;
    if (controller != null && !controller.isClosed) {
      controller.add(next);
    }
  }

  void dispose() {
    _disposed = true;
    _timer?.cancel();
    _timer = null;
    _controller?.close();
    _controller = null;
  }
}

final notificationsRealtimeServiceProvider =
    Provider<NotificationsRealtimeService>((ref) {
      final service = NotificationsRealtimeService(
        repoGetter: () => ref.read(notificationRepositoryProvider),
        sessionGetter: () => ref.read(appSessionProvider),
        enableInternalTimer: false,
      );
      ref.onDispose(service.dispose);
      return service;
    });

final notificationsStreamProvider =
    StreamProvider.autoDispose<NotificationsRealtimeSnapshot>((ref) {
      return ref.read(notificationsRealtimeServiceProvider).stream;
    });

final notificationsUnreadCountStreamProvider = StreamProvider.autoDispose<int>((
  ref,
) {
  return ref
      .read(notificationsRealtimeServiceProvider)
      .stream
      .map((snapshot) => snapshot.totalUnreadCount);
});

final notificationsRealtimeBootstrapProvider = Provider<void>((ref) {
  final service = ref.read(notificationsRealtimeServiceProvider);

  ref.listen<AuthSessionState>(
    authSessionControllerProvider.select((controller) => controller.state),
    (previous, next) {
      final wasAuthenticated =
          previous?.status == AuthSessionStatus.authenticated;
      final isAuthenticated = next.status == AuthSessionStatus.authenticated;

      if (isAuthenticated && !wasAuthenticated) {
        unawaited(service.prime());
      } else if (!isAuthenticated && wasAuthenticated) {
        service.clear();
      }
    },
  );

  final current = ref.read(authSessionControllerProvider).state;
  if (current.status == AuthSessionStatus.authenticated) {
    unawaited(service.prime());
  }
});
