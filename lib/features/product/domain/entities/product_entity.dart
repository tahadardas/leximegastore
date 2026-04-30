import '../../../../core/utils/url_utils.dart';
import 'product_image_set.dart';

/// Domain entity for a product.
///
/// This is the clean, presentation-ready object used by the UI layer.
/// Created from [ProductModel] via [ProductModelMapper.toEntity].
class ProductEntity {
  final int id;
  final String name;
  final double price;
  final double regularPrice;
  final double? salePrice;
  final ProductImageSet? _image;
  final List<String>? _images;
  final List<String>? _cardImages;
  final double rating;
  final int reviewsCount;
  final bool inStock;
  final String description;
  final String shortDescription;
  final int wishlistCount;
  final int? brandId;
  final String brandName;
  final List<int>? _categoryIds;
  final String type;
  final DateTime? createdAt;
  final int salesCount;
  final int viewsCount;

  const ProductEntity({
    required this.id,
    required this.name,
    required this.price,
    required this.regularPrice,
    this.salePrice,
    ProductImageSet? image,
    List<String>? images,
    List<String>? cardImages,
    this.rating = 0.0,
    this.reviewsCount = 0,
    this.inStock = true,
    this.description = '',
    this.shortDescription = '',
    this.wishlistCount = 0,
    this.brandId,
    this.brandName = '',
    List<int>? categoryIds,
    this.type = 'simple',
    this.createdAt,
    this.salesCount = 0,
    this.viewsCount = 0,
    this.saleEndDate,
  }) : _image = image,
       _images = images,
       _categoryIds = categoryIds,
       _cardImages = cardImages;

  ProductImageSet get image => _image ?? ProductImageSet.empty;

  List<String> get images => _images ?? const <String>[];

  List<String> get cardImages => _cardImages ?? const <String>[];

  List<int> get categoryIds => _categoryIds ?? const <int>[];

  /// The end date of the sale, if any.
  final DateTime? saleEndDate;

  /// Whether this product is a variable product (has versions/colors).
  bool get isVariable => type == 'variable' || type == 'variation';

  /// Whether this product currently has a discount.
  bool get isOnSale => salePrice != null && salePrice! < regularPrice;

  /// Alias for isOnSale for clearer naming.
  bool get hasDiscount => isOnSale;

  /// Discount percentage (0 if not on sale).
  int get discountPercentage {
    if (!isOnSale) return 0;
    return (((regularPrice - salePrice!) / regularPrice) * 100).floor();
  }

  /// The price that should be charged (sale price when available, else price).
  double get effectivePrice => isOnSale ? salePrice! : price;

  /// The savings amount (0 if not on sale).
  double get savingsAmount {
    if (!isOnSale) return 0;
    return regularPrice - salePrice!;
  }

  /// The first image URL, or empty string if none.
  String get primaryImage {
    final detail = image.detailUrl;
    if ((detail ?? '').isNotEmpty) {
      return detail!;
    }
    if (images.isNotEmpty) {
      return images.first;
    }
    if (cardImages.isNotEmpty) {
      return cardImages.first;
    }
    return '';
  }

  /// The first valid HTTPS image URL, or null if none available.
  String? get primaryImageUrl {
    final detail = normalizeNullableHttpUrl(image.detailUrl);
    if ((detail ?? '').isNotEmpty && detail!.startsWith('https://')) {
      return detail;
    }

    for (final url in images) {
      final normalized = normalizeNullableHttpUrl(url);
      if (normalized != null && normalized.startsWith('https://')) {
        return normalized;
      }
    }

    for (final url in cardImages) {
      final normalized = normalizeNullableHttpUrl(url);
      if (normalized != null && normalized.startsWith('https://')) {
        return normalized;
      }
    }

    return normalizeNullableHttpUrl(
      images.isNotEmpty
          ? images.first
          : (cardImages.isNotEmpty ? cardImages.first : null),
    );
  }

  /// Card-friendly gallery URLs (small/medium), with fallback to full images.
  List<String> get effectiveCardImages {
    return _collectUniqueUrls(<String>[
      ...cardImages,
      image.cardUrl ?? primaryImage,
      ...images,
    ]);
  }

  List<String> _collectUniqueUrls(Iterable<String> values) {
    final output = <String>[];
    final seen = <String>{};
    for (final value in values) {
      final normalized = normalizeNullableHttpUrl(value);
      if (normalized == null || !seen.add(normalized)) {
        continue;
      }
      output.add(normalized);
    }
    return output;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ProductEntity &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'ProductEntity(id: $id, name: $name, price: $price)';
}
