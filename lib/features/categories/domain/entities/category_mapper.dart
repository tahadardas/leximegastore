import '../../data/models/category_model.dart';
import '../entities/category_entity.dart';

/// Extension to convert [CategoryModel] (DTO) ??" [CategoryEntity] (domain).
extension CategoryModelMapper on CategoryModel {
  /// Converts a DTO to a domain entity.
  CategoryEntity toEntity() {
    return CategoryEntity(
      id: id,
      name: name,
      image: image,
      count: count,
      parentId: parentId,
      childrenCount: childrenCount,
      sortOrder: sortOrder,
    );
  }
}

/// Extension to convert [CategoryEntity] back to [CategoryModel].
extension CategoryEntityMapper on CategoryEntity {
  /// Converts a domain entity to a DTO (for sending to API).
  CategoryModel toModel() {
    return CategoryModel(
      id: id,
      name: name,
      image: image,
      count: count,
      parentId: parentId,
      childrenCount: childrenCount,
      sortOrder: sortOrder,
    );
  }
}
