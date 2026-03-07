import '../../../../../core/utils/text_normalizer.dart';

class AdminHomeSection {
  final int id;
  final String titleAr;
  final String type;
  final int? termId;
  final String? termName;
  final int sortOrder;
  final bool isActive;
  final int itemsCount;

  const AdminHomeSection({
    required this.id,
    required this.titleAr,
    required this.type,
    required this.termId,
    required this.termName,
    required this.sortOrder,
    required this.isActive,
    required this.itemsCount,
  });

  factory AdminHomeSection.fromJson(Map<String, dynamic> json) {
    return AdminHomeSection(
      id: (json['id'] as num?)?.toInt() ?? 0,
      titleAr: TextNormalizer.normalize(json['title_ar']),
      type: (json['type'] ?? 'manual_products').toString(),
      termId: (json['term_id'] as num?)?.toInt(),
      termName: json['term_name'] == null
          ? null
          : TextNormalizer.normalize(json['term_name']),
      sortOrder: (json['sort_order'] as num?)?.toInt() ?? 0,
      isActive: json['is_active'] == true,
      itemsCount: (json['items_count'] as num?)?.toInt() ?? 0,
    );
  }

  AdminHomeSection copyWith({
    String? titleAr,
    String? type,
    int? termId,
    String? termName,
    int? sortOrder,
    bool? isActive,
    int? itemsCount,
  }) {
    return AdminHomeSection(
      id: id,
      titleAr: titleAr ?? this.titleAr,
      type: type ?? this.type,
      termId: termId ?? this.termId,
      termName: termName ?? this.termName,
      sortOrder: sortOrder ?? this.sortOrder,
      isActive: isActive ?? this.isActive,
      itemsCount: itemsCount ?? this.itemsCount,
    );
  }
}
