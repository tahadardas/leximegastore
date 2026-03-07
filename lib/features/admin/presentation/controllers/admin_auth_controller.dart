import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/app_exception.dart';
import '../../../../core/storage/secure_store.dart';
import '../../../../core/auth/auth_session_controller.dart';
import 'package:flutter/widgets.dart';
import '../../data/repositories/admin_auth_repository_impl.dart';
import '../../domain/entities/admin_user.dart';
import '../../domain/repositories/admin_auth_repository.dart';

final adminAuthControllerProvider =
    StateNotifierProvider<AdminAuthController, AsyncValue<AdminUser?>>((ref) {
      final authStatus = ref.watch(
        authSessionControllerProvider.select((s) => s.state.status),
      );

      final controller = AdminAuthController(
        ref.watch(adminAuthRepositoryProvider),
        ref.watch(secureStoreProvider),
      );

      // Auto-logout admin state when core session is cleared
      if (authStatus == AuthSessionStatus.unauthenticated) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          controller.handleLogout();
        });
      }

      return controller;
    });

class AdminAuthController extends StateNotifier<AsyncValue<AdminUser?>> {
  final AdminAuthRepository _repo;
  final SecureStore _storage;

  AdminAuthController(this._repo, this._storage) : super(const AsyncLoading()) {
    _checkAuthStatus();
  }

  Future<void> _checkAuthStatus() async {
    final token = await _storage.getAdminToken();
    if (!mounted) return;
    if (token == null || token.isEmpty) {
      state = const AsyncData(null);
      return;
    }

    final cachedUser = await _readCachedUser(token);
    if (!mounted) return;
    if (cachedUser != null) {
      state = AsyncData(cachedUser);
    }

    try {
      final freshUser = await _repo.getCurrentUser();
      if (!mounted) return;
      state = AsyncData(freshUser);
    } on AppException catch (e, st) {
      final isAuthFailure =
          e.statusCode == 401 ||
          (e.statusCode == 403 && e.data == 'jwt_auth_bad_config');

      if (isAuthFailure) {
        await logout();
        return;
      }

      if (cachedUser != null) {
        state = AsyncData(cachedUser);
        return;
      }

      state = AsyncError(e, st);
    } catch (e, st) {
      if (cachedUser != null) {
        state = AsyncData(cachedUser);
        return;
      }
      state = AsyncError(e, st);
    }
  }

  Future<AdminUser?> _readCachedUser(String token) async {
    final raw = await _storage.getAdminUserJson();
    if (raw == null || raw.trim().isEmpty) {
      return null;
    }

    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        return AdminUser.fromJson(decoded, token: token);
      }
      if (decoded is Map) {
        return AdminUser.fromJson(
          decoded.map((key, value) => MapEntry(key.toString(), value)),
          token: token,
        );
      }
    } catch (_) {
      // Ignore cache parse errors and continue with live validation.
    }

    return null;
  }

  Future<void> login(String email, String password) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      return _repo.login(email, password);
    });
    if (!mounted) return;
  }

  Future<void> logout() async {
    // Note: This only clears admin-specific tokens.
    // To clear the global session, one should call AuthSessionController.logout().
    // However, if we call this, we should also clear our state.
    await handleLogout();
  }

  Future<void> handleLogout() async {
    await _storage.deleteAdminToken();
    await _storage.deleteAdminUserJson();
    if (!mounted) return;
    state = const AsyncData(null);
  }

  bool get isAuthenticated => state.asData?.value != null;

  bool get isAdmin =>
      state.asData?.value?.roles.contains('administrator') ?? false;

  bool get isShopManager =>
      state.asData?.value?.roles.contains('shop_manager') ?? false;

  bool get canAccessAdminPanel => isAdmin || isShopManager;
}
