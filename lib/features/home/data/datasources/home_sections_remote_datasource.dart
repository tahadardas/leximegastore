import 'dart:async';
import 'dart:convert';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../config/constants/endpoints.dart';
import '../../../../core/cache/cache_policy.dart';
import '../../../../core/cache/cache_store.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../core/utils/safe_parsers.dart';
import '../../../../core/utils/text_normalizer.dart';
import '../../../product/data/models/product_model.dart';
import '../../../product/domain/entities/product_entity.dart';
import '../../../product/domain/entities/product_mapper.dart';
import '../models/home_ad_banner_model.dart';
import '../models/home_section_model.dart';

final homeSectionsRemoteDatasourceProvider =
    Provider<HomeSectionsRemoteDatasource>((ref) {
      return HomeSectionsRemoteDatasource(
        ref.watch(dioClientProvider),
        cacheStore: ref.watch(cacheStoreProvider),
      );
    });

class HomeSectionsRemoteDatasource {
  final DioClient _client;
  final CacheStore _cacheStore;
  final Connectivity _connectivity = Connectivity();

  HomeSectionsRemoteDatasource(this._client, {required CacheStore cacheStore})
    : _cacheStore = cacheStore;

  Future<List<HomeSectionModel>> getSections({bool preferCache = true}) async {
    final cacheKey = CachePolicy.key(CacheKey.homeProducts);
    final hasConnection = await _hasConnection();
    final cached = preferCache ? await _cacheStore.readJson(cacheKey) : null;

    // 1) Fast path for offline mode: serve cache if available.
    if (!hasConnection) {
      if (cached != null) {
        return _parseSections(cached.data['payload']);
      }
      // IMPORTANT: Do not hard-fail to empty here.
      // Some Android devices report transient "none" on connectivity checks
      // while network is actually available. We still try one network fetch.
    }

    // 2) Online/cache-first path.
    if (preferCache && cached != null) {
      // Return cached and refresh silently in background.
      unawaited(_refreshHomeCacheSilently());
      return _parseSections(cached.data['payload']);
    }

    try {
      final payload = await _fetchSectionsPayload();
      await _saveHomePayload(payload);
      final sections = _parseSections(payload);

      if (sections.isNotEmpty) {
        return sections;
      }

      final fallbackProducts = await _getFallbackProducts();
      if (fallbackProducts.isNotEmpty) {
        return [
          HomeSectionModel(
            id: 0,
            titleAr: 'كل المنتجات',
            type: 'fallback_all_products',
            sortOrder: 0,
            termId: null,
            items: fallbackProducts,
          ),
        ];
      }

      return const [];
    } catch (error) {
      // 3. Network Fetch Failed: Fallback to cache even if preferCache was false
      final fallbackCache = await _cacheStore.readJson(cacheKey);
      if (fallbackCache != null) {
        return _parseSections(fallbackCache.data['payload']);
      }

      // 4) Final graceful fallback: try generic products feed so the home page
      // can still render content instead of failing hard.
      final fallbackProducts = _shouldUseProductFeedFallback(error)
          ? await _getFallbackProducts()
          : const <ProductEntity>[];
      if (fallbackProducts.isNotEmpty) {
        return [
          HomeSectionModel(
            id: 0,
            titleAr: 'كل المنتجات',
            type: 'fallback_all_products',
            sortOrder: 0,
            termId: null,
            items: fallbackProducts,
          ),
        ];
      }

      return const [];
    }
  }

  Future<List<HomeAdBannerModel>> getAdBanners({
    bool preferCache = true,
  }) async {
    final cacheKey = CachePolicy.key(CacheKey.homeAdBanners);
    final cached = preferCache ? await _cacheStore.readJson(cacheKey) : null;

    if (preferCache && cached != null) {
      unawaited(_refreshAdBannersCacheSilently());
      return _parseAdBanners(cached.data['payload']);
    }

    try {
      final payload = await _fetchAdBannersPayload();
      await _saveAdBannersPayload(payload);
      return _parseAdBanners(payload);
    } catch (_) {
      if (cached != null) {
        return _parseAdBanners(cached.data['payload']);
      }
      return const [];
    }
  }

  Future<dynamic> _fetchSectionsPayload() async {
    final response = await _client.get(
      Endpoints.homeSections(),
      options: Options(extra: const {'requiresAuth': false}),
    );
    return _jsonSafe(response.data);
  }

  Future<dynamic> _fetchAdBannersPayload() async {
    final response = await _client.get(
      Endpoints.homeAdBanners(),
      options: Options(extra: const {'requiresAuth': false}),
    );
    return _jsonSafe(response.data);
  }

  Future<void> _refreshHomeCacheSilently() async {
    final hasConnection = await _hasConnection();
    if (!hasConnection) {
      return;
    }

    try {
      final payload = await _fetchSectionsPayload();
      await _saveHomePayload(payload);
    } catch (_) {
      // Keep stale cache when background refresh fails.
    }
  }

  Future<void> _refreshAdBannersCacheSilently() async {
    final hasConnection = await _hasConnection();
    if (!hasConnection) {
      return;
    }

    try {
      final payload = await _fetchAdBannersPayload();
      await _saveAdBannersPayload(payload);
    } catch (_) {
      // Keep stale banner cache when background refresh fails.
    }
  }

