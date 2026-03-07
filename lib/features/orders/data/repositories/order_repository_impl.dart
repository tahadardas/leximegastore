import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/order.dart';
import '../../domain/entities/order_track.dart';
import '../../domain/repositories/order_repository.dart';
import '../datasources/order_remote_datasource.dart';

final orderRepositoryProvider = Provider<OrderRepository>((ref) {
  return OrderRepositoryImpl(ref.watch(orderRemoteDatasourceProvider));
});

class OrderRepositoryImpl implements OrderRepository {
  final OrderRemoteDatasource _datasource;

  OrderRepositoryImpl(this._datasource);

  @override
  Future<dynamic> getInvoice(String orderId, String type, {String? phone}) =>
      _datasource.getInvoice(orderId, type, phone: phone);

  @override
  Future<({int page, int perPage, List<Order> items})> myOrders({
    int page = 1,
    int perPage = 20,
  }) => _datasource.myOrders(page: page, perPage: perPage);

  @override
  Future<Order> myOrderDetails(int orderId) =>
      _datasource.myOrderDetails(orderId);

  @override
  Future<OrderTrackInfo> trackOrderByNumber({
    required String orderNumber,
    String? verifier,
  }) => _datasource.trackOrderByNumber(
    orderNumber: orderNumber,
    verifier: verifier,
  );

  @override
  Future<void> confirmReceived(int orderId) =>
      _datasource.confirmReceived(orderId);

  @override
  Future<void> refuseOrder(int orderId, String reason) =>
      _datasource.refuseOrder(orderId, reason);
}
