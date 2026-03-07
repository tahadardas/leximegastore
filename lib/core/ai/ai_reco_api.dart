import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../config/constants/endpoints.dart';
import '../../core/device/device_id_provider.dart';
import '../../core/network/dio_client.dart';
import '../../core/session/app_session.dart';
import '../../features/product/data/models/product_model.dart';
import '../../features/product/domain/entities/product_entity.dart';
import '../../features/product/domain/entities/product_mapper.dart';

/// AI Recommendation API provider
final aiRecoApiProvider = Provider<AIRecoApi>((ref) {
  return AIRecoApi(
    ref.watch(dioClientProvider),
    ref.watch(appSessionProvider),
    ref.watch(deviceIdProvider),
  );
});

/// AI Recommendation API
class AIRecoApi {
  final DioClient _client;
  final AppSession _session;
  final AsyncValue<String> _deviceIdValue;

  AIRecoApi(this._client, this._session, this._deviceIdValue);

  /// Get "For You" personalized recommendations
  Future<List<ProductEntity>> getForYou({int limit = 20}) async {
    final queryParams = <String, dynamic>{};

    // Add device_id for guests
    if (!_session.isLoggedIn) {
      final deviceId = _deviceIdValue.valueOrNull;
      if (deviceId != null) {
        queryParams['device_id'] = deviceId;
      }
    }

    final response = await _client.get(
      Endpoints.aiForYou(limit: limit),
      queryParameters: queryParams.isEmpty ? null : queryParams,
      options: Options(extra: const {'requiresAuth': false}),
    );

    return _parseProductList(response.data);
  }

  /// Get similar products
  Future<List<ProductEntity>> getSimilar(
    int productId, {
    int limit = 12,
  }) async {
    final response = await _client.get(
      Endpoints.aiSimilar(productId, limit: limit),
      options: Options(extra: const {'requiresAuth': false}),
    );

    return _parseProductList(response.data);
  }

  /// Get trending products
  Future<List<ProductEntity>> getTrending({
    String range = '24h',
    int limit = 20,
  }) async {
    final response = await _client.get(
      Endpoints.aiTrending(range: range, limit: limit),
      options: Options(extra: const {'requiresAuth': false}),
    );

    return _parseProductList(response.data);
  }

  /// Get frequently bought together (bundles)
  Future<List<ProductEntity>> getBundles(
    int productId, {
    int limit = 10,
  }) async {
    final response = await _client.get(
      Endpoints.aiBundles(productId, limit: limit),
      options: Options(extra: const {'requiresAuth': false}),
    );

    return _parseProductList(response.data);
  }

  List<ProductEntity> _parseProductList(dynamic data) {
    final list = extractList(data);
    return list
        .map((e) => ProductModel.fromJson(e as Map<String, dynamic>).toEntity())
        .toList();
  }
}

/// AI Recommendation Repository provider
final aiRecoRepositoryProvider = Provider<AIRecoRepository>((ref) {
  return AIRecoRepository(ref.watch(aiRecoApiProvider));
});

/// AI Recommendation Repository
class AIRecoRepository {
  final AIRecoApi _api;

  AIRecoRepository(this._api);

  Future<List<ProductEntity>> getForYou({int limit = 20}) {
    return _api.getForYou(limit: limit);
  }

  Future<List<ProductEntity>> getSimilar(int productId, {int limit = 12}) {
    return _api.getSimilar(productId, limit: limit);
  }

  Future<List<ProductEntity>> getTrending({
    String range = '24h',
    int limit = 20,
  }) {
    return _api.getTrending(range: range, limit: limit);
  }

  Future<List<ProductEntity>> getBundles(int productId, {int limit = 10}) {
    return _api.getBundles(productId, limit: limit);
  }
}

/// For You recommendations provider
final forYouProductsProvider = FutureProvider<List<ProductEntity>>((ref) {
  return ref.read(aiRecoRepositoryProvider).getForYou();
});

/// Trending products provider
final trendingProductsProvider = FutureProvider<List<ProductEntity>>((ref) {
  return ref.read(aiRecoRepositoryProvider).getTrending();
});

/// Similar products provider family
final similarProductsProvider = FutureProvider.family<List<ProductEntity>, int>(
  (ref, productId) {
    return ref.read(aiRecoRepositoryProvider).getSimilar(productId);
  },
);

/// Bundles provider family
final bundlesProductsProvider = FutureProvider.family<List<ProductEntity>, int>(
  (ref, productId) {
    return ref.read(aiRecoRepositoryProvider).getBundles(productId);
  },
);
