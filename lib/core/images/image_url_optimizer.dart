import 'package:flutter/foundation.dart';

import '../utils/url_utils.dart';

abstract final class ImageUrlOptimizer {
  /// Per-session cache buster derived from the dev server port.
  /// Each `flutter run` uses a different random port, so this ensures
  /// proxy URLs are unique per session and won't get stale CORS from cache.
  static final String _sessionCacheBuster = kIsWeb
      ? Uri.base.port.toString()
      : '';

  static String optimize(String url, {bool preferWebp = true}) {
    final normalized = normalizeHttpUrl(url);
    if (normalized.isEmpty) {
      return normalized;
    }

    final uri = Uri.tryParse(normalized);
    if (uri == null) {
      return normalized;
    }

    final path = uri.path;
    final lower = path.toLowerCase();
    final isUploadsImage = lower.contains('/wp-content/uploads/');

    // NOTE: WebP conversion is disabled — server doesn't generate .webp
    // variants for all sizes, which causes noisy 404s. Keep original format.

    final candidate = uri.toString();

    // Flutter Web cannot render cross-origin uploads without proper static CORS headers.
    // Proxy upload images through WordPress admin-ajax where we control CORS headers.
    if (kIsWeb && isUploadsImage) {
      if (_isAlreadyProxy(candidate)) {
        return candidate;
      }

      final proxyParams = <String, String>{
        'action': 'lexi_media_proxy',
        'url': candidate,
        // Cache-bust per session: each `flutter run` uses a different port.
        // Without this, server-side caches (nginx/CDN) serve stale
        // Access-Control-Allow-Origin headers from a previous port.
        '_cb': _sessionCacheBuster,
      };
      return uri
          .replace(
            path: '/wp-admin/admin-ajax.php',
            queryParameters: proxyParams,
          )
          .toString();
    }

    return candidate;
  }

  static bool _isAlreadyProxy(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null) {
      return false;
    }
    if (!uri.path.endsWith('/wp-admin/admin-ajax.php')) {
      return false;
    }
    return uri.queryParameters['action'] == 'lexi_media_proxy';
  }
}
