import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../config/constants/endpoints.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../core/utils/safe_parsers.dart';
import '../../../../core/utils/text_normalizer.dart';
import '../../domain/entities/admin_courier_assignment.dart';
import '../../domain/entities/admin_courier_location.dart';
import '../../domain/entities/admin_courier_report.dart';
import '../../domain/entities/admin_order.dart';
import '../../domain/entities/shamcash_order.dart';

final adminOrdersRemoteDatasourceProvider =
    Provider<AdminOrdersRemoteDatasource>((ref) {
      return AdminOrdersRemoteDatasource(ref.read(dioClientProvider));
    });

class AdminOrdersRemoteDatasource {
  final DioClient _client;

  AdminOrdersRemoteDatasource(this._client);

  Future<AdminOrdersResponse> getOrders({
    String? status,
    int page = 1,
    int perPage = 20,
  }) async {
    final response = await _client.get(
      Endpoints.adminOrders(),
      queryParameters: {
        if (status != null && status.isNotEmpty) 'status': status,
        'page': page,
        'per_page': perPage,
      },
    );

    final map = extractMap(response.data);
    return AdminOrdersResponse.fromJson(
      _normalizeOrdersResponse(map, page, perPage),
    );
  }

  Future<AdminOrder> getOrder(int id) async {
    final response = await _client.get(Endpoints.adminOrder(id));
    final map = extractMap(response.data);
    return AdminOrder.fromJson(_normalizeOrder(map));
  }

  Future<AdminOrder> updateOrderStatus(
    int id,
    String status, {
    String? note,
  }) async {
    await _client.patch(
      Endpoints.adminOrder(id),
      data: {
        'status': status,
        if (note != null && note.isNotEmpty) 'note': note,
      },
      options: Options(extra: const {'requiresAuth': true}),
    );

    return getOrder(id);
  }

  Future<void> notifyOrderCustomer(
    int id, {
    required String subject,
    required String message,
    bool asCustomerNote = true,
  }) async {
    await _client.post(
      Endpoints.adminOrderNotify(id),
      data: {
        'subject': subject,
        'message': message,
        'as_customer_note': asCustomerNote,
      },
      options: Options(extra: const {'requiresAuth': true}),
    );
  }

  Future<List<AdminCourier>> getCouriers({
    bool availableOnly = false,
    String search = '',
  }) async {
    final response = await _client.get(
      Endpoints.adminCouriers(),
      queryParameters: {
        if (availableOnly) 'available_only': 1,
        if (search.trim().isNotEmpty) 'search': search.trim(),
      },
      options: Options(extra: const {'requiresAuth': true}),
    );

    final map = extractMap(response.data);
    final list = extractList(map['items']);
    return list
        .whereType<Map>()
        .map(
          (item) => AdminCourier.fromJson(
            item.map((key, value) => MapEntry(key.toString(), value)),
          ),
        )
        .toList(growable: false);
  }

  Future<AdminCouriersReportResponse> getCouriersReport({
    DateTime? date,
    int? courierId,
    DateTime? from,
    DateTime? to,
    bool includeDetails = true,
    int detailsLimit = 50,
  }) async {
    final response = await _client.get(
      Endpoints.adminCouriersReport(),
      queryParameters: {
        if (date != null)
          'date':
              '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}',
        if (from != null)
          'from':
              '${from.year.toString().padLeft(4, '0')}-${from.month.toString().padLeft(2, '0')}-${from.day.toString().padLeft(2, '0')} 00:00:00',
        if (to != null)
          'to':
              '${to.year.toString().padLeft(4, '0')}-${to.month.toString().padLeft(2, '0')}-${to.day.toString().padLeft(2, '0')} 23:59:59',
        if ((courierId ?? 0) > 0) 'courier_id': courierId,
        'include_details': includeDetails ? 1 : 0,
        'details_limit': detailsLimit.clamp(1, 200),
      },
      options: Options(extra: const {'requiresAuth': true}),
    );

    final map = extractMap(response.data);
    return AdminCouriersReportResponse.fromJson(map);
  }

