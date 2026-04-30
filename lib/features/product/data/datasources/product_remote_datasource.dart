import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../../../config/constants/endpoints.dart';
import '../../../../core/cache/cache_policy.dart';
import '../../../../core/cache/cache_store.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../core/utils/safe_parsers.dart';
import '../../../../core/utils/text_normalizer.dart';
import '../models/product_model.dart';

/// Remote data source for Products.
class ProductRemoteDatasource {
  final DioClient _client;
  final CacheStore _cacheStore;
  static const String _listMediaCacheVersion = 'media_v2';
  static const String _storeProductsPath = '/wp-json/wc/store/v1/products';
  static const Duration _detailsMemoryCacheTtl = Duration(minutes: 10);
  static final Map<String, int> _slugToIdMemoryCache = <String, int>{};
  static final Map<String, _ProductDetailsMemoryEntry>
  _productDetailsMemoryCache = <String, _ProductDetailsMemoryEntry>{};
  final Map<String, Future<ProductListResponse>> _listInFlight =
      <String, Future<ProductListResponse>>{};
  final Map<String, Future<ProductModel>> _detailsInFlight =
      <String, Future<ProductModel>>{};

  ProductRemoteDatasource({
    required DioClient client,
    required CacheStore cacheStore,
  }) : _client = client,
       _cacheStore = cacheStore;

  /// Fetches a paginated list of products.
  Future<ProductListResponse> fetchProducts({
    int page = 1,
    int perPage = 20,
    String? search,
    int? categoryId,
    int? brandId,
    String? brandName,
    String? sort,
    bool preferCache = true,
  }) async {
    final queryParams = <String, dynamic>{'page': page, 'per_page': perPage};
    if (search != null && search.isNotEmpty) {
      queryParams['search'] = search;
      queryParams['q'] = search;
    }
    if (categoryId != null) {
      queryParams['category_id'] = categoryId;
    }
    if (brandId != null) {
      queryParams['brand_id'] = brandId;
    }
    final normalizedBrandName = (brandName ?? '').trim();
    if (normalizedBrandName.isNotEmpty) {
      queryParams['brand'] = normalizedBrandName;
      queryParams['brand_name'] = normalizedBrandName;
    }
    if (sort != null && sort.isNotEmpty) {
      queryParams['sort'] = sort;
    }

    final (_, cacheKey) = _buildListCacheKey(
      page: page,
      perPage: perPage,
      search: search,
      categoryId: categoryId,
      brandId: brandId,
      brandName: normalizedBrandName,
      sort: sort,
    );

    final inFlightKey = 'list:$cacheKey|prefer:${preferCache ? 1 : 0}';
    final existingRequest = _listInFlight[inFlightKey];
    if (existingRequest != null) {
      return existingRequest;
    }

    final request = () async {
      final cached = await _cacheStore.readJson(cacheKey);
      if (preferCache && cached != null) {
        final cachedResult = _parseProductList(
          cached.data['payload'],
          requestedPage: page,
          requestedPerPage: perPage,
          fromCache: true,
          cachedAt: cached.savedAt,
          requiredCategoryId: categoryId,
          requiredBrandId: brandId,
          requiredBrandName: normalizedBrandName,
        );

        // Do not short-circuit on empty cache payloads. They can be stale or from
        // an older response shape and would incorrectly render "no products".
        if (cachedResult.products.isNotEmpty) {
          unawaited(
            _refreshProductsSilently(
              cacheKey: cacheKey,
              queryParams: queryParams,
            ),
          );
          return cachedResult;
        }
      }

      try {
        final response = await _client.get(
          Endpoints.productsPath,
          queryParameters: queryParams,
          options: Options(
            extra: const <String, dynamic>{'requiresAuth': false},
          ),
        );

        await _cacheStore.saveJson(cacheKey, {
          'payload': _jsonSafe(response.data),
        }, DateTime.now());

        return _parseProductList(
          response.data,
          requestedPage: page,
          requestedPerPage: perPage,
          requiredCategoryId: categoryId,
          requiredBrandId: brandId,
          requiredBrandName: normalizedBrandName,
        );
      } catch (error, stackTrace) {
        if (_canUseStoreApiFallback(error)) {
          try {
            final fallbackPayload = await _fetchProductsFromStoreApi(
              page: page,
              perPage: perPage,
              search: search,
              categoryId: categoryId,
              brandId: brandId,
              brandName: normalizedBrandName,
              sort: sort,
            );

            await _cacheStore.saveJson(cacheKey, {
              'payload': _jsonSafe(fallbackPayload),
            }, DateTime.now());

            return _parseProductList(
              fallbackPayload,
              requestedPage: page,
              requestedPerPage: perPage,
              requiredCategoryId: categoryId,
              requiredBrandId: brandId,
              requiredBrandName: normalizedBrandName,
            );
          } catch (_) {
            // Fall back to the normal cache/error path below.
          }
        }

        if (cached != null) {
          return _parseProductList(
            cached.data['payload'],
            requestedPage: page,
            requestedPerPage: perPage,
            fromCache: true,
            cachedAt: cached.savedAt,
            requiredCategoryId: categoryId,
            requiredBrandId: brandId,
            requiredBrandName: normalizedBrandName,
          );
        }
        Error.throwWithStackTrace(error, stackTrace);
      }
    }();

    _listInFlight[inFlightKey] = request;
    return request.whenComplete(() {
      if (identical(_listInFlight[inFlightKey], request)) {
        _listInFlight.remove(inFlightKey);
      }
    });
  }

