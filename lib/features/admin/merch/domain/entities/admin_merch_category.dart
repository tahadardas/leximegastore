import '../../../../../core/utils/text_normalizer.dart';

class AdminMerchCategory {
  final int id;
  final String name;
  final String slug;
  final int count;
  final String imageUrl;
  final int sortOrder;

  const AdminMerchCategory({
    required this.id,
    required this.name,
    required this.slug,
    required this.count,
    required this.imageUrl,
    required this.sortOrder,
  });

  factory AdminMerchCategory.fromJson(Map<String, dynamic> json) {
    return AdminMerchCategory(
      id: (json['id'] as num?)?.toInt() ?? 0,
      name: TextNormalizer.normalize(json['name']),
      slug: (json['slug'] ?? '').toString(),
      count: (json['count'] as num?)?.toInt() ?? 0,
      imageUrl: (json['image_url'] ?? json['image'] ?? '').toString(),
      sortOrder: (json['sort_order'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toOrderJson() => {'id': id, 'sort_order': sortOrder};

  AdminMerchCategory copyWith({int? sortOrder}) {
    return AdminMerchCategory(
      id: id,
      name: name,
      slug: slug,
      count: count,
      imageUrl: imageUrl,
      sortOrder: sortOrder ?? this.sortOrder,
    );
  }
}
