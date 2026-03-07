import 'user_friendly_errors.dart';

class ApiErrorMapper {
  static String map(dynamic error) {
    return UserFriendlyErrors.from(
      error is Object ? error : Exception(error.toString()),
      fallback: 'حدث خطأ غير متوقع. حاول مرة أخرى.',
    );
  }
}
