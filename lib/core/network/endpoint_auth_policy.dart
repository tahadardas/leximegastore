abstract final class EndpointAuthPolicy {
  static const String requiresAuthKey = 'requiresAuth';

  static bool resolveRequiresAuth({
    required String method,
    required String path,
    bool? explicit,
  }) {
    if (explicit != null) {
      return explicit;
    }

    final route = _canonicalRoute(path);
    if (route.isEmpty) {
      return true;
    }

    final m = method.trim().toUpperCase();

    // Public auth bootstrap endpoints.
    if (_publicAuthRoutes.contains(route)) {
      return false;
    }

    // Reviews endpoint is mixed: GET public, POST protected.
    if (_isProductReviewsRoute(route)) {
      return m != 'GET';
    }

    if (_publicRoutePrefixes.any(route.startsWith)) {
      return false;
    }

    return true;
  }

  static String _canonicalRoute(String rawPath) {
    final value = rawPath.trim();
    if (value.isEmpty) {
      return '';
    }

    final uri = Uri.tryParse(value);
    if (uri == null) {
      return value;
    }

    final restRoute = (uri.queryParameters['rest_route'] ?? '').trim();
    if (restRoute.isNotEmpty) {
      return restRoute.startsWith('/') ? restRoute : '/$restRoute';
    }

    final path = uri.path.trim();
    if (path.startsWith('/wp-json/')) {
      return '/${path.substring('/wp-json/'.length)}';
    }

    return path;
  }

  static bool _isProductReviewsRoute(String route) {
    final parts = route.split('/');
    if (parts.length < 6) {
      return false;
    }
    // /lexi/v1/products/{id}/reviews
    return parts.length >= 6 &&
        parts[1] == 'lexi' &&
        parts[2] == 'v1' &&
        parts[3] == 'products' &&
        parts[5] == 'reviews';
  }

  static const Set<String> _publicAuthRoutes = <String>{
    '/jwt-auth/v1/token',
    '/lexi/v1/auth/login',
    '/lexi/v1/auth/register',
    '/lexi/v1/auth/refresh',
    '/lexi/v1/auth/forgot-password',
    '/lexi/v1/auth/reset-password',
  };

  static const List<String> _publicRoutePrefixes = <String>[
    '/lexi/v1/products',
    '/lexi/v1/categories',
    '/lexi/v1/search',
    '/lexi/v1/home/',
    '/lexi/v1/shipping/',
    '/lexi/v1/payment-settings',
    '/lexi/v1/payments/shamcash/config',
    '/lexi/v1/checkout/guest',
    '/lexi/v1/checkout/create-order',
    '/lexi/v1/coupons/validate',
    '/lexi/v1/track-order',
    '/lexi/v1/ai/',
  ];
}
