import 'dart:developer' as developer;

import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../../core/utils/safe_parsers.dart';
import '../../../../core/utils/text_normalizer.dart';
import '../../../../core/utils/url_utils.dart';
import '../../domain/entities/product_image_set.dart';

part 'product_model.freezed.dart';

/// Product DTO - mirrors the Lexi API JSON shape.
@freezed
class ProductModel with _$ProductModel {
  const factory ProductModel({
    required int id,
    required String name,

    /// Current selling price (after discount if any).
    required double price,

    /// Original price before discount.
    @JsonKey(name: 'regular_price') required double regularPrice,

    /// Discounted price (null if no sale).
    @JsonKey(name: 'sale_price') double? salePrice,

    /// Primary image sizes for small/medium/large rendering.
    @Default(ProductImageSet.empty) ProductImageSet image,

    /// Full gallery URLs (prefer large/original) for detail screens.
    @Default([]) List<String> images,

    /// Card-friendly gallery URLs (prefer thumb/medium).
    @JsonKey(name: 'card_images') @Default([]) List<String> cardImages,

    /// Average product rating (0.0 - 5.0).
    @Default(0.0) double rating,

    /// Number of reviews.
    @JsonKey(name: 'reviews_count') @Default(0) int reviewsCount,

    /// Whether the product is currently in stock.
    @JsonKey(name: 'in_stock') @Default(true) bool inStock,

    /// HTML description of the product.
    @Default('') String description,

    /// HTML short description of the product.
    @JsonKey(name: 'short_description') @Default('') String shortDescription,

    /// Sale end date timestamp (seconds since epoch).
    @JsonKey(name: 'date_on_sale_to') int? dateOnSaleTo,

    /// Total number of wishlist additions.
    @JsonKey(name: 'wishlist_count') @Default(0) int wishlistCount,

    /// Brand/taxonomy id for this product if available.
    @JsonKey(name: 'brand_id') int? brandId,

    /// Brand display name for this product if available.
    @JsonKey(name: 'brand_name') @Default('') String brandName,

    /// Category ids used for home-feed diversity fallback.
    @JsonKey(name: 'category_ids') @Default(<int>[]) List<int> categoryIds,

    /// Product type (simple, variable, etc.)
    @JsonKey(name: 'type') @Default('simple') String type,

    /// Product publish/create timestamp (if available from API).
    @JsonKey(name: 'created_at') DateTime? createdAt,

    /// Historical sales count used for home ranking.
    @JsonKey(name: 'total_sales') @Default(0) int salesCount,

    /// Product views count used for home ranking.
    @JsonKey(name: 'views') @Default(0) int viewsCount,
  }) = _ProductModel;

