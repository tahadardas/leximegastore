import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../logging/app_logger.dart';

class NetworkLoggingInterceptor extends Interceptor {
  static const String _startKey = 'request_start_ms';
  static int _activeRequests = 0;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    options.extra[_startKey] = DateTime.now().millisecondsSinceEpoch;
    _activeRequests++;
    if (kDebugMode) {
      debugPrint(
        '[NetworkCounter] active=$_activeRequests method=${options.method.toUpperCase()} path=${_pathOnly(options.uri)}',
      );
    }
    handler.next(options);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    _activeRequests = (_activeRequests - 1).clamp(0, 1000000).toInt();

    final options = response.requestOptions;
    final elapsed = _elapsedMs(options);
    final sizeBytes = _estimateResponseSize(response);
    final retryCount = (options.extra['retry_attempt'] as int?) ?? 0;

    final extra = {
      'method': options.method.toUpperCase(),
      'path': _pathOnly(options.uri),
      'status_code': response.statusCode,
      'duration_ms': elapsed,
      'size_kb': (sizeBytes / 1024).toStringAsFixed(1),
      if (retryCount > 0) 'retries': retryCount,
    };

    if (elapsed > 1500 || sizeBytes > 1024 * 1024) {
      AppLogger.warn(
        'Network performance warning',
        extra: {
          ...extra,
          'reason': [
            if (elapsed > 1500) 'slow_response',
            if (sizeBytes > 1024 * 1024) 'large_payload',
          ].join(','),
        },
      );
    } else {
      AppLogger.info('Network request success', extra: extra);
    }

    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    _activeRequests = (_activeRequests - 1).clamp(0, 1000000).toInt();

    final options = err.requestOptions;
    final elapsed = _elapsedMs(options);
    final responseData = err.response?.data;
    final responseSnippet = _responseSnippet(responseData);
    final traceId = _traceIdFromBody(err.response?.data);
    final statusCode = err.response?.statusCode;
    final path = _pathOnly(options.uri);
    final errorCode = _extractErrorCode(responseData);
    final errorMessage = _extractErrorMessage(responseData);
    final expectedAuthFailure = _isExpectedAuthFailure(
      path: path,
      statusCode: statusCode,
      errorCode: errorCode,
    );

    if (expectedAuthFailure) {
      AppLogger.info(
        'Network auth rejected',
        extra: {
          'method': options.method.toUpperCase(),
          'path': path,
          'status_code': statusCode,
          'duration_ms': elapsed,
          'category': 'auth',
          'error_code': errorCode,
          'message': errorMessage,
        },
      );
      handler.next(err);
      return;
    }

    AppLogger.warn(
      'Network request failed',
      extra: {
        'method': options.method.toUpperCase(),
        'path': path,
        'status_code': statusCode,
        'duration_ms': elapsed,
        'error_type': err.type.name,
        'error_message': (err.message ?? '').toString(),
        'error_object': (err.error ?? '').toString(),
        'category': _errorCategory(err),
        'trace_id': traceId,
        'response_snippet': responseSnippet.isNotEmpty ? responseSnippet : null,
      },
    );

