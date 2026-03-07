import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';

import 'app_exception.dart';

abstract final class UserFriendlyErrors {
  static String from(Object error, {String fallback = 'حدث خطأ غير متوقع.'}) {
    if (error is AppException) {
      return _safe(error.message) ?? fromStatusCode(error.statusCode);
    }

    if (error is DioException) {
      return fromDio(error, fallback: fallback);
    }

    final raw = error.toString().trim();
    return _safe(raw) ?? fallback;
  }

  static String fromDio(
    DioException error, {
    String fallback = 'حدث خطأ غير متوقع.',
  }) {
    if (error.type == DioExceptionType.connectionError ||
        error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.sendTimeout ||
        error.type == DioExceptionType.receiveTimeout ||
        (error.type == DioExceptionType.unknown &&
            error.error is SocketException)) {
      if (error.type == DioExceptionType.connectionError ||
          (error.type == DioExceptionType.unknown &&
              error.error is SocketException)) {
        return 'لا يوجد اتصال بالإنترنت.';
      }
      return 'الاتصال بطيء. حاول مرة أخرى.';
    }

    final status = error.response?.statusCode;
    final payload = _extractPayloadMap(error.response?.data);
    if (payload != null) {
      final map = payload.map((k, v) => MapEntry(k.toString(), v));
      final message = (map['message'] ?? map['error_message'] ?? '').toString();
      final safe = _safe(message);
      if (safe != null) {
        return safe;
      }
      final errorObj = map['error'];
      if (errorObj is Map) {
        final nested = (errorObj['message'] ?? '').toString();
        final nestedSafe = _safe(nested);
        if (nestedSafe != null) {
          return nestedSafe;
        }
      }
    }

    if (status != null) {
      return fromStatusCode(status);
    }
    return fallback;
  }

  static Map<String, dynamic>? _extractPayloadMap(dynamic payload) {
    if (payload is Map) {
      return payload.map((k, v) => MapEntry(k.toString(), v));
    }

    if (payload is! String) {
      return null;
    }

    final normalized = payload.trimLeft();
    if (!(normalized.startsWith('{') || normalized.startsWith('['))) {
      return null;
    }

    try {
      final decoded = jsonDecode(normalized);
      if (decoded is Map) {
        return decoded.map((k, v) => MapEntry(k.toString(), v));
      }
    } catch (_) {
      return null;
    }

    return null;
  }

  static String fromStatusCode(int? statusCode) {
    if (statusCode == null) {
      return 'حدث خطأ غير متوقع.';
    }
    if (statusCode == 401 || statusCode == 403) {
      return 'يلزم تسجيل الدخول للمتابعة.';
    }
    if (statusCode == 404) {
      return 'المحتوى المطلوب غير متوفر.';
    }
    if (statusCode == 408 || statusCode == 429) {
      return 'الاتصال بطيء. حاول مرة أخرى.';
    }
    if (statusCode >= 500) {
      return 'حدث خطأ بالخادم. حاول لاحقاً.';
    }
    return 'حدث خطأ غير متوقع.';
  }

  static String? _safe(String? message) {
    final value = (message ?? '').trim();
    if (value.isEmpty) {
      return null;
    }

    final lower = value.toLowerCase();
    const blocked = <String>[
      'http://',
      'https://',
      'wp-json',
      'dioexception',
      'socketexception',
      'stacktrace',
      'xmlhttprequest',
      '<html',
      '</html',
    ];
    final isUnsafe = blocked.any(lower.contains);
    if (isUnsafe) {
      return null;
    }
    return value;
  }
}
