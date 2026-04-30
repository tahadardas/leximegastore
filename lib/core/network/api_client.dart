import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:pretty_dio_logger/pretty_dio_logger.dart';

import '../../config/constants/endpoints.dart';
import '../storage/secure_store.dart';
import 'auth_interceptor.dart';
import 'network_guard.dart';
import 'network_logging_interceptor.dart';
import 'request_queue.dart';
import 'retry_interceptor.dart';
import 'retry_policy.dart';
import 'token_manager.dart';

class ApiClient {
  ApiClient({
    required SecureStore secureStore,
    required TokenManager tokenManager,
    required NetworkGuard networkGuard,
    required RequestQueue requestQueue,
    required RetryPolicy retryPolicy,
  }) : dio = Dio(
       BaseOptions(
           baseUrl: Endpoints.baseUrl,
           // Fail faster on dead connections while still allowing slower
           // catalog payloads to complete.
           connectTimeout: const Duration(seconds: 12),
           receiveTimeout: const Duration(seconds: 25),
           sendTimeout: kIsWeb ? null : const Duration(seconds: 15),
           validateStatus: (status) =>
               status != null && status >= 200 && status < 300,
           headers: {'Accept': 'application/json'},
         ),
       ) {
    dio.interceptors.addAll([
      _JsonSanitizerInterceptor(),
      _ClientIdentityInterceptor(),
      NetworkLoggingInterceptor(),
      AuthInterceptor(dio: dio, tokenManager: tokenManager),
      RetryInterceptor(dio: dio, retryPolicy: retryPolicy),
      if (kDebugMode)
        PrettyDioLogger(
          requestHeader: false,
          requestBody: false,
          responseBody: false,
          responseHeader: false,
          error: false,
          compact: true,
        ),
      NetworkGuardInterceptor(networkGuard),
      RequestQueueInterceptor(queue: requestQueue),
    ]);

    if (kDebugMode) {
      debugPrint('[ApiClient] baseUrl=${Endpoints.baseUrl}');
      debugPrint('[ApiClient] queueMax=${requestQueue.maxConcurrent}');
    }
  }

  final Dio dio;
}

/// Adds stable client identity headers for non-web platforms.
class _ClientIdentityInterceptor extends Interceptor {
  static const _chromeUA =
      'Mozilla/5.0 (Linux; Android 13; Mobile) '
      'AppleWebKit/537.36 (KHTML, like Gecko) '
      'Chrome/124.0.0.0 Mobile Safari/537.36';

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    _ensureHeader(options.headers, 'Accept', 'application/json');
    if (!kIsWeb) {
      _ensureHeader(options.headers, 'User-Agent', _chromeUA);
      _ensureHeader(
        options.headers,
        'Accept-Language',
        'ar,en-US;q=0.9,en;q=0.8',
      );
    }
    handler.next(options);
  }

  void _ensureHeader(Map<String, dynamic> headers, String key, String value) {
    final exists = headers.keys.any(
      (existing) => existing.toLowerCase() == key.toLowerCase(),
    );
    if (!exists) {
      headers[key] = value;
    }
  }
}

/// Forces responseType plain and decodes JSON safely.
class _JsonSanitizerInterceptor extends Interceptor {
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    if (options.responseType == ResponseType.json) {
      options.responseType = ResponseType.plain;
    }
    handler.next(options);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    response.data = _decodeJsonLike(response.data, response.headers);
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    if (err.response != null) {
      err.response!.data = _decodeJsonLike(
        err.response!.data,
        err.response!.headers,
      );
    }
    handler.next(err);
  }

  dynamic _decodeJsonLike(dynamic data, Headers headers) {
    if (data is List<int>) {
      try {
        data = utf8.decode(data, allowMalformed: true);
      } catch (_) {
        return data;
      }
    }

    if (data is! String) {
      return data;
    }

    final raw = _stripUtf8Bom(data).trimLeft();
    if (raw.isEmpty) {
      return data;
    }

    final normalized = _trimJsonPrefixNoise(raw);
    final contentType = headers.value('content-type')?.toLowerCase() ?? '';
    final looksJson =
        contentType.contains('application/json') ||
        contentType.contains('+json') ||
        normalized.startsWith('{') ||
        normalized.startsWith('[');
    if (!looksJson) {
      return data;
    }

    try {
      return jsonDecode(normalized);
    } catch (_) {
      return data;
    }
  }

  String _trimJsonPrefixNoise(String value) {
    if (value.isEmpty) {
      return value;
    }
    if (value.startsWith('{') || value.startsWith('[')) {
      return value;
    }

    final firstObject = value.indexOf('{');
    final firstArray = value.indexOf('[');
    var first = -1;
    if (firstObject >= 0 && firstArray >= 0) {
      first = firstObject < firstArray ? firstObject : firstArray;
    } else if (firstObject >= 0) {
      first = firstObject;
    } else if (firstArray >= 0) {
      first = firstArray;
    }

    if (first > 0 && first <= 24) {
      return value.substring(first).trimLeft();
    }
    return value;
  }

  String _stripUtf8Bom(String input) {
    if (input.isEmpty) {
      return input;
    }
    var start = 0;
    while (start < input.length && input.codeUnitAt(start) == 0xFEFF) {
      start++;
    }
    return start == 0 ? input : input.substring(start);
  }
}
