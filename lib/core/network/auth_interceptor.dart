import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../session/app_session.dart';
import 'token_manager.dart';

/// Attaches bearer token and performs a single 401 refresh-retry cycle.
class AuthInterceptor extends Interceptor {
  static const _retriedAfterRefreshKey = 'retried_after_refresh';
  static const _skipAuthRefreshKey = 'skipAuthRefresh';

  final Dio dio;
  final TokenManager tokenManager;

  AuthInterceptor({required this.dio, required this.tokenManager});

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final requiresAuth = options.extra['requiresAuth'] as bool? ?? true;
    if (!requiresAuth) {
      options.headers.remove('Authorization');
      handler.next(options);
      return;
    }

    final token = await tokenManager.getValidAccessToken();
    if (token != null && token.isNotEmpty) {
      options.headers['Authorization'] = 'Bearer $token';
    } else {
      options.headers.remove('Authorization');
    }

    handler.next(options);
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final request = err.requestOptions;
    final statusCode = err.response?.statusCode;
    final requiresAuth = request.extra['requiresAuth'] as bool? ?? true;
    final skipRefresh = request.extra[_skipAuthRefreshKey] == true;
    final alreadyRetried = request.extra[_retriedAfterRefreshKey] == true;

    if (!requiresAuth ||
        skipRefresh ||
        !_isRefreshable401(statusCode, request)) {
      handler.next(err);
      return;
    }

    if (alreadyRetried) {
      handler.next(err);
      return;
    }

    final result = await tokenManager.refresh();
    if (result != TokenRefreshResult.refreshed) {
      handler.next(err);
      return;
    }

    final newToken = await tokenManager.getValidAccessToken();
    if (newToken == null || newToken.isEmpty) {
      handler.next(err);
      return;
    }

    final retryRequest = _cloneRequestWithRetryFlag(request, token: newToken);

    try {
      final response = await dio.fetch<dynamic>(retryRequest);
      handler.resolve(response);
    } on DioException catch (retryError) {
      handler.next(retryError);
    } catch (_) {
      handler.next(err);
    }
  }

  bool _isRefreshable401(int? statusCode, RequestOptions request) {
    if (statusCode != 401) {
      return false;
    }
    return !_isRefreshEndpoint(request);
  }

  bool _isRefreshEndpoint(RequestOptions request) {
    final route = _canonicalRoute(request).toLowerCase();
    return route.contains('/auth/refresh');
  }

  String _canonicalRoute(RequestOptions request) {
    final uri = request.uri;
    final restRoute = (uri.queryParameters['rest_route'] ?? '').trim();
    if (restRoute.isNotEmpty) {
      return restRoute;
    }
    return uri.path;
  }

  RequestOptions _cloneRequestWithRetryFlag(
    RequestOptions source, {
    required String token,
  }) {
    final headers = Map<String, dynamic>.from(source.headers);
    headers['Authorization'] = 'Bearer $token';

    final extra = Map<String, dynamic>.from(source.extra);
    extra[_retriedAfterRefreshKey] = true;

    if (kDebugMode) {
      debugPrint(
        '[AuthInterceptor] retry-once ${source.method.toUpperCase()} ${source.path}',
      );
    }

    return source.copyWith(headers: headers, extra: extra);
  }
}
