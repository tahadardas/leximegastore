import '../entities/city.dart';

abstract class ShippingRepository {
  Future<List<City>> getCities();
  Future<double> getShippingRate(String cityId);
}
