import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lexi_mega_store/core/auth/token_store.dart';
import 'package:lexi_mega_store/core/security/app_lifecycle_observer.dart';
import 'package:lexi_mega_store/core/security/app_lock_service.dart';

class _FakeStorage extends Fake implements FlutterSecureStorage {}

class _FakeTokenStore extends Fake implements TokenStore {}

class _SpyAppLockService extends AppLockService {
  int lockCallCount = 0;

  _SpyAppLockService({required super.storage, required super.tokenStore});

  @override
  void lock() {
    lockCallCount++;
    super.lock();
  }
}

void main() {
  test(
    'AppLifecycleObserver does not lock on paused/inactive and locks on detached',
    () {
      final service = _SpyAppLockService(
        storage: _FakeStorage(),
        tokenStore: _FakeTokenStore(),
      );
      final observer = AppLifecycleObserver(service);

      observer.didChangeAppLifecycleState(AppLifecycleState.inactive);
      observer.didChangeAppLifecycleState(AppLifecycleState.paused);
      observer.didChangeAppLifecycleState(AppLifecycleState.resumed);
      observer.didChangeAppLifecycleState(AppLifecycleState.hidden);
      expect(service.lockCallCount, 0);

      observer.didChangeAppLifecycleState(AppLifecycleState.detached);
      expect(service.lockCallCount, 1);
    },
  );
}
