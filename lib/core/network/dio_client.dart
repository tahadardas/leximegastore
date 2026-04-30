import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../config/constants/endpoints.dart';
import '../storage/secure_store.dart';
import 'api_response.dart';
import 'api_client.dart';
import 'dio_exception_mapper.dart';
import 'endpoint_auth_policy.dart';
import 'network_guard.dart';
import 'request_queue.dart';
import 'retry_policy.dart';
import 'token_manager.dart';

/// Dio singleton provider
final dioClientProvider = Provider<DioClient>((ref) {
  return DioClient(
    secureStore: ref.watch(secureStoreProvider),
    tokenManager: ref.watch(tokenManagerProvider),
    networkGuard: ref.watch(networkGuardProvider),
    requestQueue: ref.watch(requestQueueProvider),
    retryPolicy: ref.watch(retryPolicyProvider),
  );
});

/// Returns a list from multiple possible API response shapes:
/// - Raw array: `[...]`
/// - Wrapped: `{data:[...]}`
/// - Wrapped with nested payload: `{success:true,data:{items:[...]}}`
List<dynamic> extractList(dynamic json) {
  final data = extractData(json);
  if (data is List) {
    return data;
  }

  // Custom API response check
  if (json is Map && json.containsKey('data') && json['data'] is Map) {
    var nestedData = json['data'];
    for (final key in const [
      'items',
      'data',
      'results',
      'products',
      'categories',
    ]) {
      final candidate = nestedData[key];
      if (candidate is List) {
        return candidate;
      }
    }
  }

  if (data is Map<String, dynamic>) {
    for (final key in const [
      'items',
      'data',
      'results',
      'products',
      'categories',
    ]) {
      final candidate = data[key];
      if (candidate is List) {
        return candidate;
      }
    }
  }

  if (json is List) {
    return json;
  }

  if (json is Map<String, dynamic>) {
    final data = json['data'];

    if (data is List) {
      return data;
    }

    if (data is Map<String, dynamic>) {
      for (final key in const [
        'items',
        'data',
        'results',
        'products',
        'categories',
      ]) {
        final candidate = data[key];
        if (candidate is List) {
          return candidate;
        }
      }
    }

    for (final key in const ['items', 'results', 'products', 'categories']) {
      final candidate = json[key];
      if (candidate is List) {
        return candidate;
      }
    }
  }

  return const [];
}

/// Returns the inner `data` payload if present, otherwise the original JSON.
dynamic extractData(dynamic json) {
  if (json is Map && json.containsKey('data')) {
    return json['data'];
  }

  return json;
}

/// Returns a map from various API response shapes.
Map<String, dynamic> extractMap(dynamic json) {
  final data = extractData(json);

  if (data is Map) {
    return Map<String, dynamic>.from(
      data.map((key, value) => MapEntry(key.toString(), value)),
    );
  }

  return const {};
}

/// Configured Dio HTTP client for the Lexi API.
class DioClient {
  static const String _allowHostFallbackExtraKey = 'allowHostFallback';

  late final ApiClient _apiClient;
  final SecureStore secureStore;
  final TokenManager tokenManager;
  final NetworkGuard networkGuard;
  final RequestQueue requestQueue;
  final RetryPolicy retryPolicy;

  DioClient({
    required this.secureStore,
    required this.tokenManager,
    required this.networkGuard,
    required this.requestQueue,
    required this.retryPolicy,
  }) {
    _apiClient = ApiClient(
      secureStore: secureStore,
      tokenManager: tokenManager,
      networkGuard: networkGuard,
      requestQueue: requestQueue,
      retryPolicy: retryPolicy,
    );
    if (kDebugMode) {
      debugPrint('[DioClient] baseUrl = ${Endpoints.baseUrl}');
      debugPrint('[DioClient] productsPath = ${Endpoints.productsPath}');
      debugPrint('[DioClient] categoriesPath = ${Endpoints.categoriesPath}');
    }
  }

  /// The raw Dio instance. Prefer the typed helpers below.
  Dio get dio => _apiClient.dio;
  Dio get _dio => _apiClient.dio;

