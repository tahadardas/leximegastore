import 'package:flutter/foundation.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

/// Aggressive cache manager for images with 30-day TTL.
class LexiCacheManager {
  static const String key = 'lexi_image_cache';

  static final CacheManager instance = kIsWeb
      ? DefaultCacheManager()
      : CacheManager(
          Config(
            key,
            stalePeriod: const Duration(days: 30),
            maxNrOfCacheObjects: 1000,
            repo: JsonCacheInfoRepository(databaseName: key),
            fileService: HttpFileService(),
          ),
        );
}
