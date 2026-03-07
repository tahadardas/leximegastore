import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:synchronized/synchronized.dart';

import '../repositories/admin_orders_repository.dart';
import '../../domain/entities/admin_courier_location.dart';

class CourierLocationRealtimeSnapshot {
  final AdminCourierLocation? location;
  final bool isLoading;
  final bool isStale;
  final Object? error;
  final DateTime? updatedAt;

  const CourierLocationRealtimeSnapshot({
    this.location,
    this.isLoading = false,
    this.isStale = false,
    this.error,
    this.updatedAt,
  });

  CourierLocationRealtimeSnapshot copyWith({
    AdminCourierLocation? location,
    bool? isLoading,
    bool? isStale,
    Object? error = _noValue,
    DateTime? updatedAt,
  }) {
    return CourierLocationRealtimeSnapshot(
      location: location ?? this.location,
      isLoading: isLoading ?? this.isLoading,
      isStale: isStale ?? this.isStale,
      error: identical(error, _noValue) ? this.error : error,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

const Object _noValue = Object();

class CourierLocationRealtimeService {
  static const Duration defaultInterval = Duration(seconds: 12);

  final AdminOrdersRepository Function() _repoGetter;
  final Duration _interval;
  final Map<int, _CourierEntry> _entries = <int, _CourierEntry>{};
  bool _disposed = false;

  CourierLocationRealtimeService({
    required AdminOrdersRepository Function() repoGetter,
    Duration interval = defaultInterval,
  }) : _repoGetter = repoGetter,
       _interval = interval;

  Stream<CourierLocationRealtimeSnapshot> streamForCourier(int courierId) {
    final entry = _entries.putIfAbsent(
      courierId,
      () => _CourierEntry(courierId: courierId),
    );
    entry.ensureController(
      onFirstListen: () => _start(courierId),
      onNoListeners: () => _stop(courierId),
    );
    return entry.controller!.stream;
  }

  Future<void> refreshNow(int courierId, {bool soft = true}) async {
    if (_disposed || courierId <= 0) {
      return;
    }

    final entry = _entries.putIfAbsent(
      courierId,
      () => _CourierEntry(courierId: courierId),
    );

    await entry.lock.synchronized(() async {
      if (_disposed) {
        return;
      }

      final hasCached = entry.snapshot.location != null;
      if (!soft || !hasCached) {
        _emit(
          entry,
          entry.snapshot.copyWith(
            isLoading: true,
            isStale: hasCached,
            error: null,
          ),
        );
      }

      try {
        final location = await _repoGetter().getCourierLocation(courierId);
        _emit(
          entry,
          CourierLocationRealtimeSnapshot(
            location: location,
            isLoading: false,
            isStale: false,
            error: null,
            updatedAt: DateTime.now(),
          ),
        );
      } catch (error) {
        if (entry.snapshot.location != null) {
          _emit(
            entry,
            entry.snapshot.copyWith(
              isLoading: false,
              isStale: true,
              error: error,
            ),
          );
          return;
        }
        _emit(
          entry,
          CourierLocationRealtimeSnapshot(
            location: null,
            isLoading: false,
            isStale: false,
            error: error,
            updatedAt: entry.snapshot.updatedAt,
          ),
        );
      }
    });
  }

  void dispose() {
    _disposed = true;
    for (final entry in _entries.values) {
      entry.timer?.cancel();
      entry.timer = null;
      entry.controller?.close();
      entry.controller = null;
    }
    _entries.clear();
  }

  void _start(int courierId) {
    if (_disposed || courierId <= 0) {
      return;
    }

    final entry = _entries[courierId];
    if (entry == null) {
      return;
    }

    entry.controller?.add(entry.snapshot);
    entry.timer ??= Timer.periodic(_interval, (_) {
      unawaited(refreshNow(courierId));
    });
    unawaited(refreshNow(courierId));
  }

  void _stop(int courierId) {
    final entry = _entries[courierId];
    if (entry == null) {
      return;
    }

    if (entry.controller?.hasListener == true) {
      return;
    }

    entry.timer?.cancel();
    entry.timer = null;
  }

  void _emit(_CourierEntry entry, CourierLocationRealtimeSnapshot next) {
    entry.snapshot = next;
    final controller = entry.controller;
    if (controller != null && !controller.isClosed) {
      controller.add(next);
    }
  }
}

class _CourierEntry {
  final int courierId;
  final Lock lock = Lock();
  StreamController<CourierLocationRealtimeSnapshot>? controller;
  Timer? timer;
  CourierLocationRealtimeSnapshot snapshot =
      const CourierLocationRealtimeSnapshot();

  _CourierEntry({required this.courierId});

  void ensureController({
    required void Function() onFirstListen,
    required void Function() onNoListeners,
  }) {
    controller ??= StreamController<CourierLocationRealtimeSnapshot>.broadcast(
      onListen: onFirstListen,
      onCancel: onNoListeners,
    );
  }
}

final courierLocationRealtimeServiceProvider =
    Provider<CourierLocationRealtimeService>((ref) {
      final service = CourierLocationRealtimeService(
        repoGetter: () => ref.read(adminOrdersRepositoryProvider),
      );
      ref.onDispose(service.dispose);
      return service;
    });

final courierLocationStreamProvider = StreamProvider.family
    .autoDispose<CourierLocationRealtimeSnapshot, int>((ref, courierId) {
      return ref
          .read(courierLocationRealtimeServiceProvider)
          .streamForCourier(courierId);
    });
