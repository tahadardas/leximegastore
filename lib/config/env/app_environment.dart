abstract final class AppEnvironment {
  static const String environment = String.fromEnvironment(
    'APP_ENV',
    defaultValue: 'production',
  );

  // Explicit override wins (useful for CI/staging).
  static const String _baseUrlOverride = String.fromEnvironment(
    'BASE_URL',
    defaultValue: '',
  );

  static const String _devBaseUrl = String.fromEnvironment(
    'DEV_BASE_URL',
    defaultValue: 'https://dev.leximega.store',
  );

  static const String _prodBaseUrl = String.fromEnvironment(
    'PROD_BASE_URL',
    defaultValue: 'https://leximega.store',
  );

  static String get baseUrl {
    final override = _normalizeUrl(_baseUrlOverride);
    if (override.isNotEmpty) {
      return override;
    }

    final env = environment.trim().toLowerCase();
    final isProd = env == 'prod' || env == 'production' || env == 'release';
    final fallback = isProd ? _prodBaseUrl : _devBaseUrl;
    final normalized = _normalizeUrl(fallback);
    return normalized.isEmpty ? 'https://leximega.store' : normalized;
  }

  static String _normalizeUrl(String raw) {
    var value = raw.trim();
    if (value.isEmpty) {
      return '';
    }

    if (!value.startsWith('http://') && !value.startsWith('https://')) {
      value = 'https://$value';
    }

    final uri = Uri.tryParse(value);
    if (uri == null || uri.host.trim().isEmpty) {
      return '';
    }

    final scheme = uri.scheme.isEmpty ? 'https' : uri.scheme;
    final host = uri.host.trim();
    if (host.isEmpty) {
      return '';
    }

    final portPart =
        uri.hasPort &&
            !((scheme == 'https' && uri.port == 443) ||
                (scheme == 'http' && uri.port == 80))
        ? ':${uri.port}'
        : '';
    final path = uri.path == '/' ? '' : uri.path;
    return '$scheme://$host$portPart$path';
  }
}
