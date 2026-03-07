import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../../core/utils/safe_parsers.dart';
import '../../../../core/utils/text_normalizer.dart';
import '../../../../core/utils/url_utils.dart';

part 'category_model.freezed.dart';

/// Category DTO - mirrors the Lexi API JSON shape.
@freezed
class CategoryModel with _$CategoryModel {
  const factory CategoryModel({
    required int id,
    required String name,

    /// Category image URL (optional).
    String? image,

    /// Number of products in this category.
    @Default(0) int count,

    /// Parent category term id (0 means main category).
    @Default(0) int parentId,

    /// Number of direct child categories if provided by API.
    @Default(0) int childrenCount,

    /// Custom sort order.
    @Default(0) int sortOrder,
  }) = _CategoryModel;

  factory CategoryModel.fromJson(Map<String, dynamic> json) {
    return CategoryModel(
      id: parseInt(json['id']),
      name: TextNormalizer.normalize(json['name']),
      image: _parseImage(json['image_url'] ?? json['image']),
      count: parseInt(json['count']),
      parentId: parseInt(
        json['parent'] ?? json['parent_id'] ?? json['parentId'],
      ),
      childrenCount: parseInt(
        json['children_count'] ?? json['childrenCount'] ?? json['child_count'],
      ),
      sortOrder: parseInt(json['sort_order']),
    );
  }
}

String? _parseImage(dynamic raw) {
  if (raw == null) return null;

  if (raw is String) {
    final value = raw.trim();
    if (value.isEmpty) return null;
    return _normalizeUrl(value);
  }

  if (raw is Map<String, dynamic>) {
    final value = (raw['src'] ?? raw['url'] ?? '').toString().trim();
    if (value.isEmpty) return null;
    return _normalizeUrl(value);
  }

  return null;
}

String _normalizeUrl(String url) {
  return normalizeHttpUrl(url);
}
