import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:lexi_mega_store/core/security/app_lock_service.dart';
import 'package:lexi_mega_store/core/auth/token_store.dart';

class FakeFlutterSecureStorage extends Fake implements FlutterSecureStorage {
  final Map<String, String> data = {};

  @override
  Future<void> write({
    required String key,
    required String? value,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    if (value != null) {
      data[key] = value;
    } else {
      data.remove(key);
    }
  }

  @override
  Future<String?> read({
    required String key,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    return data[key];
  }

  @override
  Future<void> delete({
    required String key,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    data.remove(key);
  }
}

class FakeTokenStore extends Fake implements TokenStore {
  String? refreshToken;
  bool cleared = false;

  @override
  Future<String?> readRefreshToken() async => refreshToken;

  @override
  Future<void> clear() async {
    cleared = true;
    refreshToken = null;
  }
}

String _todayKey() {
  final now = DateTime.now();
  final month = now.month.toString().padLeft(2, '0');
  final day = now.day.toString().padLeft(2, '0');
  return '${now.year}-$month-$day';
}

void main() {
  late AppLockService service;
  late FakeFlutterSecureStorage fakeStorage;
  late FakeTokenStore fakeTokenStore;

  setUp(() {
    fakeStorage = FakeFlutterSecureStorage();
    fakeTokenStore = FakeTokenStore();
    service = AppLockService(storage: fakeStorage, tokenStore: fakeTokenStore);
  });

  group('AppLockService - PIN Lifecycle', () {
    test('setPin hashes and stores PIN', () async {
      await service.setPin('1234');

      expect(fakeStorage.data.containsKey('app_lock_pin_hash_v2'), true);
      expect(fakeStorage.data.containsKey('app_lock_pin_salt_v2'), true);
    });

    test('verifyPin returns success for correct PIN', () async {
      await service.setPin('1234');
      final result = await service.verifyPin('1234');
      expect(result, PinVerifyResult.success);
      expect(service.locked, false);
    });

    test('verifyPin returns invalidPin for wrong PIN', () async {
      await service.setPin('1234');
      final result = await service.verifyPin('5678');
      expect(result, PinVerifyResult.invalidPin);
    });
  });

  group('AppLockService - Cooldown & Failure Escalation', () {
    test('forces logout after 10 attempts', () async {
      // Mock hash and salt to be present manually since setPin wipes attempts
      fakeStorage.data['app_lock_pin_hash_v2'] = base64.encode(Uint8List(32));
      fakeStorage.data['app_lock_pin_salt_v2'] = base64.encode(Uint8List(16));

      for (int i = 0; i < 9; i++) {
        await service.verifyPin('wrong');
      }

      final result = await service.verifyPin('wrong');
      expect(result, PinVerifyResult.forcedLogout);
      expect(fakeTokenStore.cleared, true);
    });

    test('applies cooldown after 5 failed attempts', () async {
      fakeStorage.data['app_lock_pin_hash_v2'] = base64.encode(Uint8List(32));
      fakeStorage.data['app_lock_pin_salt_v2'] = base64.encode(Uint8List(16));

      // 4 failures (no cooldown)
      for (int i = 0; i < 4; i++) {
        await service.verifyPin('wrong');
      }
      expect(service.inCooldown, false);

      // 5th failure
      await service.verifyPin('wrong');
      expect(service.inCooldown, true);

      final result = await service.verifyPin('any');
      expect(result, PinVerifyResult.inCooldown);
    });
  });

  group('AppLockService - Migration', () {
    test('migrates from legacy plaintext PIN', () async {
      fakeStorage.data['app_lock_pin_v1'] = '1111';
      fakeStorage.data['biometric_enabled'] = 'true';
      fakeTokenStore.refreshToken = 'active_session';

      await service.bootstrap();

      // Should have written new hashed versions and enabled lock
      expect(fakeStorage.data.containsKey('app_lock_pin_hash_v2'), true);
      expect(fakeStorage.data['app_lock_enabled_v2'], 'true');
      expect(fakeStorage.data['app_lock_biometric_v2'], 'true');

      // Should have deleted legacy key
      expect(fakeStorage.data.containsKey('app_lock_pin_v1'), false);
    });
  });

  group('AppLockService - Daily Unlock Policy', () {
    test('locks on startup when not unlocked today', () async {
      fakeStorage.data['app_lock_enabled_v2'] = 'true';
      fakeTokenStore.refreshToken = 'active_session';

      await service.bootstrap();

      expect(service.locked, true);
      expect(service.unlockRequiredToday, true);
    });

    test('does not lock on startup when already unlocked today', () async {
      fakeStorage.data['app_lock_enabled_v2'] = 'true';
      fakeStorage.data['app_lock_last_unlocked_day_v1'] = _todayKey();
      fakeTokenStore.refreshToken = 'active_session';

      await service.bootstrap();

      expect(service.locked, false);
      expect(service.unlockRequiredToday, false);
    });

    test('verifyPin success marks today as unlocked', () async {
      await service.setPin('1234');
      await service.enableLock();
      service.lock();

      final result = await service.verifyPin('1234');

      expect(result, PinVerifyResult.success);
      expect(fakeStorage.data['app_lock_last_unlocked_day_v1'], _todayKey());
      expect(service.unlockRequiredToday, false);
    });
  });
}
