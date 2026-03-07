import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:logger/logger.dart';
import 'package:synchronized/synchronized.dart';

import '../auth/token_store.dart';
import '../errors/app_failure.dart';
import '../services/auth_service.dart';

enum SessionValidationResult {
  authenticated,
  unauthenticated,
  authenticatedOffline,
}

enum TokenRefreshResult { refreshed, invalid, transientFailure }

class AppSession extends ChangeNotifier {
  static const _userRoleKey = 'user_role';
  static const _displayNameKey = 'display_name';
  static const _emailKey = 'email';
  static const _biometricEnabledKey = 'biometric_enabled';

  final FlutterSecureStorage _storage;
  final AuthService _authService;
  final TokenStore _tokenStore;
  final _logger = Logger();
  final Lock _refreshLock = Lock();
  Future<TokenRefreshResult>? _refreshInFlight;

  bool _isLoggedIn = false;
  bool _biometricEnabled = false;
  String? _token;
  String? _refreshToken;
  String? _displayName;
  String? _email;
  String? _phone;
  String? _address1;
  String? _city;
  String? _role; // administrator, shop_manager, delivery_agent, customer, guest
  bool _isLoading = true;

  AppSession(this._storage, this._authService, {TokenStore? tokenStore})
    : _tokenStore = tokenStore ?? const TokenStore();

  bool get isLoggedIn => _isLoggedIn;
  bool get biometricEnabled => _biometricEnabled;
  bool get isAdmin => _role == 'administrator' || _role == 'shop_manager';
  bool get isDeliveryAgent => _role == 'delivery_agent';
  bool get isLoading => _isLoading;
  String? get token => _token;
  String? get refreshToken => _refreshToken;
  String? get displayName => _displayName;
  String? get email => _email;
  String? get phone => _phone;
  String? get address1 => _address1;
  String? get city => _city;
  String? get role => _role;
  bool get hasStoredToken => (_token ?? '').trim().isNotEmpty;
  bool get hasStoredRefreshToken => (_refreshToken ?? '').trim().isNotEmpty;
  bool get hasCachedIdentity =>
      (_displayName ?? '').trim().isNotEmpty ||
      (_email ?? '').trim().isNotEmpty;

  Future<void> init() => restoreFromStorage();