  Options _withAuthPolicy({
    required String method,
    required String rawPath,
    required Options? options,
  }) {
    final rawRequiresAuth = options?.extra?[EndpointAuthPolicy.requiresAuthKey];
    final explicitRequiresAuth = rawRequiresAuth is bool
        ? rawRequiresAuth
        : null;
    final resolvedRequiresAuth = EndpointAuthPolicy.resolveRequiresAuth(
      method: method,
      path: rawPath,
      explicit: explicitRequiresAuth,
    );

    final mergedExtra = <String, dynamic>{
      ...?options?.extra,
      EndpointAuthPolicy.requiresAuthKey: resolvedRequiresAuth,
    };
    return (options ?? Options()).copyWith(extra: mergedExtra);
  }

  Future<Response> get(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
  }) async {
    final basePath = _normalizeBasePath(path);
    final resolvedOptions = _withAuthPolicy(
      method: 'GET',
      rawPath: basePath,
      options: options,
    );
    final normalizedPath = _applyRestRouteFallback(basePath);
    final fallbackPath = _buildRawWpJsonFallbackPath(
      basePath: basePath,
      normalizedPath: normalizedPath,
      options: resolvedOptions,
    );
    final preferRawWpJsonOnWeb =
        kIsWeb &&
        basePath.startsWith('/wp-json/') &&
        !_requiresAuthForFallback(resolvedOptions, null);
    final primaryPath = preferRawWpJsonOnWeb
        ? (fallbackPath ?? normalizedPath)
        : normalizedPath;
    final secondaryPath = preferRawWpJsonOnWeb ? normalizedPath : fallbackPath;

    try {
      return await _dio.get(
        primaryPath,
        queryParameters: queryParameters,
        options: resolvedOptions,
        cancelToken: cancelToken,
      );
    } on DioException catch (e) {
      if (_shouldTryWpFallbackGet(e)) {
        if (secondaryPath != null && secondaryPath != primaryPath) {
          if (kDebugMode) {
            final direction = preferRawWpJsonOnWeb
                ? 'rest_route'
                : 'raw wp-json';
            debugPrint(
              '[DioClient] GET fallback -> $direction path for $basePath',
            );
          }
          if (kDebugMode) {
            debugPrint(
              '[DioClient] primary=$primaryPath secondary=$secondaryPath',
            );
          }
          try {
            return await _dio.get(
              secondaryPath,
              queryParameters: queryParameters,
              options: resolvedOptions,
              cancelToken: cancelToken,
            );
          } on DioException catch (_) {
            // Try host fallback below.
          }
        }

        final hostFallbackResponse = await _tryAlternateHostFallbackGet(
          originalError: e,
          normalizedPath: normalizedPath,
          fallbackPath: fallbackPath,
          queryParameters: queryParameters,
          options: resolvedOptions,
          cancelToken: cancelToken,
        );
        if (hostFallbackResponse != null) {
          return hostFallbackResponse;
        }
      }
      rethrow;
    }
  }

  Future<Response> post(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
  }) async {
    final basePath = _normalizeBasePath(path);
    final resolvedOptions = _withAuthPolicy(
      method: 'POST',
      rawPath: basePath,
      options: options,
    );
    final normalizedPath = _applyRestRouteFallback(basePath);
    final fallbackPath = _buildRawWpJsonFallbackPath(
      basePath: basePath,
      normalizedPath: normalizedPath,
      options: resolvedOptions,
    );

    try {
      return await _dio.post(
        normalizedPath,
        data: data,
        queryParameters: queryParameters,
        options: resolvedOptions,
        cancelToken: cancelToken,
      );
    } on DioException catch (e) {
      if (_shouldTryWpFallbackPost(e)) {
        if (fallbackPath != null) {
          if (kDebugMode) {
            debugPrint(
              '[DioClient] POST fallback -> raw wp-json path for $basePath',
            );
          }
          try {
            return await _dio.post(
              fallbackPath,
              data: data,
              queryParameters: queryParameters,
              options: resolvedOptions,
              cancelToken: cancelToken,
            );
          } on DioException catch (_) {
            // Try host fallback below.
          }
        }

        final hostFallbackResponse = await _tryAlternateHostFallbackPost(
          originalError: e,
          normalizedPath: normalizedPath,
          fallbackPath: fallbackPath,
          queryParameters: queryParameters,
          options: resolvedOptions,
          cancelToken: cancelToken,
          data: data,
        );
        if (hostFallbackResponse != null) {
          return hostFallbackResponse;
        }
      }
      rethrow;
    }
  }

  Future<Response> patch(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
  }) {
    final basePath = _normalizeBasePath(path);
    final resolvedOptions = _withAuthPolicy(
      method: 'PATCH',
      rawPath: basePath,
      options: options,
    );
    return _dio.patch(
      _applyRestRouteFallback(basePath),
      data: data,
      queryParameters: queryParameters,
      options: resolvedOptions,
      cancelToken: cancelToken,
    );
  }

  Future<Response> put(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
  }) {
    final basePath = _normalizeBasePath(path);
    final resolvedOptions = _withAuthPolicy(
      method: 'PUT',
      rawPath: basePath,
      options: options,
    );
    return _dio.put(
      _applyRestRouteFallback(basePath),
      data: data,
      queryParameters: queryParameters,
      options: resolvedOptions,
      cancelToken: cancelToken,
    );
  }

  Future<Response> delete(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
  }) {
    final basePath = _normalizeBasePath(path);
    final resolvedOptions = _withAuthPolicy(
      method: 'DELETE',
      rawPath: basePath,
      options: options,
    );
    return _dio.delete(
      _applyRestRouteFallback(basePath),
      data: data,
      queryParameters: queryParameters,
      options: resolvedOptions,
      cancelToken: cancelToken,
    );
  }

  Future<Response> request(
    String method,
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
  }) {
    final basePath = _normalizeBasePath(path);
    final resolvedOptions = _withAuthPolicy(
      method: method,
      rawPath: basePath,
      options: options,
    ).copyWith(method: method);
    return _dio.request(
      _applyRestRouteFallback(basePath),
      data: data,
      queryParameters: queryParameters,
      options: resolvedOptions,
      cancelToken: cancelToken,
    );
  }

  Future<ApiResponse<T>> getTyped<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    T Function(dynamic json)? fromJsonT,
  }) async {
    try {
      final response = await get(path, queryParameters: queryParameters);
      final apiResponse = ApiResponse<T>.fromJson(
        response.data as Map<String, dynamic>,
        fromJsonT,
      );
      DioExceptionMapper.validateApiResponse(apiResponse);
      return apiResponse;
    } on DioException catch (e) {
      throw DioExceptionMapper.fromDioException(e);
    }
  }

  Future<ApiResponse<T>> postTyped<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    T Function(dynamic json)? fromJsonT,
  }) async {
    try {
      final response = await post(
        path,
        data: data,
        queryParameters: queryParameters,
      );
      final apiResponse = ApiResponse<T>.fromJson(
        response.data as Map<String, dynamic>,
        fromJsonT,
      );
      DioExceptionMapper.validateApiResponse(apiResponse);
      return apiResponse;
    } on DioException catch (e) {
      throw DioExceptionMapper.fromDioException(e);
    }
  }

  Future<ApiResponse<T>> putTyped<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    T Function(dynamic json)? fromJsonT,
  }) async {
    try {
      final response = await put(
        path,
        data: data,
        queryParameters: queryParameters,
      );
      final apiResponse = ApiResponse<T>.fromJson(
        response.data as Map<String, dynamic>,
        fromJsonT,
      );
      DioExceptionMapper.validateApiResponse(apiResponse);
      return apiResponse;
    } on DioException catch (e) {
      throw DioExceptionMapper.fromDioException(e);
    }
  }

  Future<ApiResponse<T>> deleteTyped<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    T Function(dynamic json)? fromJsonT,
  }) async {
    try {
      final response = await delete(
        path,
        data: data,
        queryParameters: queryParameters,
      );
      final apiResponse = ApiResponse<T>.fromJson(
        response.data as Map<String, dynamic>,
        fromJsonT,
      );
      DioExceptionMapper.validateApiResponse(apiResponse);
      return apiResponse;
    } on DioException catch (e) {
      throw DioExceptionMapper.fromDioException(e);
    }
  }

  String _normalizeBasePath(String path) {
    final trimmed = path.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError('Request path must not be empty.');
    }

    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
      final uri = Uri.parse(trimmed);
      final baseUri = Uri.parse(Endpoints.baseUrl);
      if (uri.host != baseUri.host) {
        throw ArgumentError('Only path-only endpoints are allowed: $path');
      }
      final query = uri.hasQuery ? '?${uri.query}' : '';
      return '${uri.path}$query';
    }

    if (!trimmed.startsWith('/')) {
      return '/$trimmed';
    }

    return trimmed;
  }

  String _applyRestRouteFallback(String path) {
    // Normalize all WP REST routes to ?rest_route= form.
    // This is more tolerant across some hosting/security layers that may
    // block direct /wp-json/* paths for specific clients/networks.
    if (!path.startsWith('/wp-json/')) {
      return path;
    }

    final uri = Uri.parse(path);
    final route = uri.path.substring('/wp-json/'.length);
    final buffer = StringBuffer('/index.php?rest_route=/$route');

    uri.queryParametersAll.forEach((key, values) {
      for (final value in values) {
        buffer
          ..write('&')
          ..write(Uri.encodeQueryComponent(key))
          ..write('=')
          ..write(Uri.encodeQueryComponent(value));
      }
    });

    return buffer.toString();
  }

  String? _buildRawWpJsonFallbackPath({
    required String basePath,
    required String normalizedPath,
    required Options? options,
  }) {
    if (!basePath.startsWith('/wp-json/')) {
      return null;
    }
    final normalizedUri = Uri.parse(normalizedPath);
    if (normalizedUri.path != '/index.php') {
      return null;
    }
    // For web: keep auth endpoints on rest_route, but allow public GET routes
    // to fall back to raw /wp-json when rest_route hits CORS/XHR edge cases.
    if (kIsWeb && _requiresAuthForFallback(options, null)) {
      return null;
    }
    return basePath;
  }

  bool _shouldTryWpFallbackGet(DioException error) {
    return _shouldTryWpFallbackByError(error);
  }

  bool _shouldTryWpFallbackPost(DioException error) {
    return _shouldTryWpFallbackByError(error);
  }

  bool _shouldTryWpFallbackByError(DioException error) {
    final status = error.response?.statusCode;
    if (status == 401) {
      return _shouldFallbackToRawWpJsonOnUnauthorized(error);
    }
    if (status == 403) {
      // Only retry 403 when the backend responded with an HTML block page.
      // Token/permission JSON responses should not trigger route/host fallbacks.
      return _looksLikeHtmlBlock(error.response);
    }
    if (status == 404 || status == 405) {
      return true;
    }

    if (error.response != null) {
      return false;
    }

    return switch (error.type) {
      DioExceptionType.connectionError => true,
      DioExceptionType.connectionTimeout => true,
      DioExceptionType.receiveTimeout => true,
      DioExceptionType.sendTimeout => true,
      DioExceptionType.unknown => true,
      _ => false,
    };
  }

  bool _shouldFallbackToRawWpJsonOnUnauthorized(DioException error) {
    final request = error.requestOptions;
    final requiresAuth = request.extra['requiresAuth'] as bool? ?? true;
    if (!requiresAuth) {
      return false;
    }

    final hasBearer = request.headers.entries.any((entry) {
      if (entry.key.toLowerCase() != 'authorization') {
        return false;
      }
      final value = (entry.value ?? '').toString().trim().toLowerCase();
      return value.startsWith('bearer ');
    });
    if (!hasBearer) {
      return false;
    }

    final uri = request.uri;
    final restRoute = (uri.queryParameters['rest_route'] ?? '')
        .toString()
        .trim();
    if (uri.path != '/index.php' || restRoute.isEmpty) {
      return false;
    }

    final lowerRoute = restRoute.toLowerCase();
    if (lowerRoute.contains('/auth/refresh') ||
        lowerRoute.contains('/jwt-auth/v1/token')) {
      return false;
    }

    final lowerBody = (error.response?.data ?? '').toString().toLowerCase();
    if (lowerBody.contains('jwt_auth_invalid_token') ||
        lowerBody.contains('token is invalid') ||
        lowerBody.contains('token has expired')) {
      return false;
    }

    return true;
  }

  bool _looksLikeHtmlBlock(Response<dynamic>? response) {
    if (response == null) {
      return false;
    }

    final contentType =
        response.headers.value(Headers.contentTypeHeader)?.toLowerCase() ?? '';
    if (contentType.contains('text/html')) {
      return true;
    }

    final raw = (response.data ?? '').toString().toLowerCase();
    return raw.contains('<!doctype html') ||
        raw.contains('<html') ||
        raw.contains('<meta name="robots"') ||
        raw.contains('<title>405');
  }

  bool _requiresAuthForFallback(Options? options, RequestOptions? request) {
    final fromOptions = options?.extra?['requiresAuth'];
    if (fromOptions is bool) {
      return fromOptions;
    }

    final fromRequest = request?.extra['requiresAuth'];
    if (fromRequest is bool) {
      return fromRequest;
    }

    return true;
  }

  Future<Response?> _tryAlternateHostFallbackGet({
    required DioException originalError,
    required String normalizedPath,
    required String? fallbackPath,
    required Map<String, dynamic>? queryParameters,
    required Options? options,
    required CancelToken? cancelToken,
  }) async {
    if (!_allowHostFallback(
      options: options,
      request: originalError.requestOptions,
      error: originalError,
    )) {
      return null;
    }

    if (kIsWeb &&
        _requiresAuthForFallback(options, originalError.requestOptions)) {
      return null;
    }

    final attempted =
        (options?.extra?['host_fallback_attempted'] as bool?) == true ||
        (originalError.requestOptions.extra['host_fallback_attempted']
                as bool?) ==
            true;
    if (attempted) {
      return null;
    }

    final baseUri = Uri.parse(Endpoints.baseUrl);
    final currentHost = baseUri.host.toLowerCase();
    final hosts = <String>[];
    if (currentHost.startsWith('www.')) {
      hosts.add(currentHost.substring(4));
    } else {
      hosts.add('www.$currentHost');
    }

    final candidatePaths = <String>{
      normalizedPath,
      if (fallbackPath != null && fallbackPath.isNotEmpty) fallbackPath,
    };

    for (final host in hosts) {
      for (final candidatePath in candidatePaths) {
        final altUrl = '${baseUri.scheme}://$host$candidatePath';
        final mergedExtra = <String, dynamic>{
          ...?options?.extra,
          'host_fallback_attempted': true,
          'host_fallback_from': currentHost,
          'host_fallback_to': host,
        };

        try {
          return await _dio.get(
            altUrl,
            queryParameters: queryParameters,
            options: (options ?? Options()).copyWith(extra: mergedExtra),
            cancelToken: cancelToken,
          );
        } on DioException {
          continue;
        }
      }
    }

    return null;
  }

  Future<Response?> _tryAlternateHostFallbackPost({
    required DioException originalError,
    required String normalizedPath,
    required String? fallbackPath,
    required Map<String, dynamic>? queryParameters,
    required Options? options,
    required CancelToken? cancelToken,
    required dynamic data,
  }) async {
    if (!_allowHostFallback(
      options: options,
      request: originalError.requestOptions,
      error: originalError,
    )) {
      return null;
    }

    if (kIsWeb &&
        _requiresAuthForFallback(options, originalError.requestOptions)) {
      return null;
    }

    final attempted =
        (options?.extra?['host_fallback_attempted'] as bool?) == true ||
        (originalError.requestOptions.extra['host_fallback_attempted']
                as bool?) ==
            true;
    if (attempted) {
      return null;
    }

    final baseUri = Uri.parse(Endpoints.baseUrl);
    final currentHost = baseUri.host.toLowerCase();
    final hosts = <String>[];
    if (currentHost.startsWith('www.')) {
      hosts.add(currentHost.substring(4));
    } else {
      hosts.add('www.$currentHost');
    }

    final candidatePaths = <String>{
      normalizedPath,
      if (fallbackPath != null && fallbackPath.isNotEmpty) fallbackPath,
    };

    for (final host in hosts) {
      for (final candidatePath in candidatePaths) {
        final altUrl = '${baseUri.scheme}://$host$candidatePath';
        final mergedExtra = <String, dynamic>{
          ...?options?.extra,
          'host_fallback_attempted': true,
          'host_fallback_from': currentHost,
          'host_fallback_to': host,
        };

        try {
          return await _dio.post(
            altUrl,
            data: data,
            queryParameters: queryParameters,
            options: (options ?? Options()).copyWith(extra: mergedExtra),
            cancelToken: cancelToken,
          );
        } on DioException {
          continue;
        }
      }
    }

    return null;
  }

  bool _allowHostFallback({
    required Options? options,
    required RequestOptions? request,
    required DioException error,
  }) {
    final fromOptions = options?.extra?[_allowHostFallbackExtraKey];
    final fromRequest = request?.extra[_allowHostFallbackExtraKey];
    final enabled =
        (fromOptions is bool && fromOptions) ||
        (fromRequest is bool && fromRequest);
    if (!enabled) {
      return false;
    }

    if (error.response != null) {
      return false;
    }

    return switch (error.type) {
      DioExceptionType.connectionError => true,
      DioExceptionType.connectionTimeout => true,
      DioExceptionType.receiveTimeout => true,
      DioExceptionType.sendTimeout => true,
      DioExceptionType.unknown => true,
      _ => false,
    };
  }
}
