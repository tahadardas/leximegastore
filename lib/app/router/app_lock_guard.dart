import 'package:go_router/go_router.dart';

import '../../core/security/app_lock_service.dart';
import 'app_routes.dart';

/// Global route guard for App Lock.
///
/// Wire this into GoRouter's [redirect] callback:
/// ```dart
/// redirect: (context, state) {
///   final lockRedirect = AppLockGuard.redirect(state, lockService);
///   if (lockRedirect != null) return lockRedirect;
///   // ... other redirect logic
/// },
/// ```
class AppLockGuard {
  AppLockGuard._();

  /// Paths that are allowed to be accessed while the app is locked.
  static const _allowedWhileLocked = {
    AppRoutePaths.appLock,
    AppRoutePaths.securityReauth,
    AppRoutePaths.login,
    AppRoutePaths.register,
    AppRoutePaths.forgotPassword,
    AppRoutePaths.splash,
  };

  /// Paths that should never appear as a "next" redirect target
  /// (prevents lock-screen → lock-screen redirect loops).
  static const _blockedAsNext = {
    AppRoutePaths.appLock,
    AppRoutePaths.securityReauth,
    AppRoutePaths.securityEnable,
    AppRoutePaths.pinSetup,
    AppRoutePaths.login,
    AppRoutePaths.register,
    AppRoutePaths.splash,
  };

  /// Returns a redirect path if routing should be intercepted, or null to allow.
  static String? redirect(GoRouterState state, AppLockService lockService) {
    final path = state.uri.path;

    // --- Lock enforcement ---
    if (lockService.locked) {
      if (_allowedWhileLocked.contains(path)) return null;
      final next = _sanitizeNext(state.uri.toString());
      return next != null
          ? '${AppRoutePaths.appLock}?next=${Uri.encodeComponent(next)}'
          : AppRoutePaths.appLock;
    }

    // --- Setup-prompt redirect ---
    if (lockService.setupPromptPending &&
        !lockService.lockEnabled &&
        path != AppRoutePaths.securityEnable &&
        path != AppRoutePaths.securityReauth &&
        path != AppRoutePaths.appLock) {
      return AppRoutePaths.securityEnable;
    }

    return null;
  }

  /// Decodes and validates the `next` query parameter.
  /// Returns null if the path is unsafe or should not be used.
  static String? sanitizeNext(String? rawNext) => _sanitizeNext(rawNext);

  static String? _sanitizeNext(String? rawNext) {
    final raw = (rawNext ?? '').trim();
    if (raw.isEmpty) return null;
    try {
      final decoded = Uri.decodeComponent(raw).trim();
      if (decoded.isEmpty || !decoded.startsWith('/')) return null;
      final path = Uri.parse(decoded).path;
      if (_blockedAsNext.contains(path)) return null;
      return decoded;
    } catch (_) {
      return null;
    }
  }
}
