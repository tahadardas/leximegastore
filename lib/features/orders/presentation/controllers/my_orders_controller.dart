import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/realtime/orders_realtime_service.dart';
import '../../domain/entities/order.dart';

class MyOrdersState {
  final List<Order> items;
  final DateTime? lastUpdatedAt;
  final bool isLoadingInitial;
  final bool isStale;
  final Object? error;

  const MyOrdersState({
    this.items = const [],
    this.lastUpdatedAt,
    this.isLoadingInitial = false,
    this.isStale = false,
    this.error,
  });

  MyOrdersState copyWith({
    List<Order>? items,
    DateTime? lastUpdatedAt,
    bool? isLoadingInitial,
    bool? isStale,
    Object? error,
  }) {
    return MyOrdersState(
      items: items ?? this.items,
      lastUpdatedAt: lastUpdatedAt ?? this.lastUpdatedAt,
      isLoadingInitial: isLoadingInitial ?? this.isLoadingInitial,
      isStale: isStale ?? this.isStale,
      error: error,
    );
  }
}

final myOrdersControllerProvider =
    AutoDisposeNotifierProvider<MyOrdersController, MyOrdersState>(
      MyOrdersController.new,
    );

class MyOrdersController extends AutoDisposeNotifier<MyOrdersState> {
  late final OrdersRealtimeService _realtime;
  StreamSubscription<OrdersRealtimeSnapshot>? _subscription;

  @override
  MyOrdersState build() {
    _realtime = ref.read(ordersRealtimeServiceProvider);
    _subscription = _realtime.stream.listen(_applySnapshot);

    ref.onDispose(() {
      _subscription?.cancel();
      _subscription = null;
    });

    return _stateFromSnapshot(_realtime.snapshot);
  }

  Future<void> loadInitial({int perPage = 20}) async {
    await _realtime.refreshNow(soft: false);
  }

  Future<void> refresh() async {
    await _realtime.refreshNow(soft: false);
  }

  Future<void> loadMore() async {
    // Orders stream fetches a larger first page periodically.
    // Keep method for UI compatibility.
  }

  void _applySnapshot(OrdersRealtimeSnapshot snapshot) {
    state = _stateFromSnapshot(snapshot);
  }

  MyOrdersState _stateFromSnapshot(OrdersRealtimeSnapshot snapshot) {
    return MyOrdersState(
      items: snapshot.items,
      lastUpdatedAt: snapshot.updatedAt,
      isLoadingInitial: snapshot.isLoading && snapshot.items.isEmpty,
      isStale: snapshot.isStale,
      error: snapshot.error,
    );
  }
}
