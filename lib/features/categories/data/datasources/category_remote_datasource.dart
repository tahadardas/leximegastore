import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../../../config/constants/endpoints.dart';
import '../../../../core/cache/cache_policy.dart';
import '../../../../core/cache/cache_store.dart';
import '../../../../core/network/dio_client.dart';
import '../models/category_model.dart';

/// Remote data source for Categories.
class CategoryRemoteDatasource {
  static const String _categoriesCacheVersion = 'wp_admin_ordered_v2';
  static const String _storeCategoriesPath =
      '/wp-json/wc/store/v1/products/categories';
  static const Duration _freshCategoriesCacheTtl = Duration(minutes: 2);

  final DioClient _client;
  final CacheStore _cacheStore;

  CategoryRemoteDatasource({
    required DioClient client,
    required CacheStore cacheStore,
  }) : _client = client,
       _cacheStore = cacheStore;

  /// Fetches all categories.
  Future<List<CategoryModel>> getCategories({bool preferCache = true}) async {
    final cacheKey = _categoriesCacheKey;
    final cached = await _cacheStore.readJson(cacheKey);
    final hasFreshCache =
        cached != null &&
        DateTime.now().difference(cached.savedAt) <= _freshCategoriesCacheTtl;

    if (preferCache && hasFreshCache) {
      unawaited(_refreshCategoriesSilently());
      return _parseCategoryList(cached.data['payload']);
    }

    try {
      final response = await _client.get(
        Endpoints.categoriesPath,
        queryParameters: _categoryQueryParameters,
        options: _publicNoCacheOptions,
      );
      final payload = await _normalizeCategoriesPayload(response.data);

      await _cacheStore.saveJson(cacheKey, {
        'payload': _jsonSafe(payload),
      }, DateTime.now());

      return _parseCategoryList(payload);
    } catch (error, stackTrace) {
      try {
        final fallbackPayload = await _fetchStoreCategories();
        final payload = await _normalizeCategoriesPayload(fallbackPayload);

        await _cacheStore.saveJson(cacheKey, {
          'payload': _jsonSafe(payload),
        }, DateTime.now());

        return _parseCategoryList(payload);
      } catch (_) {
        // Fall back to the normal cache/error path below.
      }

      if (cached != null) {
        return _parseCategoryList(cached.data['payload']);
      }
      Error.throwWithStackTrace(error, stackTrace);
    }
  }

  /// Fetches a single category by [id].
  Future<CategoryModel> getCategoryById(
    String id, {
    bool preferCache = true,
  }) async {
    final cacheKey = CachePolicy.key(CacheKey.categoriesList, suffix: 'id_$id');
    final cached = await _cacheStore.readJson(cacheKey);

    if (preferCache && cached != null) {
      final item = _extractItem(cached.data['payload']);
      if (item != null) {
        return CategoryModel.fromJson(item);
      }
    }

    try {
      final response = await _client.get(
        Endpoints.categoryById(id),
        options: Options(extra: const {'requiresAuth': false}),
      );

      await _cacheStore.saveJson(cacheKey, {
        'payload': _jsonSafe(response.data),
      }, DateTime.now());

      final item = _extractItem(response.data);
      if (item == null) {
        _logParseError(
          where: 'category/$id',
          error: 'Unable to resolve category object from response',
          payload: response.data,
        );
        throw const FormatException('Invalid category response shape');
      }

      try {
        return CategoryModel.fromJson(item);
      } catch (e, st) {
        _logParseError(
          where: 'category/$id',
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
          return CategoryModel.fromJson(item);
        }
      }
      rethrow;
    }
  }

  Future<void> _refreshCategoriesSilently() async {
    try {
      final response = await _client.get(
        Endpoints.categoriesPath,
        queryParameters: _categoryQueryParameters,
        options: _publicNoCacheOptions,
      );
      final payload = await _normalizeCategoriesPayload(response.data);
      await _cacheStore.saveJson(_categoriesCacheKey, {
        'payload': _jsonSafe(payload),
      }, DateTime.now());
    } catch (_) {
      // Keep stale cache when background refresh fails.
    }
  }

  Future<List<dynamic>> _fetchStoreCategories() async {
    final categories = <dynamic>[];
    var page = 1;
    var totalPages = 1;

    do {
      final response = await _client.get(
        _storeCategoriesPath,
        queryParameters: <String, dynamic>{
          'page': page,
          'per_page': 100,
          ..._localWebCorsCacheKey,
        },
        options: _publicNoCacheOptions,
      );

      categories.addAll(extractList(response.data));
      final headerTotalPages = int.tryParse(
        response.headers.value('x-wp-totalpages') ?? '',
      );
      totalPages = headerTotalPages != null && headerTotalPages > 0
          ? headerTotalPages
          : 1;
      page++;
    } while (page <= totalPages && page <= 20);

    return categories;
  }

  String get _categoriesCacheKey =>
      CachePolicy.key(CacheKey.categoriesList, suffix: _categoriesCacheVersion);

  Map<String, dynamic> get _categoryQueryParameters {
    return <String, dynamic>{
      'include_empty': 1,
      'view': 'admin_ordered',
      ..._localWebCorsCacheKey,
    };
  }

  Options get _publicNoCacheOptions {
    return Options(extra: const {'requiresAuth': false});
  }