  Future<ProductListResponse> getProducts({
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

  /// Fetches a single product by [id].
  Future<ProductModel> getProductById(
    String id, {
    bool preferCache = true,
  }) async {
    final normalizedId = id.trim();
    final cacheKey = CachePolicy.key(
      CacheKey.productDetails,
      suffix: 'id_$normalizedId',
    );
    final inFlightKey = 'details:$normalizedId|prefer:${preferCache ? 1 : 0}';
    final existingRequest = _detailsInFlight[inFlightKey];
    if (existingRequest != null) {
      return existingRequest;
    }

    final request = () async {
      if (preferCache) {
        final memoryCached = _readProductDetailsMemory(normalizedId);
        if (memoryCached != null) {
          unawaited(_refreshProductDetailsSilently(normalizedId, cacheKey));
          return memoryCached;
        }
      }

      final cached = await _cacheStore.readJson(cacheKey);

      if (preferCache && cached != null) {
        unawaited(_refreshProductDetailsSilently(normalizedId, cacheKey));
        final item = _extractItem(cached.data['payload']);
        if (item != null) {
          try {
            final model = ProductModel.fromJson(item);
            _saveProductDetailsMemory(model);
            return model;
          } catch (e, st) {
            _logParseError(
              where: 'product/$normalizedId/cache',
              error: e,
              stackTrace: st,
              payload: item,
            );
          }
        }
      }

      try {
        final response = await _client.get(
          Endpoints.productById(normalizedId),
          options: Options(extra: const {'requiresAuth': false}),
        );

        await _cacheStore.saveJson(cacheKey, {
          'payload': _jsonSafe(response.data),
        }, DateTime.now());

        final item = _extractItem(response.data);
        if (item == null) {
          _logParseError(
            where: 'product/$normalizedId',
            error: 'Unable to resolve product object from response',
            payload: response.data,
          );
          throw const FormatException('Invalid product response shape');
        }

        try {
          final model = ProductModel.fromJson(item);
          _saveProductDetailsMemory(model);
          return model;
        } catch (e, st) {
          _logParseError(
            where: 'product/$normalizedId',
            error: e,
            stackTrace: st,
            payload: item,
          );
          rethrow;
        }
      } catch (error, stackTrace) {
        if (_canUseStoreApiFallback(error)) {
          try {
            final response = await _client.get(
              '$_storeProductsPath/$normalizedId',
              options: Options(extra: const {'requiresAuth': false}),
            );
            await _cacheStore.saveJson(cacheKey, {
              'payload': _jsonSafe(response.data),
            }, DateTime.now());
            final model = ProductModel.fromJson(
              Map<String, dynamic>.from(response.data),
            );
            _saveProductDetailsMemory(model);
            return model;
          } catch (_) {
            // Fall back to cached custom payload if present.
          }
        }

        if (cached != null) {
          final item = _extractItem(cached.data['payload']);
          if (item != null) {
            final model = ProductModel.fromJson(item);
            _saveProductDetailsMemory(model);
            return model;
          }
        }
        Error.throwWithStackTrace(error, stackTrace);
      }
    }();

    _detailsInFlight[inFlightKey] = request;
    return request.whenComplete(() {
      if (identical(_detailsInFlight[inFlightKey], request)) {
        _detailsInFlight.remove(inFlightKey);
      }
    });
  }

  Future<int?> resolveProductIdBySlug(String slug) async {
    final normalizedSlug = _normalizeSlug(slug);
    if (normalizedSlug.isEmpty) {
      return null;
    }

    final numeric = int.tryParse(normalizedSlug);
    if (numeric != null && numeric > 0) {
      return numeric;
    }

    final cachedId = _slugToIdMemoryCache[normalizedSlug];
    if (cachedId != null && cachedId > 0) {
      return cachedId;
    }

    final cacheKey = CachePolicy.key(
      CacheKey.productDetails,
      suffix: 'slug_$normalizedSlug',
    );
    final cached = await _cacheStore.readJson(cacheKey);
    if (cached != null) {
      final cachedId = parseInt(cached.data['product_id']);
      if (cachedId > 0) {
        _slugToIdMemoryCache[normalizedSlug] = cachedId;
        return cachedId;
      }
    }

    final resolvedId = await _resolveProductIdBySlugRemote(normalizedSlug);
    if (resolvedId != null && resolvedId > 0) {
      _slugToIdMemoryCache[normalizedSlug] = resolvedId;
      await _cacheStore.saveJson(cacheKey, {
        'product_id': resolvedId,
      }, DateTime.now());
    }
    return resolvedId;
  }

  ProductListResponse _parseProductList(
    dynamic payload, {
    required int requestedPage,
    required int requestedPerPage,
    bool fromCache = false,
    DateTime? cachedAt,
    int? requiredCategoryId,
    int? requiredBrandId,
    String? requiredBrandName,
  }) {
    final rawList = extractList(payload);
    final products = <ProductModel>[];

    for (var i = 0; i < rawList.length; i++) {
      final item = rawList[i];

      if (item is! Map) {
        _logParseError(
          where: 'products[$i]',
          error: 'Expected JSON object but found ${item.runtimeType}',
          payload: item,
        );
        continue;
      }

      final itemMap = Map<String, dynamic>.from(item);
      // We trust the API to return the correct items for the requested category/brand.
      // Strict client-side filtering here breaks hierarchical categories where
      // products in subcategories should be visible under the parent category.

      try {
        products.add(ProductModel.fromJson(itemMap));
      } catch (e, st) {
        _logParseError(
          where: 'products[$i]',
          error: e,
          stackTrace: st,
          payload: item,
        );
      }
    }

    final effectiveProducts = _applyRequestedBrandFilter(
      products,
      requiredBrandId: requiredBrandId,
      requiredBrandName: requiredBrandName,
    );

    final meta = _extractMeta(payload);
    final total = parseInt(meta['total']);
    final totalPages = parseInt(meta['total_pages']);
    final currentPage = parseInt(meta['page']);
    final perPage = parseInt(meta['per_page']);

    final resolvedPage = currentPage > 0 ? currentPage : requestedPage;
    final resolvedPerPage = perPage > 0 ? perPage : requestedPerPage;
    final resolvedTotalPages = totalPages > 0 ? totalPages : 0;
    final hasMore = resolvedTotalPages > 0
        ? resolvedPage < resolvedTotalPages
        : effectiveProducts.length >= resolvedPerPage;
    _saveProductDetailsMemoryBulk(effectiveProducts);

    return ProductListResponse(
      products: effectiveProducts,
      total: total > 0 ? total : effectiveProducts.length,
      totalPages: resolvedTotalPages > 0 ? resolvedTotalPages : 1,
      currentPage: resolvedPage,
      perPage: resolvedPerPage,
      hasMore: hasMore,
      fromCache: fromCache,
      cachedAt: cachedAt,
    );
  }

  List<ProductModel> _applyRequestedBrandFilter(
    List<ProductModel> products, {
    int? requiredBrandId,
    String? requiredBrandName,
  }) {
    if (products.isEmpty) {
      return products;
    }

    final expectedBrandId = requiredBrandId ?? 0;
    final expectedBrandName = TextNormalizer.normalize(
      requiredBrandName,
    ).toLowerCase();
    if (expectedBrandId <= 0 && expectedBrandName.isEmpty) {
      return products;
    }

    final hasBrandSignals = products.any(
      (product) =>
          (product.brandId ?? 0) > 0 || product.brandName.trim().isNotEmpty,
    );
    if (!hasBrandSignals) {
      return products;
    }

    final matches = products
        .where((product) {
          if (expectedBrandId > 0 && product.brandId == expectedBrandId) {
            return true;
          }

          if (expectedBrandName.isEmpty) {
            return false;
          }

          final actualBrandName = TextNormalizer.normalize(
            product.brandName,
          ).toLowerCase();
          if (actualBrandName.isEmpty) {
            return false;
          }

          return actualBrandName == expectedBrandName ||
              actualBrandName.contains(expectedBrandName) ||
              expectedBrandName.contains(actualBrandName);
        })
        .toList(growable: false);

    // If we cannot confidently match any row, keep the original payload
    // to avoid empty-result regressions on inconsistent backend data.
    return matches.isEmpty ? products : matches;
  }

  Future<void> _refreshProductsSilently({
    required String cacheKey,
    required Map<String, dynamic> queryParams,
  }) async {
    try {
      final response = await _client.get(
        Endpoints.productsPath,
        queryParameters: queryParams,
        options: Options(extra: const <String, dynamic>{'requiresAuth': false}),
      );

      await _cacheStore.saveJson(cacheKey, {
        'payload': _jsonSafe(response.data),
      }, DateTime.now());
    } catch (_) {
      // Keep stale cache when background refresh fails.
    }
  }

  Future<Map<String, dynamic>> _fetchProductsFromStoreApi({
    required int page,
    required int perPage,
    required String? search,
    required int? categoryId,
    required int? brandId,
    required String? brandName,
    required String? sort,
  }) async {
    final queryParams = _buildStoreApiQueryParams(
      page: page,
      perPage: perPage,
      search: search,
      categoryId: categoryId,
      brandId: brandId,
      brandName: brandName,
      sort: sort,
    );

    final response = await _client.get(
      _storeProductsPath,
      queryParameters: queryParams,
      options: Options(extra: const <String, dynamic>{'requiresAuth': false}),
    );

    final items = extractList(response.data);
    final total = parseInt(response.headers.value('x-wp-total'));
    final totalPages = parseInt(response.headers.value('x-wp-totalpages'));

    return <String, dynamic>{
      'items': items,
      'page': page,
      'per_page': perPage,
      'total': total > 0 ? total : items.length,
      'total_pages': totalPages > 0 ? totalPages : 1,
      'has_more': totalPages > 0 ? page < totalPages : items.length >= perPage,
      'source': 'woocommerce_store_api',
    };
  }

  Map<String, dynamic> _buildStoreApiQueryParams({
    required int page,
    required int perPage,
    required String? search,
    required int? categoryId,
    required int? brandId,
    required String? brandName,
    required String? sort,
  }) {
    final query = <String, dynamic>{'page': page, 'per_page': perPage};

    final normalizedSearch = (search ?? '').trim();
    final normalizedBrandName = (brandName ?? '').trim();
    if (normalizedSearch.isNotEmpty) {
      query['search'] = normalizedSearch;
    } else if ((brandId ?? 0) <= 0 && normalizedBrandName.isNotEmpty) {
      query['search'] = normalizedBrandName;
    }

    if ((categoryId ?? 0) > 0) {
      query['category'] = categoryId;
    }
    if ((brandId ?? 0) > 0) {
      query['brand'] = brandId;
    }

    switch ((sort ?? '').trim().toLowerCase()) {
      case 'price_asc':
        query['orderby'] = 'price';
        query['order'] = 'asc';
        break;
      case 'price_desc':
        query['orderby'] = 'price';
        query['order'] = 'desc';
        break;
      case 'top_rated':
        query['orderby'] = 'rating';
        query['order'] = 'desc';
        break;
      case 'best_selling':
        query['orderby'] = 'popularity';
        query['order'] = 'desc';
        break;
      case 'on_sale':
      case 'flash_deals':
        query['on_sale'] = true;
        query['orderby'] = 'date';
        query['order'] = 'desc';
        break;
      case 'manual':
        query['orderby'] = 'menu_order';
        query['order'] = 'asc';
        break;
      case 'newest':
      default:
        query['orderby'] = 'date';
        query['order'] = 'desc';
        break;
    }

    return query;
  }

  Future<void> _refreshProductDetailsSilently(
    String id,
    String cacheKey,
  ) async {
    try {
      final response = await _client.get(
        Endpoints.productById(id),
        options: Options(extra: const {'requiresAuth': false}),
      );
      await _cacheStore.saveJson(cacheKey, {
        'payload': _jsonSafe(response.data),
      }, DateTime.now());
      final item = _extractItem(response.data);
      if (item != null) {
        try {
          _saveProductDetailsMemory(ProductModel.fromJson(item));
        } catch (_) {
          // Ignore parse errors in background warm-up path.
        }
      }
    } catch (_) {
      // Keep stale cache when background refresh fails.
    }
  }

  ProductModel? _readProductDetailsMemory(String id) {
    final now = DateTime.now();
    _evictExpiredProductDetailsMemory(now);
    final entry = _productDetailsMemoryCache[id];
    if (entry == null) {
      return null;
    }
    if (entry.expiresAt.isBefore(now)) {
      _productDetailsMemoryCache.remove(id);
      return null;
    }
    return entry.model;
  }

  void _saveProductDetailsMemory(ProductModel model) {
    if (model.id <= 0) {
      return;
    }
    final now = DateTime.now();
    _evictExpiredProductDetailsMemory(now);
    _productDetailsMemoryCache['${model.id}'] = _ProductDetailsMemoryEntry(
      model: model,
      expiresAt: now.add(_detailsMemoryCacheTtl),
    );
  }

  void _saveProductDetailsMemoryBulk(Iterable<ProductModel> products) {
    final now = DateTime.now();
    _evictExpiredProductDetailsMemory(now);
    for (final model in products) {
      if (model.id <= 0) {
        continue;
      }
      _productDetailsMemoryCache['${model.id}'] = _ProductDetailsMemoryEntry(
        model: model,
        expiresAt: now.add(_detailsMemoryCacheTtl),
      );
    }
  }

  void _evictExpiredProductDetailsMemory(DateTime now) {
    final expired = _productDetailsMemoryCache.entries
        .where((entry) => entry.value.expiresAt.isBefore(now))
        .map((entry) => entry.key)
        .toList(growable: false);
    for (final key in expired) {
      _productDetailsMemoryCache.remove(key);
    }
  }

  Future<int?> _resolveProductIdBySlugRemote(String normalizedSlug) async {
    // 1) WooCommerce Store API supports exact slug lookup on public stores.
    try {
      final response = await _client.get(
        '/wp-json/wc/store/v1/products',
        queryParameters: {'slug': normalizedSlug, 'per_page': 1},
        options: Options(extra: const {'requiresAuth': false}),
      );
      final fromStoreApi = _extractProductIdFromCollection(
        response.data,
        expectedSlug: normalizedSlug,
      );
      if (fromStoreApi != null && fromStoreApi > 0) {
        return fromStoreApi;
      }
    } catch (_) {
      // Fallback below.
    }

    // 2) WP core products endpoint fallback (if exposed).
    try {
      final response = await _client.get(
        '/wp-json/wp/v2/product',
        queryParameters: {
          'slug': normalizedSlug,
          'per_page': 1,
          '_fields': 'id,slug,link',
        },
        options: Options(extra: const {'requiresAuth': false}),
      );
      final fromWpCore = _extractProductIdFromCollection(
        response.data,
        expectedSlug: normalizedSlug,
      );
      if (fromWpCore != null && fromWpCore > 0) {
        return fromWpCore;
      }
    } catch (_) {
      // Fallback below.
    }

    // 3) Lexi API search fallback. Useful when only Lexi routes are enabled.
    try {
      final response = await _client.get(
        Endpoints.productsPath,
        queryParameters: {
          'page': 1,
          'per_page': 24,
          'search': normalizedSlug.replaceAll('-', ' '),
        },
        options: Options(extra: const <String, dynamic>{'requiresAuth': false}),
      );
      final fromLexiSearch = _extractProductIdFromCollection(
        response.data,
        expectedSlug: normalizedSlug,
      );
      if (fromLexiSearch != null && fromLexiSearch > 0) {
        return fromLexiSearch;
      }
    } catch (_) {
      // Fall through to null.
    }

    return null;
  }

  bool _canUseStoreApiFallback(Object error) {
    if (error is! DioException) {
      return false;
    }

    final status = error.response?.statusCode ?? 0;
    if (status == 404 || status == 405) {
      return true;
    }
    if (status >= 500) {
      return true;
    }

    if (status == 403 && _looksLikeHtmlErrorBody(error.response?.data)) {
      return true;
    }

    if (status == 0) {
      return switch (error.type) {
        DioExceptionType.connectionError => true,
        DioExceptionType.connectionTimeout => true,
        DioExceptionType.receiveTimeout => true,
        DioExceptionType.sendTimeout => true,
        DioExceptionType.unknown => true,
        _ => false,
      };
    }

    return false;
  }

  bool _looksLikeHtmlErrorBody(dynamic body) {
    final text = (body ?? '').toString().toLowerCase();
    if (text.trim().isEmpty) {
      return false;
    }
    return text.contains('<html') ||
        text.contains('<!doctype html') ||
        text.contains('<title>');
  }

  (CacheKey, String) _buildListCacheKey({
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

    final keyType = categoryId != null || brandId != null
        ? CacheKey.productsByCategory
        : (normalizedSort == 'on_sale' || normalizedSort == 'flash_deals')
        ? CacheKey.homeDeals
        : CacheKey.homeProducts;

    final suffix =
        '$_listMediaCacheVersion|category:${categoryId ?? 0}|brand:${brandId ?? 0}|brand_name:$normalizedBrandName|page:$page|per_page:$perPage|sort:${normalizedSort.isEmpty ? 'manual' : normalizedSort}|search:$normalizedSearch';

    return (keyType, CachePolicy.key(keyType, suffix: suffix));
  }

  Map<String, dynamic> _extractMeta(dynamic json) {
    if (json is Map) {
      final jsonMap = Map<String, dynamic>.from(json);
      // Check if it's `{ success: ..., data: { ... } }`
      if (jsonMap.containsKey('data') && jsonMap['data'] is Map) {
        return Map<String, dynamic>.from(jsonMap['data']);
      }
      return jsonMap;
    }

    return const {};
  }

  Map<String, dynamic>? _extractItem(dynamic json) {
    if (json is Map) {
      final data = json['data'];
      if (data is Map) {
        return Map<String, dynamic>.from(data);
      }
      return Map<String, dynamic>.from(json);
    }

    return null;
  }

  int? _extractProductIdFromCollection(
    dynamic payload, {
    required String expectedSlug,
  }) {
    final items = extractList(payload);
    int? firstId;

    for (final item in items) {
      if (item is! Map) {
        continue;
      }

      final map = Map<String, dynamic>.from(item);
      final id = parseInt(map['id']);
      if (id <= 0) {
        continue;
      }

      firstId ??= id;

      final rawSlug = _normalizeSlug(
        map['slug'] ?? map['post_name'] ?? map['product_slug'],
      );
      if (rawSlug == expectedSlug) {
        return id;
      }

      final permalinkSlug = _normalizeSlug(
        _extractLastPathSegment(map['permalink'] ?? map['link']),
      );
      if (permalinkSlug == expectedSlug) {
        return id;
      }

      final nameSlug = _slugifyName(TextNormalizer.normalize(map['name']));
      if (nameSlug == expectedSlug) {
        return id;
      }
    }

    return firstId;
  }

  String _extractLastPathSegment(dynamic rawUrl) {
    final value = rawUrl?.toString().trim() ?? '';
    if (value.isEmpty) {
      return '';
    }

    final parsed = Uri.tryParse(value);
    if (parsed != null && parsed.pathSegments.isNotEmpty) {
      final nonEmpty = parsed.pathSegments
          .where((segment) => segment.trim().isNotEmpty)
          .toList(growable: false);
      if (nonEmpty.isNotEmpty) {
        return nonEmpty.last;
      }
    }

    return value;
  }

  String _normalizeSlug(dynamic raw) {
    final source = (raw ?? '').toString();
    String decoded;
    try {
      decoded = Uri.decodeComponent(source);
    } catch (_) {
      decoded = source;
    }
    final value = decoded.trim();
    if (value.isEmpty) {
      return '';
    }
    return value.toLowerCase();
  }

  String _slugifyName(String value) {
    final lower = value.trim().toLowerCase();
    if (lower.isEmpty) {
      return '';
    }

    return lower
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'-{2,}'), '-')
        .replaceAll(RegExp(r'^-|-$'), '');
  }

  dynamic _jsonSafe(dynamic payload) {
    return jsonDecode(jsonEncode(payload));
  }

  void _logParseError({
    required String where,
    required Object error,
    StackTrace? stackTrace,
    dynamic payload,
  }) {
    if (!kDebugMode) {
      return;
    }

    final payloadText = payload?.toString() ?? '';
    final snippet = payloadText.length <= 500
        ? payloadText
        : '${payloadText.substring(0, 500)}...';

    debugPrint('[API][PARSE][$where] $error');
    if (snippet.isNotEmpty) {
      debugPrint('[API][PARSE][$where][PAYLOAD] $snippet');
    }
    if (stackTrace != null) {
      debugPrint('[API][PARSE][$where][STACK] $stackTrace');
    }
  }
}

class _ProductDetailsMemoryEntry {
  final ProductModel model;
  final DateTime expiresAt;

  const _ProductDetailsMemoryEntry({
    required this.model,
    required this.expiresAt,
  });
}

/// Wrapper for paginated product list responses.
class ProductListResponse {
  final List<ProductModel> products;
  final int total;
  final int totalPages;
  final int currentPage;
  final int perPage;
  final bool hasMore;
  final bool fromCache;
  final DateTime? cachedAt;

  const ProductListResponse({
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
