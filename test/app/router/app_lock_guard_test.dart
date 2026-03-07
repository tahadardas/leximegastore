import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:lexi_mega_store/app/router/app_lock_guard.dart';
import 'package:lexi_mega_store/core/security/app_lock_service.dart';
import 'package:lexi_mega_store/app/router/app_routes.dart';

class TinyFakeAppLockService extends Fake implements AppLockService {
  @override
  bool get locked => _locked;
  bool _locked = false;
  set locked(bool v) => _locked = v;

  @override
  bool get lockEnabled => _lockEnabled;
  bool _lockEnabled = false;
  set lockEnabled(bool v) => _lockEnabled = v;

  @override
  bool get setupPromptPending => _setupPromptPending;
  bool _setupPromptPending = false;
  set setupPromptPending(bool v) => _setupPromptPending = v;

  @override
  void addListener(VoidCallback listener) {
    // No-op for fake
  }

  @override
  void removeListener(VoidCallback listener) {
    // No-op for fake
  }
}

class FakeGoRouterState extends Fake implements GoRouterState {
  @override
  final Uri uri;
  FakeGoRouterState(this.uri);
}

void main() {
  late TinyFakeAppLockService fakeLock;

  setUp(() {
    fakeLock = TinyFakeAppLockService();
  });

  group('AppLockGuard - redirect', () {
    test('redirects to /security/lock when app is locked', () async {
      fakeLock.locked = true;
      fakeLock.lockEnabled = true;
      final state = FakeGoRouterState(Uri.parse('/home'));

      final result = AppLockGuard.redirect(state, fakeLock);
      expect(result, startsWith(AppRoutePaths.appLock));
    });

    test(
      'redirects to /security/enable when setup prompt is pending',
      () async {
        fakeLock.locked = false;
        fakeLock.lockEnabled = false;
        fakeLock.setupPromptPending = true;
        final state = FakeGoRouterState(Uri.parse('/home'));

        final result = AppLockGuard.redirect(state, fakeLock);
        expect(result, AppRoutePaths.securityEnable);
      },
    );

    test('no redirect when unlocked and not on security routes', () async {
      fakeLock.locked = false;
      fakeLock.setupPromptPending = false;
      final state = FakeGoRouterState(Uri.parse('/home'));

      final result = AppLockGuard.redirect(state, fakeLock);
      expect(result, isNull);
    });

    test(
      'allows access to lock screen and reauth screen while locked',
      () async {
        fakeLock.locked = true;

        // Lock screen
        expect(
          AppLockGuard.redirect(
            FakeGoRouterState(Uri.parse(AppRoutePaths.appLock)),
            fakeLock,
          ),
          isNull,
        );

        // Reauth screen
        expect(
          AppLockGuard.redirect(
            FakeGoRouterState(Uri.parse(AppRoutePaths.securityReauth)),
            fakeLock,
          ),
          isNull,
        );
      },
    );
  });
}