  Future<void> restoreFromStorage() async {
    _isLoading = true;
    notifyListeners();
    try {
      _token = await _tokenStore.readAccessToken();
      _refreshToken = await _tokenStore.readRefreshToken();
      _role =
          await _tokenStore.readUserRoleCache() ??
          await _storage.read(key: _userRoleKey);
      _displayName = await _storage.read(key: _displayNameKey);
      _email = await _storage.read(key: _emailKey);

      final bioStr = await _storage.read(key: _biometricEnabledKey);
      _biometricEnabled = !kIsWeb && bioStr == 'true';

      // Treat refresh token as source of persisted authentication.
      _isLoggedIn =
          (_refreshToken ?? '').trim().isNotEmpty && hasCachedIdentity;
    } catch (e, st) {
      if (kDebugMode) {
        _logger.e('restoreFromStorage failed', error: e, stackTrace: st);
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> saveSession({
    required String token,
    String? refreshToken,
    required String role,
    required String displayName,
    required String email,
    String? phone,
    String? address1,
    String? city,
  }) async {
    _token = token.trim();
    if ((refreshToken ?? '').trim().isNotEmpty) {
      _refreshToken = refreshToken!.trim();
    }
    _role = role.trim();
    _displayName = displayName.trim();
    _email = email.trim();
    _phone = (phone ?? '').trim();
    _address1 = (address1 ?? '').trim();
    _city = (city ?? '').trim();
    _isLoggedIn = _token!.isNotEmpty && (_refreshToken ?? '').trim().isNotEmpty;

    await _tokenStore.saveAccessToken(_token!);
    if ((_refreshToken ?? '').trim().isNotEmpty) {
      await _tokenStore.saveRefreshToken(_refreshToken!);
    }
    await _tokenStore.saveUserRoleCache(_role ?? 'customer');
    await _tokenStore.saveLastLoginAt(DateTime.now());

    await _storage.write(key: _userRoleKey, value: _role);
    await _storage.write(key: _displayNameKey, value: _displayName);
    await _storage.write(key: _emailKey, value: _email);

    notifyListeners();
  }

  Future<void> clearSession() async {
    _isLoggedIn = false;
    _token = null;
    _refreshToken = null;
    _role = null;
    _displayName = null;
    _email = null;
    _phone = null;
    _address1 = null;
    _city = null;
    _biometricEnabled = false;

    await _tokenStore.clear();
    await _storage.delete(key: _userRoleKey);
    await _storage.delete(key: _displayNameKey);
    await _storage.delete(key: _emailKey);
    await _storage.write(key: _biometricEnabledKey, value: 'false');

    notifyListeners();
  }

  Future<void> setBiometricEnabled(bool value) async {
    final enabled = !kIsWeb && value;
    _biometricEnabled = enabled;
    await _storage.write(
      key: _biometricEnabledKey,
      value: enabled ? 'true' : 'false',
    );
    notifyListeners();
  }

  Future<void> login(String username, String password) async {
    final auth = await _authService.login(username, password);
    final userData = auth.user ?? await _authService.getMe(auth.accessToken);
    await _applyUserData(
      userData,
      auth.accessToken,
      refreshToken: auth.refreshToken,
    );
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
    final auth = await _authService.register(
      email: email,
      password: password,
      username: username,
      firstName: firstName,
      lastName: lastName,
      phone: phone,
      address1: address1,
      city: city,
    );
    final userData = auth.user ?? await _authService.getMe(auth.accessToken);
    await _applyUserData(
      userData,
      auth.accessToken,
      refreshToken: auth.refreshToken,
    );
  }

  Future<TokenRefreshResult> refreshAccessToken() async {
    final pending = _refreshInFlight;
    if (pending != null) {
      return pending;
    }

    final future = _refreshLock.synchronized<TokenRefreshResult>(() async {
      final inLockPending = _refreshInFlight;
      if (inLockPending != null) {
        return inLockPending;
      }

      final refreshFuture = _refreshAccessTokenInternal().whenComplete(() {
        _refreshInFlight = null;
      });
      _refreshInFlight = refreshFuture;
      return refreshFuture;
    });

    return future;
  }

  Future<TokenRefreshResult> _refreshAccessTokenInternal() async {
    final storedRefresh =
        (_refreshToken ?? await _tokenStore.readRefreshToken() ?? '').trim();
    if (storedRefresh.isEmpty) {
      await clearSession();
      return TokenRefreshResult.invalid;
    }

    try {
      final tokens = await _authService.refresh(storedRefresh);
      final accessToken = tokens.accessToken.trim();
      if (accessToken.isEmpty) {
        await clearSession();
        return TokenRefreshResult.invalid;
      }

      final rotatedRefresh = (tokens.refreshToken ?? storedRefresh).trim();

      _token = accessToken;
      _refreshToken = rotatedRefresh;
      _isLoggedIn = true;

      await _tokenStore.saveAccessToken(accessToken);
      await _tokenStore.saveRefreshToken(rotatedRefresh);
      await _tokenStore.saveLastLoginAt(DateTime.now());
      notifyListeners();

      return TokenRefreshResult.refreshed;
    } catch (e, st) {
      if (_isUnauthorizedFailure(e)) {
        await clearSession();
        return TokenRefreshResult.invalid;
      }

      if (_isNetworkFailure(e)) {
        if (kDebugMode) {
          _logger.w(
            'refreshAccessToken transient failure',
            error: e,
            stackTrace: st,
          );
        }
        return TokenRefreshResult.transientFailure;
      }

      if (kDebugMode) {
        _logger.w(
          'refreshAccessToken unexpected failure',
          error: e,
          stackTrace: st,
        );
      }
      return TokenRefreshResult.transientFailure;
    }
  }

  Future<void> logout() async {
    final access = (_token ?? '').trim();
    final refresh = (_refreshToken ?? '').trim();
    try {
      await _authService.logout(
        accessToken: access.isEmpty ? null : access,
        refreshToken: refresh.isEmpty ? null : refresh,
      );
    } catch (_) {
      // Best-effort server logout; local cleanup still happens.
    }

    await clearSession();
  }

  Future<bool> validateStoredToken() async {
    final result = await validateStoredTokenWithState(allowOffline: true);
    return result != SessionValidationResult.unauthenticated;
  }

  Future<SessionValidationResult> validateStoredTokenWithState({
    bool allowOffline = true,
  }) async {
    final refresh =
        (_refreshToken ?? await _tokenStore.readRefreshToken() ?? '').trim();

    if (refresh.isEmpty) {
      await clearSession();
      return SessionValidationResult.unauthenticated;
    }

    final refreshResult = await refreshAccessToken();
    if (refreshResult == TokenRefreshResult.invalid) {
      return SessionValidationResult.unauthenticated;
    }

    if (refreshResult == TokenRefreshResult.transientFailure) {
      if (allowOffline && hasCachedIdentity) {
        _isLoggedIn = true;
        notifyListeners();
        return SessionValidationResult.authenticatedOffline;
      }
      return SessionValidationResult.unauthenticated;
    }

    final accessToken = (_token ?? '').trim();
    if (accessToken.isEmpty) {
      await clearSession();
      return SessionValidationResult.unauthenticated;
    }

    try {
      final userData = await _authService.getMe(accessToken);
      await _applyUserData(
        userData,
        accessToken,
        refreshToken: (_refreshToken ?? refresh).trim(),
      );
      return SessionValidationResult.authenticated;
    } catch (e, st) {
      if (_isUnauthorizedFailure(e)) {
        await clearSession();
        return SessionValidationResult.unauthenticated;
      }

      if (allowOffline && hasCachedIdentity && _isNetworkFailure(e)) {
        if (kDebugMode) {
          _logger.w(
            'validateStoredTokenWithState offline fallback',
            error: e,
            stackTrace: st,
          );
        }
        _isLoggedIn = true;
        notifyListeners();
        return SessionValidationResult.authenticatedOffline;
      }

      await clearSession();
      return SessionValidationResult.unauthenticated;
    }
  }

  Future<void> refreshUserData() async {
    final accessToken = (_token ?? '').trim();
    if (accessToken.isEmpty) {
      return;
    }
    try {
      final userData = await _authService.getMe(accessToken);
      await _applyUserData(
        userData,
        accessToken,
        refreshToken: (_refreshToken ?? '').trim(),
      );
    } catch (e, st) {
      if (kDebugMode) {
        _logger.w('refreshUserData failed', error: e, stackTrace: st);
      }
    }
  }

  Future<void> _applyUserData(
    Map<String, dynamic> user,
    String accessToken, {
    String? refreshToken,
  }) async {
    final displayName = (user['display_name'] ?? '').toString();
    final email = (user['email'] ?? '').toString();
    final role = _resolveRole(user);

    await saveSession(
      token: accessToken,
      refreshToken: refreshToken,
      role: role,
      displayName: displayName,
      email: email,
      phone: (user['billing_phone'] ?? user['phone'] ?? '').toString(),
      address1: (user['billing_address_1'] ?? user['address_1'] ?? '')
          .toString(),
      city: (user['billing_city'] ?? user['city'] ?? '').toString(),
    );
  }

  String _resolveRole(Map<String, dynamic> user) {
    final roles = List<String>.from(user['roles'] ?? const <String>[]);
    if (user['is_admin'] == true || roles.contains('administrator')) {
      return 'administrator';
    }
    if (roles.contains('shop_manager')) {
      return 'shop_manager';
    }
    if (roles.contains('delivery_agent')) {
      return 'delivery_agent';
    }
    return 'customer';
  }

  bool _isUnauthorizedFailure(Object error) {
    if (error is AppFailure) {
      return error.code == '401' || error.code == '403';
    }

    final text = error.toString().toLowerCase();
    return text.contains('401') ||
        text.contains('403') ||
        text.contains('jwt_auth_invalid_token') ||
        text.contains('session expired');
  }

  bool _isNetworkFailure(Object error) {
    if (error is AppFailure) {
      final code = (error.code ?? '').toLowerCase();
      if (code == 'network' || code == 'timeout') {
        return true;
      }
    }

    final text = error.toString().toLowerCase();
    return text.contains('timeout') ||
        text.contains('socketexception') ||
        text.contains('connection error') ||
        text.contains('failed host lookup');
  }
}

// Global Provider
final appSessionProvider = ChangeNotifierProvider<AppSession>((ref) {
  // Overridden in main.dart
  throw UnimplementedError('Provider was not overridden');
});
