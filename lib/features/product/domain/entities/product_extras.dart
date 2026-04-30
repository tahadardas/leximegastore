import '../../../../core/utils/safe_parsers.dart';
import '../../../../core/utils/text_normalizer.dart';
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
    final storePrices = json['prices'] is Map
        ? Map<String, dynamic>.from(json['prices'] as Map)
        : const <String, dynamic>{};
    final rawPrice = parseDouble(
      json['price'] ?? _storeApiPrice(storePrices, 'price'),
    );
    final rawRegular = parseDouble(
      json['regular_price'] ?? _storeApiPrice(storePrices, 'regular_price'),
    );
    final rawSale = _nullableDouble(
      json['sale_price'] ?? _storeApiPrice(storePrices, 'sale_price'),
    );
    final stockStatus = TextNormalizer.normalize(
      json['stock_status'] ?? json['status'],
    ).toLowerCase();

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
      inStock:
          parseBool(json['in_stock'] ?? json['is_in_stock']) ||
          stockStatus == 'instock' ||
          stockStatus == 'in_stock' ||
          stockStatus == 'available',
      imageUrl: _extractVariationImageUrl(
        json['image_url'] ?? json['image'] ?? json['image_data'],
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

double? _storeApiPrice(Map<String, dynamic> prices, String key) {
  if (prices.isEmpty || !prices.containsKey(key)) {
    return null;
  }

  final parsed = parseDouble(prices[key]);
  if (parsed <= 0) {
    return null;
  }

  final minorUnit = parseInt(prices['currency_minor_unit']);
  if (minorUnit <= 0) {
    return parsed;
  }

  var divisor = 1.0;
  for (var i = 0; i < minorUnit; i++) {
    divisor *= 10;
  }
  return parsed / divisor;
}

String? _extractVariationImageUrl(dynamic raw) {
  if (raw == null) {
    return null;
  }

  if (raw is String) {
    return normalizeNullableHttpUrl(raw);
  }

  if (raw is List) {
    for (final item in raw) {
      final candidate = _extractVariationImageUrl(item);
      if ((candidate ?? '').isNotEmpty) {
        return candidate;
      }
    }
    return null;
  }

  if (raw is Map) {
    final map = Map<String, dynamic>.from(raw);
    for (final key in const [
      'src',
      'url',
      'image_url',
      'thumbnail',
      'thumb',
      'medium',
      'large',
      'full',
    ]) {
      final candidate = normalizeNullableHttpUrl(map[key]?.toString());
      if ((candidate ?? '').isNotEmpty) {
        return candidate;
      }
    }

    for (final key in const ['sizes', 'image', 'images']) {
      final nested = _extractVariationImageUrl(map[key]);
      if ((nested ?? '').isNotEmpty) {
        return nested;
      }
    }
  }

  return normalizeNullableHttpUrl(raw.toString());
}
