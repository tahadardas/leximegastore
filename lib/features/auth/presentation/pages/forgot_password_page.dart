import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/errors/app_failure.dart';
import '../../../../design_system/lexi_tokens.dart';
import '../../../../design_system/lexi_typography.dart';
import '../../../../shared/widgets/lexi_ui/lexi_button.dart';
import '../../../../shared/widgets/lexi_ui/lexi_card.dart';
import '../../../../shared/widgets/lexi_ui/lexi_input.dart';
import '../../../../shared/ui/lexi_alert.dart';
import '../../data/repositories/customer_auth_repository_impl.dart';

class ForgotPasswordPage extends ConsumerStatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  ConsumerState<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends ConsumerState<ForgotPasswordPage> {
  final _emailController = TextEditingController();
  final _codeController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirm = true;

  /// 0 = enter email, 1 = enter OTP, 2 = enter new password
  int _step = 0;

  @override
  void dispose() {
    _emailController.dispose();
    _codeController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: LexiColors.neutral100,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(LexiSpacing.lg),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: LexiCard(
                padding: const EdgeInsets.all(LexiSpacing.xl),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Center(
                        child: Container(
                          padding: const EdgeInsets.all(LexiSpacing.md),
                          decoration: BoxDecoration(
                            color: LexiColors.brandBlack.withValues(
                              alpha: 0.06,
                            ),
                            shape: BoxShape.circle,
                          ),
                          child: FaIcon(
                            _stepIcon,
                            size: 28,
                            color: LexiColors.brandBlack,
                          ),
                        ),
                      ),
                      const SizedBox(height: LexiSpacing.lg),
                      Text(
                        _stepTitle,
                        textAlign: TextAlign.center,
                        style: LexiTypography.h2,
                      ),
                      const SizedBox(height: LexiSpacing.sm),
                      Text(
                        _stepSubtitle,
                        textAlign: TextAlign.center,
                        style: LexiTypography.bodyMd.copyWith(
                          color: LexiColors.neutral500,
                        ),
                      ),
                      const SizedBox(height: LexiSpacing.xl),
                      // — Step 0: Email —
                      if (_step == 0) ...[
                        LexiInput(
                          label: 'البريد الإلكتروني',
                          hint: 'email@example.com',
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          autofillHints: const [AutofillHints.email],
                          prefixIcon: const Padding(
                            padding: EdgeInsets.only(top: 10),
                            child: FaIcon(
                              FontAwesomeIcons.envelope,
                              size: 15,
                              color: LexiColors.neutral500,
                            ),
                          ),
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) {
                              return 'الرجاء إدخال البريد الإلكتروني';
                            }
                            if (!v.contains('@')) {
                              return 'بريد إلكتروني غير صالح';
                            }
                            return null;
                          },
                        ),
                      ],
                      // — Step 1: OTP code —
                      if (_step == 1) ...[
                        LexiInput(
                          label: 'رمز التحقق',
                          hint: '000000',
                          controller: _codeController,
                          keyboardType: TextInputType.number,
                          prefixIcon: const Padding(
                            padding: EdgeInsets.only(top: 10),
                            child: FaIcon(
                              FontAwesomeIcons.shieldHalved,
                              size: 15,
                              color: LexiColors.neutral500,
                            ),
                          ),
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) {
                              return 'الرجاء إدخال رمز التحقق';
                            }
                            if (v.trim().length != 6) {
                              return 'رمز التحقق يتكون من 6 أرقام';
                            }
                            return null;
                          },
                        ),
                      ],
                      // — Step 2: New password —
                      if (_step == 2) ...[
                        LexiInput(
                          label: 'كلمة المرور الجديدة',
                          hint: '******',
                          controller: _newPasswordController,
                          obscureText: _obscurePassword,
                          prefixIcon: const Padding(
                            padding: EdgeInsets.only(top: 10),
                            child: FaIcon(
                              FontAwesomeIcons.lock,
                              size: 15,
                              color: LexiColors.neutral500,
                            ),
                          ),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscurePassword
                                  ? Icons.visibility_off
                                  : Icons.visibility,
                              color: LexiColors.neutral500,
                            ),
                            onPressed: () => setState(
                              () => _obscurePassword = !_obscurePassword,
                            ),
                          ),
                          validator: (v) {
                            if (v == null || v.isEmpty) {
                              return 'الرجاء إدخال كلمة المرور';
                            }
                            if (v.length < 6) {
                              return 'كلمة المرور يجب أن تكون 6 أحرف على الأقل';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: LexiSpacing.md),
                        LexiInput(
                          label: 'تأكيد كلمة المرور',
                          hint: '******',
                          controller: _confirmPasswordController,
                          obscureText: _obscureConfirm,
                          prefixIcon: const Padding(
                            padding: EdgeInsets.only(top: 10),
                            child: FaIcon(
                              FontAwesomeIcons.lock,
                              size: 15,
                              color: LexiColors.neutral500,
                            ),
                          ),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscureConfirm
                                  ? Icons.visibility_off
                                  : Icons.visibility,
                              color: LexiColors.neutral500,
                            ),
                            onPressed: () => setState(
                              () => _obscureConfirm = !_obscureConfirm,
                            ),
                          ),
                          validator: (v) {
                            if (v == null || v.isEmpty) {
                              return 'الرجاء تأكيد كلمة المرور';
                            }
                            if (v != _newPasswordController.text) {
                              return 'كلمات المرور غير متطابقة';
                            }
                            return null;
                          },
                        ),
                      ],
                      const SizedBox(height: LexiSpacing.xl),
                      LexiButton(
                        text: _stepButtonLabel,
                        isLoading: _isLoading,
                        onPressed: _onSubmit,
                        type: LexiButtonType.primary,
                        isFullWidth: true,
                      ),
                      const SizedBox(height: LexiSpacing.lg),
                      TextButton(
                        onPressed: () => context.go('/login'),
                        child: Text(
                          'العودة لتسجيل الدخول',
                          style: LexiTypography.bodyMd.copyWith(
                            decoration: TextDecoration.underline,
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
      ),
    );
  }

  // ── Step state helpers ──────────────────────────────────────────

  IconData get _stepIcon => switch (_step) {
    0 => FontAwesomeIcons.envelope,
    1 => FontAwesomeIcons.shieldHalved,
    _ => FontAwesomeIcons.lock,
  };

  String get _stepTitle => switch (_step) {
    0 => 'نسيت كلمة المرور؟',
    1 => 'أدخل رمز التحقق',
    _ => 'كلمة مرور جديدة',
  };

  String get _stepSubtitle => switch (_step) {
    0 => 'أدخل بريدك الإلكتروني وسنرسل لك رمز التحقق',
    1 => 'أدخل الرمز المكون من 6 أرقام الذي أرسلناه إلى بريدك',
    _ => 'أدخل كلمة المرور الجديدة',
  };

  String get _stepButtonLabel => switch (_step) {
    0 => 'إرسال رمز التحقق',
    1 => 'تحقق',
    _ => 'تعيين كلمة المرور',
  };

  // ── Actions ─────────────────────────────────────────────────────

  Future<void> _onSubmit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      switch (_step) {
        case 0:
          await _sendOtp();
        case 1:
          await _verifyAndReset();
        case 2:
          await _resetPassword();
      }
    } catch (e) {
      if (mounted) {
        await LexiAlert.error(context, text: _friendlyError(e));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _sendOtp() async {
    final repo = ref.read(customerAuthRepositoryProvider);
    await repo.forgotPassword(_emailController.text.trim());
    if (mounted) {
      await LexiAlert.success(
        context,
        text: 'تم إرسال رمز التحقق إلى بريدك الإلكتروني',
      );
      setState(() => _step = 1);
    }
  }

  Future<void> _verifyAndReset() async {
    // Move to step 2 to collect new password before calling API
    setState(() => _step = 2);
  }

  Future<void> _resetPassword() async {
    final repo = ref.read(customerAuthRepositoryProvider);
    await repo.resetPassword(
      _emailController.text.trim(),
      _codeController.text.trim(),
      _newPasswordController.text,
    );
    if (mounted) {
      await LexiAlert.success(
        context,
        text: 'تم تغيير كلمة المرور بنجاح. يمكنك تسجيل الدخول الآن.',
      );
      if (mounted) context.go('/login');
    }
  }

  String _friendlyError(Object error) {
    if (error is AppFailure) {
      return error.message;
    }
    return 'حدث خطأ. حاول مرة أخرى.';
  }
}
