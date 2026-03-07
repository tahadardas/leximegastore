import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../core/utils/safe_parsers.dart';
import '../../../../config/constants/endpoints.dart';
import '../../domain/entities/admin_shipping_city.dart';

final adminShippingRemoteDatasourceProvider =
    Provider<AdminShippingRemoteDatasource>((ref) {
      return AdminShippingRemoteDatasource(ref.read(dioClientProvider));
    });

class AdminShippingRemoteDatasource {
  final DioClient _client;

  AdminShippingRemoteDatasource(this._client);

  Future<List<AdminShippingCity>> getCities() async {
    final response = await _client.get(Endpoints.adminShippingCities());
    final list = extractList(response.data);
    return list
        .whereType<Map>()
        .map(
          (e) => AdminShippingCity.fromJson(
            _normalizeCity(Map<String, dynamic>.from(e)),
          ),
        )
        .toList();
  }

  Future<AdminShippingCity> createCity(Map<String, dynamic> data) async {
    final response = await _client.post(
      Endpoints.adminShippingCities(),
      data: data,
    );
    return AdminShippingCity.fromJson(
      _normalizeCity(extractMap(response.data)),
    );
  }

  Future<AdminShippingCity> updateCity(
    int id,
    Map<String, dynamic> data,
  ) async {
    final response = await _client.patch(
      Endpoints.adminShippingCity(id),
      data: data,
    );
    return AdminShippingCity.fromJson(
      _normalizeCity(extractMap(response.data)),
    );
  }

  Future<void> deleteCity(int id) async {
    await _client.delete(Endpoints.adminShippingCity(id));
  }

  Map<String, dynamic> _normalizeCity(Map<String, dynamic> raw) {
    return {
      'id': parseInt(raw['id']),
      'name': (raw['name'] ?? '').toString(),
      'price': parseDouble(raw['price']),
      'is_active': parseBool(raw['is_active']),
      'sort_order': parseInt(raw['sort_order']),
    };
  }
}
