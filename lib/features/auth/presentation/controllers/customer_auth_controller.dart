import 'dart:convert';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/auth/auth_session_controller.dart';
import '../../../../core/errors/app_exception.dart';
import '../../../../core/session/app_session.dart';
import '../../../../core/storage/secure_store.dart';
import '../../data/repositories/customer_auth_repository_impl.dart';
import '../../domain/entities/customer_user.dart';
import '../../domain/repositories/customer_auth_repository.dart';
import '../../../cart/presentation/controllers/cart_controller.dart';
import '../../../wishlist/presentation/controllers/wishlist_controller.dart';
import '../../../orders/presentation/controllers/my_orders_controller.dart';
import '../../../shipping/presentation/controllers/shipping_controller.dart';

final customerAuthControllerProvider =
    StateNotifierProvider<CustomerAuthController, AsyncValue<CustomerUser?>>((
      ref,
    ) {
      final authStatus = ref.watch(
        authSessionControllerProvider.select((s) => s.state.status),
      );

      final controller = CustomerAuthController(
        repo: ref.watch(customerAuthRepositoryProvider),
        storage: ref.watch(secureStoreProvider),
        appSession: ref.watch(appSessionProvider),
        authSessionController: ref.read(authSessionControllerProvider),
        ref: ref,
      );

      // Auto-logout feature state when core session is cleared
      if (authStatus == AuthSessionStatus.unauthenticated) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          controller.handleLogout();
        });
      }

      return controller;
    });

class CustomerAuthController extends StateNotifier<AsyncValue<CustomerUser?>> {
  final CustomerAuthRepository _repo;
  final SecureStore _storage;
  final AppSession _appSession;
  final AuthSessionController _authSessionController;
  final Ref _ref;
  bool _disposed = false;

  CustomerAuthController({
    required CustomerAuthRepository repo,
    required SecureStore storage,
    required AppSession appSession,
    required AuthSessionController authSessionController,
    required Ref ref,
  }) : _repo = repo,
       _storage = storage,
       _appSession = appSession,
       _authSessionController = authSessionController,
       _ref = ref,
       super(const AsyncLoading()) {
    _checkAuthStatus();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  bool get _canUpdateState => !_disposed;

  void _setState(AsyncValue<CustomerUser?> next) {
    if (!_canUpdateState) {
      return;
    }
    state = next;
  }

  Future<void> _checkAuthStatus() async {
    final token = await _storage.getAccessToken();
    if (!_canUpdateState) {
      return;
    }
    if (token == null || token.isEmpty) {
      _setState(const AsyncData(null));
      return;
    }

    final cachedUser = await _readCachedUser(token);
    if (!_canUpdateState) {
      return;
    }
    if (cachedUser != null) {
      _setState(AsyncData(cachedUser));
    }

    try {
      final freshUser = await _repo.getCurrentUser();
      _setState(AsyncData(freshUser));
    } on AppException catch (e, st) {
      if (e.statusCode == 401 || e.statusCode == 403) {
        await logout();
        return;
      }

      if (cachedUser != null) {
        _setState(AsyncData(cachedUser));
        return;
      }
      _setState(AsyncError(e, st));
    } catch (e, st) {
      if (cachedUser != null) {
        _setState(AsyncData(cachedUser));
        return;
      }
      _setState(AsyncError(e, st));
    }
  }

  Future<CustomerUser?> _readCachedUser(String token) async {
    final raw = await _storage.getCustomerUserJson();
    if (raw == null || raw.trim().isEmpty) {
      return null;
    }

    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        return CustomerUser.fromJson(decoded, token: token);
      }
      if (decoded is Map) {
        return CustomerUser.fromJson(
          decoded.map((key, value) => MapEntry(key.toString(), value)),
          token: token,
        );
      }
    } catch (_) {
      // Ignore cache parse errors and continue with live profile check.
    }
    return null;
  }

  Future<void> login(String emailOrUsername, String password) async {
    _setState(const AsyncLoading());
    final nextState = await AsyncValue.guard(() async {
      await _appSession.login(emailOrUsername, password);
      return _repo.getCurrentUser();
    });
    _setState(nextState);
  }

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
    _setState(const AsyncLoading());
    final nextState = await AsyncValue.guard(() async {
      await _appSession.register(
        email: email,
        password: password,
        username: username,
        firstName: firstName,
        lastName: lastName,
        phone: phone,
        address1: address1,
        city: city,
      );
      return _repo.getCurrentUser();
    });
    _setState(nextState);
  }

  Future<void> refreshProfile() async {
    if (!isAuthenticated) {
      return;
    }

    final previous = state.asData?.value;
    _setState(const AsyncLoading());
    try {
      final user = await _repo.getCurrentUser();
      _setState(AsyncData(user));
    } catch (e, st) {
      if (previous != null) {
        _setState(AsyncData(previous));
        return;
      }
      _setState(AsyncError(e, st));
    }
  }

  Future<CustomerUser> updateProfile({
    String? firstName,
    String? lastName,
    String? displayName,
    String? email,
    String? phone,
    String? address1,
    String? city,
  }) async {
    final previous = state.asData?.value;
    _setState(const AsyncLoading());
    try {
      final user = await _repo.updateProfile(
        firstName: firstName,
        lastName: lastName,
        displayName: displayName,
        email: email,
        phone: phone,
        address1: address1,
        city: city,
      );
      _setState(AsyncData(user));
      return user;
    } catch (e, st) {
      if (previous != null) {
        _setState(AsyncData(previous));
      } else {
        _setState(AsyncError(e, st));
      }
      rethrow;
    }
  }

  Future<CustomerUser> uploadAvatar(String filePath) async {
    final previous = state.asData?.value;
    _setState(const AsyncLoading());
    try {
      final user = await _repo.uploadAvatar(filePath);
      _setState(AsyncData(user));
      return user;
    } catch (e, st) {
      if (previous != null) {
        _setState(AsyncData(previous));
      } else {
        _setState(AsyncError(e, st));
      }
      rethrow;
    }
  }

  Future<void> logout() async {
    // 1. Core logout (tokens, session data)
    await _authSessionController.logout();

    // 2. Clear feature-specific persistent and memory state
    await handleLogout();
  }

  /// Clears feature-specific data (cart, wishlist, orders state).
  /// Called during logout or when core session is invalidated.
  Future<void> handleLogout() async {
    final storage = _ref.read(secureStoreProvider);
    await _ref.read(cartControllerProvider.notifier).clearCart();
    await _ref.read(wishlistControllerProvider.notifier).clear();
    await storage.deleteSupportTicketsJson();
    await storage.deleteCustomerUserJson();
    await storage.deleteAdminUserJson();

    _setState(const AsyncData(null));

    _ref.invalidate(myOrdersControllerProvider);
    _ref.invalidate(selectedCityProvider);
  }

  bool get isAuthenticated => state.asData?.value != null;
}
