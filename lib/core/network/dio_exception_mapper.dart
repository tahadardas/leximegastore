import 'dart:io';

import 'package:dio/dio.dart';

import '../errors/app_exception.dart';
import '../errors/user_friendly_errors.dart';
import 'api_response.dart';

/// Maps [DioException] and API error responses to [AppException].
abstract class DioExceptionMapper {
  /// Maps a [DioException] to the appropriate [AppException].
  static AppException fromDioException(DioException e) {
    final lowerMessage = (e.message ?? '').toLowerCase();

    return switch (e.type) {
      DioExceptionType.connectionTimeout ||
      DioExceptionType.sendTimeout ||
      DioExceptionType.receiveTimeout => const TimeoutException(),
      DioExceptionType.connectionError => const NetworkException(),
      DioExceptionType.unknown when e.error is SocketException =>
        const NetworkException(),
      DioExceptionType.unknown when e.response == null =>
        const NetworkException(),
      DioExceptionType.unknown
          when lowerMessage.contains('xmlhttprequest') ||
              lowerMessage.contains('network') ||
              lowerMessage.contains('failed to fetch') =>
        const NetworkException(),
      DioExceptionType.badResponse => _fromResponse(e.response),
      DioExceptionType.badCertificate => const ServerException(
        message: 'شهادة الأمان غير صالحة',
      ),
      DioExceptionType.cancel => const ServerException(
        message: 'تم إلغاء الطلب',
      ),
      _ => const UnknownException(),
    };
  }

  /// Maps a bad HTTP response to [AppException].
  static AppException _fromResponse(Response? response) {
    final statusCode = response?.statusCode;
    final data = response?.data;
    final htmlChallenge = looksLikeHtmlChallenge(response);

    String message = 'حدث خطأ بالخادم. حاول لاحقاً.';
    String? code;

    if (data is Map<String, dynamic>) {
      final errorMap = data['error'];
      if (errorMap is Map<String, dynamic>) {
        message = errorMap['message'] as String? ?? message;
        code = errorMap['code'] as String?;
      }

      if (data['message'] is String && (data['message'] as String).isNotEmpty) {
        message = data['message'] as String;
      }

      if (data['code'] is String && (data['code'] as String).isNotEmpty) {
        code = data['code'] as String;
      }
    }

    message = _sanitizeServerMessage(message, statusCode);

    return switch (statusCode) {
      400 => ServerException(message: message, statusCode: 400, data: code),
      401 => UnauthorizedException(
        message: message == 'حدث خطأ بالخادم. حاول لاحقاً.'
            ? 'غير مصرح بالوصول'
            : message,
        statusCode: 401,
      ),
      403 when code == 'jwt_auth_bad_config' => const ServerException(
        message:
            'إعداد JWT غير صحيح على السيرفر. تأكد من wp-config.php وتمرير Authorization header.',
        statusCode: 403,
        data: 'jwt_auth_bad_config',
      ),
      403 => ServerException(
        message: htmlChallenge
            ? 'تم رفض الاتصال من مزود الحماية. جرّب تبديل الشبكة أو تعطيل Private DNS.'
            : (message == 'حدث خطأ بالخادم. حاول لاحقاً.'
                  ? 'ليس لديك صلاحية للوصول'
                  : message),
        statusCode: 403,
        data: code,
      ),
      404 => ServerException(
        message: 'المورد غير موجود',
        statusCode: 404,
        data: code,
      ),
      422 => ServerException(message: message, statusCode: 422, data: code),
      429 => const ServerException(
        message: 'عدد كبير من الطلبات، حاول لاحقًا',
        statusCode: 429,
      ),
      500 || 502 || 503 || 504 => ServerException(
        message: message,
        statusCode: statusCode,
        data: code,
      ),
      _ => ServerException(
        message: message,
        statusCode: statusCode,
        data: code,
      ),
    };
  }

  /// Validates an [ApiResponse] and throws [ServerException] if unsuccessful.
  static void validateApiResponse(ApiResponse response) {
    if (response.isError) {
      throw ServerException(
        message: response.error?.message ?? 'خطأ غير معروف',
        statusCode: response.error?.status,
        data: response.error?.code,
      );
    }
  }

  static String _sanitizeServerMessage(String raw, int? statusCode) {
    final value = raw.trim();
    if (value.isEmpty) {
      return UserFriendlyErrors.fromStatusCode(statusCode);
    }
    final lower = value.toLowerCase();
    const blocked = <String>[
      'http://',
      'https://',
      'wp-json',
      '<html',
      '</html',
      'stacktrace',
      'exception',
    ];
    final unsafe = blocked.any(lower.contains);
    if (unsafe) {
      return UserFriendlyErrors.fromStatusCode(statusCode);
    }
    return value;
  }

  static bool looksLikeHtmlChallenge(Response? response) {
    if (response == null) {
      return false;
    }

    final contentType =
        response.headers.value('content-type')?.toLowerCase() ?? '';
    if (contentType.contains('text/html')) {
      return true;
    }

    final data = response.data;
    if (data is String) {
      final lower = data.toLowerCase();
      return lower.contains('<!doctype html') ||
          lower.contains('<html') ||
          lower.contains('noindex,nofollow');
    }

    return false;
  }
}
