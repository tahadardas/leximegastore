import '../../../../core/utils/url_utils.dart';

/// Normalized image set for product media sizes.
///
/// The API may return one URL or multiple sizes. This model keeps a stable
/// shape so UI can pick small images for cards and large images for details.
class ProductImageSet {
  final String? thumb;
  final String? medium;
  final String? large;

  const ProductImageSet({this.thumb, this.medium, this.large});

  static const ProductImageSet empty = ProductImageSet();

  bool get isEmpty =>
      (thumb ?? '').trim().isEmpty &&
      (medium ?? '').trim().isEmpty &&
      (large ?? '').trim().isEmpty;

  bool get isNotEmpty => !isEmpty;

  /// Best image for small cards/lists.
  String? get cardUrl => _firstNonEmpty([thumb, medium, large]);

  /// Best image for detail/gallery views.
  String? get detailUrl => _firstNonEmpty([large, medium, thumb]);

  ProductImageSet withFallback(String? fallbackUrl) {
    final fallback = normalizeNullableHttpUrl(fallbackUrl);
    if ((fallback ?? '').isEmpty) {
      return this;
    }

    return ProductImageSet(
      thumb: thumb ?? fallback,
      medium: medium ?? fallback,
      large: large ?? fallback,
    );
  }

  static ProductImageSet fromDynamic(dynamic raw, {String? fallbackUrl}) {
    String? thumb;
    String? medium;
    String? large;

    if (raw is String) {
      final url = normalizeNullableHttpUrl(raw);
      thumb = url;
      medium = url;
      large = url;
    } else if (raw is Map) {
      final map = Map<String, dynamic>.from(raw);
      thumb = _normalizeAny(
        map['thumb'] ?? map['thumbnail'] ?? map['small'] ?? map['size_thumb'],
      );
      medium = _normalizeAny(map['medium'] ?? map['size_medium']);
      large = _normalizeAny(
        map['large'] ??
            map['full'] ??
            map['src'] ??
            map['url'] ??
            map['original'] ??
            map['size_large'],
      );

      thumb ??= medium ?? large;
      medium ??= thumb ?? large;
      large ??= medium ?? thumb;
    }

    final parsed = ProductImageSet(thumb: thumb, medium: medium, large: large);
    return parsed.withFallback(fallbackUrl);
  }

  String? _firstNonEmpty(List<String?> values) {
    for (final value in values) {
      final normalized = normalizeNullableHttpUrl(value);
      if ((normalized ?? '').isNotEmpty) {
        return normalized;
      }
    }
    return null;
  }

  static String? _normalizeAny(dynamic value) {
    if (value == null) {
      return null;
    }
    return normalizeNullableHttpUrl(value.toString());
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ProductImageSet &&
          runtimeType == other.runtimeType &&
          thumb == other.thumb &&
          medium == other.medium &&
          large == other.large;

  @override
  int get hashCode => Object.hash(thumb, medium, large);

  @override
  String toString() =>
      'ProductImageSet(thumb: $thumb, medium: $medium, large: $large)';
}
