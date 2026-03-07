import '../repositories/product_repository.dart';

/// Fetches a paginated, optionally filtered list of products.
///
/// Usage:
/// ```dart
/// final result = await getProducts(
///   GetProductsParams(page: 1, search: 'ساعة'),
/// );
/// ```
class GetProducts {
  final ProductRepository _repository;

  GetProducts({required ProductRepository repository})
    : _repository = repository;

  Future<ProductListResult> call(GetProductsParams params) {
    return _repository.fetchProducts(
      page: params.page,
      perPage: params.perPage,
      search: params.search,
      categoryId: params.categoryId,
      brandId: params.brandId,
      brandName: params.brandName,
      sort: params.sort,
      preferCache: params.preferCache,
    );
  }
}

/// Parameters for [GetProducts] use case.
class GetProductsParams {
  final int page;
  final int perPage;
  final String? search;
  final int? categoryId;
  final int? brandId;
  final String? brandName;
  final String? sort;
  final bool preferCache;

  const GetProductsParams({
    this.page = 1,
    this.perPage = 20,
    this.search,
    this.categoryId,
    this.brandId,
    this.brandName,
    this.sort,
    this.preferCache = true,
  });

  /// Creates a copy with modified fields (for pagination).
  GetProductsParams copyWith({
    int? page,
    int? perPage,
    String? search,
    int? categoryId,
    int? brandId,
    String? brandName,
    String? sort,
    bool? preferCache,
  }) {
    return GetProductsParams(
      page: page ?? this.page,
      perPage: perPage ?? this.perPage,
      search: search ?? this.search,
      categoryId: categoryId ?? this.categoryId,
      brandId: brandId ?? this.brandId,
      brandName: brandName ?? this.brandName,
      sort: sort ?? this.sort,
      preferCache: preferCache ?? this.preferCache,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GetProductsParams &&
          page == other.page &&
          perPage == other.perPage &&
          search == other.search &&
          categoryId == other.categoryId &&
          brandId == other.brandId &&
          brandName == other.brandName &&
          sort == other.sort &&
          preferCache == other.preferCache;

  @override
  int get hashCode => Object.hash(
    page,
    perPage,
    search,
    categoryId,
    brandId,
    brandName,
    sort,
    preferCache,
  );
}
