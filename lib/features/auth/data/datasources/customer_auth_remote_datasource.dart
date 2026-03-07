import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../config/constants/endpoints.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../core/network/dio_exception_mapper.dart';
import '../../domain/entities/customer_user.dart';

final customerAuthRemoteDatasourceProvider =
    Provider<CustomerAuthRemoteDatasource>(
      (ref) => CustomerAuthRemoteDatasourceImpl(ref.watch(dioClientProvider)),
    );

abstract class CustomerAuthRemoteDatasource {
  Future<String> login(String emailOrUsername, String password);

  Future<void> register({
    required String email,
    required String password,
    String? username,
    String? firstName,
    String? lastName,
    String? phone,
    String? address1,
    String? city,
  });

  Future<CustomerUser> getMe();

  Future<CustomerUser> updateProfile({
    String? firstName,
    String? lastName,
    String? displayName,
    String? email,
    String? phone,
    String? address1,
    String? city,
  });

  Future<CustomerUser> uploadAvatar(String filePath);

  Future<void> forgotPassword(String email);

  Future<void> resetPassword(String email, String code, String newPassword);

  Future<void> changePassword(String currentPassword, String newPassword);
}

class CustomerAuthRemoteDatasourceImpl implements CustomerAuthRemoteDatasource {
  final DioClient _dioClient;

  CustomerAuthRemoteDatasourceImpl(this._dioClient);

  static const _lexiAuthMeRoute = '/lexi/v1/auth/me';
  static const _lexiProfileUpdateRoute = '/lexi/v1/profile/update';
  static const _lexiLegacyProfileRoute = '/lexi/v1/auth/profile';
  static const _lexiAvatarRoute = '/lexi/v1/profile/avatar';

  static String _restRoutePath(String route) => '/index.php?rest_route=$route';

  @override
  Future<String> login(String emailOrUsername, String password) async {
    try {
      final response = await _dioClient.post(
        Endpoints.customerAuthLogin(),
        // x-www-form-urlencoded to avoid extra web preflight issues.
        data: {'username': emailOrUsername, 'password': password},
        options: Options(
          extra: const {'requiresAuth': false, 'skipAuthRefresh': true},
          contentType: Headers.formUrlEncodedContentType,
        ),
      );

      final map = extractMap(response.data);
      final token =
          (map['access_token'] ?? map['token'] ?? '').toString().trim();
      if (token.isEmpty) {
        throw const FormatException('فشل تسجيل الدخول: لم يتم استلام التوكن.');
      }
      return token;
    } on DioException catch (e) {
      throw DioExceptionMapper.fromDioException(e);
    }
  }

  @override
  Future<void> register({
    required String email,
    required String password,
    String? username,
    String? firstName,
    String? lastName,
    String? phone,
    String? address1,
    String? city,
  }) async {
    try {
      await _dioClient.post(
        Endpoints.customerAuthRegister(),
        data: {
          'email': email,
          'password': password,
          if ((username ?? '').trim().isNotEmpty) 'username': username!.trim(),
          if ((firstName ?? '').trim().isNotEmpty)
            'first_name': firstName!.trim(),
          if ((lastName ?? '').trim().isNotEmpty) 'last_name': lastName!.trim(),
          if ((phone ?? '').trim().isNotEmpty) 'phone': phone!.trim(),
          if ((address1 ?? '').trim().isNotEmpty) 'address_1': address1!.trim(),
          if ((city ?? '').trim().isNotEmpty) 'city': city!.trim(),
        },
        options: Options(
          extra: const {'requiresAuth': false, 'skipAuthRefresh': true},
        ),
      );
    } on DioException catch (e) {
      throw DioExceptionMapper.fromDioException(e);
    }
  }

  @override
  Future<CustomerUser> getMe() async {
    final response = await _getWithFallback([
      _restRoutePath(_lexiAuthMeRoute),
      Endpoints.customerAuthMe(),
    ]);
    return CustomerUser.fromJson(_extractUserMap(response.data));
  }

  @override
  Future<CustomerUser> updateProfile({
    String? firstName,
    String? lastName,
    String? displayName,
    String? email,
    String? phone,
    String? address1,
    String? city,
  }) async {
    final payload = {
      if (firstName != null) 'first_name': firstName.trim(),
      if (lastName != null) 'last_name': lastName.trim(),
      if (displayName != null) 'display_name': displayName.trim(),
      if (email != null) 'email': email.trim(),
      if (phone != null) 'phone': phone.trim(),
      if (address1 != null) 'address_1': address1.trim(),
      if (city != null) 'city': city.trim(),
    };

    final response = await _postWithFallback([
      _restRoutePath(_lexiProfileUpdateRoute),
      Endpoints.customerProfileUpdate(),
      _restRoutePath(_lexiLegacyProfileRoute),
      Endpoints.customerAuthProfile(),
    ], data: payload);
    return CustomerUser.fromJson(_extractUserMap(response.data));
  }

