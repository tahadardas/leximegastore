import 'dart:convert';
import 'dart:math';

import 'package:cryptography/cryptography.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../auth/token_store.dart';

// ---------------------------------------------------------------------------
// Result types
// ---------------------------------------------------------------------------

enum PinVerifyResult { success, invalidPin, inCooldown, forcedLogout }

enum BiometricAuthResult {
  success,
  notAvailable,
  notEnrolled,
  lockedOut,
  permanentlyLockedOut,
  userCancel,
  failed,
}

// ---------------------------------------------------------------------------
// Storage keys
// ---------------------------------------------------------------------------

class _K {
  // v2 keys
  static const pinHash = 'app_lock_pin_hash_v2';
  static const pinSalt = 'app_lock_pin_salt_v2';
  static const lockEnabled = 'app_lock_enabled_v2';
  static const biometricEnabled = 'app_lock_biometric_v2';
  static const failedAttempts = 'app_lock_failed_attempts';
  static const cooldownUntil = 'app_lock_cooldown_until';
  static const setupPromptPending = 'app_lock_setup_prompt_pending';
  static const lastUnlockedDay = 'app_lock_last_unlocked_day_v1';

  // Legacy keys (v1 — for migration)
  static const legacyPin = 'app_lock_pin_v1';
  static const legacyBiometric = 'biometric_enabled';
}

// ---------------------------------------------------------------------------
// Cooldown schedule
// ---------------------------------------------------------------------------

/// Returns the cooldown in seconds for the given attempt number (1-based).
/// Attempts 1-4: 0 seconds. Attempt 5+: escalating up to 300 s cap.
int _cooldownSeconds(int attempt) {
  const schedule = [30, 60, 120, 240, 300];
  if (attempt < 5) return 0;
  final index = (attempt - 5).clamp(0, schedule.length - 1);
  return schedule[index];
}

// ---------------------------------------------------------------------------
// AppLockService
// ---------------------------------------------------------------------------

class AppLockService extends ChangeNotifier {
  final FlutterSecureStorage _storage;
  final TokenStore _tokenStore;

  bool _initialized = false;
  bool _lockEnabled = false;
  bool _locked = false;
  bool _biometricEnabled = false;
  bool _setupPromptPending = false;
  String _lastUnlockedDay = '';

  // Failed-attempt state (also persisted for restart-resistance)
  int _failedAttempts = 0;
  DateTime? _cooldownUntil;

  AppLockService({
    required FlutterSecureStorage storage,
    required TokenStore tokenStore,
  }) : _storage = storage,
       _tokenStore = tokenStore;

  // ---------------------------------------------------------------------------
  // Public state getters
  // ---------------------------------------------------------------------------

  bool get initialized => _initialized;
  bool get lockEnabled => _lockEnabled;
  bool get locked => _lockEnabled && _locked;
  bool get biometricEnabled => _biometricEnabled;
  bool get setupPromptPending => _setupPromptPending;
  bool get unlockRequiredToday => _lockEnabled && _lastUnlockedDay != _todayKey();

  /// True when a cooldown is still active.
  bool get inCooldown {
    final until = _cooldownUntil;
    if (until == null) return false;
    return DateTime.now().isBefore(until);
  }

  /// Remaining cooldown in seconds (0 if none).
  int get cooldownSecondsRemaining {
    final until = _cooldownUntil;
    if (until == null) return 0;
    final diff = until.difference(DateTime.now()).inSeconds;
    return diff > 0 ? diff : 0;
  }

  // ---------------------------------------------------------------------------
  // Bootstrap (call before runApp)
  // ---------------------------------------------------------------------------

