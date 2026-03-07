import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/errors/app_failure.dart';
import '../../../../core/security/biometric_service.dart';
import '../../../../core/security/app_lock_service.dart';
import '../../../../core/session/app_session.dart';
import '../../../../design_system/lexi_tokens.dart';
import '../../../../design_system/lexi_typography.dart';
import '../../../../l10n/l10n.dart';
import '../../../../ui/forms/focus_chain.dart';
import '../../../../shared/widgets/lexi_ui/lexi_button.dart';
import '../../../../shared/widgets/lexi_ui/lexi_card.dart';
import '../../../../shared/widgets/lexi_ui/lexi_input.dart';
import '../../../../shared/ui/lexi_alert.dart';

class UnifiedLoginPage extends ConsumerStatefulWidget {
  const UnifiedLoginPage({super.key});

  @override
  ConsumerState<UnifiedLoginPage> createState() => _UnifiedLoginPageState();
}

class _UnifiedLoginPageState extends ConsumerState<UnifiedLoginPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _emailFocus = FocusNode();
  final _passwordFocus = FocusNode();
  final _formKey = GlobalKey<FormState>();
  late final FocusChain _focusChain;
  bool _isLoading = false;
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    _focusChain = FocusChain([_emailFocus, _passwordFocus]);
    _emailController.addListener(_handleFieldChanged);
    _passwordController.addListener(_handleFieldChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusChain.enableAutoScroll();
    });
  }

  @override
  void dispose() {
    _emailController.removeListener(_handleFieldChanged);
    _passwordController.removeListener(_handleFieldChanged);
    _emailController.dispose();
    _passwordController.dispose();
    _focusChain.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final session = ref.watch(appSessionProvider);
    final lockService = ref.watch(appLockServiceProvider);
    final showBiometricButton =
        !kIsWeb && session.hasStoredToken && lockService.biometricEnabled;
    final canSubmit =
        !_isLoading &&
        _emailController.text.trim().isNotEmpty &&
        _passwordController.text.trim().isNotEmpty;

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
                child: AutofillGroup(
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Center(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(LexiRadius.sm),
                            child: Image.asset(
                              'assets/images/logo_long.jpg',
                              width: 150,
                              height: 52,
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                        const SizedBox(height: LexiSpacing.xl),
                        Text(
                          l10n.loginWelcomeTitle,
                          textAlign: TextAlign.center,
                          style: LexiTypography.h2,
                        ),
                        const SizedBox(height: LexiSpacing.sm),
                        Text(
                          l10n.loginSubtitle,
                          textAlign: TextAlign.center,
                          style: LexiTypography.bodyMd,
                        ),
                        if (showBiometricButton) ...[
                          const SizedBox(height: LexiSpacing.lg),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: _isLoading ? null : _loginBiometric,
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 16,
                                ),
                                backgroundColor: LexiColors.brandBlack,
                                foregroundColor: LexiColors.brandWhite,
                              ),
                              icon: const FaIcon(
                                FontAwesomeIcons.fingerprint,
                                size: 18,
                              ),
                              label: Text(l10n.loginBiometric),
                            ),
                          ),
                          const SizedBox(height: LexiSpacing.md),
                          Text(
                            l10n.loginWithPasswordOption,
                            textAlign: TextAlign.center,
                            style: LexiTypography.bodySm,
                          ),
                        ],
                        const SizedBox(height: LexiSpacing.xl),
                        LexiInput(
                          label: l10n.loginEmailOrUsername,
                          hint: 'email@example.com',
                          controller: _emailController,
                          focusNode: _emailFocus,
                          textInputAction: TextInputAction.next,
                          onFieldSubmitted: (_) =>
                              _focusChain.focusNext(context, _emailFocus),
                          autofillHints: const [AutofillHints.username],
                          prefixIcon: const Padding(
                            padding: EdgeInsets.only(top: 10),
                            child: FaIcon(
                              FontAwesomeIcons.user,
                              size: 15,
                              color: LexiColors.neutral500,
                            ),
                          ),
                          validator: (v) =>
                              v!.isEmpty ? l10n.fieldRequired : null,
                        ),
                        const SizedBox(height: LexiSpacing.md),
                        LexiInput(
                          label: l10n.loginPassword,
                          hint: '******',
                          controller: _passwordController,
                          focusNode: _passwordFocus,
                          textInputAction: TextInputAction.done,
                          onFieldSubmitted: (_) =>
                              _focusChain.focusDone(context, _login),
                          autofillHints: const [AutofillHints.password],
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
                          validator: (v) =>
                              v!.isEmpty ? l10n.fieldRequired : null,
                        ),
                        const SizedBox(height: LexiSpacing.sm),
                        Align(
                          alignment: AlignmentDirectional.centerEnd,
                          child: TextButton(
                            onPressed: () => context.go('/forgot-password'),
                            style: TextButton.styleFrom(
                              padding: EdgeInsets.zero,
                              minimumSize: const Size(0, 0),
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            child: Text(
                              l10n.loginForgotPassword,
                              style: LexiTypography.bodySm.copyWith(
                                color: LexiColors.neutral500,
                                decoration: TextDecoration.underline,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: LexiSpacing.xl),
                        LexiButton(
                          text: l10n.loginButton,
                          isLoading: _isLoading,
                          onPressed: canSubmit ? _login : null,
                          type: LexiButtonType.primary,
                          isFullWidth: true,
                        ),
                        const SizedBox(height: LexiSpacing.lg),
                        TextButton(
                          onPressed: () {
                            context.go('/register');
                          },
                          child: Text(
                            l10n.loginCreateAccount,
                            style: LexiTypography.bodyMd.copyWith(
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ),
                        const SizedBox(height: LexiSpacing.xs),
                        TextButton(
                          onPressed: () {
                            context.go('/');
                          },
                          child: Text(
                            l10n.loginContinueAsGuest,
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
      ),
    );
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      final session = ref.read(appSessionProvider);
      await session.login(_emailController.text, _passwordController.text);
      if (!mounted) {
        return;
      }

      // Prompt user to set up App Lock (non-blocking)
      if (mounted) {
        await ref.read(appLockServiceProvider).setSetupPromptPending(true);
      }
      if (!mounted) {
        return;
      }

      // If App Lock is already enabled for this account, require unlock
      // immediately after successful login (PIN or biometric).
      final lockService = ref.read(appLockServiceProvider);
      if (lockService.lockEnabled && lockService.unlockRequiredToday) {
        final biometricAvailable = await ref
            .read(biometricServiceProvider)
            .isAvailable();
        if (biometricAvailable && !lockService.biometricEnabled) {
          await lockService.enableBiometrics();
        }
        lockService.lock();
      }
      if (!mounted) {
        return;
      }
      // Removed LexiAlert.success as requested by user
      context.go('/');
    } catch (e) {
      if (mounted) {
        await LexiAlert.error(context, text: _friendlyError(e));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loginBiometric() async {
    setState(() => _isLoading = true);
    try {
      final biometric = ref.read(biometricServiceProvider);
      final session = ref.read(appSessionProvider);

      final lockService = ref.read(appLockServiceProvider);

      if (!lockService.biometricEnabled || !session.hasStoredToken) {
        if (mounted) {
          await LexiAlert.warning(
            context,
            text: context.l10n.loginPasswordFirst,
          );
        }
        return;
      }

      final available = await biometric.isAvailable();
      if (!available) {
        if (mounted) {
          await LexiAlert.warning(
            context,
            text: context.l10n.loginBiometricUnavailable,
          );
        }
        return;
      }

      final authPassed = await biometric.authenticate();
      if (!authPassed) {
        if (mounted) {
          await LexiAlert.error(
            context,
            text: context.l10n.loginBiometricFailed,
          );
        }
        return;
      }

      final tokenValid = await session.validateStoredToken();
      if (!tokenValid) {
        if (mounted) {
          await LexiAlert.error(
            context,
            text: context.l10n.loginSessionExpired,
          );
        }
        return;
      }

      if (mounted) {
        context.go('/');
      }
    } catch (e) {
      if (mounted) {
        await LexiAlert.error(context, text: context.l10n.loginBiometricFailed);
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _friendlyError(Object error) {
    if (error is AppFailure) {
      return error.message;
    }
    return context.l10n.loginFailedGeneric;
  }

  void _handleFieldChanged() {
    if (mounted) {
      setState(() {});
    }
  }
}
