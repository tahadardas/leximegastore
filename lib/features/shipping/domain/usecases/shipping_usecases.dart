import '../entities/city.dart';
import '../repositories/shipping_repository.dart';

class GetCities {
  final ShippingRepository repository;

  GetCities(this.repository);

  Future<List<City>> call() => repository.getCities();
}

class GetShippingRate {
  final ShippingRepository repository;

  GetShippingRate(this.repository);

  Future<double> call(String cityId) => repository.getShippingRate(cityId);
}