  Future<AdminCourierLocation> getCourierLocation(int courierId) async {
    final response = await _client.get(
      Endpoints.adminCourierLocation(courierId),
      options: Options(extra: const {'requiresAuth': true}),
    );
    final map = extractMap(response.data);
    return AdminCourierLocation.fromJson(map);
  }

  Future<Map<String, dynamic>> settleCourierAccount(int courierId) async {
    final response = await _client.patch(
      Endpoints.adminCourierSettle(courierId),
      options: Options(extra: const {'requiresAuth': true}),
    );
    return extractMap(response.data);
  }

  Future<AdminOrderCourierAssignment> getOrderCourierAssignment(int id) async {
    final response = await _client.get(
      Endpoints.adminOrderAssignCourier(id),
      options: Options(extra: const {'requiresAuth': true}),
    );

    final map = extractMap(response.data);
    final assignmentRaw = map['assignment'];
    final assignmentMap = assignmentRaw is Map<String, dynamic>
        ? assignmentRaw
        : assignmentRaw is Map
        ? assignmentRaw.map((key, value) => MapEntry(key.toString(), value))
        : <String, dynamic>{};

    return AdminOrderCourierAssignment.fromJson(assignmentMap);
  }

  Future<AdminOrder> assignOrderCourier({
    required int orderId,
    int? courierId,
    bool unassign = false,
  }) async {
    await _client.patch(
      Endpoints.adminOrderAssignCourier(orderId),
      data: {
        if (courierId != null && courierId > 0) 'courier_id': courierId,
        if (unassign || (courierId ?? 0) <= 0) 'unassign': true,
      },
      options: Options(extra: const {'requiresAuth': true}),
    );

    return getOrder(orderId);
  }

  /// Get pending ShamCash orders awaiting verification
  Future<ShamCashOrdersResponse> getPendingShamCashOrders({
    int page = 1,
    int perPage = 20,
  }) async {
    final response = await _client.get(
      Endpoints.adminShamCashPending(),
      queryParameters: {'page': page, 'per_page': perPage},
    );

    final map = extractMap(response.data);
    return ShamCashOrdersResponse.fromJson(
      _normalizeShamCashResponse(map, page, perPage),
    );
  }

  /// Approve ShamCash payment
  Future<ShamCashVerificationResult> approveShamCash(
    int orderId, {
    String? noteAr,
  }) async {
    final response = await _client.patch(
      Endpoints.adminShamCashOrder(orderId),
      data: {
        'action': 'approve',
        'note_ar': (noteAr ?? 'تم التحقق من الإيصال').trim(),
      },
      options: Options(extra: const {'requiresAuth': true}),
    );

    final map = extractMap(response.data);
    return ShamCashVerificationResult.fromJson(map);
  }

  /// Reject ShamCash payment
  Future<ShamCashVerificationResult> rejectShamCash(
    int orderId, {
    required String noteAr,
  }) async {
    final response = await _client.patch(
      Endpoints.adminShamCashOrder(orderId),
      data: {'action': 'reject', 'note_ar': noteAr},
      options: Options(extra: const {'requiresAuth': true}),
    );

    final map = extractMap(response.data);
    return ShamCashVerificationResult.fromJson(map);
  }

  Map<String, dynamic> _normalizeShamCashResponse(
    Map<String, dynamic> raw,
    int defaultPage,
    int defaultPerPage,
  ) {
    final ordersRaw = raw['orders'];
    final orders = <Map<String, dynamic>>[];

    if (ordersRaw is List) {
      for (final item in ordersRaw) {
        if (item is Map<String, dynamic>) {
          orders.add(_normalizeShamCashOrder(item));
        } else if (item is Map) {
          orders.add(
            _normalizeShamCashOrder(
              item.map((key, value) => MapEntry(key.toString(), value)),
            ),
          );
        }
      }
    }

    return {
      'orders': orders,
      'total': parseInt(raw['total']),
      'page': parseInt(raw['page']) > 0 ? parseInt(raw['page']) : defaultPage,
      'per_page': parseInt(raw['per_page']) > 0
          ? parseInt(raw['per_page'])
          : defaultPerPage,
      'total_pages': parseInt(raw['total_pages']) > 0
          ? parseInt(raw['total_pages'])
          : 1,
    };
  }

