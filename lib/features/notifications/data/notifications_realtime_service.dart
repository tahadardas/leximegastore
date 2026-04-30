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
  final DateTime? itemsUpdatedAt;

  const NotificationsRealtimeSnapshot({
    this.customerItems = const <NotificationEntity>[],
    this.adminItems = const <NotificationEntity>[],
    this.customerUnreadCount = 0,
    this.adminUnreadCount = 0,
    this.isLoading = false,
    this.isStale = false,
    this.error,
    this.itemsUpdatedAt,
  });

  @Deprecated('Use itemsUpdatedAt')
  DateTime? get updatedAt => itemsUpdatedAt;

  int get totalUnreadCount => customerUnreadCount + adminUnreadCount;

  NotificationsRealtimeSnapshot copyWith({
    List<NotificationEntity>? customerItems,
    List<NotificationEntity>? adminItems,
    int? customerUnreadCount,
    int? adminUnreadCount,
    bool? isLoading,
    bool? isStale,
    Object? error = _noValue,
    DateTime? itemsUpdatedAt,
  }) {
    return NotificationsRealtimeSnapshot(
      customerItems: customerItems ?? this.customerItems,
      adminItems: adminItems ?? this.adminItems,
      customerUnreadCount: customerUnreadCount ?? this.customerUnreadCount,
      adminUnreadCount: adminUnreadCount ?? this.adminUnreadCount,
      isLoading: isLoading ?? this.isLoading,
      isStale: isStale ?? this.isStale,
      error: identical(error, _noValue) ? this.error : error,
      itemsUpdatedAt: itemsUpdatedAt ?? this.itemsUpdatedAt,
    );
  }
}

const Object _noValue = Object();

class NotificationsRealtimeService {
  static const Duration defaultInterval = Duration(seconds: 45);

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
    if (_snapshot.itemsUpdatedAt != null) {
      await refreshNow(onlyCount: true);
      return;
    }
    await refreshNow(soft: false);
  }

  Future<void> refreshNow({bool soft = true, bool onlyCount = false}) async {
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

      if (soft && !onlyCount && _snapshot.itemsUpdatedAt != null) {
        // We already have item data, skip soft item refresh
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

        if (onlyCount) {
          final customerLocalUnread = _localUnreadCount(
            _snapshot.customerItems,
          );
          final customerCount = await _safeUnreadCount(
            resolver: () => repo.getCustomerUnreadCount(),
            fallback: customerLocalUnread,
          );
          final adminLocalUnread = _localUnreadCount(_snapshot.adminItems);
          final adminCount = session.isAdmin
              ? await _safeUnreadCount(
                  resolver: () => repo.getAdminUnreadCount(),
                  fallback: adminLocalUnread,
                )
              : 0;

          _emit(
            _snapshot.copyWith(
              customerUnreadCount: customerCount,
              adminUnreadCount: adminCount,
              isLoading: false,
              isStale: false,
              error: null,
            ),
          );
          return;
        }

        final customerFuture = repo.getCustomerNotifications(
          page: 1,
          perPage: 30,
        );
        final adminFuture = session.isAdmin
            ? repo.getAdminNotifications(page: 1, perPage: 30)
            : Future.value(NotificationsPage.empty(page: 1, perPage: 30));

        final customerPage = await customerFuture;
        final adminPage = await adminFuture;
        final customerCount = await _safeUnreadCount(
          resolver: () => repo.getCustomerUnreadCount(),
          fallback: customerPage.unreadCount,
        );
        final adminCount = session.isAdmin
            ? await _safeUnreadCount(
                resolver: () => repo.getAdminUnreadCount(),
                fallback: adminPage.unreadCount,
              )
            : 0;

        _emit(
          NotificationsRealtimeSnapshot(
            customerItems: customerPage.notifications,
            adminItems: adminPage.notifications,
            customerUnreadCount: customerCount,
            adminUnreadCount: adminCount,
            isLoading: false,
            isStale: false,
            error: null,
            itemsUpdatedAt: DateTime.now(),
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
            itemsUpdatedAt: _snapshot.itemsUpdatedAt,
          ),
        );
      }
    });
  }

  Future<int> _safeUnreadCount({
    required Future<int> Function() resolver,
    required int fallback,
  }) async {
    try {
      final count = await resolver();
      if (count < 0) {
        return 0;
      }
      return count;
    } catch (_) {
      return fallback < 0 ? 0 : fallback;
    }
  }

  int _localUnreadCount(List<NotificationEntity> items) {
    if (items.isEmpty) {
      return 0;
    }
    return items.where((item) => !item.isRead).length;
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
      await refreshNow(onlyCount: true);
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
      await refreshNow(onlyCount: true);
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
      await refreshNow(soft: false);
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
      await refreshNow(soft: false);
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

    // Immediately emit current state to new listener
    final controller = _controller;
    if (controller != null && !controller.isClosed) {
      // Use scheduleMicrotask to ensure the listener is ready
      scheduleMicrotask(() {
        if (!controller.isClosed) {
          controller.add(_snapshot);
        }
      });
    }

    if (_enableInternalTimer) {
      _timer ??= Timer.periodic(_interval, (_) {
        final shouldCountOnly = _snapshot.itemsUpdatedAt != null;
        unawaited(refreshNow(onlyCount: shouldCountOnly));
      });
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
        enableInternalTimer: true,
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

  String sessionSignature(AuthSessionState state) {
    return [
      state.status.name,
      (state.role ?? '').trim().toLowerCase(),
      (state.email ?? '').trim().toLowerCase(),
      (state.displayName ?? '').trim(),
    ].join('|');
  }

  ref.listen<AuthSessionState>(
    authSessionControllerProvider.select((controller) => controller.state),
    (previous, next) {
      final wasAuthenticated =
          previous?.status == AuthSessionStatus.authenticated;
      final isAuthenticated = next.status == AuthSessionStatus.authenticated;
      final identityChanged =
          previous == null ||
          sessionSignature(previous) != sessionSignature(next);

      if (!isAuthenticated && wasAuthenticated) {
        service.clear();
        return;
      }

      if (isAuthenticated && (!wasAuthenticated || identityChanged)) {
        if (identityChanged) {
          service.clear();
        }
        unawaited(service.prime());
      }
    },
  );

  final current = ref.read(authSessionControllerProvider).state;
  if (current.status == AuthSessionStatus.authenticated) {
    unawaited(service.prime());
  }
});
