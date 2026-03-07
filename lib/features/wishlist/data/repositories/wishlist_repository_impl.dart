import 'package:lexi_mega_store/features/product/domain/entities/product_entity.dart';
import 'package:lexi_mega_store/features/wishlist/data/datasources/wishlist_local_datasource.dart';
import 'package:lexi_mega_store/features/wishlist/domain/repositories/wishlist_repository.dart';

class WishlistRepositoryImpl implements WishlistRepository {
  final WishlistLocalDatasource _local;

  WishlistRepositoryImpl({required WishlistLocalDatasource localDatasource})
    : _local = localDatasource;

  @override
  Future<List<int>> getWishlistIds() {
    return _local.getIds();
  }

  @override
  Future<List<ProductEntity>> getWishlist() {
    return _local.getProducts();
  }

  @override
  Future<List<int>> toggleWishlist(int productId, {ProductEntity? product}) {
    return _local.toggle(productId, product: product);
  }

  @override
  Future<void> clearWishlist() {
    return _local.clear();
  }
}
