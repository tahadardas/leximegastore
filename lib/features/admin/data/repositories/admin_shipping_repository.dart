import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../datasources/admin_shipping_datasource.dart';
import '../../domain/entities/admin_shipping_city.dart';

final adminShippingRepositoryProvider = Provider<AdminShippingRepository>((
  ref,
) {
  return AdminShippingRepository(
    ref.read(adminShippingRemoteDatasourceProvider),
  );
});

class AdminShippingRepository {
  final AdminShippingRemoteDatasource _datasource;

  AdminShippingRepository(this._datasource);

  Future<List<AdminShippingCity>> getCities() {
    return _datasource.getCities();
  }

  Future<AdminShippingCity> createCity({
    required String name,
    required double price,
    bool isActive = true,
    int sortOrder = 0,
  }) {
    return _datasource.createCity({
      'name': name,
      'price': price,
      'is_active': isActive ? 1 : 0,
      'sort_order': sortOrder,
    });
  }

  Future<AdminShippingCity> updateCity(
    int id, {
    String? name,
    double? price,
    bool? isActive,
    int? sortOrder,
  }) {
    final data = <String, dynamic>{};
    if (name != null) data['name'] = name;
    if (price != null) data['price'] = price;
    if (isActive != null) data['is_active'] = isActive ? 1 : 0;
    if (sortOrder != null) data['sort_order'] = sortOrder;

    return _datasource.updateCity(id, data);
  }

  Future<void> deleteCity(int id) {
    return _datasource.deleteCity(id);
  }
}
