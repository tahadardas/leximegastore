import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/cache/cache_store.dart';
import '../../../../core/network/dio_client.dart';
import '../../data/datasources/product_remote_datasource.dart';
import '../../data/repositories/product_repository_impl.dart';

import '../../domain/repositories/product_repository.dart';
import '../../domain/usecases/get_products.dart';

// ?"??"? Datasource ?"??"?
final productRemoteDatasourceProvider = Provider<ProductRemoteDatasource>((
  ref,
) {
  return ProductRemoteDatasource(
    client: ref.watch(dioClientProvider),
    cacheStore: ref.watch(cacheStoreProvider),
  );
});

// ?"??"? Repository ?"??"?
final productRepositoryProvider = Provider<ProductRepository>((ref) {
  return ProductRepositoryImpl(
    datasource: ref.watch(productRemoteDatasourceProvider),
  );
});

// ?"??"? Use cases ?"??"?
final getProductsUseCaseProvider = Provider<GetProducts>((ref) {
  return GetProducts(repository: ref.watch(productRepositoryProvider));
});

// ?"??"? Controller ?"??"?

/// Controller for the products list with loading/error states.
///
/// Usage in widgets:
/// ```dart
/// final productsAsync = ref.watch(productsControllerProvider('deals'));
/// productsAsync.when(
///   data: (result) => ...,
///   loading: () => ...,
///   error: (e, st) => ...,
/// );
/// ```
final productsControllerProvider =
    AutoDisposeAsyncNotifierProviderFamily<
      ProductsController,
      ProductListResult,
      String
    >(ProductsController.new);

class ProductsController
    extends AutoDisposeFamilyAsyncNotifier<ProductListResult, String> {
  static const Duration _minimumLoadingDuration = Duration(milliseconds: 650);
  static const ProductListResult _emptyResult = ProductListResult(
    products: [],
    total: 0,
    totalPages: 1,
  );

  GetProductsParams _params = const GetProductsParams(
    sort: 'manual',
    preferCache: false,
  );
  int _activeRequestId = 0;

  @override
  Future<ProductListResult> build(String scopeKey) async {
    // This controller is loaded explicitly per-screen (deals/category scope).
    // Returning an empty baseline avoids an initial unscoped fetch race.
    return _emptyResult;
  }

  Future<ProductListResult> _fetch({required bool preferCache}) {
    final getProducts = ref.read(getProductsUseCaseProvider);
    return getProducts(_params.copyWith(preferCache: preferCache));
  }

  /// Reload the current page (pull-to-refresh).
  Future<void> refresh() async {
    await _loadFresh();
  }

  /// Load products filtered by search query.
  Future<void> search(String query) async {
    _params = GetProductsParams(
      page: 1,
      perPage: _params.perPage,
      search: query.isEmpty ? null : query,
      categoryId: _params.categoryId,
      brandId: _params.brandId,
      brandName: _params.brandName,
      sort: _params.sort,
      preferCache: false,
    );
    await _loadFresh();
  }

  /// Load products filtered by category.
  Future<void> filterByCategory(int? categoryId) async {
    _params = GetProductsParams(
      categoryId: categoryId,
      brandId: null,
      sort: categoryId == null ? 'newest' : 'manual',
      preferCache: false,
    );
    await _loadFresh();
  }

  Future<void> changeSort(String sort) async {
    _params = _params.copyWith(page: 1, sort: sort, preferCache: false);
    await _loadFresh();
  }

  Future<void> loadDeals() async {
    _params = const GetProductsParams(
      page: 1,
      perPage: 20,
      categoryId: null,
      brandId: null,
      sort: 'flash_deals',
      preferCache: false,
    );
    await _loadFresh();
  }

  /// Load list with one consolidated query (avoids multi-request flicker).
  Future<void> loadCatalog({
    required String sort,
    String? search,
    int? categoryId,
    int? brandId,
    String? brandName,
    int page = 1,
    int? perPage,
  }) async {
    _params = GetProductsParams(
      page: page,
      perPage: perPage ?? _params.perPage,
      search: search == null || search.trim().isEmpty ? null : search.trim(),
      categoryId: categoryId,
      brandId: brandId,
      brandName: brandName == null || brandName.trim().isEmpty
          ? null
          : brandName.trim(),
      sort: sort,
      preferCache: false,
    );
    await _loadFresh();
  }

  /// Load the next page of products and append to existing list.
  Future<void> loadNextPage() async {
    final currentData = state.valueOrNull;
    if (currentData == null) return;

    final currentPage = _params.page;
    if (currentPage >= currentData.totalPages) return; // No more pages

    final requestId = ++_activeRequestId;
    _params = _params.copyWith(page: currentPage + 1);

    try {
      final getProducts = ref.read(getProductsUseCaseProvider);
      final nextPage = await getProducts(_params.copyWith(preferCache: false));
      if (requestId != _activeRequestId) {
        return;
      }

      state = AsyncData(
        ProductListResult(
          products: [...currentData.products, ...nextPage.products],
          total: nextPage.total,
          totalPages: nextPage.totalPages,
          fromCache: false,
          cachedAt: nextPage.cachedAt,
        ),
      );
    } catch (e, st) {
      // Revert page on failure so user can retry
      if (requestId != _activeRequestId) {
        return;
      }
      _params = _params.copyWith(page: currentPage);
      state = AsyncError(e, st);
    }
  }

  Future<void> _loadFresh() async {
    final requestId = ++_activeRequestId;
    state = const AsyncLoading();
    try {
      final fresh = await _fetchWithMinimumDelay(preferCache: false);
      if (requestId != _activeRequestId) {
        return;
      }
      state = AsyncData(fresh);
    } catch (error, stackTrace) {
      if (requestId != _activeRequestId) {
        return;
      }
      state = AsyncError(error, stackTrace);
    }
  }

  Future<ProductListResult> _fetchWithMinimumDelay({bool? preferCache}) async {
    final startedAt = DateTime.now();
    try {
      return await _fetch(preferCache: preferCache ?? _params.preferCache);
    } finally {
      final elapsed = DateTime.now().difference(startedAt);
      final remaining = _minimumLoadingDuration - elapsed;
      if (remaining > Duration.zero) {
        await Future<void>.delayed(remaining);
      }
    }
  }
}
