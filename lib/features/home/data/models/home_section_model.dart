import '../../../product/domain/entities/product_entity.dart';

class HomeSectionModel {
  final int id;
  final String titleAr;
  final String type;
  final int sortOrder;
  final int? termId;
  final bool isActive;
  final List<ProductEntity> items;

  const HomeSectionModel({
    required this.id,
    required this.titleAr,
    required this.type,
    required this.sortOrder,
    required this.items,
    this.termId,
    this.isActive = true,
  });
}
