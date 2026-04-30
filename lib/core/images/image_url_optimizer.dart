import 'package:flutter/foundation.dart';

import '../utils/url_utils.dart';

abstract final class ImageUrlOptimizer {
  /// Per-session cache buster derived from the dev server port.
  ///
  /// Flutter web development uses random localhost ports. Including the port
  /// prevents browser/CDN cache entries with stale CORS headers from being
  /// reused between sessions.
  static bool get _isLocalWebOrigin {
    if (!kIsWeb) {
      return false;
    }
    final host = Uri.base.host.toLowerCase();
    return host == 'localhost' || host == '127.0.0.1' || host == '::1';
  }

  static final String _sessionCacheBuster =
      kIsWeb && _isLocalWebOrigin ? Uri.base.port.toString() : '';

  static String optimize(String url, {bool preferWebp = true}) {
    final normalized = normalizeHttpUrl(url);
    if (normalized.isEmpty) {
      return normalized;
    }

    final uri = Uri.tryParse(normalized);
    if (uri == null) {
      return normalized;
    }

    String candidate = uri.toString();

    // If the URL is already wrapped in our old proxy from local cache, unwrap
    // it and rebuild it with the current web session cache buster.
    if (_isAlreadyProxy(candidate)) {
      final proxyUri = Uri.parse(candidate);
      final rawOriginal = proxyUri.queryParameters['url'];
      if (rawOriginal != null && rawOriginal.isNotEmpty) {
        candidate = rawOriginal;
      }
    }

    final candidateUri = Uri.tryParse(candidate);
    final isUploadsImage =
        candidateUri != null &&
        candidateUri.path.toLowerCase().contains('/wp-content/uploads/');

    if (kIsWeb &&
        candidateUri != null &&
        isUploadsImage &&
        _shouldProxyWebImage(candidateUri)) {
      final query = <String, String>{
        'action': 'lexi_media_proxy',
        'url': candidate,
      };
      if (_sessionCacheBuster.isNotEmpty) {
        query['_cb'] = _sessionCacheBuster;
      }

      return candidateUri
          .replace(
            path: '/wp-admin/admin-ajax.php',
            queryParameters: query,
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

  static bool _shouldProxyWebImage(Uri imageUri) {
    if (_isLocalWebOrigin) {
      return true;
    }

    final page = Uri.base;
    final pageHost = _normalizedHost(page.host);
    final imageHost = _normalizedHost(imageUri.host);
    if (pageHost == imageHost) {
      return false;
    }

    // Different hostnames generally indicate cross-origin image fetches.
    return true;
  }

  static String _normalizedHost(String host) {
    final lower = host.trim().toLowerCase();
    if (lower.startsWith('www.')) {
      return lower.substring(4);
    }
    return lower;
  }
}
