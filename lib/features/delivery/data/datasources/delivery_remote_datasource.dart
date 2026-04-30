import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../config/constants/endpoints.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../core/utils/safe_parsers.dart';
import '../../domain/entities/delivery_entities.dart';

final deliveryRemoteDatasourceProvider = Provider<DeliveryRemoteDatasource>((
  ref,
) {
  return DeliveryRemoteDatasource(ref.read(dioClientProvider));
});

class DeliveryRemoteDatasource {
  final DioClient _client;
  int? _lastCourierId;

  DeliveryRemoteDatasource(this._client);

  Future<DeliveryAgentProfile> getMe() async {
    try {
      final response = await _client.get(
        Endpoints.deliveryMe(),
        options: Options(extra: const {'requiresAuth': true}),
      );
      final map = extractMap(response.data);
      final profile = DeliveryAgentProfile.fromJson(map);
      if (profile.id > 0) {
        _lastCourierId = profile.id;
      }
      return profile;
    } on DioException catch (error) {
      if (!_isLikelyMissingDeliveryRoute(error)) {
        rethrow;
      }
      return _getMeViaWordPressFallback();
    }
  }

  Future<bool> setAvailability(bool isAvailable) async {
    final response = await _client.patch(
      Endpoints.deliveryAvailability(),
      data: {'is_available': isAvailable},
      options: Options(extra: const {'requiresAuth': true}),
    );
    final map = extractMap(response.data);
    return parseBool(map['is_available']);
  }

  Future<Map<String, dynamic>> getOrders({
    String status = '',
    int page = 1,
    int perPage = 20,
  }) async {
    try {
      final response = await _client.get(
        Endpoints.deliveryOrders(),
        queryParameters: {
          if (status.trim().isNotEmpty) 'status': status.trim(),
          'page': page,
          'per_page': perPage,
        },
        options: Options(extra: const {'requiresAuth': true}),
      );
      return extractMap(response.data);
    } on DioException catch (error) {
      if (!_isLikelyMissingDeliveryRoute(error)) {
        rethrow;
      }
      return _getOrdersViaWooFallback(
        status: status,
        page: page,
        perPage: perPage,
      );
    }
  }

  Future<void> updateOrderStatus(
    int orderId, {
    required String status,
    String note = '',
  }) async {
    await _client.patch(
      Endpoints.deliveryOrderStatus(orderId),
      data: {'status': status, if (note.trim().isNotEmpty) 'note': note.trim()},
      options: Options(extra: const {'requiresAuth': true}),
    );
  }

  Future<Map<String, dynamic>> collectCod(
    int orderId, {
    required String collectedAmount,
    String currency = 'SYP',
    String note = '',
  }) async {
    final response = await _client.post(
      Endpoints.deliveryOrderCollectCod(orderId),
      data: {
        'collected_amount': collectedAmount,
        'currency': currency,
        if (note.trim().isNotEmpty) 'note': note.trim(),
      },
      options: Options(extra: const {'requiresAuth': true}),
    );
    return extractMap(response.data);
  }

  Future<Map<String, dynamic>> acceptAssignment(int orderId) async {
    final response = await _client.post(
      Endpoints.courierAssignmentAccept(orderId),
      options: Options(extra: const {'requiresAuth': true}),
    );
    return extractMap(response.data);
  }

  Future<Map<String, dynamic>> declineAssignment(int orderId) async {
    final response = await _client.post(
      Endpoints.courierAssignmentDecline(orderId),
      options: Options(extra: const {'requiresAuth': true}),
    );
    return extractMap(response.data);
  }

  Future<Map<String, dynamic>> cancelAssignment(int orderId) async {
    final response = await _client.post(
      Endpoints.courierAssignmentCancel(orderId),
      options: Options(extra: const {'requiresAuth': true}),
    );
    return extractMap(response.data);
  }

  Future<void> pingLocation({
    required double lat,
    required double lng,
    double? accuracy,
    double? heading,
    double? speed,
    String? deviceId,
  }) async {
    final data = <String, dynamic>{
      'lat': lat,
      'lng': lng,
      'accuracy': accuracy,
      'heading': heading,
      'speed': speed,
      if ((deviceId ?? '').trim().isNotEmpty) 'device_id': deviceId!.trim(),
    }..removeWhere((key, value) => value == null);

    await _client.post(
      Endpoints.courierLocationPing(),
      data: data,
      options: Options(extra: const {'requiresAuth': true}),
    );
  }

  Future<DeliveryAgentProfile> _getMeViaWordPressFallback() async {
    final response = await _client.get(
      '/wp-json/wp/v2/users/me',
      queryParameters: const {'context': 'edit'},
      options: Options(extra: const {'requiresAuth': true}),
    );
    final map = extractMap(response.data);
    final hasIsAvailableField = map.containsKey('is_available');
    final profile = DeliveryAgentProfile(
      id: parseInt(map['id']),
      displayName: (map['display_name'] ?? map['name'] ?? '').toString(),
      email: (map['email'] ?? '').toString(),
      isAvailable: hasIsAvailableField ? parseBool(map['is_available']) : true,
    );
    if (profile.id > 0) {
      _lastCourierId = profile.id;
    }
    return profile;
  }