  factory ProductModel.fromJson(Map<String, dynamic> json) {
    final type = (json['type'] ?? 'simple').toString().toLowerCase();
    final storePrices = json['prices'] is Map
        ? Map<String, dynamic>.from(json['prices'] as Map)
        : const <String, dynamic>{};
    final saleRaw =
        json['sale_price'] ??
        json['sale_min'] ??
        _storeApiPrice(storePrices, 'sale_price');
    final stockStatus = (json['stock_status'] ?? '').toString().toLowerCase();
    final parsedName = TextNormalizer.normalize(json['name']);
    final parsedDescription = TextNormalizer.normalize(json['description']);
    final parsedShortDescription = TextNormalizer.normalize(
      json['short_description'],
    );
    final brand = _parseBrand(
      brand: json['brand'],
      brands: json['brands'],
      brandId: json['brand_id'],
      brandName: json['brand_name'],
    );

    final legacyImageUrl =
        json['image_url'] ??
        json['imageUrl'] ??
        json['thumbnail'] ??
        json['src'];
    final parsedImages = _parseImageCollections(
      json['images'],
      json['featured_image'] ?? legacyImageUrl,
      json['image'] ?? legacyImageUrl,
      json['card_images'],
    );
    final parsedPrice = parseDouble(
      json['price'] ??
          json['price_min'] ??
          _storeApiPrice(storePrices, 'price'),
    );
    final parsedRegular = parseDouble(
      json['regular_price'] ??
          json['regular_min'] ??
          json['price_max'] ??
          _storeApiPrice(storePrices, 'regular_price'),
    );
    final parsedSale = _nullableDouble(saleRaw);

    var salePrice = (parsedSale != null && parsedSale > 0) ? parsedSale : null;
    var regularPrice = parsedRegular > 0 ? parsedRegular : 0.0;
    var price = parsedPrice > 0 ? parsedPrice : 0.0;

    if (salePrice != null && regularPrice > 0 && salePrice >= regularPrice) {
      salePrice = null;
    }

    // When a valid sale price exists, ensure `price` reflects the discounted
    // amount. The API's `price` field sometimes equals `regular_price` even
    // when the product is on sale.
    if (salePrice != null && salePrice > 0 && salePrice < regularPrice) {
      price = salePrice;
    }

    if (price <= 0 && salePrice != null) {
      price = salePrice;
    }
    if (price <= 0 && regularPrice > 0) {
      price = regularPrice;
    }
    if (regularPrice <= 0 && price > 0) {
      regularPrice = price;
    }

    var resolvedBrandName = brand.name.trim();
    if (resolvedBrandName.isEmpty) {
      resolvedBrandName = _deriveBrandNameFallback(
        name: parsedName,
        description: parsedDescription,
        shortDescription: parsedShortDescription,
        attributes: json['attributes'],
      );
    }

    return ProductModel(
      id: parseInt(json['id']),
      name: parsedName,
      price: price,
      regularPrice: regularPrice,
      salePrice: salePrice,
      image: parsedImages.primary,
      images: parsedImages.detailImages,
      cardImages: parsedImages.cardImages,
      rating: parseDouble(
        json['rating'] ?? json['rating_avg'] ?? json['average_rating'],
      ),
      reviewsCount: parseInt(
        json['reviews_count'] ??
            json['rating_count'] ??
            json['review_count'] ??
            json['reviews'],
      ),
      inStock:
          parseBool(json['in_stock'] ?? json['is_in_stock']) ||
          stockStatus == 'instock',
      description: parsedDescription,
      shortDescription: parsedShortDescription,
      dateOnSaleTo: parseIntNullable(json['date_on_sale_to']),
      wishlistCount: parseInt(json['wishlist_count']),
      brandId: brand.id,
      brandName: resolvedBrandName,
      categoryIds: _parseCategoryIds(json['category_ids'], json['categories']),
      type: type,
      createdAt: _parseDateTime(
        json['created_at'] ??
            json['date_created'] ??
            json['createdAt'] ??
            json['date'],
      ),
      salesCount: parseInt(
        json['total_sales'] ??
            json['sales_count'] ??
            json['sales'] ??
            json['sold_count'] ??
            json['orders_count'],
      ),
      viewsCount: parseInt(
        json['views'] ??
            json['view_count'] ??
            json['views_count'] ??
            json['total_views'],
      ),
    );
  }
}

class _ParsedBrand {
  final int? id;
  final String name;

  const _ParsedBrand({this.id, this.name = ''});
}

_ParsedBrand _parseBrand({
  dynamic brand,
  dynamic brands,
  dynamic brandId,
  dynamic brandName,
}) {
  int? resolvedId = parseIntNullable(brandId);
  var resolvedName = TextNormalizer.normalize(brandName);

  void absorb(dynamic value) {
    if (value == null) {
      return;
    }

    if (value is List) {
      for (final item in value) {
        absorb(item);
      }
      return;
    }

    if (value is Map) {
      final map = Map<String, dynamic>.from(value);
      resolvedId ??=
          parseIntNullable(map['id']) ??
          parseIntNullable(map['term_id']) ??
          parseIntNullable(map['brand_id']);

      if (resolvedName.isEmpty) {
        resolvedName = TextNormalizer.normalize(
          map['name'] ?? map['title'] ?? map['label'] ?? map['brand_name'],
        );
      }
      return;
    }

    if (value is num) {
      resolvedId ??= value.toInt();
      return;
    }

    final text = TextNormalizer.normalize(value);
    if (text.isEmpty) {
      return;
    }

    if (resolvedName.isEmpty) {
      resolvedName = text;
    }
    resolvedId ??= parseIntNullable(text);
  }

  absorb(brand);
  absorb(brands);

  return _ParsedBrand(id: resolvedId, name: resolvedName);
}

