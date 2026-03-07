import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/device/device_id_provider.dart';
import '../../../../core/session/app_session.dart';
import '../../data/notification_repository.dart';
import '../../domain/entities/notification_entity.dart';

/// State for notifications list
class NotificationsState {
  final List<NotificationEntity> notifications;
  final bool isLoading;
  final bool hasMore;
  final int currentPage;
  final String? error;
  final int unreadCount;

  const NotificationsState({
    this.notifications = const [],
    this.isLoading = false,
    this.hasMore = true,
    this.currentPage = 1,
    this.error,
    this.unreadCount = 0,
  });

  NotificationsState copyWith({
    List<NotificationEntity>? notifications,
    bool? isLoading,
    bool? hasMore,
    int? currentPage,
    String? error,
    int? unreadCount,
  }) {
    return NotificationsState(
      notifications: notifications ?? this.notifications,
      isLoading: isLoading ?? this.isLoading,
      hasMore: hasMore ?? this.hasMore,
      currentPage: currentPage ?? this.currentPage,
      error: error,
      unreadCount: unreadCount ?? this.unreadCount,
    );
  }
}

/// Controller for customer notifications
final customerNotificationsProvider =
    StateNotifierProvider<CustomerNotificationsController, NotificationsState>((
      ref,
    ) {
      return CustomerNotificationsController(
        ref.watch(notificationRepositoryProvider),
      );
    });

class CustomerNotificationsController
    extends StateNotifier<NotificationsState> {
  final NotificationRepository _repo;
  CancelToken? _cancelToken;

  CustomerNotificationsController(this._repo)
    : super(const NotificationsState()) {
    // Load initial data
    loadFirstPage();
  }

  Future<void> loadFirstPage() async {
    _cancelToken?.cancel();
    _cancelToken = CancelToken();

    state = state.copyWith(isLoading: true, error: null);

    try {
      final page = await _repo.getCustomerNotifications(
        page: 1,
        perPage: 20,
        cancelToken: _cancelToken,
      );

      if (mounted) {
        state = NotificationsState(
          notifications: page.notifications,
          isLoading: false,
          hasMore: page.hasMore,
          currentPage: 1,
          unreadCount: page.unreadCount,
        );
      }
    } catch (e) {
      if (mounted) {
        state = state.copyWith(isLoading: false, error: e.toString());
      }
    }
  }

  Future<void> loadMore() async {
    if (state.isLoading || !state.hasMore) return;

    _cancelToken?.cancel();
    _cancelToken = CancelToken();

    state = state.copyWith(isLoading: true);

    try {
      final nextPage = state.currentPage + 1;
      final page = await _repo.getCustomerNotifications(
        page: nextPage,
        perPage: 20,
        cancelToken: _cancelToken,
      );

      if (mounted) {
        state = state.copyWith(
          notifications: [...state.notifications, ...page.notifications],
          isLoading: false,
          hasMore: page.hasMore,
          currentPage: nextPage,
        );
      }
    } catch (e) {
      if (mounted) {
        state = state.copyWith(isLoading: false);
      }
    }
  }

  Future<void> refresh() async {
    await loadFirstPage();
  }

  Future<void> markAsRead(int notificationId) async {
    final index = state.notifications.indexWhere((n) => n.id == notificationId);
    if (index == -1) return;

    final notification = state.notifications[index];
    if (notification.isRead) return;

    // Optimistic update
    state = state.copyWith(
      notifications: state.notifications.map((n) {
        if (n.id == notificationId) {
          return n.copyWith(isRead: true);
        }
        return n;
      }).toList(),
      unreadCount: state.unreadCount > 0 ? state.unreadCount - 1 : 0,
    );

    try {
      await _repo.markCustomerRead(ids: [notificationId]);
    } catch (_) {
      // Revert on error
      if (mounted) {
        state = state.copyWith(
          notifications: state.notifications.map((n) {
            if (n.id == notificationId) {
              return n.copyWith(isRead: false);
            }
            return n;
          }).toList(),
          unreadCount: state.unreadCount + 1,
        );
      }
    }
  }

  Future<void> markAllAsRead() async {
    // Optimistic update
    state = state.copyWith(
      notifications: state.notifications
          .map((n) => n.copyWith(isRead: true))
          .toList(),
      unreadCount: 0,
    );

    try {
      await _repo.markAllCustomerRead();
    } catch (_) {
      // Refresh to get correct state
      await refresh();
    }
  }

  Future<void> updateUnreadCount() async {
    try {
      final count = await _repo.getCustomerUnreadCount();
      if (mounted) {
        state = state.copyWith(unreadCount: count);
      }
    } catch (_) {}
  }
}

/// Controller for admin notifications
final adminNotificationsProvider =
    StateNotifierProvider<AdminNotificationsController, NotificationsState>((
      ref,
    ) {
      return AdminNotificationsController(
        ref.watch(notificationRepositoryProvider),
        ref.watch(appSessionProvider),
      );
    });

class AdminNotificationsController extends StateNotifier<NotificationsState> {
  final NotificationRepository _repo;
  final AppSession _session;
  CancelToken? _cancelToken;

