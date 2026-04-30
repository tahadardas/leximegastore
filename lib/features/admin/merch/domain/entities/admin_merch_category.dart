import '../../../../../core/utils/text_normalizer.dart';

class AdminMerchCategory {
  final int id;
  final String name;
  final String displayName;
  final String slug;
  final int count;
  final String imageUrl;
  final int sortOrder;
  final int parentId;
  final int depth;

  const AdminMerchCategory({
    required this.id,
    required this.name,
    required this.displayName,
    required this.slug,
    required this.count,
    required this.imageUrl,
    required this.sortOrder,
    required this.parentId,
    required this.depth,
  });

  factory AdminMerchCategory.fromJson(Map<String, dynamic> json) {
    final name = TextNormalizer.normalize(json['name']);
    final displayName = TextNormalizer.normalize(
      json['display_name'] ?? json['displayName'] ?? json['name'],
    );
    return AdminMerchCategory(
      id: (json['id'] as num?)?.toInt() ?? 0,
      name: name,
      displayName: displayName,
      slug: (json['slug'] ?? '').toString(),
      count: (json['count'] as num?)?.toInt() ?? 0,
      imageUrl: (json['image_url'] ?? json['image'] ?? '').toString(),
      sortOrder: (json['sort_order'] as num?)?.toInt() ?? 0,
      parentId:
          (json['parent_id'] as num?)?.toInt() ??
          (json['parent'] as num?)?.toInt() ??
          0,
      depth: (json['depth'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toOrderJson() => {'id': id, 'sort_order': sortOrder};

  String get hierarchyLabel {
    if (displayName.trim().isNotEmpty) {
      return displayName;
    }
    if (depth <= 0) {
      return name;
    }
    return '${List.filled(depth, '--').join(' ')} $name';
  }

  AdminMerchCategory copyWith({int? sortOrder}) {
    return AdminMerchCategory(
      id: id,
      name: name,
      displayName: displayName,
      slug: slug,
      count: count,
      imageUrl: imageUrl,
      sortOrder: sortOrder ?? this.sortOrder,
      parentId: parentId,
      depth: depth,
    );
  }
}