  Future<void> bootstrap() async {
    try {
      await _migrateFromLegacy();
      await _restorePersistedState();
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('[AppLockService] bootstrap error: $e\n$st');
      }
    } finally {
      _initialized = true;
      notifyListeners();
    }
  }

  // ---------------------------------------------------------------------------
  // Lock lifecycle
  // ---------------------------------------------------------------------------

  Future<void> enableLock() async {
    _lockEnabled = true;
    await _storage.write(key: _K.lockEnabled, value: 'true');
    notifyListeners();
  }

  Future<void> disableLock() async {
    _lockEnabled = false;
    _locked = false;
    _lastUnlockedDay = '';
    await _storage.write(key: _K.lockEnabled, value: 'false');
    // Clear PIN and biometric when disabling
    await _storage.delete(key: _K.pinHash);
    await _storage.delete(key: _K.pinSalt);
    await _storage.delete(key: _K.biometricEnabled);
    await _storage.delete(key: _K.lastUnlockedDay);
    await _resetFailedAttempts();
    notifyListeners();
  }

  void lock() {
    if (!_lockEnabled) return;
    _locked = true;
    notifyListeners();
  }

  void unlock() {
    _locked = false;
    notifyListeners();
  }

  Future<void> markUnlockedToday() async {
    final today = _todayKey();
    _lastUnlockedDay = today;
    await _storage.write(key: _K.lastUnlockedDay, value: today);
  }

  // ---------------------------------------------------------------------------
  // PIN management
  // ---------------------------------------------------------------------------

  Future<void> setPin(String pin) async {
    final normalized = _normalizePin(pin);
    if (normalized.length != 4) {
      throw ArgumentError('PIN must be exactly 4 digits');
    }

    final salt = _generateSalt();
    final hash = await _hashPin(normalized, salt);

    await _storage.write(key: _K.pinHash, value: base64.encode(hash));
    await _storage.write(key: _K.pinSalt, value: base64.encode(salt));
    await _resetFailedAttempts();
  }

  Future<PinVerifyResult> verifyPin(String pin) async {
    // Check cooldown first
    if (inCooldown) {
      // Keep counting brute-force attempts during cooldown.
      _failedAttempts++;
      await _storage.write(
        key: _K.failedAttempts,
        value: _failedAttempts.toString(),
      );

      if (_failedAttempts >= 10) {
        await _forcedLogout();
        return PinVerifyResult.forcedLogout;
      }

      notifyListeners();
      return PinVerifyResult.inCooldown;
    }

    final normalized = _normalizePin(pin);
    final storedHashB64 = await _storage.read(key: _K.pinHash);
    final storedSaltB64 = await _storage.read(key: _K.pinSalt);

    if (storedHashB64 == null || storedSaltB64 == null) {
      return PinVerifyResult.invalidPin;
    }

    Uint8List storedHash;
    Uint8List storedSalt;
    try {
      storedHash = Uint8List.fromList(base64.decode(storedHashB64));
      storedSalt = Uint8List.fromList(base64.decode(storedSaltB64));
    } catch (_) {
      return PinVerifyResult.invalidPin;
    }

    final derivedHash = await _hashPin(normalized, storedSalt);
    final match = _constantTimeEquals(storedHash, derivedHash);

    if (match) {
      await _resetFailedAttempts();
      await markUnlockedToday();
      unlock();
      return PinVerifyResult.success;
    }

    // Wrong PIN — increment attempts
    _failedAttempts++;
    await _storage.write(
      key: _K.failedAttempts,
      value: _failedAttempts.toString(),
    );

    // Check for forced logout at attempt 10
    if (_failedAttempts >= 10) {
      await _forcedLogout();
      return PinVerifyResult.forcedLogout;
    }

    // Apply cooldown if applicable
    final cooldown = _cooldownSeconds(_failedAttempts);
    if (cooldown > 0) {
      _cooldownUntil = DateTime.now().add(Duration(seconds: cooldown));
      await _storage.write(
        key: _K.cooldownUntil,
        value: _cooldownUntil!.toIso8601String(),
      );
    }

    notifyListeners();
    return PinVerifyResult.invalidPin;
  }

  // ---------------------------------------------------------------------------
  // Biometrics
  // ---------------------------------------------------------------------------

  Future<void> enableBiometrics() async {
    _biometricEnabled = true;
    await _storage.write(key: _K.biometricEnabled, value: 'true');
    notifyListeners();
  }

  Future<void> disableBiometrics() async {
    _biometricEnabled = false;
    await _storage.write(key: _K.biometricEnabled, value: 'false');
    notifyListeners();
  }

  Future<bool> isBiometricsAvailable() async {
    if (kIsWeb) return false;
    try {
      // Deferred check — actual availability is done via BiometricService
      return !kIsWeb;
    } catch (_) {
      return false;
    }
  }

  // ---------------------------------------------------------------------------
  // Setup-prompt flag
  // ---------------------------------------------------------------------------

  Future<void> setSetupPromptPending(bool pending) async {
    _setupPromptPending = pending;
    await _storage.write(
      key: _K.setupPromptPending,
      value: pending ? 'true' : 'false',
    );
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // Private helpers
  // ---------------------------------------------------------------------------

  Future<void> _restorePersistedState() async {
    _lockEnabled =
        (await _storage.read(key: _K.lockEnabled) ?? 'false') == 'true';
    _biometricEnabled =
        (await _storage.read(key: _K.biometricEnabled) ?? 'false') == 'true';
    _setupPromptPending =
        (await _storage.read(key: _K.setupPromptPending) ?? 'false') == 'true';
    _lastUnlockedDay = (await _storage.read(key: _K.lastUnlockedDay) ?? '')
        .trim();

    final attemptsStr = (await _storage.read(key: _K.failedAttempts) ?? '0')
        .trim();
    _failedAttempts = int.tryParse(attemptsStr) ?? 0;

    final cooldownStr = await _storage.read(key: _K.cooldownUntil);
    if (cooldownStr != null && cooldownStr.isNotEmpty) {
      _cooldownUntil = DateTime.tryParse(cooldownStr);
      if (_cooldownUntil != null && DateTime.now().isAfter(_cooldownUntil!)) {
        _cooldownUntil = null;
      }
    }

    // Lock on startup if lock is enabled and we have an active session
    if (_lockEnabled) {
      final refreshToken = ((await _tokenStore.readRefreshToken()) ?? '')
          .trim();
      _locked = refreshToken.isNotEmpty && unlockRequiredToday;
    } else {
      _locked = false;
    }
  }

  /// One-time migration from plaintext PIN v1 storage.
  Future<void> _migrateFromLegacy() async {
    final legacyPin = await _storage.read(key: _K.legacyPin);
    if (legacyPin != null && legacyPin.trim().length == 4) {
      final normalized = _normalizePin(legacyPin.trim());
      if (normalized.length == 4) {
        // Hash the legacy PIN and store it in v2 format
        final salt = _generateSalt();
        final hash = await _hashPin(normalized, salt);
        await _storage.write(key: _K.pinHash, value: base64.encode(hash));
        await _storage.write(key: _K.pinSalt, value: base64.encode(salt));
        await _storage.write(key: _K.lockEnabled, value: 'true');

        if (kDebugMode) {
          debugPrint(
            '[AppLockService] Migrated legacy plain-text PIN to v2 hash.',
          );
        }
      }
      // Delete the legacy plaintext key regardless
      await _storage.delete(key: _K.legacyPin);
    }

    // Migrate legacy biometric preference
    final legacyBio = await _storage.read(key: _K.legacyBiometric);
    if (legacyBio == 'true') {
      final v2Bio = await _storage.read(key: _K.biometricEnabled);
      if (v2Bio == null) {
        await _storage.write(key: _K.biometricEnabled, value: 'true');
      }
    }
  }

  Future<void> _resetFailedAttempts() async {
    _failedAttempts = 0;
    _cooldownUntil = null;
    await _storage.delete(key: _K.failedAttempts);
    await _storage.delete(key: _K.cooldownUntil);
    notifyListeners();
  }

  Future<void> _forcedLogout() async {
    // Clear tokens
    await _tokenStore.clear();
    // Clear failed attempts
    await _resetFailedAttempts();
    // Keep lock enabled but remain locked
    _locked = true;
    if (kDebugMode) {
      debugPrint(
        '[AppLockService] Forced logout after 10 failed PIN attempts.',
      );
    }
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // PBKDF2-HMAC-SHA256 (210,000 iterations, 32-byte derived key, 16-byte salt)
  // ---------------------------------------------------------------------------

  static const _pbkdf2Iterations = 210000;
  static const _keyLengthBytes = 32;
  static const _saltLengthBytes = 16;

  static final _pbkdf2 = Pbkdf2(
    macAlgorithm: Hmac.sha256(),
    iterations: _pbkdf2Iterations,
    bits: _keyLengthBytes * 8,
  );

  Uint8List _generateSalt() {
    final rng = Random.secure();
    return Uint8List.fromList(
      List<int>.generate(_saltLengthBytes, (_) => rng.nextInt(256)),
    );
  }

  Future<Uint8List> _hashPin(String pin, Uint8List salt) async {
    final secretKey = SecretKey(utf8.encode(pin));
    final derived = await _pbkdf2.deriveKey(secretKey: secretKey, nonce: salt);
    final bytes = await derived.extractBytes();
    return Uint8List.fromList(bytes);
  }

  /// Constant-time byte comparison to prevent timing attacks.
  bool _constantTimeEquals(Uint8List a, Uint8List b) {
    if (a.length != b.length) return false;
    int diff = 0;
    for (int i = 0; i < a.length; i++) {
      diff |= a[i] ^ b[i];
    }
    return diff == 0;
  }

  String _normalizePin(String pin) {
    final digits = pin.replaceAll(RegExp(r'[^0-9]'), '');
    return digits.length > 4 ? digits.substring(0, 4) : digits;
  }

  String _todayKey() {
    final now = DateTime.now();
    final month = now.month.toString().padLeft(2, '0');
    final day = now.day.toString().padLeft(2, '0');
    return '${now.year}-$month-$day';
  }
}

// ---------------------------------------------------------------------------
// Provider
// ---------------------------------------------------------------------------

final appLockServiceProvider = ChangeNotifierProvider<AppLockService>((ref) {
  throw UnimplementedError('appLockServiceProvider must be overridden in main');
});
