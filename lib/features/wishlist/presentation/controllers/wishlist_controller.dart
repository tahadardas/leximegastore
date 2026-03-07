import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lexi_mega_store/features/product/domain/entities/product_entity.dart';
import 'package:lexi_mega_store/features/wishlist/data/datasources/wishlist_local_datasource.dart';
import 'package:lexi_mega_store/features/wishlist/data/repositories/wishlist_repository_impl.dart';
import 'package:lexi_mega_store/features/wishlist/domain/repositories/wishlist_repository.dart';

final wishlistLocalDatasourceProvider = Provider<WishlistLocalDatasource>((
  ref,
) {
  return WishlistLocalDatasource();
});

final wishlistRepositoryProvider = Provider<WishlistRepository>((ref) {
  return WishlistRepositoryImpl(
    localDatasource: ref.watch(wishlistLocalDatasourceProvider),
  );
});

final _wishlistIdsStateProvider = StateProvider<Set<int>>((_) => <int>{});

final wishlistControllerProvider =
    AsyncNotifierProvider<WishlistController, List<ProductEntity>>(
      WishlistController.new,
    );

class WishlistController extends AsyncNotifier<List<ProductEntity>> {
  @override
  Future<List<ProductEntity>> build() async {
    return _loadLocalWishlist();
  }

  Future<List<ProductEntity>> _loadLocalWishlist() async {
    final repository = ref.read(wishlistRepositoryProvider);
    final products = await repository.getWishlist();
    _setIds(products.map((e) => e.id).toSet());
    return products;
  }

  void _setIds(Set<int> ids) {
    ref.read(_wishlistIdsStateProvider.notifier).state = ids;
  }

  Future<void> toggle(int productId, {ProductEntity? product}) async {
    final repository = ref.read(wishlistRepositoryProvider);
    final previous = state;

    try {
      final ids = await repository.toggleWishlist(productId, product: product);
      _setIds(ids.toSet());
      state = await AsyncValue.guard(() => repository.getWishlist());
    } catch (_) {
      state = previous;
      rethrow;
    }
  }

  Future<void> remove(int productId) async {
    await toggle(productId);
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(_loadLocalWishlist);
  }

  Future<void> clear() async {
    await ref.read(wishlistRepositoryProvider).clearWishlist();
    _setIds({});
    state = const AsyncData([]);
  }
}

// Provider for quick lookup of wishlist IDs (e.g. for heart icons)
final wishlistIdsProvider = Provider<Set<int>>((ref) {
  final ids = ref.watch(_wishlistIdsStateProvider);
  if (ids.isNotEmpty) {
    return ids;
  }
  final state = ref.watch(wishlistControllerProvider);
  return state.valueOrNull?.map((e) => e.id).toSet() ?? const <int>{};
});
