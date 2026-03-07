import '../entities/category_entity.dart';
import '../repositories/category_repository.dart';

/// Fetches all categories.
///
/// Usage:
/// ```dart
/// final categories = await getCategories();
/// ```
class GetCategories {
  final CategoryRepository _repository;

  GetCategories({required CategoryRepository repository})
    : _repository = repository;

  Future<List<CategoryEntity>> call({bool preferCache = true}) {
    return _repository.getCategories(preferCache: preferCache);
  }
}