  AdminNotificationsController(this._repo, this._session)
    : super(const NotificationsState()) {
    // Only load if admin
    if (_session.isAdmin) {
      loadFirstPage();
    }
  }

  Future<void> loadFirstPage() async {
    if (!_session.isAdmin) return;

    _cancelToken?.cancel();
    _cancelToken = CancelToken();

    state = state.copyWith(isLoading: true, error: null);

    try {
      final page = await _repo.getAdminNotifications(
        page: 1,
        perPage: 20,
        cancelToken: _cancelToken,
      );

      if (mounted) {
        state = NotificationsState(
          notifications: page.notifications,
          isLoading: false,
          hasMore: page.hasMore,
          currentPage: 1,
          unreadCount: page.unreadCount,
        );
      }
    } catch (e) {
      if (mounted) {
        state = state.copyWith(isLoading: false, error: e.toString());
      }
    }
  }

  Future<void> loadMore() async {
    if (state.isLoading || !state.hasMore || !_session.isAdmin) return;

    _cancelToken?.cancel();
    _cancelToken = CancelToken();

    state = state.copyWith(isLoading: true);

    try {
      final nextPage = state.currentPage + 1;
      final page = await _repo.getAdminNotifications(
        page: nextPage,
        perPage: 20,
        cancelToken: _cancelToken,
      );

      if (mounted) {
        state = state.copyWith(
          notifications: [...state.notifications, ...page.notifications],
          isLoading: false,
          hasMore: page.hasMore,
          currentPage: nextPage,
        );
      }
    } catch (e) {
      if (mounted) {
        state = state.copyWith(isLoading: false);
      }
    }
  }

  Future<void> refresh() async {
    await loadFirstPage();
  }

  Future<void> markAsRead(int notificationId) async {
    final index = state.notifications.indexWhere((n) => n.id == notificationId);
    if (index == -1) return;

    final notification = state.notifications[index];
    if (notification.isRead) return;

    // Optimistic update
    state = state.copyWith(
      notifications: state.notifications.map((n) {
        if (n.id == notificationId) {
          return n.copyWith(isRead: true);
        }
        return n;
      }).toList(),
      unreadCount: state.unreadCount > 0 ? state.unreadCount - 1 : 0,
    );

    try {
      await _repo.markAdminRead(ids: [notificationId]);
    } catch (_) {
      // Revert on error
      if (mounted) {
        state = state.copyWith(
          notifications: state.notifications.map((n) {
            if (n.id == notificationId) {
              return n.copyWith(isRead: false);
            }
            return n;
          }).toList(),
          unreadCount: state.unreadCount + 1,
        );
      }
    }
  }

  Future<void> markAllAsRead() async {
    // Optimistic update
    state = state.copyWith(
      notifications: state.notifications
          .map((n) => n.copyWith(isRead: true))
          .toList(),
      unreadCount: 0,
    );

    try {
      await _repo.markAllAdminRead();
    } catch (_) {
      // Refresh to get correct state
      await refresh();
    }
  }

  Future<void> updateUnreadCount() async {
    if (!_session.isAdmin) return;
    try {
      final count = await _repo.getAdminUnreadCount();
      if (mounted) {
        state = state.copyWith(unreadCount: count);
      }
    } catch (_) {}
  }

  /// Admin: Approve or reject an order
  Future<Map<String, dynamic>> makeOrderDecision({
    required int orderId,
    required String decision,
    String? note,
  }) async {
    final result = await _repo.adminOrderDecision(
      orderId: orderId,
      decision: decision,
      note: note,
    );

    // Refresh notifications after decision
    if (result['success'] == true) {
      await refresh();
    }

    return result;
  }
}

/// Combined unread count for badge display
final totalUnreadCountProvider = Provider<int>((ref) {
  final customerState = ref.watch(customerNotificationsProvider);
  final adminState = ref.watch(adminNotificationsProvider);
  final session = ref.watch(appSessionProvider);

  int total = customerState.unreadCount;
  if (session.isAdmin) {
    total += adminState.unreadCount;
  }
  return total;
});

/// Periodic unread count refresh
final unreadCountRefreshProvider =
    StateNotifierProvider<UnreadCountRefresher, void>((ref) {
      return UnreadCountRefresher(ref);
    });

class UnreadCountRefresher extends StateNotifier<void> {
  final Ref _ref;
  Timer? _timer;

  UnreadCountRefresher(this._ref) : super(null) {
    _startPolling();
  }

  void _startPolling() {
    _timer?.cancel();
    // Poll every 60 seconds
    _timer = Timer.periodic(const Duration(seconds: 60), (_) {
      _refresh();
    });
  }

  void _refresh() {
    final session = _ref.read(appSessionProvider);
    final deviceId = _ref.read(deviceIdProvider).valueOrNull;

    final canCustomer =
        session.isLoggedIn || ((deviceId ?? '').trim().isNotEmpty);
    if (canCustomer) {
      _ref.read(customerNotificationsProvider.notifier).updateUnreadCount();
    }

    final canAdmin =
        session.isAdmin && session.isLoggedIn && session.hasStoredRefreshToken;
    if (canAdmin) {
      _ref.read(adminNotificationsProvider.notifier).updateUnreadCount();
    }
  }

  void refreshNow() {
    _refresh();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
