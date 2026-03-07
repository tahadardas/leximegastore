import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/app_exception.dart';
import '../../../../core/storage/secure_store.dart';
import '../../domain/entities/admin_user.dart';
import '../../domain/repositories/admin_auth_repository.dart';
import '../datasources/admin_auth_remote_datasource.dart';

final adminAuthRepositoryProvider = Provider<AdminAuthRepository>((ref) {
  return AdminAuthRepositoryImpl(
    ref.watch(adminAuthRemoteDatasourceProvider),
    ref.watch(secureStoreProvider),
  );
});

class AdminAuthRepositoryImpl implements AdminAuthRepository {
  final AdminAuthRemoteDatasource _datasource;
  final SecureStore _store;

  AdminAuthRepositoryImpl(this._datasource, this._store);

  @override
  Future<AdminUser> login(String email, String password) async {
    final token = await _datasource.login(email, password);
    await _store.setAdminToken(token);

    try {
      final user = await _datasource.getMe();
      final mergedUser = AdminUser(
        id: user.id,
        username: user.username,
        email: user.email,
        displayName: user.displayName,
        roles: user.roles,
        token: token,
      );
      await _store.setAdminUserJson(jsonEncode(mergedUser.toJson()));
      return mergedUser;
    } on AppException catch (e) {
      await _store.deleteAdminToken();
      await _store.deleteAdminUserJson();

      if (e.data == 'jwt_auth_bad_config') {
        throw const ServerException(
          message:
              'خطأ إعداد JWT على السيرفر. تأكد من JWT_AUTH_SECRET_KEY وتمرير Authorization header.',
          statusCode: 403,
          data: 'jwt_auth_bad_config',
        );
      }

      if (e.statusCode == 401 || e.statusCode == 403) {
        throw const ServerException(
          message: 'هذا الحساب لا يملك صلاحية الدخول إلى لوحة التحكم.',
          statusCode: 403,
        );
      }
      rethrow;
    } catch (_) {
      await _store.deleteAdminToken();
      await _store.deleteAdminUserJson();
      rethrow;
    }
  }

  @override
  Future<AdminUser> getCurrentUser() async {
    final user = await _datasource.getMe();
    final token = await _store.getAdminToken() ?? '';
    final mergedUser = AdminUser(
      id: user.id,
      username: user.username,
      email: user.email,
      displayName: user.displayName,
      roles: user.roles,
      token: token,
    );
    await _store.setAdminUserJson(jsonEncode(mergedUser.toJson()));
    return mergedUser;
  }
}