    handler.next(err);
  }

  int _elapsedMs(RequestOptions options) {
    final start = options.extra[_startKey];
    if (start is! int) {
      return 0;
    }
    return DateTime.now().millisecondsSinceEpoch - start;
  }

  int _estimateResponseSize(Response response) {
    try {
      if (response.data == null) {
        return 0;
      }
      if (response.data is String) {
        return (response.data as String).length;
      }
      // Rough estimate for JSON maps/lists.
      return jsonEncode(response.data).length;
    } catch (_) {
      return 0;
    }
  }

  String _pathOnly(Uri uri) {
    final restRoute = uri.queryParameters['rest_route'] ?? '';
    if (uri.path == '/index.php' && restRoute.trim().isNotEmpty) {
      return restRoute.trim();
    }

    final path = uri.path.trim();
    if (path.isNotEmpty) {
      return path;
    }

    if (restRoute.trim().isNotEmpty) {
      return restRoute.trim();
    }

    return '/';
  }

  String _errorCategory(DioException err) {
    if (err.type == DioExceptionType.connectionError) {
      return 'offline';
    }

    if (err.type == DioExceptionType.unknown) {
      final msg = (err.message ?? '').toLowerCase();
      if (msg.contains('xmlhttprequest') ||
          msg.contains('failed to fetch') ||
          msg.contains('network')) {
        return 'offline';
      }
    }

    if (err.type == DioExceptionType.connectionTimeout ||
        err.type == DioExceptionType.sendTimeout ||
        err.type == DioExceptionType.receiveTimeout) {
      return 'timeout';
    }

    final status = err.response?.statusCode ?? 0;
    if (status >= 500) {
      return 'server';
    }

    if (status >= 400) {
      return 'client';
    }

    return 'unknown';
  }

  String _responseSnippet(dynamic data) {
    if (data == null) {
      return '';
    }

    try {
      final text = data is String ? data : jsonEncode(data);
      final normalized = text.replaceAll(RegExp(r'\s+'), ' ').trim();
      if (normalized.isEmpty) {
        return '';
      }
      if (normalized.length <= 300) {
        return normalized;
      }
      return '${normalized.substring(0, 300)}...';
    } catch (_) {
      return '';
    }
  }

  String? _traceIdFromBody(dynamic data) {
    final payload = _payloadMap(data);
    if (payload == null) {
      return null;
    }

    final topTrace = payload['trace_id'];
    if (topTrace is String && topTrace.trim().isNotEmpty) {
      return topTrace.trim();
    }

    final error = payload['error'];
    if (error is Map) {
      final details = error['details'];
      if (details is Map) {
        final trace = details['trace_id'];
        if (trace is String && trace.trim().isNotEmpty) {
          return trace.trim();
        }
      }
    }

    final details = payload['details'];
    if (details is Map) {
      final trace = details['trace_id'];
      if (trace is String && trace.trim().isNotEmpty) {
        return trace.trim();
      }
    }

    return null;
  }

  bool _isExpectedAuthFailure({
    required String path,
    required int? statusCode,
    required String? errorCode,
  }) {
    final authPath =
        path == '/lexi/v1/auth/login' || path == '/lexi/v1/auth/refresh';
    if (!authPath) {
      return false;
    }

    if (errorCode == 'invalid_credentials' ||
        errorCode == 'invalid_refresh_token' ||
        errorCode == 'refresh_token_expired') {
      return true;
    }

    return statusCode == 401 || statusCode == 422;
  }

  String? _extractErrorCode(dynamic data) {
    final payload = _payloadMap(data);
    if (payload == null) {
      return null;
    }

    final top = payload['code'];
    if (top is String && top.trim().isNotEmpty) {
      return top.trim().toLowerCase();
    }

    final error = payload['error'];
    if (error is Map) {
      final nested = error['code'];
      if (nested is String && nested.trim().isNotEmpty) {
        return nested.trim().toLowerCase();
      }
    }

    return null;
  }

  String? _extractErrorMessage(dynamic data) {
    final payload = _payloadMap(data);
    if (payload == null) {
      return null;
    }

    final top = payload['message'];
    if (top is String && top.trim().isNotEmpty) {
      return top.trim();
    }

    final error = payload['error'];
    if (error is Map) {
      final nested = error['message'];
      if (nested is String && nested.trim().isNotEmpty) {
        return nested.trim();
      }
    }

    return null;
  }

  Map<String, dynamic>? _payloadMap(dynamic data) {
    if (data is Map) {
      return data.map((k, v) => MapEntry(k.toString(), v));
    }

    if (data is! String) {
      return null;
    }

    final text = data.trimLeft();
    if (!(text.startsWith('{') || text.startsWith('['))) {
      return null;
    }

    try {
      final decoded = jsonDecode(text);
      if (decoded is Map) {
        return decoded.map((k, v) => MapEntry(k.toString(), v));
      }
    } catch (_) {
      return null;
    }

    return null;
  }
}
