import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/admin_intel_models.dart';
import '../datasources/admin_intel_remote_datasource.dart';

final adminIntelRepositoryProvider = Provider<AdminIntelRepository>((ref) {
  return AdminIntelRepository(ref.watch(adminIntelRemoteDatasourceProvider));
});

class AdminIntelRepository {
  final AdminIntelRemoteDatasource _remote;
  final Map<String, _CacheEntry> _cache = <String, _CacheEntry>{};

  static const Duration _ttl = Duration(minutes: 5);

  AdminIntelRepository(this._remote);

  Future<AdminIntelOverview> getOverview({
    String range = 'today',
    bool forceRefresh = false,
  }) {
    return _cached(
      'overview:$range',
      forceRefresh,
      () => _remote.getOverview(range: range),
    );
  }

  Future<List<AdminIntelTrendingProduct>> getTrendingProducts({
    String range = '24h',
    int limit = 20,
    bool forceRefresh = false,
  }) {
    return _cached(
      'trending:$range:$limit',
      forceRefresh,
      () => _remote.getTrendingProducts(range: range, limit: limit),
    );
  }

  Future<List<AdminIntelOpportunity>> getOpportunities({
    String range = '7d',
    int limit = 30,
    bool forceRefresh = false,
  }) {
    return _cached(
      'opportunities:$range:$limit',
      forceRefresh,
      () => _remote.getOpportunities(range: range, limit: limit),
    );
  }

  Future<List<AdminIntelWishlistItem>> getWishlistTop({
    String range = '7d',
    int limit = 30,
    bool forceRefresh = false,
  }) {
    return _cached(
      'wishlist:$range:$limit',
      forceRefresh,
      () => _remote.getWishlistTop(range: range, limit: limit),
    );
  }

  Future<AdminIntelSearchData> getSearchIntelligence({
    String range = '7d',
    int limit = 50,
    bool forceRefresh = false,
  }) {
    return _cached(
      'search:$range:$limit',
      forceRefresh,
      () => _remote.getSearchIntelligence(range: range, limit: limit),
    );
  }

  Future<AdminIntelBundlesData> getBundles({
    required int productId,
    String range = '30d',
    int limit = 10,
    bool forceRefresh = false,
  }) {
    return _cached(
      'bundles:$productId:$range:$limit',
      forceRefresh,
      () =>
          _remote.getBundles(range: range, productId: productId, limit: limit),
    );
  }

  Future<AdminIntelStockAlertsData> getStockAlerts({
    bool forceRefresh = false,
  }) {
    return _cached(
      'stock_alerts',
      forceRefresh,
      () => _remote.getStockAlerts(),
    );
  }

  Future<AdminIntelActionResult> createOfferDraft({
    required String titleAr,
    required List<int> productIds,
    String type = 'flash',
    String? startAt,
    String? endAt,
  }) async {
    final result = await _remote.createOfferDraft(
      titleAr: titleAr,
      productIds: productIds,
      type: type,
      startAt: startAt,
      endAt: endAt,
    );
    _invalidatePattern('opportunities:');
    _invalidatePattern('trending:');
    return result;
  }

  Future<AdminIntelActionResult> pinHome({
    required int productId,
    required String section,
  }) async {
    final result = await _remote.pinHome(
      productId: productId,
      section: section,
    );
    _invalidatePattern('trending:');
    return result;
  }

  void clearCache() => _cache.clear();

  Future<T> _cached<T>(
    String key,
    bool forceRefresh,
    Future<T> Function() loader,
  ) async {
    if (!forceRefresh) {
      final hit = _cache[key];
      if (hit != null &&
          DateTime.now().difference(hit.at) <= _ttl &&
          hit.value is T) {
        return hit.value as T;
      }
    }
    final value = await loader();
    _cache[key] = _CacheEntry(value);
    return value;
  }

  void _invalidatePattern(String prefix) {
    _cache.removeWhere((key, value) => key.startsWith(prefix));
  }
}

class _CacheEntry {
  final dynamic value;
  final DateTime at;

  _CacheEntry(this.value) : at = DateTime.now();
}
