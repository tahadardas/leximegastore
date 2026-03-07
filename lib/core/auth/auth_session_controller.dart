import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../session/app_session.dart';
import 'auth_token_refresher.dart';
import 'token_store.dart';

enum AuthSessionStatus { unknown, authenticated, unauthenticated }

class AuthSessionUser {
  final String role;
  final String displayName;
  final String email;

  const AuthSessionUser({
    required this.role,
    required this.displayName,
    required this.email,
  });
}

class AuthSessionState {
  final AuthSessionStatus status;
  final bool isOffline;
  final AuthSessionUser? user;

  const AuthSessionState({
    required this.status,
    this.isOffline = false,
    this.user,
  });

  const AuthSessionState.unknown()
    : this(status: AuthSessionStatus.unknown, isOffline: false);

  const AuthSessionState.unauthenticated()
    : this(status: AuthSessionStatus.unauthenticated, isOffline: false);

  const AuthSessionState.authenticated({
    required AuthSessionUser user,
    bool isOffline = false,
  }) : this(
         status: AuthSessionStatus.authenticated,
         isOffline: isOffline,
         user: user,
       );

  String? get role => user?.role;
  String? get displayName => user?.displayName;
  String? get email => user?.email;
}

class AuthSessionController extends ChangeNotifier {
  final AppSession _appSession;
  final TokenStore _tokenStore;
  final AuthTokenRefresher _tokenRefresher;

  AuthSessionState _state = const AuthSessionState.unknown();
  bool _restoring = false;

  AuthSessionController({
    required AppSession appSession,
    required TokenStore tokenStore,
    required AuthTokenRefresher tokenRefresher,
  }) : _appSession = appSession,
       _tokenStore = tokenStore,
       _tokenRefresher = tokenRefresher {
    _appSession.addListener(_syncFromAppSession);
  }

  AuthSessionState get state => _state;

  Future<void> restoreSession({bool skipStorageRestore = false}) async {
    if (_restoring) return;
    _restoring = true;
    _state = const AuthSessionState.unknown();
    notifyListeners();

    try {
      if (!skipStorageRestore) {
        await _appSession.restoreFromStorage();
      }
      final refreshToken = (await _tokenStore.readRefreshToken() ?? '').trim();

      if (refreshToken.isEmpty) {
        _state = const AuthSessionState.unauthenticated();
        notifyListeners();
        return;
      }

      final result = await _appSession.validateStoredTokenWithState(
        allowOffline: true,
      );

      switch (result) {
        case SessionValidationResult.authenticated:
          _state = AuthSessionState.authenticated(user: _buildUser());
          break;
        case SessionValidationResult.authenticatedOffline:
          _state = AuthSessionState.authenticated(
            user: _buildUser(),
            isOffline: true,
          );
          break;
        case SessionValidationResult.unauthenticated:
          _state = const AuthSessionState.unauthenticated();
          break;
      }
      notifyListeners();
    } catch (_) {
      // Never block app startup.
      final hasRefreshToken = ((_appSession.refreshToken ?? '')
          .trim()
          .isNotEmpty);
      _state = hasRefreshToken && _appSession.hasCachedIdentity
          ? AuthSessionState.authenticated(user: _buildUser(), isOffline: true)
          : const AuthSessionState.unauthenticated();
      notifyListeners();
    } finally {
      _restoring = false;
    }
  }

  Future<TokenRefreshResult> refreshFor401() async {
    final result = await _tokenRefresher.refresh();
    if (result == TokenRefreshResult.invalid) {
      _state = const AuthSessionState.unauthenticated();
      notifyListeners();
    } else if (result == TokenRefreshResult.refreshed &&
        _state.status == AuthSessionStatus.authenticated) {
      final next = AuthSessionState.authenticated(user: _buildUser());
      if (_state.displayName != next.displayName ||
          _state.email != next.email ||
          _state.role != next.role ||
          _state.isOffline != next.isOffline) {
        _state = next;
        notifyListeners();
      }
    }
    return result;
  }

  Future<void> handleUnauthorized401() async {
    await _appSession.clearSession();
    _state = const AuthSessionState.unauthenticated();
    notifyListeners();
  }

  Future<void> logout() async {
    await _appSession.logout();
    _state = const AuthSessionState.unauthenticated();
    notifyListeners();
  }

  void _syncFromAppSession() {
    if (_appSession.isLoggedIn) {
      final next = AuthSessionState.authenticated(user: _buildUser());
      if (_state.status != next.status ||
          _state.role != next.role ||
          _state.displayName != next.displayName ||
          _state.email != next.email ||
          _state.isOffline != next.isOffline) {
        _state = next;
        notifyListeners();
      }
      return;
    }

    if (_state.status != AuthSessionStatus.unauthenticated) {
      _state = const AuthSessionState.unauthenticated();
      notifyListeners();
    }
  }

  AuthSessionUser _buildUser() {
    return AuthSessionUser(
      role: (_appSession.role ?? 'customer').trim().isEmpty
          ? 'customer'
          : (_appSession.role ?? 'customer').trim(),
      displayName: (_appSession.displayName ?? '').trim(),
      email: (_appSession.email ?? '').trim(),
    );
  }

  @override
  void dispose() {
    _appSession.removeListener(_syncFromAppSession);
    super.dispose();
  }
}

final authSessionControllerProvider =
    ChangeNotifierProvider<AuthSessionController>((ref) {
      return AuthSessionController(
        appSession: ref.watch(appSessionProvider),
        tokenStore: ref.watch(tokenStoreProvider),
        tokenRefresher: ref.watch(authTokenRefresherProvider),
      );
    });