  @override
  Future<CustomerUser> uploadAvatar(String filePath) async {
    final paths = <String>[
      _restRoutePath(_lexiAvatarRoute),
      Endpoints.customerProfileAvatar(),
    ];

    DioException? lastError;
    for (var i = 0; i < paths.length; i++) {
      final path = paths[i];
      final isLast = i == paths.length - 1;

      final formData = FormData.fromMap({
        'avatar': await MultipartFile.fromFile(filePath),
      });

      try {
        final response = await _dioClient.post(
          path,
          data: formData,
          options: Options(contentType: 'multipart/form-data'),
        );
        return CustomerUser.fromJson(_extractUserMap(response.data));
      } on DioException catch (e) {
        lastError = e;
        if (!isLast && _canTryFallbackPath(e)) {
          continue;
        }
        throw DioExceptionMapper.fromDioException(e);
      }
    }

    if (lastError != null) {
      throw DioExceptionMapper.fromDioException(lastError);
    }
    throw const FormatException('تعذر رفع الصورة حالياً.');
  }

  @override
  Future<void> forgotPassword(String email) async {
    try {
      await _dioClient.post(
        Endpoints.forgotPassword(),
        data: {'email': email},
        options: Options(
          extra: const {'requiresAuth': false, 'skipAuthRefresh': true},
        ),
      );
    } on DioException catch (e) {
      throw DioExceptionMapper.fromDioException(e);
    }
  }

  @override
  Future<void> resetPassword(
    String email,
    String code,
    String newPassword,
  ) async {
    try {
      await _dioClient.post(
        Endpoints.resetPassword(),
        data: {'email': email, 'code': code, 'new_password': newPassword},
        options: Options(
          extra: const {'requiresAuth': false, 'skipAuthRefresh': true},
        ),
      );
    } on DioException catch (e) {
      throw DioExceptionMapper.fromDioException(e);
    }
  }

  @override
  Future<void> changePassword(
    String currentPassword,
    String newPassword,
  ) async {
    try {
      await _dioClient.post(
        Endpoints.changePassword(),
        data: {
          'current_password': currentPassword,
          'new_password': newPassword,
        },
      );
    } on DioException catch (e) {
      throw DioExceptionMapper.fromDioException(e);
    }
  }

  Map<String, dynamic> _extractUserMap(dynamic raw) {
    final map = extractMap(raw);
    final user = map['user'];
    if (user is Map<String, dynamic>) {
      return user;
    }
    if (user is Map) {
      return user.map((key, value) => MapEntry(key.toString(), value));
    }
    return map;
  }

  Future<Response<dynamic>> _getWithFallback(List<String> paths) async {
    DioException? lastError;
    for (var i = 0; i < paths.length; i++) {
      final isLast = i == paths.length - 1;
      try {
        return await _dioClient.get(paths[i]);
      } on DioException catch (e) {
        lastError = e;
        if (!isLast && _canTryFallbackPath(e)) {
          continue;
        }
        throw DioExceptionMapper.fromDioException(e);
      }
    }

    if (lastError != null) {
      throw DioExceptionMapper.fromDioException(lastError);
    }
    throw const FormatException('تعذر تنفيذ الطلب.');
  }

  Future<Response<dynamic>> _postWithFallback(
    List<String> paths, {
    required dynamic data,
  }) async {
    DioException? lastError;
    for (var i = 0; i < paths.length; i++) {
      final isLast = i == paths.length - 1;
      try {
        return await _dioClient.post(paths[i], data: data);
      } on DioException catch (e) {
        lastError = e;
        if (!isLast && _canTryFallbackPath(e)) {
          continue;
        }
        throw DioExceptionMapper.fromDioException(e);
      }
    }

    if (lastError != null) {
      throw DioExceptionMapper.fromDioException(lastError);
    }
    throw const FormatException('تعذر تنفيذ الطلب.');
  }

  bool _canTryFallbackPath(DioException e) {
    final statusCode = e.response?.statusCode;
    if (statusCode == null) {
      // Network/CORS issue on one route, try the alternative route.
      return true;
    }

    return statusCode == 404 ||
        statusCode == 405 ||
        statusCode == 502 ||
        statusCode == 503 ||
        statusCode == 504;
  }
}
