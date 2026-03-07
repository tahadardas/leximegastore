import '../entities/order.dart';
import '../entities/order_track.dart';

abstract class OrderRepository {
  Future<dynamic> getInvoice(String orderId, String type, {String? phone});
  Future<({int page, int perPage, List<Order> items})> myOrders({
    int page,
    int perPage,
  });
  Future<Order> myOrderDetails(int orderId);
  Future<OrderTrackInfo> trackOrderByNumber({
    required String orderNumber,
    String? verifier,
  });
  Future<void> confirmReceived(int orderId);
  Future<void> refuseOrder(int orderId, String reason);
}
