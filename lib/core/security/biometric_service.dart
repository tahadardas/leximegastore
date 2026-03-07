import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_auth/local_auth.dart';
import 'package:local_auth/error_codes.dart' as auth_error;
import 'package:flutter/foundation.dart';

import 'app_lock_service.dart';

final biometricServiceProvider = Provider<BiometricService>((ref) {
  return BiometricService();
});

class BiometricService {
  final LocalAuthentication _auth;

  BiometricService({LocalAuthentication? auth})
    : _auth = auth ?? LocalAuthentication();

  Future<bool> isAvailable() async {
    if (kIsWeb) return false;
    try {
      final deviceSupported = await _auth.isDeviceSupported();
      final canCheckBiometrics = await _auth.canCheckBiometrics;
      return deviceSupported && canCheckBiometrics;
    } on PlatformException catch (e) {
      if (kDebugMode) {
        debugPrint(
          '[BiometricService] isAvailable error code=${e.code} msg=${e.message}',
        );
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  /// Legacy helper — returns a plain bool for backwards compatibility.
  Future<bool> authenticate() async {
    final result = await authenticateWithResult();
    return result == BiometricAuthResult.success;
  }

  /// Full typed result with explicit error-code mapping.
  Future<BiometricAuthResult> authenticateWithResult({
    String localizedReason = 'يرجى تأكيد هويتك لفتح التطبيق',
  }) async {
    if (kIsWeb) return BiometricAuthResult.notAvailable;

    try {
      final available = await isAvailable();
      if (!available) return BiometricAuthResult.notAvailable;

      final passed = await _auth.authenticate(
        localizedReason: localizedReason,
        options: const AuthenticationOptions(
          biometricOnly: true,
          stickyAuth: true,
          useErrorDialogs: true,
        ),
      );
      return passed ? BiometricAuthResult.success : BiometricAuthResult.failed;
    } on PlatformException catch (e) {
      if (kDebugMode) {
        debugPrint(
          '[BiometricService] PlatformException code=${e.code} msg=${e.message}',
        );
      }
      return _mapPlatformException(e);
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('[BiometricService] unexpected error: $e\n$st');
      }
      return BiometricAuthResult.failed;
    }
  }

  BiometricAuthResult _mapPlatformException(PlatformException e) {
    switch (e.code) {
      case auth_error.notAvailable:
        return BiometricAuthResult.notAvailable;
      case auth_error.notEnrolled:
        return BiometricAuthResult.notEnrolled;
      case auth_error.lockedOut:
        return BiometricAuthResult.lockedOut;
      case auth_error.permanentlyLockedOut:
        return BiometricAuthResult.permanentlyLockedOut;
      case auth_error.passcodeNotSet:
        return BiometricAuthResult.notEnrolled;
      default:
        // User cancel / dismiss
        final code = e.code.toLowerCase();
        if (code.contains('cancel') || code.contains('usercancel')) {
          return BiometricAuthResult.userCancel;
        }
        return BiometricAuthResult.failed;
    }
  }
}
