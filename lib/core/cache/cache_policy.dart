enum CacheKey {
  homeCategories,
  homeDeals,
  homeAdBanners,
  homeProducts,
  categoriesList,
  productsByCategory,
  productDetails,
}

abstract final class CachePolicy {
  static const Duration _ttl30Minutes = Duration(minutes: 30);
  static const Duration _ttl24Hours = Duration(hours: 24);

  static Duration ttl(CacheKey key) {
    return switch (key) {
      CacheKey.homeCategories => _ttl24Hours,
      CacheKey.homeDeals => _ttl30Minutes,
      CacheKey.homeAdBanners => _ttl30Minutes,
      CacheKey.homeProducts => _ttl30Minutes,
      CacheKey.categoriesList => _ttl24Hours,
      CacheKey.productsByCategory => _ttl30Minutes,
      CacheKey.productDetails => _ttl24Hours,
    };
  }

  static String key(CacheKey key, {String? suffix}) {
    final base = key.name;
    if (suffix == null || suffix.trim().isEmpty) {
      return base;
    }
    return '$base:${suffix.trim()}';
  }

  static bool isFresh(CacheKey key, DateTime savedAt) {
    return DateTime.now().difference(savedAt) <= ttl(key);
  }
}