  Future<Map<String, dynamic>> _getOrdersViaWooFallback({
    required String status,
    required int page,
    required int perPage,
  }) async {
    final response = await _client.get(
      '/wp-json/wc/v3/orders',
      queryParameters: {
        if (status.trim().isNotEmpty) 'status': status.trim(),
        'orderby': 'date',
        'order': 'desc',
        'page': page,
        'per_page': perPage.clamp(1, 50),
      },
      options: Options(extra: const {'requiresAuth': true}),
    );

    final rawList = extractList(response.data)
        .whereType<Map>()
        .map((row) => row.map((key, value) => MapEntry('$key', value)))
        .toList(growable: false);
    final courierId = _lastCourierId ?? 0;
    final items = rawList
        .where((order) => _isAssignedToCourier(order, courierId))
        .map(_mapWooOrderToDeliveryShape)
        .toList(growable: false);

    final totalHeader = response.headers.value('x-wp-total');
    final totalPagesHeader = response.headers.value('x-wp-totalpages');
    final total = parseInt(totalHeader);
    final totalPages = parseInt(totalPagesHeader);

    return <String, dynamic>{
      'items': items,
      'page': page,
      'total': total > 0 ? total : items.length,
      'total_pages': totalPages > 0 ? totalPages : 1,
      'total_collected_today': 0,
      'is_available': true,
      'source': 'woo_fallback',
    };
  }

  bool _isAssignedToCourier(Map<String, dynamic> order, int courierId) {
    if (courierId <= 0) {
      return false;
    }

    final meta = extractList(order['meta_data']);
    for (final row in meta) {
      if (row is! Map) {
        continue;
      }
      final key = (row['key'] ?? '').toString().trim();
      if (key != '_lexi_delivery_agent_id') {
        continue;
      }
      final value = parseInt(row['value']);
      if (value == courierId) {
        return true;
      }
    }
    return false;
  }

  Map<String, dynamic> _mapWooOrderToDeliveryShape(Map<String, dynamic> order) {
    final billing = extractMap(order['billing']);
    final shipping = extractMap(order['shipping']);
    final meta = extractList(order['meta_data']);
    final orderNumber =
        (order['number'] ?? order['order_number'] ?? order['id']).toString();
    final status = (order['status'] ?? '').toString();
    final total = (order['total'] ?? '').toString();
    final date = (order['date_created'] ?? order['date_created_gmt'] ?? '')
        .toString();
    final paymentMethod = (order['payment_method'] ?? '').toString();
    final currency = (order['currency'] ?? 'SYP').toString();
    final deliveryState =
        _metaValue(meta, '_lexi_delivery_state').trim().isNotEmpty
        ? _metaValue(meta, '_lexi_delivery_state')
        : (status == 'completed' ? 'completed' : 'processing');

    final addressParts = <String>[
      (shipping['city'] ?? billing['city'] ?? '').toString().trim(),
      (shipping['address_1'] ?? billing['address_1'] ?? '').toString().trim(),
      (shipping['address_2'] ?? billing['address_2'] ?? '').toString().trim(),
    ]..removeWhere((entry) => entry.isEmpty);
    final fullAddress = addressParts.join(', ');

    return <String, dynamic>{
      ...order,
      'order_number': orderNumber,
      'status': status,
      'total': total,
      'date': date,
      'date_created': date,
      'billing': <String, dynamic>{
        ...billing,
        'first_name': (billing['first_name'] ?? '').toString(),
        'last_name': (billing['last_name'] ?? '').toString(),
        'phone': (billing['phone'] ?? '').toString(),
        'city': (billing['city'] ?? '').toString(),
        'address_1': (billing['address_1'] ?? '').toString(),
      },
      'delivery_assignment': <String, dynamic>{'delivery_state': deliveryState},
      'delivery_location': <String, dynamic>{
        'full_address': fullAddress,
        'city': (shipping['city'] ?? billing['city'] ?? '').toString(),
        'street': (shipping['address_1'] ?? billing['address_1'] ?? '')
            .toString(),
        'building': (shipping['address_2'] ?? billing['address_2'] ?? '')
            .toString(),
      },
      'cod': <String, dynamic>{
        'is_cod': paymentMethod.toLowerCase() == 'cod',
        'expected_amount': total,
        'currency': currency,
        'collected_status':
            _metaValue(meta, '_lexi_cod_collected_status').isNotEmpty
            ? _metaValue(meta, '_lexi_cod_collected_status')
            : 'pending',
        'collected_amount': _metaValue(meta, '_lexi_cod_collected_amount'),
        'locked': parseBool(
          _metaValue(meta, '_lexi_courier_assignment_accept_lock'),
        ),
      },
    };
  }

  String _metaValue(List<dynamic> metaRows, String key) {
    for (final row in metaRows) {
      if (row is! Map) {
        continue;
      }
      final rowKey = (row['key'] ?? '').toString().trim();
      if (rowKey != key) {
        continue;
      }
      return (row['value'] ?? '').toString();
    }
    return '';
  }

  bool _isLikelyMissingDeliveryRoute(DioException error) {
    final status = error.response?.statusCode ?? 0;
    if (status != 404 && status != 405) {
      return false;
    }
    return _looksLikeNoRouteBody(error.response?.data);
  }

  bool _looksLikeNoRouteBody(dynamic body) {
    final lower = (body ?? '').toString().toLowerCase();
    if (lower.trim().isEmpty) {
      return false;
    }
    return lower.contains('rest_no_route') ||
        lower.contains(
          'no route was found matching the url and request method',
        ) ||
        lower.contains('لم يتم العثور على مسار يتوافق مع الرابط');
  }
}
