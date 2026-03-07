import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';

import '../../data/datasources/admin_orders_datasource.dart';
import '../../domain/entities/shamcash_order.dart';

/// Controller state for ShamCash verification
class ShamCashVerificationState {
  final bool isLoading;
  final List<ShamCashOrder> orders;
  final int total;
  final int page;
  final int totalPages;
  final String? error;
  final bool isApproving;
  final bool isRejecting;
  final int? processingOrderId;

  const ShamCashVerificationState({
    this.isLoading = false,
    this.orders = const [],
    this.total = 0,
    this.page = 1,
    this.totalPages = 1,
    this.error,
    this.isApproving = false,
    this.isRejecting = false,
    this.processingOrderId,
  });

  ShamCashVerificationState copyWith({
    bool? isLoading,
    List<ShamCashOrder>? orders,
    int? total,
    int? page,
    int? totalPages,
    String? error,
    bool? isApproving,
    bool? isRejecting,
    int? processingOrderId,
  }) {
    return ShamCashVerificationState(
      isLoading: isLoading ?? this.isLoading,
      orders: orders ?? this.orders,
      total: total ?? this.total,
      page: page ?? this.page,
      totalPages: totalPages ?? this.totalPages,
      error: error,
      isApproving: isApproving ?? this.isApproving,
      isRejecting: isRejecting ?? this.isRejecting,
      processingOrderId: processingOrderId,
    );
  }
}

class ShamCashVerificationNotifier
    extends StateNotifier<ShamCashVerificationState> {
  final AdminOrdersRemoteDatasource _datasource;

  ShamCashVerificationNotifier(this._datasource)
    : super(const ShamCashVerificationState()) {
    loadOrders();
  }

  /// Load pending ShamCash orders
  Future<void> loadOrders({int page = 1}) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final response = await _datasource.getPendingShamCashOrders(
        page: page,
        perPage: 20,
      );
      final mergedOrders = page <= 1
          ? response.orders
          : [...state.orders, ...response.orders];

      state = state.copyWith(
        isLoading: false,
        orders: mergedOrders,
        total: response.total,
        page: response.page,
        totalPages: response.totalPages,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: _friendlyError(e));
    }
  }

  /// Refresh orders list
  Future<void> refresh() async {
    await loadOrders(page: 1);
  }

  /// Load next page
  Future<void> loadMore() async {
    if (state.page < state.totalPages && !state.isLoading) {
      await loadOrders(page: state.page + 1);
    }
  }

  /// Approve ShamCash payment
  Future<ShamCashVerificationResult?> approveOrder(
    int orderId, {
    String? note,
  }) async {
    state = state.copyWith(isApproving: true, processingOrderId: orderId);

    try {
      final result = await _datasource.approveShamCash(orderId, noteAr: note);

      // Remove approved order from list
      final updatedOrders = state.orders.where((o) => o.id != orderId).toList();
      state = state.copyWith(
        isApproving: false,
        processingOrderId: null,
        orders: updatedOrders,
        total: state.total - 1,
      );

      return result;
    } catch (e) {
      state = state.copyWith(
        isApproving: false,
        processingOrderId: null,
        error: _friendlyError(e),
      );
      return null;
    }
  }

  /// Reject ShamCash payment
  Future<ShamCashVerificationResult?> rejectOrder(
    int orderId, {
    required String reason,
  }) async {
    state = state.copyWith(isRejecting: true, processingOrderId: orderId);

    try {
      final result = await _datasource.rejectShamCash(orderId, noteAr: reason);

      // Remove rejected order from list
      final updatedOrders = state.orders.where((o) => o.id != orderId).toList();
      state = state.copyWith(
        isRejecting: false,
        processingOrderId: null,
        orders: updatedOrders,
        total: state.total - 1,
      );

      return result;
    } catch (e) {
      state = state.copyWith(
        isRejecting: false,
        processingOrderId: null,
        error: _friendlyError(e),
      );
      return null;
    }
  }

  /// Clear error
  void clearError() {
    state = state.copyWith(error: null);
  }

  String _friendlyError(Object error) {
    if (error is DioException) {
      final status = error.response?.statusCode ?? 0;
      if (status == 401 || status == 403) {
        return 'غير مصرح بتنفيذ هذه العملية.';
      }
      if (status == 422) {
        return 'تعذر تنفيذ العملية. تحقق من البيانات ثم أعد المحاولة.';
      }
      if (status >= 500) {
        return 'الخدمة غير متاحة حالياً. حاول لاحقاً.';
      }
    }

    return 'حدث خطأ غير متوقع. حاول مرة أخرى.';
  }
}

/// Provider for ShamCash verification controller
final shamCashVerificationProvider =
    StateNotifierProvider<
      ShamCashVerificationNotifier,
      ShamCashVerificationState
    >((ref) {
      return ShamCashVerificationNotifier(
        ref.read(adminOrdersRemoteDatasourceProvider),
      );
    });