String _deriveBrandNameFallback({
  required String name,
  required String description,
  required String shortDescription,
  dynamic attributes,
}) {
  final fromAttributes = _extractBrandFromAttributes(attributes);
  if (fromAttributes.isNotEmpty) {
    return fromAttributes;
  }

  final fromDescription = _extractBrandFromText(
    '$shortDescription\n$description',
  );
  if (fromDescription.isNotEmpty) {
    return fromDescription;
  }

  return '';
}

String _extractBrandFromAttributes(dynamic attributes) {
  if (attributes is! List) {
    return '';
  }

  for (final item in attributes) {
    if (item is! Map) {
      continue;
    }
    final map = Map<String, dynamic>.from(item);
    final attrName = TextNormalizer.normalize(map['name']).toLowerCase();
    final attrSlug = TextNormalizer.normalize(map['slug']).toLowerCase();
    final looksLikeBrand =
        attrName.contains('brand') ||
        attrName.contains('العلامة') ||
        attrName.contains('ماركة') ||
        attrSlug.contains('brand');
    if (!looksLikeBrand) {
      continue;
    }

    final options = map['options'];
    if (options is List && options.isNotEmpty) {
      final optionValue = TextNormalizer.normalize(options.first);
      final cleaned = _cleanBrandCandidate(optionValue);
      if (cleaned.isNotEmpty) {
        return cleaned;
      }
    }

    final single = _cleanBrandCandidate(
      TextNormalizer.normalize(map['option']),
    );
    if (single.isNotEmpty) {
      return single;
    }
  }

  return '';
}

String _extractBrandFromText(String text) {
  if (text.trim().isEmpty) {
    return '';
  }

  final patterns = <RegExp>[
    RegExp(r'العلامة\s*التجارية\s*[:：]\s*([^\n\r<]+)', multiLine: true),
    RegExp(
      r'brand\s*[:：]\s*([^\n\r<]+)',
      caseSensitive: false,
      multiLine: true,
    ),
  ];

  for (final pattern in patterns) {
    final match = pattern.firstMatch(text);
    if (match == null) {
      continue;
    }
    final candidate = _cleanBrandCandidate(match.group(1) ?? '');
    if (candidate.isNotEmpty) {
      return candidate;
    }
  }

  return '';
}

String _cleanBrandCandidate(String raw) {
  var text = TextNormalizer.normalize(raw);
  if (text.isEmpty) {
    return '';
  }

  final paren = RegExp(r'^([^()]+)\(([^()]+)\)$').firstMatch(text);
  if (paren != null) {
    text = TextNormalizer.normalize(paren.group(1));
    if (text.isEmpty) {
      text = TextNormalizer.normalize(paren.group(2));
    }
  }

  final split = text.split(RegExp(r'[،,;|]'));
  if (split.isNotEmpty) {
    text = TextNormalizer.normalize(split.first);
  }

  text = text.replaceAll(RegExp(r'^[\-\*\u2022\s]+'), '');
  text = text.replaceAll(RegExp(r'[\-\*\u2022\s]+$'), '');
  return text;
}

class _ParsedImageCollections {
  final ProductImageSet primary;
  final List<String> detailImages;
  final List<String> cardImages;

  const _ParsedImageCollections({
    required this.primary,
    required this.detailImages,
    required this.cardImages,
  });
}

/// One-time flag so we only log the first product image URL once per session.
bool _didLogFirstImage = false;

