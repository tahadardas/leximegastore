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

  DeliveryRemoteDatasource(this._client);

  Future<DeliveryAgentProfile> getMe() async {
    final response = await _client.get(
      Endpoints.deliveryMe(),
      options: Options(extra: const {'requiresAuth': true}),
    );
    final map = extractMap(response.data);
    return DeliveryAgentProfile.fromJson(map);
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
}
