import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/city.dart';
import '../../domain/repositories/shipping_repository.dart';
import '../datasources/shipping_remote_datasource.dart';

final shippingRepositoryProvider = Provider<ShippingRepository>((ref) {
  final datasource = ref.watch(shippingRemoteDatasourceProvider);
  return ShippingRepositoryImpl(datasource: datasource);
});

class ShippingRepositoryImpl implements ShippingRepository {
  final ShippingRemoteDatasource _datasource;

  ShippingRepositoryImpl({required ShippingRemoteDatasource datasource})
    : _datasource = datasource;

  @override
  Future<List<City>> getCities() async {
    final models = await _datasource.getCities();
    return models.map((e) => e.toEntity()).toList();
  }

  @override
  Future<double> getShippingRate(String cityId) =>
      _datasource.getShippingRate(cityId);
}
