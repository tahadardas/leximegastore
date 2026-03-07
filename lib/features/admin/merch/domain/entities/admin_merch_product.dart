import '../../../../../core/utils/safe_parsers.dart';
import '../../../../../core/utils/text_normalizer.dart';

class AdminMerchProduct {
  final int id;
  final String name;
  final String imageUrl;
  final String? featuredImage;
  final double price;
  final double regularPrice;
  final double? salePrice;
  final bool inStock;
  final bool pinned;
  final int? sortOrder;
  final DateTime? dateOnSaleFrom;
  final DateTime? dateOnSaleTo;

  const AdminMerchProduct({
    required this.id,
    required this.name,
    required this.imageUrl,
    this.featuredImage,
    required this.price,
    required this.regularPrice,
    this.salePrice,
    required this.inStock,
    required this.pinned,
    required this.sortOrder,
    this.dateOnSaleFrom,
    this.dateOnSaleTo,
  });

  factory AdminMerchProduct.fromJson(Map<String, dynamic> json) {
    return AdminMerchProduct(
      id: parseInt(json['id']),
      name: TextNormalizer.normalize(json['name']),
      imageUrl: (json['image_url'] ?? '').toString(),
      featuredImage: json['featured_image']?.toString(),
      price: parseDouble(json['price'] ?? json['price_min']),
      regularPrice: parseDouble(
        json['regular_price'] ?? json['regular_min'] ?? json['price_max'],
      ),
      salePrice: parseDoubleNullable(json['sale_price'] ?? json['sale_min']),
      inStock: parseBool(json['in_stock']),
      pinned: parseBool(json['pinned']),
      sortOrder: parseIntNullable(json['sort_order']),
      dateOnSaleFrom: parseIntNullable(json['date_on_sale_from']) != null
          ? DateTime.fromMillisecondsSinceEpoch(
              parseInt(json['date_on_sale_from']) * 1000,
            )
          : null,
      dateOnSaleTo: parseIntNullable(json['date_on_sale_to']) != null
          ? DateTime.fromMillisecondsSinceEpoch(
              parseInt(json['date_on_sale_to']) * 1000,
            )
          : null,
    );
  }

  AdminMerchProduct copyWith({
    bool? pinned,
    int? sortOrder,
    double? salePrice,
    DateTime? dateOnSaleFrom,
    DateTime? dateOnSaleTo,
  }) {
    return AdminMerchProduct(
      id: id,
      name: name,
      imageUrl: imageUrl,
      featuredImage: featuredImage,
      price: price,
      regularPrice: regularPrice,
      salePrice: salePrice ?? this.salePrice,
      inStock: inStock,
      pinned: pinned ?? this.pinned,
      sortOrder: sortOrder ?? this.sortOrder,
      dateOnSaleFrom: dateOnSaleFrom ?? this.dateOnSaleFrom,
      dateOnSaleTo: dateOnSaleTo ?? this.dateOnSaleTo,
    );
  }

  Map<String, dynamic> toPatchJson(int fallbackSortOrder) => {
    'product_id': id,
    'pinned': pinned,
    'sort_order': sortOrder ?? fallbackSortOrder,
  };
}