  Future<void> _saveHomePayload(dynamic payload) async {
    final now = DateTime.now();
    final jsonPayload = _jsonSafe(payload);

    await _cacheStore.saveJson(CachePolicy.key(CacheKey.homeProducts), {
      'payload': jsonPayload,
    }, now);

    final products = _extractProductRows(jsonPayload);
    await _cacheStore.saveJson(CachePolicy.key(CacheKey.homeDeals), {
      'payload': _extractDeals(products),
    }, now);

    await _cacheStore.saveJson(CachePolicy.key(CacheKey.homeCategories), {
      'payload': jsonPayload,
    }, now);
  }

  Future<void> _saveAdBannersPayload(dynamic payload) async {
    await _cacheStore.saveJson(CachePolicy.key(CacheKey.homeAdBanners), {
      'payload': _jsonSafe(payload),
    }, DateTime.now());
  }

  List<HomeSectionModel> _parseSections(dynamic payload) {
    final rows = extractList(payload);
    final sections = <HomeSectionModel>[];

    for (final row in rows) {
      if (row is! Map) {
        continue;
      }

      final map = Map<String, dynamic>.from(row);
      final products = _extractProductsFromSection(map);

      sections.add(
        HomeSectionModel(
          id: parseInt(map['id']),
          titleAr: TextNormalizer.normalize(map['title_ar']),
          type: (map['type'] ?? 'manual_products').toString(),
          sortOrder: parseInt(map['sort_order']),
          termId: map['term_id'] == null ? null : parseInt(map['term_id']),
          isActive: map['is_active'] != false,
          items: products,
        ),
      );
    }

    if (sections.isNotEmpty) {
      return sections;
    }

    final products = _extractProductsFromSection({
      'items': _extractProductRows(payload),
    });
    if (products.isEmpty) {
      return const [];
    }

    return [
      HomeSectionModel(
        id: 0,
        titleAr: 'كل المنتجات',
        type: 'fallback_all_products',
        sortOrder: 0,
        termId: null,
        items: products,
      ),
    ];
  }

  List<HomeAdBannerModel> _parseAdBanners(dynamic payload) {
    final rows = extractList(payload);
    return rows
        .whereType<Map>()
        .map(
          (row) => HomeAdBannerModel.fromJson(Map<String, dynamic>.from(row)),
        )
        .where((item) => item.imageUrl.trim().isNotEmpty)
        .toList(growable: false);
  }

  List<ProductEntity> _extractProductsFromSection(
    Map<String, dynamic> section,
  ) {
    final itemsRaw = extractList(section['items']);
    final items = <ProductEntity>[];

    for (final item in itemsRaw) {
      if (item is! Map<String, dynamic>) {
        continue;
      }
      items.add(ProductModel.fromJson(item).toEntity());
    }

    return items;
  }

  List<Map<String, dynamic>> _extractProductRows(dynamic payload) {
    final rows = extractList(payload);
    final products = <Map<String, dynamic>>[];

    for (final row in rows) {
      if (row is! Map) {
        continue;
      }
      final section = Map<String, dynamic>.from(row);
      final items = extractList(section['items']);
      for (final item in items) {
        if (item is Map<String, dynamic>) {
          products.add(item);
        }
      }
    }

    return products;
  }

  List<Map<String, dynamic>> _extractDeals(
    List<Map<String, dynamic>> products,
  ) {
    final deals = <Map<String, dynamic>>[];

    for (final item in products) {
      final regular = parseDouble(item['regular_price']);
      final sale = parseDouble(item['sale_price']);
      if (sale > 0 && sale < regular) {
        deals.add(item);
      }
      if (deals.length >= 24) {
        break;
      }
    }

    return deals;
  }

  Future<List<dynamic>> _rawFallbackRows() async {
    final response = await _client.get(
      Endpoints.productsPath,
      queryParameters: const {'page': 1, 'per_page': 20, 'sort': 'newest'},
      options: Options(extra: const {'requiresAuth': false}),
    );
    return extractList(response.data);
  }

  Future<List<ProductEntity>> _getFallbackProducts() async {
    try {
      final rows = await _rawFallbackRows();
      final products = <ProductEntity>[];
      for (final row in rows) {
        if (row is! Map<String, dynamic>) {
          continue;
        }
        products.add(ProductModel.fromJson(row).toEntity());
      }
      return products;
    } catch (_) {
      return const [];
    }
  }

  bool _shouldUseProductFeedFallback(Object error) {
    if (error is! DioException) {
      return false;
    }

    final status = error.response?.statusCode ?? 0;
    if (status >= 500 && status < 600) {
      return true;
    }

    return status == 404 || status == 405;
  }

  Future<bool> _hasConnection() async {
    try {
      final results = await _connectivity.checkConnectivity();
      if (results.isEmpty) {
        return false;
      }
      return results.any((item) => item != ConnectivityResult.none);
    } catch (_) {
      // Fail-open: if connectivity plugin throws unexpectedly,
      // allow network request attempt instead of hard-offline state.
      return true;
    }
  }

  dynamic _jsonSafe(dynamic payload) {
    return jsonDecode(jsonEncode(payload));
  }
}
