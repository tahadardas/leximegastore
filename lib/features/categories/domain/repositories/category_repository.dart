import '../entities/category_entity.dart';

/// Domain-layer contract for category data access.
///
/// Implemented by [CategoryRepositoryImpl] in the data layer.
abstract class CategoryRepository {
  /// Fetches all categories as domain entities.
  Future<List<CategoryEntity>> getCategories({bool preferCache = true});

  /// Fetches a single category by [id].
  Future<CategoryEntity> getCategoryById(String id, {bool preferCache = true});
}
