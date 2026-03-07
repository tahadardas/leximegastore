import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';
import 'package:lexi_mega_store/core/security/biometric_service.dart';
import 'package:lexi_mega_store/core/security/app_lock_service.dart';

class FakeLocalAuthentication extends Fake implements LocalAuthentication {
  bool authenticateResult = true;
  PlatformException? exception;

  @override
  Future<bool> authenticate({
    required String localizedReason,
    Iterable<Object> authMessages =
        const <Object>[], // Removed AuthMessages type here
    AuthenticationOptions options = const AuthenticationOptions(),
  }) async {
    if (exception != null) throw exception!;
    return authenticateResult;
  }

  @override
  Future<List<BiometricType>> getAvailableBiometrics() async => [
    BiometricType.fingerprint,
  ];

  @override
  Future<bool> isDeviceSupported() async => true;

  @override
  Future<bool> get canCheckBiometrics async => true;
}

void main() {
  late BiometricService service;
  late FakeLocalAuthentication fakeAuth;

  setUp(() {
    fakeAuth = FakeLocalAuthentication();
    service = BiometricService(auth: fakeAuth);
  });

  group('BiometricService - authenticateWithResult', () {
    test('returns success on successful authentication', () async {
      fakeAuth.authenticateResult = true;
      final result = await service.authenticateWithResult();
      expect(result, BiometricAuthResult.success);
    });

    test('returns userCancel on user cancellation', () async {
      fakeAuth.exception = PlatformException(code: 'UserCancel');
      final result = await service.authenticateWithResult();
      expect(result, BiometricAuthResult.userCancel);
    });

    test('maps LockedOut to correct enum', () async {
      fakeAuth.exception = PlatformException(code: 'LockedOut');
      final result = await service.authenticateWithResult();
      expect(result, BiometricAuthResult.lockedOut);
    });
  });
}
