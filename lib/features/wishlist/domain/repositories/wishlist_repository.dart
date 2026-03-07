import '../../../product/domain/entities/product_entity.dart';

abstract class WishlistRepository {
  Future<List<int>> getWishlistIds();
  Future<List<ProductEntity>> getWishlist();
  Future<List<int>> toggleWishlist(int productId, {ProductEntity? product});
  Future<void> clearWishlist();
}
