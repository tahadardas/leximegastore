/// Base exception for the application.
sealed class AppException implements Exception {
  final String message;
  final int? statusCode;
  final dynamic data;

  const AppException({required this.message, this.statusCode, this.data});

  @override
  String toString() =>
      '$runtimeType(message: $message, statusCode: $statusCode)';
}

/// Server returned an error response.
class ServerException extends AppException {
  const ServerException({required super.message, super.statusCode, super.data});
}

/// Local cache read/write failure.
class CacheException extends AppException {
  const CacheException({required super.message, super.data});
}

/// User is not authenticated or token expired.
class UnauthorizedException extends AppException {
  const UnauthorizedException({
    super.message = 'غير مصرح بالوصول',
    super.statusCode = 401,
  });
}

/// No internet connection.
class NetworkException extends AppException {
  const NetworkException({super.message = 'لا يوجد اتصال بالإنترنت'});
}

/// Request timed out.
class TimeoutException extends AppException {
  const TimeoutException({super.message = 'انتهت مهلة الاتصال'});
}

/// Generic unexpected error.
class UnknownException extends AppException {
  const UnknownException({super.message = 'حدث خطأ غير متوقع', super.data});
}
