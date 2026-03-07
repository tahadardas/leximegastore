import '../../../../core/utils/safe_parsers.dart';
import '../../../../core/utils/url_utils.dart';

class ProductVariationOption {
  final int id;
  final String label;
  final String color;
  final double price;
  final double regularPrice;
  final double? salePrice;
  final bool inStock;
  final String? imageUrl;

  const ProductVariationOption({
    required this.id,
    required this.label,
    required this.color,
    required this.price,
    required this.regularPrice,
    this.salePrice,
    required this.inStock,
    this.imageUrl,
  });

  factory ProductVariationOption.fromJson(Map<String, dynamic> json) {
    final rawPrice = parseDouble(json['price']);
    final rawRegular = parseDouble(json['regular_price']);
    final rawSale = _nullableDouble(json['sale_price']);

    final salePrice = (rawSale != null && rawSale > 0) ? rawSale : null;
    var regularPrice = rawRegular > 0 ? rawRegular : 0.0;
    var price = rawPrice > 0 ? rawPrice : 0.0;
    if (price <= 0 && salePrice != null) {
      price = salePrice;
    }
    if (price <= 0 && regularPrice > 0) {
      price = regularPrice;
    }
    if (regularPrice <= 0 && price > 0) {
      regularPrice = price;
    }

    return ProductVariationOption(
      id: parseInt(json['id']),
      label: (json['label'] ?? json['name'] ?? '').toString().trim(),
      color: (json['color'] ?? json['color_label'] ?? '').toString().trim(),
      price: price,
      regularPrice: regularPrice,
      salePrice: salePrice,
      inStock: parseBool(json['in_stock']),
      imageUrl: normalizeNullableHttpUrl(
        (json['image_url'] ?? json['image'] ?? '').toString().trim(),
      ),
    );
  }
}

class ProductReviewItem {
  final int id;
  final String author;
  final String content;
  final int rating;
  final String createdAt;

  const ProductReviewItem({
    required this.id,
    required this.author,
    required this.content,
    required this.rating,
    required this.createdAt,
  });

  factory ProductReviewItem.fromJson(Map<String, dynamic> json) {
    return ProductReviewItem(
      id: parseInt(json['id']),
      author: (json['author'] ?? json['reviewer'] ?? 'عميل').toString().trim(),
      content: (json['content'] ?? json['comment'] ?? '').toString().trim(),
      rating: parseInt(json['rating']),
      createdAt: (json['created_at'] ?? json['date_created'] ?? '')
          .toString()
          .trim(),
    );
  }
}

class ProductDetailsExtras {
  final List<ProductVariationOption> variations;
  final List<ProductReviewItem> reviews;

  const ProductDetailsExtras({
    this.variations = const [],
    this.reviews = const [],
  });
}

double? _nullableDouble(dynamic raw) {
  if (raw == null) {
    return null;
  }
  final value = raw.toString().trim();
  if (value.isEmpty) {
    return null;
  }
  final parsed = parseDouble(raw);
  return parsed > 0 ? parsed : null;
}
