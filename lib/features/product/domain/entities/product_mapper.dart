import '../../data/models/product_model.dart';
import '../entities/product_entity.dart';

/// Extension to convert [ProductModel] (DTO) ??" [ProductEntity] (domain).
extension ProductModelMapper on ProductModel {
  /// Converts a DTO to a domain entity.
  ProductEntity toEntity() {
    return ProductEntity(
      id: id,
      name: name,
      price: price,
      regularPrice: regularPrice,
      salePrice: salePrice,
      image: image,
      images: images,
      cardImages: cardImages,
      rating: rating,
      reviewsCount: reviewsCount,
      inStock: inStock,
      description: description,
      shortDescription: shortDescription,
      wishlistCount: wishlistCount,
      brandId: brandId,
      brandName: brandName,
      type: type,
      saleEndDate: dateOnSaleTo != null
          ? DateTime.fromMillisecondsSinceEpoch(dateOnSaleTo! * 1000)
          : null,
    );
  }
}

/// Extension to convert [ProductEntity] back to [ProductModel].
extension ProductEntityMapper on ProductEntity {
  /// Converts a domain entity to a DTO (for sending to API).
  ProductModel toModel() {
    return ProductModel(
      id: id,
      name: name,
      price: price,
      regularPrice: regularPrice,
      salePrice: salePrice,
      image: image,
      images: images,
      cardImages: cardImages,
      rating: rating,
      reviewsCount: reviewsCount,
      inStock: inStock,
      description: description,
      shortDescription: shortDescription,
      wishlistCount: wishlistCount,
      brandId: brandId,
      brandName: brandName,
      type: type,
      dateOnSaleTo: saleEndDate != null
          ? (saleEndDate!.millisecondsSinceEpoch / 1000).round()
          : null,
    );
  }
}
