import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class RetryPolicy {
  const RetryPolicy({this.maxAttempts = 2});

  /// Number of retries after the first attempt.
  final int maxAttempts;

  bool shouldRetry({
    required DioException error,
    required RequestOptions request,
    required int attempt,
  }) {
    if (_retryDisabled(request)) {
      return false;
    }

    if (attempt >= maxAttempts) {
      return false;
    }

    if (_isRefreshEndpoint(request)) {
      return false;
    }

    if (_isPaymentPost(request)) {
      return false;
    }

    if (_isTransientTransportError(error)) {
      return true;
    }

    final status = error.response?.statusCode ?? 0;
    return status >= 500 && status < 600;
  }

  Duration backoffForAttempt(int attemptNumber) {
    if (attemptNumber <= 1) {
      return const Duration(seconds: 1);
    }
    if (attemptNumber == 2) {
      return const Duration(seconds: 2);
    }
    return const Duration(seconds: 3);
  }

  bool _isTransientTransportError(DioException error) {
    return switch (error.type) {
      DioExceptionType.connectionTimeout => true,
      DioExceptionType.sendTimeout => true,
      DioExceptionType.receiveTimeout => true,
      DioExceptionType.connectionError => true,
      DioExceptionType.unknown when error.error is SocketException => true,
      _ => false,
    };
  }

  bool _isRefreshEndpoint(RequestOptions request) {
    final route = _canonicalRoute(request).toLowerCase();
    return route.contains('/auth/refresh');
  }

  bool _isPaymentPost(RequestOptions request) {
    if (request.method.toUpperCase() != 'POST') {
      return false;
    }
    final route = _canonicalRoute(request).toLowerCase();
    return route.contains('/payments/') ||
        route.contains('/payment-settings') ||
        route.contains('/checkout/create-order') ||
        route.contains('/checkout/guest');
  }

  String _canonicalRoute(RequestOptions request) {
    final restRoute = request.queryParameters['rest_route'];
    if (restRoute is String && restRoute.trim().isNotEmpty) {
      return restRoute.trim();
    }

    final uri = request.uri;
    final qpRoute = (uri.queryParameters['rest_route'] ?? '').trim();
    if (qpRoute.isNotEmpty) {
      return qpRoute;
    }

    return uri.path;
  }

  bool _retryDisabled(RequestOptions request) {
    final disabled = request.extra['disableRetry'];
    return disabled is bool && disabled;
  }
}

final retryPolicyProvider = Provider<RetryPolicy>((ref) {
  // Web requests can intermittently fail at the XHR/network layer.
  // Allow one extra retry there without changing mobile behavior.
  return RetryPolicy(maxAttempts: kIsWeb ? 3 : 2);
});
