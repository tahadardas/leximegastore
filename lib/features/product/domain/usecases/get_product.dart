import '../entities/product_entity.dart';
import '../repositories/product_repository.dart';

class GetProduct {
  final ProductRepository _repository;

  GetProduct({required ProductRepository repository})
    : _repository = repository;

  Future<ProductEntity> call(String id, {bool preferCache = true}) {
    return _repository.getProductById(id, preferCache: preferCache);
  }
}
