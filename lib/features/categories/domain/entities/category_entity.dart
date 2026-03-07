/// Domain entity for a category.
///
/// This is the clean, presentation-ready object used by the UI layer.
/// Created from [CategoryModel] via [CategoryModelMapper.toEntity].
class CategoryEntity {
  final int id;
  final String name;
  final String? image;
  final int count;
  final int parentId;
  final int childrenCount;
  final int sortOrder;

  const CategoryEntity({
    required this.id,
    required this.name,
    this.image,
    this.count = 0,
    this.parentId = 0,
    this.childrenCount = 0,
    this.sortOrder = 0,
  });

  /// Whether this category has a cover image.
  bool get hasImage => image != null && image!.isNotEmpty;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CategoryEntity &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() {
    return 'CategoryEntity(id: $id, name: $name, count: $count, parentId: $parentId)';
  }
}