  Map<String, dynamic> _normalizeShamCashOrder(Map<String, dynamic> raw) {
    final proofRaw = raw['proof'];
    Map<String, dynamic>? proof;
    if (proofRaw is Map<String, dynamic>) {
      proof = {
        'has_proof': proofRaw['has_proof'] == true,
        'image_url': (proofRaw['image_url'] ?? '').toString(),
        'uploaded_at': (proofRaw['uploaded_at'] ?? '').toString(),
        'note': TextNormalizer.normalize(proofRaw['note']),
      };
    } else if (proofRaw is Map) {
      proof = {
        'has_proof': proofRaw['has_proof'] == true,
        'image_url': (proofRaw['image_url'] ?? '').toString(),
        'uploaded_at': (proofRaw['uploaded_at'] ?? '').toString(),
        'note': TextNormalizer.normalize(proofRaw['note']),
      };
    }

    return {
      'id': parseInt(raw['id']),
      'order_number': TextNormalizer.normalize(raw['order_number']),
      'status': TextNormalizer.normalize(raw['status']),
      'status_label_ar': TextNormalizer.normalize(raw['status_label_ar']),
      'total': parseDouble(raw['total']),
      'currency': (raw['currency'] ?? 'SYP').toString(),
      'customer_name': TextNormalizer.normalize(raw['customer_name']),
      'customer_phone': TextNormalizer.normalize(raw['customer_phone']),
      'date_created': (raw['date_created'] ?? '').toString(),
      'proof': proof,
    };
  }

  Map<String, dynamic> _normalizeOrdersResponse(
    Map<String, dynamic> raw,
    int defaultPage,
    int defaultPerPage,
  ) {
    final itemsRaw = raw['items'];
    final items = <Map<String, dynamic>>[];

    if (itemsRaw is List) {
      for (final item in itemsRaw) {
        if (item is Map<String, dynamic>) {
          items.add(_normalizeOrder(item));
        } else if (item is Map) {
          items.add(
            _normalizeOrder(
              item.map((key, value) => MapEntry(key.toString(), value)),
            ),
          );
        }
      }
    }

    return {
      'items': items,
      'page': parseInt(raw['page']) > 0 ? parseInt(raw['page']) : defaultPage,
      'per_page': parseInt(raw['per_page']) > 0
          ? parseInt(raw['per_page'])
          : defaultPerPage,
      'total': parseInt(raw['total']),
      'total_pages': parseInt(raw['total_pages']) > 0
          ? parseInt(raw['total_pages'])
          : 1,
    };
  }

