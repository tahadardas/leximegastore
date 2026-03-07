import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../datasources/admin_orders_datasource.dart';
import '../../domain/entities/admin_courier_assignment.dart';
import '../../domain/entities/admin_courier_location.dart';
import '../../domain/entities/admin_courier_report.dart';
import '../../domain/entities/admin_order.dart';

final adminOrdersRepositoryProvider = Provider<AdminOrdersRepository>((ref) {
  return AdminOrdersRepository(ref.read(adminOrdersRemoteDatasourceProvider));
});

class AdminOrdersRepository {
  final AdminOrdersRemoteDatasource _datasource;

  AdminOrdersRepository(this._datasource);

  Future<AdminOrdersResponse> getOrders({String? status, int page = 1}) async {
    return _datasource.getOrders(status: status, page: page);
  }

  Future<AdminOrder> getOrder(int id) async {
    return _datasource.getOrder(id);
  }

  Future<AdminOrder> updateOrderStatus(
    int id,
    String status, {
    String? note,
  }) async {
    return _datasource.updateOrderStatus(id, status, note: note);
  }

  Future<void> notifyOrderCustomer(
    int id, {
    required String subject,
    required String message,
    bool asCustomerNote = true,
  }) async {
    await _datasource.notifyOrderCustomer(
      id,
      subject: subject,
      message: message,
      asCustomerNote: asCustomerNote,
    );
  }

  Future<List<AdminCourier>> getCouriers({
    bool availableOnly = false,
    String search = '',
  }) async {
    return _datasource.getCouriers(
      availableOnly: availableOnly,
      search: search,
    );
  }

  Future<AdminCouriersReportResponse> getCouriersReport({
    DateTime? date,
    int? courierId,
    DateTime? from,
    DateTime? to,
    bool includeDetails = true,
    int detailsLimit = 50,
  }) async {
    return _datasource.getCouriersReport(
      date: date,
      courierId: courierId,
      from: from,
      to: to,
      includeDetails: includeDetails,
      detailsLimit: detailsLimit,
    );
  }

  Future<AdminCourierLocation> getCourierLocation(int courierId) async {
    return _datasource.getCourierLocation(courierId);
  }

  Future<AdminOrderCourierAssignment> getOrderCourierAssignment(int id) async {
    return _datasource.getOrderCourierAssignment(id);
  }

  Future<AdminOrder> assignOrderCourier({
    required int orderId,
    int? courierId,
    bool unassign = false,
  }) async {
    return _datasource.assignOrderCourier(
      orderId: orderId,
      courierId: courierId,
      unassign: unassign,
    );
  }

  Future<Map<String, dynamic>> settleCourierAccount(int courierId) async {
    return _datasource.settleCourierAccount(courierId);
  }
}