  Map<String, String> get _localWebCorsCacheKey {
    if (!_isLocalWebOrigin) {
      return const <String, String>{};
    }

    final origin = Uri.base;
    final port = origin.hasPort ? origin.port.toString() : 'default';
    return <String, String>{
      '_lexi_web_origin': '${origin.scheme}_${origin.host}_$port',
    };
  }

  bool get _isLocalWebOrigin {
    if (!kIsWeb) {
      return false;
    }

    final host = Uri.base.host.toLowerCase();
    return host == 'localhost' || host == '127.0.0.1' || host == '::1';
  }

  Future<dynamic> _normalizeCategoriesPayload(dynamic payload) async {
    final rawList = extractList(payload);
    if (rawList.isEmpty) {
      return payload;
    }

    if (_hasServerOrdering(rawList)) {
      return rawList;
    }

    final normalized = rawList
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList(growable: false);
    if (normalized.isEmpty) {
      return rawList;
    }

    normalized.sort(_compareRawCategories);
    for (var index = 0; index < normalized.length; index++) {
      final category = normalized[index];
      if (!category.containsKey('order_index')) {
        category['order_index'] = index;
      }
      if (!category.containsKey('admin_order_index')) {
        category['admin_order_index'] = category['order_index'];
      }
    }
    return normalized;
  }

  bool _hasServerOrdering(List<dynamic> rows) {
    for (final row in rows) {
      if (row is! Map) {
        continue;
      }
      final map = Map<String, dynamic>.from(row);
      if (map.containsKey('categories_page_order_index') ||
          map.containsKey('admin_order_index') ||
          map.containsKey('order_index') ||
          map.containsKey('sort_order')) {
        return true;
      }
    }
    return false;
  }

  @visibleForTesting
  static List<dynamic> orderCategoriesByPageSlugs(
    List<dynamic> rawList,
    List<String> pageSlugs,
  ) {
    final categories = rawList
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList(growable: false);
    if (categories.isEmpty || pageSlugs.isEmpty) {
      return rawList;
    }

    final topLevelBySlug = <String, Map<String, dynamic>>{};
    final topLevelCategories = <Map<String, dynamic>>[];
    final childrenByParent = <int, List<Map<String, dynamic>>>{};

    for (final category in categories) {
      final parentId = _readInt(
        category['parent'] ?? category['parent_id'] ?? category['parentId'],
      );
      if (parentId <= 0) {
        topLevelCategories.add(category);
        final slug = (category['slug'] ?? '').toString().trim();
        if (slug.isNotEmpty) {
          topLevelBySlug[slug] = category;
        }
        continue;
      }

      childrenByParent
          .putIfAbsent(parentId, () => <Map<String, dynamic>>[])
          .add(category);
    }

    for (final siblings in childrenByParent.values) {
      siblings.sort(_compareRawCategories);
    }

    final ordered = <Map<String, dynamic>>[];
    final visited = <int>{};

    void appendWithChildren(Map<String, dynamic> category) {
      final id = _readInt(category['id']);
      if (id <= 0 || !visited.add(id)) {
        return;
      }

      category['categories_page_order_index'] = ordered.length;
      category['order_index'] = ordered.length;
      ordered.add(category);

      final children = childrenByParent[id] ?? const <Map<String, dynamic>>[];
      for (final child in children) {
        appendWithChildren(child);
      }
    }

    for (final slug in pageSlugs) {
      final category = topLevelBySlug[slug];
      if (category != null) {
        appendWithChildren(category);
      }
    }

    for (final category in topLevelCategories) {
      appendWithChildren(category);
    }

    for (final category in categories) {
      appendWithChildren(category);
    }

    return ordered.isNotEmpty ? ordered : rawList;
  }

  static int _compareRawCategories(
    Map<String, dynamic> a,
    Map<String, dynamic> b,
  ) {
    final orderCompare = _readSortOrder(a).compareTo(_readSortOrder(b));
    if (orderCompare != 0) {
      return orderCompare;
    }
    return (a['name'] ?? '').toString().compareTo((b['name'] ?? '').toString());
  }

  static int _readSortOrder(Map<String, dynamic> category) {
    return _readInt(
      category['categories_page_order_index'] ??
          category['admin_order_index'] ??
          category['order_index'] ??
          category['sort_order'],
    );
  }

  static int _readInt(dynamic value) {
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    return int.tryParse((value ?? '').toString().trim()) ?? 0;
  }

  List<CategoryModel> _parseCategoryList(dynamic payload) {
    final rawList = extractList(payload);
    final categories = <CategoryModel>[];

    for (var i = 0; i < rawList.length; i++) {
      final item = rawList[i];

      if (item is! Map) {
        _logParseError(
          where: 'categories[$i]',
          error: 'Expected JSON object but found ${item.runtimeType}',
          payload: item,
        );
        continue;
      }

      try {
        categories.add(CategoryModel.fromJson(Map<String, dynamic>.from(item)));
      } catch (e, st) {
        _logParseError(
          where: 'categories[$i]',
          error: e,
          stackTrace: st,
          payload: item,
        );
      }
    }

    return categories;
  }

  Map<String, dynamic>? _extractItem(dynamic json) {
    if (json is Map) {
      final jsonMap = Map<String, dynamic>.from(json);
      // Check if it's `{ success: ..., data: { ... } }`
      if (jsonMap.containsKey('data') && jsonMap['data'] is Map) {
        return Map<String, dynamic>.from(jsonMap['data']);
      }
      return jsonMap;
    }

    return null;
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
