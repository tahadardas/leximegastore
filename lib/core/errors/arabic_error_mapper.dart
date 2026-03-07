import 'package:dio/dio.dart';

import '../network/dio_client.dart';
import 'user_friendly_errors.dart';

abstract class ArabicErrorMapper {
  static String map(Object error, {String fallback = 'حدث خطأ غير متوقع.'}) {
    if (error is DioException) {
      return _mapDio(error, fallback: fallback);
    }

    return UserFriendlyErrors.from(error, fallback: fallback);
  }

  static String _mapDio(DioException error, {required String fallback}) {
    final code = error.response?.statusCode ?? 0;
    final payload = extractMap(error.response?.data);
    final message = _safeMessage(
      (payload['message'] ?? extractMap(payload['error'])['message'] ?? '')
          .toString(),
    );
    if (message != null) {
      return message;
    }

    if (code == 401 || code == 403) {
      return 'يلزم تسجيل الدخول للمتابعة.';
    }
    if (code == 404) {
      return 'العنصر المطلوب غير موجود.';
    }
    if (code == 422) {
      return 'البيانات المدخلة غير صالحة.';
    }
    if (code >= 500) {
      return 'الخدمة غير متاحة حالياً. حاول لاحقاً.';
    }
    if (error.type == DioExceptionType.connectionError ||
        error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.receiveTimeout ||
        error.type == DioExceptionType.sendTimeout) {
      return UserFriendlyErrors.fromDio(error, fallback: fallback);
    }
    return UserFriendlyErrors.fromDio(error, fallback: fallback);
  }

  static String? _safeMessage(String message) {
    final value = message.trim();
    if (!_isSafeArabic(value)) {
      return null;
    }
    return value;
  }

  static bool _isSafeArabic(String message) {
    if (message.isEmpty) {
      return false;
    }
    final lower = message.toLowerCase();
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
    return !blocked.any(lower.contains);
  }
}
