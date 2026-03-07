import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../core/security/app_lock_service.dart';
import '../../../../core/security/biometric_service.dart';
import '../../../../design_system/lexi_tokens.dart';
import '../../../../design_system/lexi_typography.dart';
import '../../../../shared/ui/lexi_alert.dart';
import '../widgets/pin_dots.dart';
import '../widgets/pin_keypad.dart';

enum _EnableStep { createPin, confirmPin, biometric }

class EnableAppLockFlowPage extends ConsumerStatefulWidget {
  const EnableAppLockFlowPage({super.key});

  @override
  ConsumerState<EnableAppLockFlowPage> createState() =>
      _EnableAppLockFlowPageState();
}

class _EnableAppLockFlowPageState extends ConsumerState<EnableAppLockFlowPage> {
  _EnableStep _step = _EnableStep.createPin;
  String _pin = '';
  String _firstPin = '';
  bool _hasError = false;
  bool _saving = false;
  bool _biometricAvailable = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkBiometric());
  }

  Future<void> _checkBiometric() async {
    if (kIsWeb) return;
    final available = await ref.read(biometricServiceProvider).isAvailable();
    if (mounted) setState(() => _biometricAvailable = available);
  }

  void _onDigit(String d) {
    if (_pin.length >= 4) return;
    final next = _pin + d;
    setState(() {
      _pin = next;
      _hasError = false;
    });
    if (next.length == 4) _onPinComplete(next);
  }

  void _onBackspace() {
    if (_pin.isEmpty) return;
    setState(() {
      _pin = _pin.substring(0, _pin.length - 1);
      _hasError = false;
    });
  }

  void _onPinComplete(String pin) {
    switch (_step) {
      case _EnableStep.createPin:
        setState(() {
          _firstPin = pin;
          _step = _EnableStep.confirmPin;
          _pin = '';
        });
        break;
      case _EnableStep.confirmPin:
        if (pin == _firstPin) {
          _savePin(pin);
        } else {
          setState(() {
            _pin = '';
            _firstPin = '';
            _step = _EnableStep.createPin;
            _hasError = true;
          });
        }
        break;
      default:
        break;
    }
  }

  Future<void> _savePin(String pin) async {
    setState(() => _saving = true);
    try {
      final service = ref.read(appLockServiceProvider);
      await service.setPin(pin);
      await service.enableLock();
      await service.setSetupPromptPending(false);
      if (!mounted) return;
      if (_biometricAvailable) {
        setState(() {
          _step = _EnableStep.biometric;
          _pin = '';
        });
      } else {
        _finish();
      }
    } catch (e) {
      if (mounted) {
        await LexiAlert.error(context, text: 'تعذر حفظ رمز PIN. حاول مجددًا.');
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _enableBiometric() async {
    final biometric = ref.read(biometricServiceProvider);
    final result = await biometric.authenticateWithResult();
    if (!mounted) return;
    if (result == BiometricAuthResult.success) {
      await ref.read(appLockServiceProvider).enableBiometrics();
    } else if (result != BiometricAuthResult.userCancel) {
      _showSnack('تعذر تفعيل البصمة.');
    }
    _finish();
  }

  Future<void> _skipBiometric() async {
    await ref.read(appLockServiceProvider).disableBiometrics();
    _finish();
  }

  void _finish() {
    if (mounted) context.go(AppRoutePaths.home);
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _skip() async {
    await ref.read(appLockServiceProvider).setSetupPromptPending(false);
    if (mounted) context.go(AppRoutePaths.home);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: const Color(0xFF0E1A43),
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(LexiSpacing.xl),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: _step == _EnableStep.biometric
                    ? _BiometricStep(
                        onEnable: _enableBiometric,
                        onSkip: _skipBiometric,
                      )
                    : _PinStep(
                        step: _step,
                        pin: _pin,
                        hasError: _hasError,
                        saving: _saving,
                        onDigit: _onDigit,
                        onBackspace: _onBackspace,
                        onSkip: _skip,
                        onReset: () => setState(() {
                          _step = _EnableStep.createPin;
                          _pin = '';
                          _firstPin = '';
                          _hasError = false;
                        }),
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PinStep extends StatelessWidget {
  final _EnableStep step;
  final String pin;
  final bool hasError;
  final bool saving;
  final ValueChanged<String> onDigit;
  final VoidCallback onBackspace;
  final VoidCallback onSkip;
  final VoidCallback onReset;

  const _PinStep({
    required this.step,
    required this.pin,
    required this.hasError,
    required this.saving,
    required this.onDigit,
    required this.onBackspace,
    required this.onSkip,
    required this.onReset,
  });

  @override
  Widget build(BuildContext context) {
    final isConfirm = step == _EnableStep.confirmPin;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
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
          isConfirm ? 'أكّد رمز PIN' : 'أنشئ رمز PIN',
          style: LexiTypography.h2.copyWith(color: Colors.white),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: LexiSpacing.xs),
        Text(
          isConfirm
              ? 'أعد إدخال نفس الرمز للتأكيد.'
              : 'أدخل رمزًا مكوّنًا من 4 أرقام لحماية التطبيق.',
          style: LexiTypography.bodyMd.copyWith(color: Colors.white70),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: LexiSpacing.xl),
        PinDots(filled: pin.length, hasError: hasError),
        const SizedBox(height: LexiSpacing.sm),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: hasError
              ? Text(
                  'الرمزان غير متطابقَين. أعد المحاولة.',
                  style: LexiTypography.bodyMd.copyWith(
                    color: LexiColors.error,
                  ),
                  textAlign: TextAlign.center,
                )
              : const SizedBox.shrink(),
        ),
        const SizedBox(height: LexiSpacing.xl),
        if (saving)
          const CircularProgressIndicator(color: Colors.white)
        else
          PinKeypad(onDigit: onDigit, onBackspace: onBackspace),
        if (isConfirm) ...[
          const SizedBox(height: LexiSpacing.md),
          TextButton(
            onPressed: onReset,
            child: Text(
              'إعادة الإدخال من البداية',
              style: LexiTypography.bodyMd.copyWith(color: Colors.white60),
            ),
          ),
        ],
        const SizedBox(height: LexiSpacing.sm),
        TextButton(
          onPressed: onSkip,
          child: Text(
            'تخطي الآن',
            style: LexiTypography.bodyMd.copyWith(color: Colors.white38),
          ),
        ),
      ],
    );
  }
}

class _BiometricStep extends StatelessWidget {
  final VoidCallback onEnable;
  final VoidCallback onSkip;

  const _BiometricStep({required this.onEnable, required this.onSkip});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.fingerprint, size: 44, color: Colors.white),
        ),
        const SizedBox(height: LexiSpacing.lg),
        Text(
          'تفعيل البصمة',
          style: LexiTypography.h2.copyWith(color: Colors.white),
        ),
        const SizedBox(height: LexiSpacing.xs),
        Text(
          'هل تريد فتح التطبيق بالبصمة بدلًا من رمز PIN في كل مرة؟',
          textAlign: TextAlign.center,
          style: LexiTypography.bodyMd.copyWith(color: Colors.white70),
        ),
        const SizedBox(height: LexiSpacing.xl),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: onEnable,
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              backgroundColor: LexiColors.brandPrimary,
              foregroundColor: LexiColors.brandBlack,
            ),
            icon: const Icon(Icons.fingerprint),
            label: const Text('تفعيل البصمة'),
          ),
        ),
        const SizedBox(height: LexiSpacing.md),
        TextButton(
          onPressed: onSkip,
          child: Text(
            'لاحقًا',
            style: LexiTypography.bodyMd.copyWith(color: Colors.white60),
          ),
        ),
      ],
    );
  }
}
