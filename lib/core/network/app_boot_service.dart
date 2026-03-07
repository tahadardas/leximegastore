import 'package:flutter/foundation.dart';

import '../auth/auth_session_controller.dart';
import '../session/app_session.dart';
import 'network_guard.dart';

/// Sequential app boot flow to avoid startup request storms.
class AppBootService {
  AppBootService({
    required this.networkGuard,
    required this.appSession,
    required this.authSessionController,
  });

  final NetworkGuard networkGuard;
  final AppSession appSession;
  final AuthSessionController authSessionController;

  bool _bootCompleted = false;
  Future<void>? _inFlightBoot;

  bool get isBootCompleted => _bootCompleted;

  Future<void> boot() async {
    final existing = _inFlightBoot;
    if (existing != null) {
      return existing;
    }

    final next = _bootInternal()
        .catchError((Object error, StackTrace stackTrace) {
          if (kDebugMode) {
            debugPrint('[AppBootService] boot failed: $error');
          }
        })
        .whenComplete(() {
          _bootCompleted = true;
          _inFlightBoot = null;
        });
    _inFlightBoot = next;
    return next;
  }

  Future<void> _bootInternal() async {
    if (kDebugMode) {
      debugPrint('[AppBootService] step1 check connectivity');
    }
    await networkGuard.start();
    await networkGuard.hasConnectivity();

    if (kDebugMode) {
      debugPrint('[AppBootService] step2 load stored tokens');
    }
    await appSession.restoreFromStorage();

    if (kDebugMode) {
      debugPrint('[AppBootService] step3 validate token silently');
    }
    await authSessionController.restoreSession(skipStorageRestore: true);

    if (kDebugMode) {
      debugPrint('[AppBootService] step4 fetch profile if authenticated');
    }
    if (authSessionController.state.status == AuthSessionStatus.authenticated) {
      await appSession.refreshUserData();
    }

    if (kDebugMode) {
      debugPrint('[AppBootService] step5 polling starts after UI bootstrap');
      debugPrint('[AppBootService] step6 preload starts after UI bootstrap');
    }
  }
}
