import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:synchronized/synchronized.dart';

import '../session/app_session.dart';

/// Single-flight token refresh coordinator.
///
/// Guarantees only one refresh request runs at a time while others await
/// the same in-flight future.
class AuthTokenRefresher {
  final AppSession _appSession;
  final Lock _lock = Lock();
  Future<TokenRefreshResult>? _inFlight;

  AuthTokenRefresher(this._appSession);

  Future<TokenRefreshResult> refresh() async {
    final existing = _inFlight;
    if (existing != null) {
      return existing;
    }

    return _lock.synchronized(() {
      final current = _inFlight;
      if (current != null) {
        return current;
      }

      final future = _appSession.refreshAccessToken().whenComplete(() {
        _inFlight = null;
      });
      _inFlight = future;
      return future;
    });
  }
}

final authTokenRefresherProvider = Provider<AuthTokenRefresher>((ref) {
  final session = ref.read(appSessionProvider);
  return AuthTokenRefresher(session);
});
