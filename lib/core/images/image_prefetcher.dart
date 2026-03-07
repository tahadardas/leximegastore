import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../cache/lexi_cache_manager.dart';
import '../utils/url_utils.dart';
import 'image_url_optimizer.dart';

/// Lightweight image prefetch queue for product cards.
///
/// - Prefetches only secondary images (after first image).
/// - Limits count per product.
/// - Uses stagger delay to avoid network bursts.
/// - Prevents duplicated in-flight and completed downloads.
abstract final class ImagePrefetcher {
  static final Set<String> _inFlight = <String>{};
  static final Set<String> _completed = <String>{};

  static Future<void> prefetchSecondaryImages(
    BuildContext context,
    List<String> images, {
    int maxSecondary = 3,
    Duration staggerDelay = const Duration(milliseconds: 120),
    int? memCacheWidth,
  }) async {
    if (images.length <= 1 || maxSecondary <= 0) {
      return;
    }

    final candidates = _buildCandidates(images.skip(1), maxItems: maxSecondary);

    if (candidates.isEmpty) {
      return;
    }

    final futures = <Future<void>>[];
    for (var index = 0; index < candidates.length; index++) {
      final delay = Duration(milliseconds: staggerDelay.inMilliseconds * index);
      futures.add(
        _prefetchSingle(
          context,
          candidates[index],
          delay: delay,
          memCacheWidth: memCacheWidth,
        ),
      );
    }

    await Future.wait(futures);
  }

  static List<String> _buildCandidates(
    Iterable<String> rawUrls, {
    required int maxItems,
  }) {
    final deduped = <String>[];
    final seen = <String>{};

    for (final raw in rawUrls) {
      final normalized = normalizeNullableHttpUrl(raw);
      if ((normalized ?? '').isEmpty) {
        continue;
      }

      final optimized = ImageUrlOptimizer.optimize(
        normalized!,
        preferWebp: true,
      );
      if (!seen.add(optimized)) {
        continue;
      }
      if (_completed.contains(optimized) || _inFlight.contains(optimized)) {
        continue;
      }

      deduped.add(optimized);
      if (deduped.length >= maxItems) {
        break;
      }
    }

    return deduped;
  }

  static Future<void> _prefetchSingle(
    BuildContext context,
    String url, {
    required Duration delay,
    int? memCacheWidth,
  }) async {
    if (!_inFlight.add(url)) {
      return;
    }

    try {
      if (delay > Duration.zero) {
        await Future<void>.delayed(delay);
      }
      if (!context.mounted) {
        return;
      }

      ImageProvider provider = CachedNetworkImageProvider(
        url,
        cacheManager: LexiCacheManager.instance,
      );
      if (memCacheWidth != null && memCacheWidth > 0) {
        provider = ResizeImage(provider, width: memCacheWidth);
      }

      var loaded = true;
      await precacheImage(
        provider,
        context,
        onError: (error, stackTrace) {
          loaded = false;
        },
      );
      if (loaded) {
        _completed.add(url);
      }
    } catch (_) {
      // Best effort prefetch. Ignore failures to avoid UI impact.
    } finally {
      _inFlight.remove(url);
    }
  }
}
