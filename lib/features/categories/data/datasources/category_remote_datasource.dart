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
  final DioClient _client;
  final CacheStore _cacheStore;

  CategoryRemoteDatasource({
    required DioClient client,
    required CacheStore cacheStore,
  }) : _client = client,
       _cacheStore = cacheStore;

  /// Fetches all categories.
  Future<List<CategoryModel>> getCategories({bool preferCache = true}) async {
    final cacheKey = CachePolicy.key(CacheKey.categoriesList);
    final cached = await _cacheStore.readJson(cacheKey);

    if (preferCache && cached != null) {
      unawaited(_refreshCategoriesSilently());
      return _parseCategoryList(cached.data['payload']);
    }

    try {
      final response = await _client.get(
        Endpoints.categoriesPath,
        queryParameters: const {'include_empty': 1},
        options: Options(extra: const {'requiresAuth': false}),
      );

      await _cacheStore.saveJson(cacheKey, {
        'payload': _jsonSafe(response.data),
      }, DateTime.now());

      return _parseCategoryList(response.data);
    } catch (_) {
      if (cached != null) {
        return _parseCategoryList(cached.data['payload']);
      }
      rethrow;
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
        queryParameters: const {'include_empty': 1},
        options: Options(extra: const {'requiresAuth': false}),
      );
      await _cacheStore.saveJson(CachePolicy.key(CacheKey.categoriesList), {
        'payload': _jsonSafe(response.data),
      }, DateTime.now());
    } catch (_) {
      // Keep stale cache when background refresh fails.
    }
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
