import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../config/constants/endpoints.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../core/utils/safe_parsers.dart';
import '../models/city_model.dart';

final shippingRemoteDatasourceProvider = Provider<ShippingRemoteDatasource>((
  ref,
) {
  final dio = ref.watch(dioClientProvider);
  return ShippingRemoteDatasourceImpl(dioClient: dio);
});

abstract class ShippingRemoteDatasource {
  Future<List<CityModel>> getCities();
  Future<double> getShippingRate(String cityId);
}

class ShippingRemoteDatasourceImpl implements ShippingRemoteDatasource {
  final DioClient _dioClient;

  ShippingRemoteDatasourceImpl({required DioClient dioClient})
    : _dioClient = dioClient;

  @override
  Future<List<CityModel>> getCities() async {
    final response = await _dioClient.get(
      Endpoints.shippingCities(),
      options: Options(extra: const {'requiresAuth': false}),
    );

    final list = extractList(response.data);
    return list
        .whereType<Map>()
        .map(
          (e) => CityModel.fromJson(
            e.map((key, value) => MapEntry(key.toString(), value)),
          ),
        )
        .toList();
  }

  @override
  Future<double> getShippingRate(String cityId) async {
    final response = await _dioClient.get(
      Endpoints.shippingRate(),
      queryParameters: {'city_id': cityId},
      options: Options(extra: const {'requiresAuth': false}),
    );

    final map = extractMap(response.data);
    return parseDouble(map['rate'] ?? map['price'] ?? map['shipping_rate']);
  }
}
