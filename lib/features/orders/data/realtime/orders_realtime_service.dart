import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:synchronized/synchronized.dart';

import '../../../../core/auth/auth_session_controller.dart';
import '../../domain/entities/order.dart';
import '../repositories/order_repository_impl.dart';

class OrdersRealtimeSnapshot {
  final List<Order> items;
  final bool isLoading;
  final bool isStale;
  final Object? error;
  final DateTime? updatedAt;

  const OrdersRealtimeSnapshot({
    this.items = const <Order>[],
    this.isLoading = false,
    this.isStale = false,
    this.error,
    this.updatedAt,
  });

  OrdersRealtimeSnapshot copyWith({
    List<Order>? items,
    bool? isLoading,
    bool? isStale,
    Object? error = _noValue,
    DateTime? updatedAt,
  }) {
    return OrdersRealtimeSnapshot(
      items: items ?? this.items,
      isLoading: isLoading ?? this.isLoading,
      isStale: isStale ?? this.isStale,
      error: identical(error, _noValue) ? this.error : error,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

const Object _noValue = Object();

class OrdersRealtimeService {
  static const Duration defaultInterval = Duration(seconds: 45);

  final Future<({int page, int perPage, List<Order> items})> Function({
    required int page,
    required int perPage,
  })
  _fetchOrders;
  final bool Function() _isAuthenticated;
  final Duration _interval;
  final bool _enableInternalTimer;

  final Lock _refreshLock = Lock();
  StreamController<OrdersRealtimeSnapshot>? _controller;
  Timer? _timer;
  bool _disposed = false;
  OrdersRealtimeSnapshot _snapshot = const OrdersRealtimeSnapshot();

  OrdersRealtimeService({
    required Future<({int page, int perPage, List<Order> items})> Function({
      required int page,
      required int perPage,
    })
    fetchOrders,
    required bool Function() isAuthenticated,
    Duration interval = defaultInterval,
    bool enableInternalTimer = false,
  }) : _fetchOrders = fetchOrders,
       _isAuthenticated = isAuthenticated,
       _interval = interval,
       _enableInternalTimer = enableInternalTimer;

  OrdersRealtimeSnapshot get snapshot => _snapshot;

  Stream<OrdersRealtimeSnapshot> get stream {
    _controller ??= StreamController<OrdersRealtimeSnapshot>.broadcast(
      onListen: _handleListen,
      onCancel: _handleCancel,
    );
    return _controller!.stream;
  }

  Future<void> prime() async {
    if (_disposed) {
      return;
    }
    if (_snapshot.items.isNotEmpty || _snapshot.isLoading) {
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

      if (!_isAuthenticated()) {
        _emit(
          const OrdersRealtimeSnapshot(
            items: <Order>[],
            isLoading: false,
            isStale: false,
            error: null,
          ),
        );
        return;
      }

      final hasCached = _snapshot.items.isNotEmpty;
      if (!soft || !hasCached) {
        _emit(
          _snapshot.copyWith(isLoading: true, isStale: hasCached, error: null),
        );
      }

      try {
        final result = await _fetchOrders(page: 1, perPage: 50);
        final nextItems = List<Order>.from(result.items)
          ..sort((a, b) => b.date.compareTo(a.date));

        _emit(
          OrdersRealtimeSnapshot(
            items: nextItems,
            isLoading: false,
            isStale: false,
            error: null,
            updatedAt: DateTime.now(),
          ),
        );
      } catch (error) {
        if (_snapshot.items.isNotEmpty) {
          _emit(
            _snapshot.copyWith(isLoading: false, isStale: true, error: error),
          );
          return;
        }

        _emit(
          OrdersRealtimeSnapshot(
            items: const <Order>[],
            isLoading: false,
            isStale: false,
            error: error,
            updatedAt: _snapshot.updatedAt,
          ),
        );
      }
    });
  }

  Future<void> notifyOrderMutation() async {
    await refreshNow(soft: false);
  }

  void clear() {
    if (_disposed) {
      return;
    }
    _emit(const OrdersRealtimeSnapshot());
  }

  void _handleListen() {
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

  void _handleCancel() {
    if (_disposed) {
      return;
    }
    if (_controller?.hasListener == true) {
      return;
    }
    _timer?.cancel();
    _timer = null;
  }

  void _emit(OrdersRealtimeSnapshot next) {
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

final ordersRealtimeServiceProvider = Provider<OrdersRealtimeService>((ref) {
  final service = OrdersRealtimeService(
    fetchOrders: ({required int page, required int perPage}) {
      return ref
          .read(orderRepositoryProvider)
          .myOrders(page: page, perPage: perPage);
    },
    isAuthenticated: () {
      final authState = ref.read(authSessionControllerProvider).state;
      return authState.status == AuthSessionStatus.authenticated;
    },
    enableInternalTimer: false,
  );

  ref.onDispose(service.dispose);
  return service;
});

final ordersStreamProvider = StreamProvider.autoDispose<OrdersRealtimeSnapshot>(
  (ref) {
    final service = ref.read(ordersRealtimeServiceProvider);
    return service.stream;
  },
);

final ordersRealtimeBootstrapProvider = Provider<void>((ref) {
  final service = ref.read(ordersRealtimeServiceProvider);

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
