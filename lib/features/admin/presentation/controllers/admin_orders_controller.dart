import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/repositories/admin_orders_repository.dart';
import '../../domain/entities/admin_courier_assignment.dart';
import '../../domain/entities/admin_order.dart';

final adminOrdersControllerProvider =
    AsyncNotifierProvider.autoDispose<
      AdminOrdersController,
      AdminOrdersResponse
    >(AdminOrdersController.new);

class AdminOrdersController
    extends AutoDisposeAsyncNotifier<AdminOrdersResponse> {
  String? _currentStatus;

  @override
  FutureOr<AdminOrdersResponse> build() {
    return _fetchOrders(page: 1);
  }

  Future<AdminOrdersResponse> _fetchOrders({
    String? status,
    required int page,
  }) async {
    final repository = ref.read(adminOrdersRepositoryProvider);
    return repository.getOrders(status: status, page: page);
  }

  Future<void> filterByStatus(String? status) async {
    if (_currentStatus == status) return;
    _currentStatus = status;
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => _fetchOrders(status: status, page: 1));
  }

  Future<void> loadMore() async {
    final current = state.valueOrNull;
    if (current == null || current.page >= current.totalPages) return;

    final nextPage = current.page + 1;

    // We don't want to set state to loading for pagination to avoid full screen spinner,
    // but typically we'd use a separate state for "loading more".
    // For simplicity with AsyncNotifier, we can just append data if needed, or just replace.
    // However, basic pagination usually replaces the list or appends.
    // If we want infinite scroll, we need to keep old items.

    // For now, let's just support basic "Next Page" or robust infinite scroll.
    // Let's implement robust infinite scroll by keeping previous items.

    final newData = await _fetchOrders(status: _currentStatus, page: nextPage);

    state = AsyncData(
      current.copyWith(
        items: [...current.items, ...newData.items],
        page: newData.page,
        totalPages: newData.totalPages,
        total: newData.total,
      ),
    );
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => _fetchOrders(status: _currentStatus, page: 1),
    );
  }

  Future<void> updateOrderStatus(int id, String status, {String? note}) async {
    final repository = ref.read(adminOrdersRepositoryProvider);
    await repository.updateOrderStatus(id, status, note: note);
    // Refresh the specific order details
    ref.invalidate(adminOrderDetailsProvider(id));
    // Refresh the list as well to reflect status change
    ref.invalidateSelf();
  }

  Future<void> notifyOrderCustomer(
    int id, {
    required String subject,
    required String message,
    bool asCustomerNote = true,
  }) async {
    final repository = ref.read(adminOrdersRepositoryProvider);
    await repository.notifyOrderCustomer(
      id,
      subject: subject,
      message: message,
      asCustomerNote: asCustomerNote,
    );
    ref.invalidate(adminOrderDetailsProvider(id));
  }

  Future<void> assignOrderCourier({
    required int orderId,
    int? courierId,
    bool unassign = false,
  }) async {
    final repository = ref.read(adminOrdersRepositoryProvider);
    await repository.assignOrderCourier(
      orderId: orderId,
      courierId: courierId,
      unassign: unassign,
    );
    ref.invalidate(adminOrderDetailsProvider(orderId));
    ref.invalidate(adminOrderCourierAssignmentProvider(orderId));
    ref.invalidate(adminCouriersProvider);
    ref.invalidateSelf();
  }
}

final adminOrderDetailsProvider = FutureProvider.autoDispose
    .family<AdminOrder, int>((ref, id) {
      final repository = ref.read(adminOrdersRepositoryProvider);
      return repository.getOrder(id);
    });

final adminCouriersProvider = FutureProvider.autoDispose<List<AdminCourier>>((
  ref,
) {
  final repository = ref.read(adminOrdersRepositoryProvider);
  return repository.getCouriers();
});

final adminOrderCourierAssignmentProvider = FutureProvider.autoDispose
    .family<AdminOrderCourierAssignment, int>((ref, id) {
      final repository = ref.read(adminOrdersRepositoryProvider);
      return repository.getOrderCourierAssignment(id);
    });
