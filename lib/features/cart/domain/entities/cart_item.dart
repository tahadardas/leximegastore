import 'dart:convert';
import '../../../../core/utils/safe_parsers.dart';
import '../../../../core/utils/text_normalizer.dart';

/// Domain entity for a cart item.
///
/// Stored locally via [CartLocalDatasource] using shared_preferences.
class CartItem {
  final int productId;
  final int? variationId;
  final String name;
  final double price;
  final double? regularPrice;
  final String? variationLabel;
  final String image;
  int qty;

  // Additional fields for order details/consistency
  final String? unitType;
  final double? piecesCount;
  final double? discount;
  final double? lineTotalOverride;

  CartItem({
    required this.productId,
    this.variationId,
    required this.name,
    required this.price,
    this.regularPrice,
    this.variationLabel,
    this.image = '',
    this.qty = 1,
    this.unitType,
    this.piecesCount,
    this.discount,
    this.lineTotalOverride,
  });

  /// Unique key combining product + variation for map lookups.
  String get cartKey =>
      variationId != null ? '${productId}_$variationId' : '$productId';

  /// Line total for this item.
  double get lineTotal => lineTotalOverride ?? (price * qty);

  // --------------------------------------------------------------------------
  // JSON Serialization (for shared_preferences)
  // --------------------------------------------------------------------------

  factory CartItem.fromJson(Map<String, dynamic> json) {
    return CartItem(
      productId: parseInt(json['product_id'] ?? json['productId']),
      variationId: parseIntNullable(
        json['variation_id'] ?? json['variationId'],
      ),
      name: TextNormalizer.normalize(json['name'] ?? ''),
      price: parseDouble(json['price'] ?? 0.0),
      regularPrice: parseDoubleNullable(
        json['regular_price'] ?? json['regularPrice'],
      ),
      variationLabel: json['variation_label'] as String?,
      image: json['image'] as String? ?? '',
      qty: parseInt(json['qty'] ?? 1),
      unitType: json['unit_type'] as String?,
      piecesCount: parseDoubleNullable(
        json['pieces_count'] ?? json['piecesCount'],
      ),
      discount: parseDoubleNullable(json['discount']),
      lineTotalOverride: parseDoubleNullable(
        json['line_total_override'] ?? json['lineTotalOverride'],
      ),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'product_id': productId,
      'variation_id': variationId,
      'name': name,
      'price': price,
      'regular_price': regularPrice,
      'variation_label': variationLabel,
      'image': image,
      'qty': qty,
      'unit_type': unitType,
      'pieces_count': piecesCount,
      'discount': discount,
      'line_total_override': lineTotalOverride,
    };
  }

  /// Encode the full list of cart items to a JSON string.
  static String encodeList(List<CartItem> items) =>
      jsonEncode(items.map((e) => e.toJson()).toList());

  /// Decode a JSON string into a list of cart items.
  static List<CartItem> decodeList(String source) {
    try {
      final list = jsonDecode(source) as List;
      return list
          .map((e) => CartItem.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  CartItem copyWith({
    int? productId,
    int? variationId,
    String? name,
    double? price,
    double? regularPrice,
    String? variationLabel,
    String? image,
    int? qty,
    String? unitType,
    double? piecesCount,
    double? discount,
    double? lineTotalOverride,
  }) {
    return CartItem(
      productId: productId ?? this.productId,
      variationId: variationId ?? this.variationId,
      name: name ?? this.name,
      price: price ?? this.price,
      regularPrice: regularPrice ?? this.regularPrice,
      variationLabel: variationLabel ?? this.variationLabel,
      image: image ?? this.image,
      qty: qty ?? this.qty,
      unitType: unitType ?? this.unitType,
      piecesCount: piecesCount ?? this.piecesCount,
      discount: discount ?? this.discount,
      lineTotalOverride: lineTotalOverride ?? this.lineTotalOverride,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CartItem &&
          productId == other.productId &&
          variationId == other.variationId;

  @override
  int get hashCode => Object.hash(productId, variationId);

  @override
  String toString() =>
      'CartItem(productId: $productId, name: $name, qty: $qty, price: $price)';
}
