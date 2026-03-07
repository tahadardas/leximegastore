import 'package:dio/dio.dart';

import '../../../../core/errors/app_exception.dart';
import '../../../../core/network/dio_exception_mapper.dart';
import '../../domain/entities/product_entity.dart';
import '../../domain/entities/product_mapper.dart';
import '../../domain/repositories/product_repository.dart';
import '../datasources/product_remote_datasource.dart';

/// Concrete implementation of [ProductRepository].
///
/// Handles DTO ??' Entity mapping and DioException ??' AppException mapping.
class ProductRepositoryImpl implements ProductRepository {
  final ProductRemoteDatasource _datasource;
  static const Duration _memoryCacheTtl = Duration(minutes: 5);
  static final Map<String, _ProductListMemoryCacheEntry> _memoryCache =
      <String, _ProductListMemoryCacheEntry>{};

  ProductRepositoryImpl({required ProductRemoteDatasource datasource})
    : _datasource = datasource;

  @override
  Future<ProductListResult> fetchProducts({
    int page = 1,
    int perPage = 20,
    String? search,
    int? categoryId,
    int? brandId,
    String? brandName,
    String? sort,
    bool preferCache = true,
  }) async {
    final key = _memoryCacheKey(
      page: page,
      perPage: perPage,
      search: search,
      categoryId: categoryId,
      brandId: brandId,
      brandName: brandName,
      sort: sort,
    );
    final now = DateTime.now();
    _evictExpiredMemoryCache(now);

    final cached = _memoryCache[key];
    if (preferCache &&
        cached != null &&
        cached.expiresAt.isAfter(now) &&
        cached.result.products.isNotEmpty) {
      return cached.result;
    }

    try {
      final response = await _datasource.fetchProducts(
        page: page,
        perPage: perPage,
        search: search,
        categoryId: categoryId,
        brandId: brandId,
        brandName: brandName,
        sort: sort,
        preferCache: preferCache,
      );

      final result = ProductListResult(
        products: response.products.map((m) => m.toEntity()).toList(),
        total: response.total,
        totalPages: response.totalPages,
        currentPage: response.currentPage,
        perPage: response.perPage,
        hasMore: response.hasMore,
        fromCache: response.fromCache,
        cachedAt: response.cachedAt,
      );
      _memoryCache[key] = _ProductListMemoryCacheEntry(
        result: result,
        expiresAt: now.add(_memoryCacheTtl),
      );
      return result;
    } on DioException catch (e) {
      throw DioExceptionMapper.fromDioException(e);
    } on AppException {
      rethrow;
    } catch (e) {
      throw UnknownException(data: e.toString());
    }
  }

  @override
  Future<ProductListResult> getProducts({
    int page = 1,
    int perPage = 20,
    String? search,
    int? categoryId,
    int? brandId,
    String? brandName,
    String? sort,
    bool preferCache = true,
  }) {
    return fetchProducts(
      page: page,
      perPage: perPage,
      search: search,
      categoryId: categoryId,
      brandId: brandId,
      brandName: brandName,
      sort: sort,
      preferCache: preferCache,
    );
  }

  @override
  Future<ProductEntity> getProductById(
    String id, {
    bool preferCache = true,
  }) async {
    try {
      final model = await _datasource.getProductById(
        id,
        preferCache: preferCache,
      );
      return model.toEntity();
    } on DioException catch (e) {
      throw DioExceptionMapper.fromDioException(e);
    } on AppException {
      rethrow;
    } catch (e) {
      throw UnknownException(data: e.toString());
    }
  }

  @override
  Future<int?> resolveProductIdBySlug(String slug) async {
    try {
      return await _datasource.resolveProductIdBySlug(slug);
    } on DioException catch (e) {
      throw DioExceptionMapper.fromDioException(e);
    } on AppException {
      rethrow;
    } catch (e) {
      throw UnknownException(data: e.toString());
    }
  }

  String _memoryCacheKey({
    required int page,
    required int perPage,
    required String? search,
    required int? categoryId,
    required int? brandId,
    required String? brandName,
    required String? sort,
  }) {
    final normalizedSearch = (search ?? '').trim().toLowerCase();
    final normalizedBrandName = (brandName ?? '').trim().toLowerCase();
    final normalizedSort = (sort ?? '').trim().toLowerCase();
    return 'page:$page|per_page:$perPage|search:$normalizedSearch|category:${categoryId ?? 0}|brand:${brandId ?? 0}|brand_name:$normalizedBrandName|sort:$normalizedSort';
  }

  void _evictExpiredMemoryCache(DateTime now) {
    final expired = _memoryCache.entries
        .where((entry) => entry.value.expiresAt.isBefore(now))
        .map((entry) => entry.key)
        .toList(growable: false);
    for (final key in expired) {
      _memoryCache.remove(key);
    }
  }
}

class _ProductListMemoryCacheEntry {
  final ProductListResult result;
  final DateTime expiresAt;

  const _ProductListMemoryCacheEntry({
    required this.result,
    required this.expiresAt,
  });
}
