import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../config/constants/endpoints.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../core/network/dio_exception_mapper.dart';
import '../../domain/entities/admin_user.dart';

final adminAuthRemoteDatasourceProvider = Provider<AdminAuthRemoteDatasource>((
  ref,
) {
  return AdminAuthRemoteDatasourceImpl(ref.watch(dioClientProvider));
});

abstract class AdminAuthRemoteDatasource {
  /// Returns the JWT token string.
  Future<String> login(String email, String password);

  /// Returns the current authenticated admin user details.
  Future<AdminUser> getMe();
}

class AdminAuthRemoteDatasourceImpl implements AdminAuthRemoteDatasource {
  final DioClient _dioClient;

  AdminAuthRemoteDatasourceImpl(this._dioClient);

  @override
  Future<String> login(String email, String password) async {
    final identifier = email.trim();

    // Prefer Lexi auth endpoint first (supports email/username consistently).
    try {
      final response = await _dioClient.post(
        Endpoints.customerAuthLogin(),
        data: {'username': identifier, 'password': password},
        options: Options(
          extra: const {'requiresAuth': false},
          contentType: Headers.formUrlEncodedContentType,
        ),
      );

      final map = extractMap(response.data);
      final token = (map['access_token'] ?? map['token'] ?? '').toString();
      if (token.trim().isNotEmpty) {
        return token.trim();
      }
    } on DioException catch (e) {
      final status = e.response?.statusCode;
      final canFallbackToJwt =
          status == null || status == 404 || status == 405 || status >= 500;
      if (!canFallbackToJwt) {
        throw DioExceptionMapper.fromDioException(e);
      }
    }

    // Fallback to JWT plugin endpoint for legacy server setups.
    try {
      final response = await _dioClient.post(
        Endpoints.jwtToken(),
        // Use x-www-form-urlencoded to avoid browser preflight on Flutter Web.
        // Some hosting/CDN stacks block OPTIONS on /wp-json/*.
        data: {'username': identifier, 'password': password},
        options: Options(
          extra: const {'requiresAuth': false},
          contentType: Headers.formUrlEncodedContentType,
        ),
      );

      final map = extractMap(response.data);
      final token = (map['token'] ?? '').toString();
      if (token.isEmpty) {
        throw const FormatException('فشل تسجيل الدخول: لم يتم استلام التوكن.');
      }
      return token;
    } on DioException catch (e) {
      throw DioExceptionMapper.fromDioException(e);
    }
  }

  @override
  Future<AdminUser> getMe() async {
    try {
      final response = await _dioClient.get(Endpoints.adminMe());
      return AdminUser.fromJson(extractMap(response.data));
    } on DioException catch (e) {
      throw DioExceptionMapper.fromDioException(e);
    }
  }
}
