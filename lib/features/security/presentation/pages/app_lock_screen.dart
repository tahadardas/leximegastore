import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_lock_guard.dart';
import '../../../../app/router/app_routes.dart';
import '../../../../core/security/app_lock_service.dart';
import '../../../../core/security/biometric_service.dart';
import '../../../../design_system/lexi_tokens.dart';
import '../../../../design_system/lexi_typography.dart';
import '../widgets/pin_dots.dart';
import '../widgets/pin_keypad.dart';

class AppLockScreen extends ConsumerStatefulWidget {
  final String? nextPath;

  const AppLockScreen({super.key, this.nextPath});

  @override
  ConsumerState<AppLockScreen> createState() => _AppLockScreenState();
}

class _AppLockScreenState extends ConsumerState<AppLockScreen> {
  String _pin = '';
  bool _hasError = false;
  bool _checkingBiometric = false;
  bool _biometricAvailable = false;
  int _cooldownRemaining = 0;
  Timer? _cooldownTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkBiometricAndMaybePrompt();
      _syncCooldown();
    });
  }

  @override
  void dispose() {
    _cooldownTimer?.cancel();
    super.dispose();
  }

  void _syncCooldown() {
    final service = ref.read(appLockServiceProvider);
    if (service.inCooldown) {
      setState(() => _cooldownRemaining = service.cooldownSecondsRemaining);
      _startCooldownTimer();
    }
  }

  void _startCooldownTimer() {
    _cooldownTimer?.cancel();
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      final remaining = ref
          .read(appLockServiceProvider)
          .cooldownSecondsRemaining;
      setState(() => _cooldownRemaining = remaining);
      if (remaining <= 0) t.cancel();
    });
  }

  Future<void> _checkBiometricAndMaybePrompt() async {
    if (kIsWeb) return;
    final biometric = ref.read(biometricServiceProvider);
    final available = await biometric.isAvailable();
    if (!mounted) return;
    setState(() => _biometricAvailable = available);

    // Auto-trigger biometric on first open if enabled
    final service = ref.read(appLockServiceProvider);
    if (available && service.biometricEnabled && !service.inCooldown) {
      await _unlockWithBiometric();
    }
  }

  Future<void> _onDigit(String d) async {
    if (_pin.length >= 4) return;
    final next = _pin + d;
    setState(() {
      _pin = next;
      _hasError = false;
    });
    if (next.length == 4) {
      await _submitPin(next);
    }
  }

  void _onBackspace() {
    if (_pin.isEmpty) return;
    setState(() {
      _pin = _pin.substring(0, _pin.length - 1);
      _hasError = false;
    });
  }

  Future<void> _submitPin(String pin) async {
    final service = ref.read(appLockServiceProvider);
    final result = await service.verifyPin(pin);

    if (!mounted) return;

    switch (result) {
      case PinVerifyResult.success:
        final next = AppLockGuard.sanitizeNext(widget.nextPath);
        if (mounted) context.go(next ?? AppRoutePaths.home);
        break;
      case PinVerifyResult.inCooldown:
        setState(() {
          _pin = '';
          _hasError = true;
          _cooldownRemaining = service.cooldownSecondsRemaining;
        });
        _startCooldownTimer();
        break;
      case PinVerifyResult.invalidPin:
        setState(() {
          _pin = '';
          _hasError = true;
        });
        if (service.inCooldown) {
          setState(() => _cooldownRemaining = service.cooldownSecondsRemaining);
          _startCooldownTimer();
        }
        break;
      case PinVerifyResult.forcedLogout:
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('تم تسجيل خروجك بسبب محاولات فاشلة متكررة.'),
              backgroundColor: Colors.red,
            ),
          );
          context.go(AppRoutePaths.login);
        }
        break;
    }
  }

  Future<void> _unlockWithBiometric() async {
    if (_checkingBiometric) return;
    setState(() => _checkingBiometric = true);
    try {
      final biometric = ref.read(biometricServiceProvider);
      final result = await biometric.authenticateWithResult();
      if (!mounted) return;

      switch (result) {
        case BiometricAuthResult.success:
          final lockService = ref.read(appLockServiceProvider);
          await lockService.markUnlockedToday();
          lockService.unlock();
          final next = AppLockGuard.sanitizeNext(widget.nextPath);
          if (mounted) context.go(next ?? AppRoutePaths.home);
          break;
        case BiometricAuthResult.userCancel:
          // User dismissed — do nothing, allow PIN
          break;
        case BiometricAuthResult.lockedOut:
        case BiometricAuthResult.permanentlyLockedOut:
          _showSnack('البصمة محظورة مؤقتًا. استخدم رمز PIN.');
          break;
        case BiometricAuthResult.notAvailable:
        case BiometricAuthResult.notEnrolled:
          setState(() => _biometricAvailable = false);
          break;
        case BiometricAuthResult.failed:
          _showSnack('لم يتم التعرف على البصمة. حاول مرة أخرى أو استخدم PIN.');
          break;
      }
    } finally {
      if (mounted) setState(() => _checkingBiometric = false);
    }
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final service = ref.watch(appLockServiceProvider);
    final showBiometric =
        !kIsWeb && _biometricAvailable && service.biometricEnabled;
    final inCooldown = _cooldownRemaining > 0;

    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: const Color(0xFF0E1A43),
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(
                horizontal: LexiSpacing.xl,
                vertical: LexiSpacing.lg,
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Lock icon
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.lock_outline_rounded,
                        size: 40,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: LexiSpacing.lg),
                    Text(
                      'أدخل رمز PIN',
                      style: LexiTypography.h2.copyWith(color: Colors.white),
                    ),
                    const SizedBox(height: LexiSpacing.xs),
                    Text(
                      'لفتح التطبيق والمتابعة',
                      style: LexiTypography.bodyMd.copyWith(
                        color: Colors.white70,
                      ),
                    ),
                    const SizedBox(height: LexiSpacing.xl),

                    // PIN dots
                    PinDots(filled: _pin.length, hasError: _hasError),

                    // Error / cooldown message
                    const SizedBox(height: LexiSpacing.md),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 200),
                      child: inCooldown
                          ? Text(
                              'محاولات كثيرة — انتظر $_cooldownRemaining ثانية',
                              key: const ValueKey('cooldown'),
                              style: LexiTypography.bodyMd.copyWith(
                                color: LexiColors.error,
                              ),
                              textAlign: TextAlign.center,
                            )
                          : _hasError
                          ? Text(
                              'رمز PIN غير صحيح',
                              key: const ValueKey('error'),
                              style: LexiTypography.bodyMd.copyWith(
                                color: LexiColors.error,
                              ),
                            )
                          : const SizedBox.shrink(key: ValueKey('none')),
                    ),

                    const SizedBox(height: LexiSpacing.xl),

                    // Keypad
                    PinKeypad(
                      onDigit: _onDigit,
                      onBackspace: _onBackspace,
                      disabled: inCooldown,
                    ),

                    // Biometric icon
                    if (showBiometric) ...[
                      const SizedBox(height: LexiSpacing.lg),
                      IconButton(
                        onPressed: _checkingBiometric
                            ? null
                            : _unlockWithBiometric,
                        icon: _checkingBiometric
                            ? const SizedBox(
                                width: 28,
                                height: 28,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const FaIcon(
                                FontAwesomeIcons.fingerprint,
                                size: 38,
                                color: Colors.white,
                              ),
                      ),
                      Text(
                        'الدخول بالبصمة',
                        style: LexiTypography.bodySm.copyWith(
                          color: Colors.white70,
                        ),
                      ),
                    ],

                    const SizedBox(height: LexiSpacing.lg),
                    TextButton(
                      onPressed: () => context.go(AppRoutePaths.securityReauth),
                      child: Text(
                        'نسيت رمز PIN؟',
                        style: LexiTypography.bodyMd.copyWith(
                          color: Colors.white60,
                          decoration: TextDecoration.underline,
                          decorationColor: Colors.white60,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
