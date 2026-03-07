import '../entities/product_entity.dart';

/// Domain-layer contract for product data access.
///
/// Implemented by [ProductRepositoryImpl] in the data layer.
abstract class ProductRepository {
  /// Fetches a paginated list of products as domain entities.
  Future<ProductListResult> fetchProducts({
    int page = 1,
    int perPage = 20,
    String? search,
    int? categoryId,
    int? brandId,
    String? brandName,
    String? sort,
    bool preferCache = true,
  });

  /// Fetches a paginated list of products as domain entities.
  Future<ProductListResult> getProducts({
    int page = 1,
    int perPage = 20,
    String? search,
    int? categoryId,
    int? brandId,
    String? brandName,
    String? sort,
    bool preferCache = true,
  }) => fetchProducts(
    page: page,
    perPage: perPage,
    search: search,
    categoryId: categoryId,
    brandId: brandId,
    brandName: brandName,
    sort: sort,
    preferCache: preferCache,
  );

  /// Fetches a single product by [id].
  Future<ProductEntity> getProductById(String id, {bool preferCache = true});

  /// Resolves product numeric id from SEO slug.
  ///
  /// Returns `null` if the slug cannot be resolved.
  Future<int?> resolveProductIdBySlug(String slug);
}

/// Paginated result wrapper for the domain layer.
class ProductListResult {
  final List<ProductEntity> products;
  final int total;
  final int totalPages;
  final int currentPage;
  final int perPage;
  final bool hasMore;
  final bool fromCache;
  final DateTime? cachedAt;

  const ProductListResult({
    required this.products,
    required this.total,
    required this.totalPages,
    this.currentPage = 1,
    this.perPage = 20,
    this.hasMore = false,
    this.fromCache = false,
    this.cachedAt,
  });
}
