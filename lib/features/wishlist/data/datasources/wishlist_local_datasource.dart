import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/utils/text_normalizer.dart';
import '../../../product/domain/entities/product_image_set.dart';
import '../../../product/domain/entities/product_entity.dart';

/// Local datasource for wishlist persistence.
///
/// Stores full product snapshots so wishlist can work fully offline and
/// without any WordPress dependency.
class WishlistLocalDatasource {
  static const _storageKey = 'lexi_wishlist_products_v1';

  List<ProductEntity>? _cache;

  Future<List<ProductEntity>> getProducts() async {
    if (_cache != null) {
      return List<ProductEntity>.of(_cache!);
    }

    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);

    if (raw == null || raw.trim().isEmpty) {
      _cache = const <ProductEntity>[];
      return const <ProductEntity>[];
    }

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) {
        _cache = const <ProductEntity>[];
        return const <ProductEntity>[];
      }

      final products = decoded
          .whereType<Map>()
          .map((e) => _fromMap(Map<String, dynamic>.from(e)))
          .toList(growable: false);

      _cache = products;
      return List<ProductEntity>.of(products);
    } catch (_) {
      _cache = const <ProductEntity>[];
      return const <ProductEntity>[];
    }
  }

  Future<List<int>> getIds() async {
    final products = await getProducts();
    return products.map((e) => e.id).toList(growable: false);
  }

  Future<void> saveProducts(List<ProductEntity> products) async {
    final deduped = <int, ProductEntity>{};
    for (final product in products) {
      deduped[product.id] = product;
    }
    final ordered = deduped.values.toList(growable: false);

    _cache = ordered;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _storageKey,
      jsonEncode(ordered.map(_toMap).toList(growable: false)),
    );
  }

  Future<List<int>> toggle(int productId, {ProductEntity? product}) async {
    final current = await getProducts();
    final mutable = List<ProductEntity>.of(current);
    final index = mutable.indexWhere((e) => e.id == productId);

    if (index >= 0) {
      mutable.removeAt(index);
    } else {
      mutable.insert(0, product ?? _placeholder(productId));
    }

    await saveProducts(mutable);
    return mutable.map((e) => e.id).toList(growable: false);
  }

  ProductEntity _placeholder(int productId) {
    return ProductEntity(
      id: productId,
      name: 'منتج #$productId',
      price: 0,
      regularPrice: 0,
      salePrice: null,
      image: ProductImageSet.empty,
      images: const <String>[],
      cardImages: const <String>[],
      rating: 0,
      reviewsCount: 0,
      inStock: true,
      description: '',
      shortDescription: '',
      wishlistCount: 0,
    );
  }

  Map<String, dynamic> _toMap(ProductEntity product) {
    return <String, dynamic>{
      'id': product.id,
      'name': product.name,
      'price': product.price,
      'regular_price': product.regularPrice,
      'sale_price': product.salePrice,
      'image': <String, dynamic>{
        'thumb': product.image.thumb,
        'medium': product.image.medium,
        'large': product.image.large,
      },
      'images': product.images,
      'card_images': product.cardImages,
      'rating': product.rating,
      'reviews_count': product.reviewsCount,
      'in_stock': product.inStock,
      'description': product.description,
      'short_description': product.shortDescription,
      'wishlist_count': product.wishlistCount,
      'sale_end_date': product.saleEndDate?.toIso8601String(),
    };
  }

  ProductEntity _fromMap(Map<String, dynamic> json) {
    final imagesRaw = json['images'];
    final images = imagesRaw is List
        ? imagesRaw.map((e) => e.toString()).where((e) => e.isNotEmpty).toList()
        : const <String>[];
    final cardImagesRaw = json['card_images'];
    final cardImages = cardImagesRaw is List
        ? cardImagesRaw
              .map((e) => e.toString())
              .where((e) => e.isNotEmpty)
              .toList()
        : const <String>[];
    final imageRaw = json['image'];

    final saleEndDateRaw = (json['sale_end_date'] ?? '').toString().trim();

    return ProductEntity(
      id: _toInt(json['id']),
      name: TextNormalizer.normalize(json['name']),
      price: _toDouble(json['price']),
      regularPrice: _toDouble(json['regular_price']),
      salePrice: _toNullableDouble(json['sale_price']),
      image: ProductImageSet.fromDynamic(imageRaw),
      images: images,
      cardImages: cardImages,
      rating: _toDouble(json['rating']),
      reviewsCount: _toInt(json['reviews_count']),
      inStock: _toBool(json['in_stock']),
      description: TextNormalizer.normalize(json['description']),
      shortDescription: TextNormalizer.normalize(json['short_description']),
      wishlistCount: _toInt(json['wishlist_count']),
      saleEndDate: saleEndDateRaw.isEmpty
          ? null
          : DateTime.tryParse(saleEndDateRaw),
    );
  }

  int _toInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  double _toDouble(dynamic value) {
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0.0;
  }

  double? _toNullableDouble(dynamic value) {
    if (value == null) return null;
    if (value is String && value.trim().isEmpty) return null;
    final parsed = _toDouble(value);
    return parsed == 0 && value.toString() != '0' ? null : parsed;
  }

  bool _toBool(dynamic value) {
    if (value is bool) return value;
    if (value is num) return value != 0;
    final normalized = (value ?? '').toString().trim().toLowerCase();
    return normalized == 'true' || normalized == '1' || normalized == 'yes';
  }

  Future<void> clear() async {
    _cache = const <ProductEntity>[];
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_storageKey);
  }
}