/// Parse image collections from API payloads with backward compatibility.
_ParsedImageCollections _parseImageCollections(
  dynamic rawImages,
  dynamic featuredImage,
  dynamic primaryImage,
  dynamic rawCardImages,
) {
  final featured = _normalizeUrlOrNull(featuredImage);
  final parsedPrimary = ProductImageSet.fromDynamic(
    primaryImage,
    fallbackUrl: featured,
  );

  final detailCandidates = <ProductImageSet>[];
  final seen = <String>{};

  void addCandidate(ProductImageSet candidate) {
    if (!candidate.isNotEmpty) {
      return;
    }

    final key =
        '${candidate.thumb ?? ''}|${candidate.medium ?? ''}|${candidate.large ?? ''}';
    if (!seen.add(key)) {
      return;
    }
    detailCandidates.add(candidate);
  }

  if (parsedPrimary.isNotEmpty) {
    addCandidate(parsedPrimary);
  }

  if (rawImages is List) {
    for (final item in rawImages) {
      addCandidate(ProductImageSet.fromDynamic(item, fallbackUrl: featured));
    }
  }

  if (detailCandidates.isEmpty && featured != null) {
    addCandidate(ProductImageSet.fromDynamic(featured));
  }

  final detailImages = _collectUniqueUrls(
    detailCandidates.map((e) => e.detailUrl).whereType<String>(),
  );

  final cardImageUrls = <String>[];
  if (rawCardImages is List) {
    cardImageUrls.addAll(
      _collectUniqueUrls(
        rawCardImages
            .map((e) => _normalizeUrlOrNull(e))
            .whereType<String>()
            .toList(growable: false),
      ),
    );
  }

  if (cardImageUrls.isEmpty) {
    cardImageUrls.addAll(
      _collectUniqueUrls(
        detailCandidates.map((e) => e.cardUrl).whereType<String>(),
      ),
    );
  }

  if (cardImageUrls.isEmpty) {
    cardImageUrls.addAll(detailImages);
  }

  final resolvedPrimary = detailCandidates.isNotEmpty
      ? detailCandidates.first
      : ProductImageSet.fromDynamic(featured);

  if (!_didLogFirstImage && detailImages.isNotEmpty) {
    _didLogFirstImage = true;
    developer.log(
      'First product image URL: ${detailImages.first}',
      name: 'ProductModel',
    );
  }

  return _ParsedImageCollections(
    primary: resolvedPrimary,
    detailImages: detailImages,
    cardImages: cardImageUrls,
  );
}

List<String> _collectUniqueUrls(Iterable<String> urls) {
  final dedup = <String>[];
  final seen = <String>{};
  for (final item in urls) {
    final normalized = _normalizeUrlOrNull(item);
    if (normalized == null || !seen.add(normalized)) {
      continue;
    }
    dedup.add(normalized);
  }
  return dedup;
}

String? _normalizeUrlOrNull(dynamic value) {
  if (value == null) {
    return null;
  }
  final raw = value.toString().trim();
  if (raw.isEmpty) {
    return null;
  }
  return normalizeNullableHttpUrl(raw);
}

double? _nullableDouble(dynamic raw) {
  if (raw == null) return null;
  if (raw is String && raw.trim().isEmpty) return null;
  final value = parseDouble(raw);
  return value > 0 ? value : null;
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

DateTime? _parseDateTime(dynamic raw) {
  if (raw == null) {
    return null;
  }

  if (raw is DateTime) {
    return raw.toUtc();
  }

  if (raw is num) {
    final timestamp = raw.toInt();
    if (timestamp <= 0) {
      return null;
    }
    // Heuristic: values above 1e12 are likely milliseconds.
    final millis = timestamp > 1000000000000 ? timestamp : timestamp * 1000;
    return DateTime.fromMillisecondsSinceEpoch(millis, isUtc: true);
  }

  final text = raw.toString().trim();
  if (text.isEmpty) {
    return null;
  }

  final parsed = DateTime.tryParse(text);
  return parsed?.toUtc();
}

List<int> _parseCategoryIds(dynamic rawCategoryIds, dynamic rawCategories) {
  final output = <int>[];
  final seen = <int>{};

  void addId(dynamic raw) {
    final id = parseInt(raw);
    if (id <= 0 || !seen.add(id)) {
      return;
    }
    output.add(id);
  }

  if (rawCategoryIds is List) {
    for (final raw in rawCategoryIds) {
      addId(raw);
    }
  }

  if (rawCategories is List) {
    for (final raw in rawCategories) {
      if (raw is Map) {
        final map = Map<String, dynamic>.from(raw);
        addId(map['id']);
      } else {
        addId(raw);
      }
    }
  }

  return output;
}
