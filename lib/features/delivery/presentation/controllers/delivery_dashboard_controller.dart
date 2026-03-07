import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/delivery_repository.dart';
import '../../domain/entities/delivery_entities.dart';
import '../../data/local/pending_delivery_actions_store.dart';

final deliveryDashboardControllerProvider =
    AsyncNotifierProvider.autoDispose<
      DeliveryDashboardController,
      DeliveryDashboardData
    >(DeliveryDashboardController.new);

class DeliveryDashboardController
    extends AutoDisposeAsyncNotifier<DeliveryDashboardData> {
  @override
  FutureOr<DeliveryDashboardData> build() {
    return _loadDashboard();
  }

  bool _isNetworkError(Object e) {
    if (e is DioException) {
      return e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.sendTimeout ||
          e.type == DioExceptionType.receiveTimeout ||
          e.type == DioExceptionType.connectionError ||
          e.type == DioExceptionType.unknown;
    }
    return false;
  }

  Future<void> syncOfflineActions() async {
    final store = ref.read(pendingDeliveryActionsStoreProvider);
    final repository = ref.read(deliveryRepositoryProvider);
    final pending = await store.getAll();
    if (pending.isEmpty) return;

    for (final action in pending) {
      try {
        if (action.collectedAmount != null) {
          await repository.collectCod(
            action.orderId,
            collectedAmount: action.collectedAmount!,
            currency: action.currency ?? 'SYP',
            note: action.note ?? '',
          );
        } else {
          await repository.updateOrderStatus(
            action.orderId,
            status: action.status,
            note: action.note ?? '',
          );
        }
        await store.remove(action.orderId);
      } catch (e) {
        if (!_isNetworkError(e)) {
          await store.remove(action.orderId);
        }
      }
    }
  }

  Future<DeliveryDashboardData> _loadDashboard() async {
    unawaited(syncOfflineActions());

    final repository = ref.read(deliveryRepositoryProvider);
    final rawData = await repository.getDashboard();
    return _applyOfflineActions(rawData);
  }

  Future<DeliveryDashboardData> _applyOfflineActions(
    DeliveryDashboardData rawData,
  ) async {
    final pendingStore = ref.read(pendingDeliveryActionsStoreProvider);
    final pendingActions = await pendingStore.getAll();
    if (pendingActions.isEmpty) return rawData;

    final updatedOrders = rawData.orders.map((o) {
      final match = pendingActions.where((a) => a.orderId == o.id).firstOrNull;
      if (match != null) {
        if (match.collectedAmount != null && o.cod != null) {
          return o.copyWith(
            status: 'completed',
            cod: o.cod!.copyWith(
              collectedStatus: 'collected',
              collectedAmount: match.collectedAmount,
            ),
          );
        }
        return o.copyWith(status: match.status);
      }
      return o;
    }).toList();

    return DeliveryDashboardData(
      profile: rawData.profile,
      orders: updatedOrders,
      page: rawData.page,
      total: rawData.total,
      totalPages: rawData.totalPages,
      totalCollectedToday: rawData.totalCollectedToday,
    );
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(_loadDashboard);
  }

  Future<void> setAvailability(bool isAvailable) async {
    final repository = ref.read(deliveryRepositoryProvider);
    await repository.setAvailability(isAvailable);
    await refresh();
  }

  Future<void> updateOrderStatus(
    int orderId, {
    required String status,
    String note = '',
  }) async {
    final repository = ref.read(deliveryRepositoryProvider);
    try {
      await repository.updateOrderStatus(orderId, status: status, note: note);
      await refresh();
    } catch (e) {
      if (_isNetworkError(e)) {
        final store = ref.read(pendingDeliveryActionsStoreProvider);
        await store.save(
          PendingDeliveryAction(
            orderId: orderId,
            status: status,
            note: note,
            createdAt: DateTime.now().toIso8601String(),
          ),
        );
        await refresh();
      } else {
        rethrow;
      }
    }
  }

  Future<void> collectCod(
    int orderId, {
    required String collectedAmount,
    String currency = 'SYP',
    String note = '',
  }) async {
    final repository = ref.read(deliveryRepositoryProvider);
    try {
      await repository.collectCod(
        orderId,
        collectedAmount: collectedAmount,
        currency: currency,
        note: note,
      );
      await refresh();
    } catch (e) {
      if (_isNetworkError(e)) {
        final store = ref.read(pendingDeliveryActionsStoreProvider);
        await store.save(
          PendingDeliveryAction(
            orderId: orderId,
            status: 'completed',
            collectedAmount: collectedAmount,
            currency: currency,
            note: note,
            createdAt: DateTime.now().toIso8601String(),
          ),
        );
        await refresh();
      } else {
        rethrow;
      }
    }
  }

  Future<void> cancelAssignment(int orderId) async {
    final repository = ref.read(deliveryRepositoryProvider);
    await repository.cancelAssignment(orderId);
    await refresh();
  }
}
