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
  static final Map<String, int> _slugToIdMemoryCache = <String, int>{};

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
        options: Options(extra: const {'requiresAuth': false}),
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
    } catch (_) {
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
      rethrow;
    }
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
    final cacheKey = CachePolicy.key(CacheKey.productDetails, suffix: 'id_$id');
    final cached = await _cacheStore.readJson(cacheKey);

    if (preferCache && cached != null) {
      unawaited(_refreshProductDetailsSilently(id, cacheKey));
      final item = _extractItem(cached.data['payload']);
      if (item != null) {
        return ProductModel.fromJson(item);
      }
    }

    try {
      final response = await _client.get(
        Endpoints.productById(id),
        options: Options(extra: const {'requiresAuth': false}),
      );

      await _cacheStore.saveJson(cacheKey, {
        'payload': _jsonSafe(response.data),
      }, DateTime.now());

      final item = _extractItem(response.data);
      if (item == null) {
        _logParseError(
          where: 'product/$id',
          error: 'Unable to resolve product object from response',
          payload: response.data,
        );
        throw const FormatException('Invalid product response shape');
      }

      try {
        return ProductModel.fromJson(item);
      } catch (e, st) {
        _logParseError(
          where: 'product/$id',
          error: e,
          stackTrace: st,
          payload: item,
        );
        rethrow;
      }
    } catch (_) {
      if (cached != null) {
        final item = _extractItem(cached.data['payload']);
        if (item != null) {
          return ProductModel.fromJson(item);
        }
      }
      rethrow;
    }
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
      if (requiredCategoryId != null &&
          requiredCategoryId > 0 &&
          !_itemBelongsToCategory(itemMap, requiredCategoryId)) {
        continue;
      }
      if (requiredBrandId != null &&
          requiredBrandId > 0 &&
          !_itemBelongsToBrand(itemMap, requiredBrandId)) {
        continue;
      }
      final shouldFilterByBrandName =
          (requiredBrandId == null || requiredBrandId <= 0) &&
          requiredBrandName != null &&
          requiredBrandName.trim().isNotEmpty;
      final normalizedRequiredBrandName = requiredBrandName ?? '';
      if (shouldFilterByBrandName &&
          !_itemBelongsToBrandName(itemMap, normalizedRequiredBrandName)) {
        continue;
      }

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
        : products.length >= resolvedPerPage;

    return ProductListResponse(
      products: products,
      total: total > 0 ? total : products.length,
      totalPages: resolvedTotalPages > 0 ? resolvedTotalPages : 1,
      currentPage: resolvedPage,
      perPage: resolvedPerPage,
      hasMore: hasMore,
      fromCache: fromCache,
      cachedAt: cachedAt,
    );
  }

  bool _itemBelongsToCategory(Map<String, dynamic> item, int categoryId) {
    final rawCategoryIds = item['category_ids'];
    if (rawCategoryIds is List) {
      for (final rawId in rawCategoryIds) {
        if (parseInt(rawId) == categoryId) {
          return true;
        }
      }
    }

    final rawCategories = item['categories'];
    if (rawCategories is List) {
      for (final rawCategory in rawCategories) {
        if (rawCategory is Map) {
          if (parseInt(rawCategory['id']) == categoryId) {
            return true;
          }
          continue;
        }
        if (parseInt(rawCategory) == categoryId) {
          return true;
        }
      }
    }

    return false;
  }

  bool _itemBelongsToBrand(Map<String, dynamic> item, int brandId) {
    if (parseInt(item['brand_id']) == brandId) {
      return true;
    }

    bool containsBrandId(dynamic value) {
      if (value == null) return false;

      if (value is List) {
        for (final item in value) {
          if (containsBrandId(item)) {
            return true;
          }
        }
        return false;
      }

      if (value is Map) {
        final map = Map<String, dynamic>.from(value);
        if (parseInt(map['id']) == brandId ||
            parseInt(map['term_id']) == brandId ||
            parseInt(map['brand_id']) == brandId) {
          return true;
        }
        return false;
      }

      return parseInt(value) == brandId;
    }

    return containsBrandId(item['brand']) || containsBrandId(item['brands']);
  }

  bool _itemBelongsToBrandName(Map<String, dynamic> item, String brandName) {
    final normalizedTarget = brandName.trim().toLowerCase();
    if (normalizedTarget.isEmpty) {
      return true;
    }

    bool containsBrandName(dynamic value) {
      if (value == null) {
        return false;
      }
      if (value is List) {
        for (final entry in value) {
          if (containsBrandName(entry)) {
            return true;
          }
        }
        return false;
      }
      if (value is Map) {
        final map = Map<String, dynamic>.from(value);
        final candidates = <String>[
          (map['name'] ?? '').toString(),
          (map['title'] ?? '').toString(),
          (map['label'] ?? '').toString(),
          (map['brand_name'] ?? '').toString(),
          (map['slug'] ?? '').toString(),
        ];
        for (final candidate in candidates) {
          final normalized = candidate.trim().toLowerCase();
          if (normalized.isNotEmpty &&
              (normalized == normalizedTarget ||
                  normalized.contains(normalizedTarget) ||
                  normalizedTarget.contains(normalized))) {
            return true;
          }
        }
        return false;
      }

      final normalized = value.toString().trim().toLowerCase();
      if (normalized.isEmpty) {
        return false;
      }
      return normalized == normalizedTarget ||
          normalized.contains(normalizedTarget) ||
          normalizedTarget.contains(normalized);
    }

    return containsBrandName(item['brand']) ||
        containsBrandName(item['brands']) ||
        containsBrandName(item['brand_name']);
  }

  Future<void> _refreshProductsSilently({
    required String cacheKey,
    required Map<String, dynamic> queryParams,
  }) async {
    try {
      final response = await _client.get(
        Endpoints.productsPath,
        queryParameters: queryParams,
        options: Options(extra: const {'requiresAuth': false}),
      );

      await _cacheStore.saveJson(cacheKey, {
        'payload': _jsonSafe(response.data),
      }, DateTime.now());
    } catch (_) {
      // Keep stale cache when background refresh fails.
    }
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
    } catch (_) {
      // Keep stale cache when background refresh fails.
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
        options: Options(extra: const {'requiresAuth': false}),
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
        'category:${categoryId ?? 0}|brand:${brandId ?? 0}|brand_name:$normalizedBrandName|page:$page|per_page:$perPage|sort:${normalizedSort.isEmpty ? 'manual' : normalizedSort}|search:$normalizedSearch';

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
