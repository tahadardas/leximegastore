import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/storage/secure_store.dart';
import '../../domain/entities/customer_user.dart';
import '../../domain/repositories/customer_auth_repository.dart';
import '../datasources/customer_auth_remote_datasource.dart';

final customerAuthRepositoryProvider = Provider<CustomerAuthRepository>((ref) {
  return CustomerAuthRepositoryImpl(
    ref.watch(customerAuthRemoteDatasourceProvider),
    ref.watch(secureStoreProvider),
  );
});

class CustomerAuthRepositoryImpl implements CustomerAuthRepository {
  final CustomerAuthRemoteDatasource _datasource;
  final SecureStore _store;

  CustomerAuthRepositoryImpl(this._datasource, this._store);

  @override
  Future<CustomerUser> login(String emailOrUsername, String password) async {
    final token = await _datasource.login(emailOrUsername, password);
    await _store.setAccessToken(token);

    try {
      final user = await _datasource.getMe();
      final merged = user.copyWith(token: token);
      await _store.setUserId(merged.id.toString());
      await _store.setCustomerUserJson(jsonEncode(merged.toJson()));
      return merged;
    } catch (_) {
      await _store.clearCustomerSession();
      rethrow;
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
    await _datasource.register(
      email: email,
      password: password,
      username: username,
      firstName: firstName,
      lastName: lastName,
      phone: phone,
      address1: address1,
      city: city,
    );
  }

  @override
  Future<CustomerUser> getCurrentUser() async {
    final user = await _datasource.getMe();
    final token = await _store.getAccessToken() ?? '';
    final merged = user.copyWith(token: token);
    await _store.setUserId(merged.id.toString());
    await _store.setCustomerUserJson(jsonEncode(merged.toJson()));
    return merged;
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
    final user = await _datasource.updateProfile(
      firstName: firstName,
      lastName: lastName,
      displayName: displayName,
      email: email,
      phone: phone,
      address1: address1,
      city: city,
    );
    final token = await _store.getAccessToken() ?? '';
    final merged = user.copyWith(token: token);
    await _store.setUserId(merged.id.toString());
    await _store.setCustomerUserJson(jsonEncode(merged.toJson()));
    return merged;
  }

  @override
  Future<CustomerUser> uploadAvatar(String filePath) async {
    final user = await _datasource.uploadAvatar(filePath);
    final token = await _store.getAccessToken() ?? '';
    final merged = user.copyWith(token: token);
    await _store.setUserId(merged.id.toString());
    await _store.setCustomerUserJson(jsonEncode(merged.toJson()));
    return merged;
  }

  @override
  Future<void> forgotPassword(String email) async {
    await _datasource.forgotPassword(email);
  }

  @override
  Future<void> resetPassword(
    String email,
    String code,
    String newPassword,
  ) async {
    await _datasource.resetPassword(email, code, newPassword);
  }

  @override
  Future<void> changePassword(
    String currentPassword,
    String newPassword,
  ) async {
    await _datasource.changePassword(currentPassword, newPassword);
  }

  @override
  Future<void> logout() async {
    await _store.clearCustomerSession();
  }
}