  Map<String, dynamic> _normalizeOrder(Map<String, dynamic> raw) {
    final billingRaw = raw['billing'];
    final billing = billingRaw is Map<String, dynamic>
        ? billingRaw
        : billingRaw is Map
        ? billingRaw.map((key, value) => MapEntry(key.toString(), value))
        : <String, dynamic>{};

    final itemsRaw = raw['items'];
    final items = <Map<String, dynamic>>[];
    if (itemsRaw is List) {
      for (final item in itemsRaw) {
        if (item is Map<String, dynamic>) {
          items.add(_normalizeOrderItem(item));
        } else if (item is Map) {
          items.add(
            _normalizeOrderItem(
              item.map((key, value) => MapEntry(key.toString(), value)),
            ),
          );
        }
      }
    }

    final proofRaw = raw['payment_proof'];
    final paymentProof = proofRaw is Map<String, dynamic>
        ? {
            'image_url': (proofRaw['image_url'] ?? '').toString(),
            'attachment_id': parseInt(proofRaw['attachment_id']),
            'uploaded_at': (proofRaw['uploaded_at'] ?? '').toString(),
          }
        : proofRaw is Map
        ? {
            'image_url': (proofRaw['image_url'] ?? '').toString(),
            'attachment_id': parseInt(proofRaw['attachment_id']),
            'uploaded_at': (proofRaw['uploaded_at'] ?? '').toString(),
          }
        : null;

    final deliveryRaw = raw['delivery_location'];
    final deliveryLocation = deliveryRaw is Map<String, dynamic>
        ? {
            'lat': parseDoubleNullable(deliveryRaw['lat']),
            'lng': parseDoubleNullable(deliveryRaw['lng']),
            'accuracy_meters': parseDoubleNullable(
              deliveryRaw['accuracy_meters'],
            ),
            'full_address': TextNormalizer.normalize(
              deliveryRaw['full_address'],
            ),
            'city': TextNormalizer.normalize(deliveryRaw['city']),
            'area': TextNormalizer.normalize(deliveryRaw['area']),
            'street': TextNormalizer.normalize(deliveryRaw['street']),
            'building': TextNormalizer.normalize(deliveryRaw['building']),
            'notes': TextNormalizer.normalize(deliveryRaw['notes']),
            'captured_at': (deliveryRaw['captured_at'] ?? '').toString(),
            'maps_open_url': (deliveryRaw['maps_open_url'] ?? '').toString(),
            'maps_navigate_url': (deliveryRaw['maps_navigate_url'] ?? '')
                .toString(),
          }
        : deliveryRaw is Map
        ? {
            'lat': parseDoubleNullable(deliveryRaw['lat']),
            'lng': parseDoubleNullable(deliveryRaw['lng']),
            'accuracy_meters': parseDoubleNullable(
              deliveryRaw['accuracy_meters'],
            ),
            'full_address': TextNormalizer.normalize(
              deliveryRaw['full_address'],
            ),
            'city': TextNormalizer.normalize(deliveryRaw['city']),
            'area': TextNormalizer.normalize(deliveryRaw['area']),
            'street': TextNormalizer.normalize(deliveryRaw['street']),
            'building': TextNormalizer.normalize(deliveryRaw['building']),
            'notes': TextNormalizer.normalize(deliveryRaw['notes']),
            'captured_at': (deliveryRaw['captured_at'] ?? '').toString(),
            'maps_open_url': (deliveryRaw['maps_open_url'] ?? '').toString(),
            'maps_navigate_url': (deliveryRaw['maps_navigate_url'] ?? '')
                .toString(),
          }
        : null;

    return {
      'id': parseInt(raw['id']),
      'order_number': TextNormalizer.normalize(raw['order_number']),
      'status': TextNormalizer.normalize(raw['status']),
      'total': parseDouble(raw['total']),
      'subtotal': parseDouble(raw['subtotal']),
      'shipping_cost': parseDouble(
        raw['shipping_cost'] ?? raw['shipping_total'],
      ),
      'payment_method': (raw['payment_method'] ?? '').toString(),
      'date': (raw['date'] ?? raw['date_created'])?.toString(),
      'customer_note': TextNormalizer.normalize(raw['customer_note']),
      'billing': {
        'first_name': TextNormalizer.normalize(billing['first_name']),
        'last_name': TextNormalizer.normalize(billing['last_name']),
        'phone': TextNormalizer.normalize(billing['phone']),
        'email': TextNormalizer.normalize(billing['email']),
        'address_1': TextNormalizer.normalize(billing['address_1']),
        'city': TextNormalizer.normalize(billing['city']),
      },
      'items': items,
      'delivery_location': deliveryLocation,
      'payment_proof': paymentProof,
    };
  }

  Map<String, dynamic> _normalizeOrderItem(Map<String, dynamic> raw) {
    return {
      'product_id': parseInt(raw['product_id']),
      'name': TextNormalizer.normalize(raw['name']),
      'sku': TextNormalizer.normalize(raw['sku']),
      'qty': parseInt(raw['qty'] ?? raw['quantity']),
      'price': parseDouble(raw['price']),
      'subtotal': parseDouble(raw['subtotal']),
      'total': parseDouble(raw['total'] ?? raw['subtotal']),
      'image': (raw['image'] ?? '').toString(),
    };
  }
}
