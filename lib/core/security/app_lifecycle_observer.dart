import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_lock_service.dart';

/// Observes app lifecycle for hard-exit scenarios only.
///
/// We intentionally avoid locking on `inactive/paused` so users are not
/// prompted for PIN every time they quickly switch apps.
class AppLifecycleObserver extends WidgetsBindingObserver {
  final AppLockService _lockService;

  AppLifecycleObserver(this._lockService);

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.detached:
        _lockService.lock();
        break;
      case AppLifecycleState.inactive:
      case AppLifecycleState.paused:
      case AppLifecycleState.resumed:
      case AppLifecycleState.hidden:
        // No-op: keep session unlocked while app is only backgrounded.
        break;
    }
  }
}

/// Provider that creates and registers the lifecycle observer.
/// Must be watched in app.dart to activate registration.
final appLifecycleObserverProvider = Provider<AppLifecycleObserver>((ref) {
  final lockService = ref.watch(appLockServiceProvider);
  final observer = AppLifecycleObserver(lockService);
  WidgetsBinding.instance.addObserver(observer);
  ref.onDispose(() => WidgetsBinding.instance.removeObserver(observer));
  return observer;
});
