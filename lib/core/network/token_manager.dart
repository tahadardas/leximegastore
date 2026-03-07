import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:synchronized/synchronized.dart';

import '../auth/auth_session_controller.dart';
import '../session/app_session.dart';
import '../storage/secure_store.dart';
import 'submission_lock_service.dart';

class TokenManager {
  TokenManager._internal();

  static final TokenManager instance = TokenManager._internal();

  final Lock _refreshLock = Lock();

  SecureStore? _secureStore;
  Future<TokenRefreshResult> Function()? _onRefreshToken;
  Future<void> Function()? _onUnauthorized;
  SubmissionLockService? _submissionLocks;

  Future<TokenRefreshResult>? _refreshInFlight;
  String? _accessTokenCache;
  DateTime? _accessTokenExpiresAt;

  void configure({
    required SecureStore secureStore,
    required SubmissionLockService submissionLocks,
    Future<TokenRefreshResult> Function()? onRefreshToken,
    Future<void> Function()? onUnauthorized,
  }) {
    _secureStore = secureStore;
    _submissionLocks = submissionLocks;
    _onRefreshToken = onRefreshToken;
    _onUnauthorized = onUnauthorized;
  }

  Future<String?> getValidAccessToken() async {
    await _loadFromStorageIfNeeded();

    final token = _accessTokenCache;
    if (token == null || token.isEmpty) {
      return null;
    }

    if (!_isExpired(token)) {
      return token;
    }

    final refreshResult = await refresh();
    if (refreshResult != TokenRefreshResult.refreshed) {
      return null;
    }

    await _loadFromStorageIfNeeded(force: true);
    return _accessTokenCache;
  }

  Future<TokenRefreshResult> refresh() async {
    final current = _refreshInFlight;
    if (current != null) {
      return current;
    }

    return _refreshLock.synchronized(() {
      final insideLock = _refreshInFlight;
      if (insideLock != null) {
        return insideLock;
      }

      final future = _runRefresh().whenComplete(() {
        _refreshInFlight = null;
      });
      _refreshInFlight = future;
      return future;
    });
  }

  Future<void> clearCachedToken() async {
    _accessTokenCache = null;
    _accessTokenExpiresAt = null;
  }

  Future<TokenRefreshResult> _runRefresh() async {
    final locks = _submissionLocks;
    if (locks == null) {
      return TokenRefreshResult.transientFailure;
    }

    return locks.run<TokenRefreshResult>(
      key: 'auth:refresh-token',
      action: () async {
        if (kDebugMode) {
          debugPrint('[TokenManager] refresh triggered');
        }

        final callback = _onRefreshToken;
        if (callback == null) {
          await _handleUnauthorized();
          return TokenRefreshResult.invalid;
        }

        try {
          final result = await callback();
          if (result == TokenRefreshResult.refreshed) {
            await _loadFromStorageIfNeeded(force: true);
            return result;
          }

          if (result == TokenRefreshResult.invalid) {
            await _handleUnauthorized();
          }
          return result;
        } catch (error) {
          if (kDebugMode) {
            debugPrint('[TokenManager] refresh failed: $error');
          }
          return TokenRefreshResult.transientFailure;
        }
      },
    );
  }

  Future<void> _loadFromStorageIfNeeded({bool force = false}) async {
    if (!force && _accessTokenCache != null) {
      return;
    }

    final store = _secureStore;
    if (store == null) {
      return;
    }

    final token = (await store.getAccessToken() ?? '').trim();
    _accessTokenCache = token.isEmpty ? null : token;
    _accessTokenExpiresAt = _parseJwtExpiry(_accessTokenCache);
  }

  Future<void> _handleUnauthorized() async {
    await clearCachedToken();
    final callback = _onUnauthorized;
    if (callback != null) {
      await callback();
    }
  }

  bool _isExpired(String token) {
    final expiry = _accessTokenExpiresAt ?? _parseJwtExpiry(token);
    _accessTokenExpiresAt = expiry;
    if (expiry == null) {
      // Fail-open for non-JWT tokens.
      return false;
    }

    final nowWithSkew = DateTime.now().toUtc().add(const Duration(seconds: 45));
    return nowWithSkew.isAfter(expiry);
  }

  DateTime? _parseJwtExpiry(String? token) {
    final raw = (token ?? '').trim();
    if (raw.isEmpty) {
      return null;
    }

    final parts = raw.split('.');
    if (parts.length < 2) {
      return null;
    }

    try {
      final payload = utf8.decode(
        base64Url.decode(base64Url.normalize(parts[1])),
      );
      final decoded = jsonDecode(payload);
      if (decoded is! Map) {
        return null;
      }
      final exp = decoded['exp'];
      if (exp is int) {
        return DateTime.fromMillisecondsSinceEpoch(exp * 1000, isUtc: true);
      }
      if (exp is String) {
        final value = int.tryParse(exp);
        if (value != null) {
          return DateTime.fromMillisecondsSinceEpoch(value * 1000, isUtc: true);
        }
      }
      return null;
    } catch (_) {
      return null;
    }
  }
}

final tokenManagerProvider = Provider<TokenManager>((ref) {
  final manager = TokenManager.instance;
  final authSessionController = ref.read(authSessionControllerProvider);
  manager.configure(
    secureStore: ref.watch(secureStoreProvider),
    submissionLocks: ref.watch(submissionLockServiceProvider),
    onRefreshToken: authSessionController.refreshFor401,
    onUnauthorized: authSessionController.handleUnauthorized401,
  );
  return manager;
});
