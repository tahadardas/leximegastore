import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../config/constants/endpoints.dart';
import '../../../../core/cache/cache_store.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../core/utils/safe_parsers.dart';
import '../models/city_model.dart';

final shippingRemoteDatasourceProvider = Provider<ShippingRemoteDatasource>((
  ref,
) {
  final dio = ref.watch(dioClientProvider);
  return ShippingRemoteDatasourceImpl(
    dioClient: dio,
    cacheStore: ref.watch(cacheStoreProvider),
  );
});

abstract class ShippingRemoteDatasource {
  Future<List<CityModel>> getCities();
  Future<double> getShippingRate(String cityId);
}

class ShippingRemoteDatasourceImpl implements ShippingRemoteDatasource {
  static const String _citiesCacheKey = 'shipping:cities:v1';
  static const Duration _citiesDiskTtl = Duration(hours: 24);
  static const Duration _citiesMemoryTtl = Duration(minutes: 20);
  static const Duration _shippingRateTtl = Duration(minutes: 10);

  final DioClient _dioClient;
  final CacheStore _cacheStore;

  List<CityModel>? _citiesMemoryCache;
  DateTime? _citiesMemoryCachedAt;
  Future<List<CityModel>>? _citiesInFlight;
  final Map<String, _ShippingRateCacheEntry> _rateCache =
      <String, _ShippingRateCacheEntry>{};

  ShippingRemoteDatasourceImpl({
    required DioClient dioClient,
    required CacheStore cacheStore,
  }) : _dioClient = dioClient,
       _cacheStore = cacheStore;

  @override
  Future<List<CityModel>> getCities() async {
    final now = DateTime.now();
    final memory = _citiesMemoryCache;
    final memoryAt = _citiesMemoryCachedAt;
    if (memory != null &&
        memoryAt != null &&
        now.difference(memoryAt) <= _citiesMemoryTtl) {
      return memory;
    }

    final inFlight = _citiesInFlight;
    if (inFlight != null) {
      return inFlight;
    }

    final future = _loadCities(now);
    _citiesInFlight = future;
    try {
      return await future;
    } finally {
      if (identical(_citiesInFlight, future)) {
        _citiesInFlight = null;
      }
    }
  }

  @override
  Future<double> getShippingRate(String cityId) async {
    final normalizedCityId = cityId.trim();
    if (normalizedCityId.isEmpty) {
      return 0.0;
    }

    final now = DateTime.now();
    final cached = _rateCache[normalizedCityId];
    if (cached != null && now.difference(cached.savedAt) <= _shippingRateTtl) {
      return cached.rate;
    }

    try {
      final response = await _dioClient.get(
        Endpoints.shippingRate(),
        queryParameters: {'city_id': normalizedCityId},
        options: Options(extra: const {'requiresAuth': false}),
      );

      final map = extractMap(response.data);
      final rate = parseDouble(
        map['rate'] ?? map['price'] ?? map['shipping_rate'],
      );
      if (rate > 0) {
        _rateCache[normalizedCityId] = _ShippingRateCacheEntry(
          rate: rate,
          savedAt: now,
        );
        return rate;
      }

      final local = _resolveLocalCityPrice(normalizedCityId);
      return local > 0 ? local : rate;
    } catch (_) {
      final stale = _rateCache[normalizedCityId];
      if (stale != null && stale.rate > 0) {
        return stale.rate;
      }
      final local = _resolveLocalCityPrice(normalizedCityId);
      if (local > 0) {
        return local;
      }
      rethrow;
    }
  }

  Future<List<CityModel>> _loadCities(DateTime now) async {
    final diskCache = await _readCachedCities();
    if (diskCache != null &&
        now.difference(diskCache.savedAt) <= _citiesDiskTtl &&
        diskCache.rows.isNotEmpty) {
      _rememberCities(diskCache.rows, diskCache.savedAt);
      return diskCache.rows;
    }

    try {
      final remoteRows = await _fetchRemoteCities();
      if (remoteRows.isNotEmpty) {
        await _saveCitiesCache(remoteRows, now);
        _rememberCities(remoteRows, now);
        return remoteRows;
      }
    } catch (_) {
      // Fall through to stale cache/fallback.
    }

    if (diskCache != null && diskCache.rows.isNotEmpty) {
      _rememberCities(diskCache.rows, diskCache.savedAt);
      return diskCache.rows;
    }

    final fallback = _fallbackCities();
    _rememberCities(fallback, now);
    return fallback;
  }

  Future<List<CityModel>> _fetchRemoteCities() async {
    final response = await _dioClient.get(
      Endpoints.shippingCities(),
      options: Options(extra: const {'requiresAuth': false}),
    );

    final list = extractList(response.data);
    return list
        .whereType<Map>()
        .map(
          (e) => CityModel.fromJson(
            e.map((key, value) => MapEntry(key.toString(), value)),
          ),
        )
        .toList(growable: false);
  }

  Future<_CachedCities?> _readCachedCities() async {
    final cached = await _cacheStore.readJson(_citiesCacheKey);
    if (cached == null) {
      return null;
    }

    final rawRows = cached.data['rows'];
    if (rawRows is! List) {
      return null;
    }

    final rows = <CityModel>[];
    for (final raw in rawRows) {
      if (raw is! Map) {
        continue;
      }
      rows.add(
        CityModel.fromJson(raw.map((key, value) => MapEntry('$key', value))),
      );
    }
    if (rows.isEmpty) {
      return null;
    }
    return _CachedCities(rows: rows, savedAt: cached.savedAt);
  }

  Future<void> _saveCitiesCache(List<CityModel> rows, DateTime now) async {
    await _cacheStore.saveJson(_citiesCacheKey, {
      'rows': rows
          .map(
            (city) => <String, dynamic>{
              'id': city.id,
              'name': city.name,
              'price': city.price,
            },
          )
          .toList(growable: false),
    }, now);
  }

  void _rememberCities(List<CityModel> rows, DateTime savedAt) {
    _citiesMemoryCache = List<CityModel>.unmodifiable(rows);
    _citiesMemoryCachedAt = savedAt;
  }

  double _resolveLocalCityPrice(String cityId) {
    final rows = _citiesMemoryCache;
    if (rows == null || rows.isEmpty) {
      return 0.0;
    }
    for (final city in rows) {
      if (city.id == cityId) {
        return city.price;
      }
    }
    return 0.0;
  }

  List<CityModel> _fallbackCities() {
    return const <CityModel>[
      CityModel(id: '1', name: 'دمشق', price: 5000),
      CityModel(id: '2', name: 'حلب', price: 8000),
      CityModel(id: '3', name: 'حمص', price: 6000),
    ];
  }
}

class _CachedCities {
  final List<CityModel> rows;
  final DateTime savedAt;

  const _CachedCities({required this.rows, required this.savedAt});
}

class _ShippingRateCacheEntry {
  final double rate;
  final DateTime savedAt;

  const _ShippingRateCacheEntry({required this.rate, required this.savedAt});
}
