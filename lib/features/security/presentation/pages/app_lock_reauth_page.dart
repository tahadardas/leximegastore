import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../core/security/app_lock_service.dart';
import '../../../../core/session/app_session.dart';
import '../../../../design_system/lexi_tokens.dart';
import '../../../../design_system/lexi_typography.dart';

/// Forgot-PIN re-authentication page.
///
/// The user re-authenticates using their account password.
/// On success the App Lock settings are cleared and they are forwarded
/// to the Enable App Lock flow to create a new PIN.
class AppLockReauthPage extends ConsumerStatefulWidget {
  const AppLockReauthPage({super.key});

  @override
  ConsumerState<AppLockReauthPage> createState() => _AppLockReauthPageState();
}

class _AppLockReauthPageState extends ConsumerState<AppLockReauthPage> {
  final _passwordController = TextEditingController();
  bool _obscure = true;
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _reauth() async {
    final password = _passwordController.text.trim();
    if (password.isEmpty) {
      setState(() => _error = 'يرجى إدخال كلمة المرور.');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final session = ref.read(appSessionProvider);
      // Re-authenticate using stored email/username and provided password
      final identifier = (session.email ?? '').trim();
      if (identifier.isEmpty) {
        setState(() => _error = 'لا يوجد حساب مسجّل حاليًا.');
        return;
      }

      await session.login(identifier, password);

      // Clear App Lock state
      final lockService = ref.read(appLockServiceProvider);
      await lockService.disableLock();
      await lockService.setSetupPromptPending(false);

      if (!mounted) return;
      // Forward to enable new PIN
      context.go(AppRoutePaths.securityEnable);
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'كلمة المرور غير صحيحة. حاول مرة أخرى.');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final canSubmit = !_loading && _passwordController.text.trim().isNotEmpty;

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
                child: Column(
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
                        Icons.key_rounded,
                        size: 40,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: LexiSpacing.lg),
                    Text(
                      'إعادة التحقق',
                      style: LexiTypography.h2.copyWith(color: Colors.white),
                    ),
                    const SizedBox(height: LexiSpacing.xs),
                    Text(
                      'أدخل كلمة مرور حسابك لإعادة إنشاء رمز PIN.',
                      textAlign: TextAlign.center,
                      style: LexiTypography.bodyMd.copyWith(
                        color: Colors.white70,
                      ),
                    ),
                    const SizedBox(height: LexiSpacing.xl),
                    if (_error != null) ...[
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(LexiSpacing.sm),
                        decoration: BoxDecoration(
                          color: LexiColors.error.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(LexiRadius.sm),
                          border: Border.all(color: LexiColors.error),
                        ),
                        child: Text(
                          _error!,
                          textAlign: TextAlign.center,
                          style: LexiTypography.bodySm.copyWith(
                            color: LexiColors.error,
                          ),
                        ),
                      ),
                      const SizedBox(height: LexiSpacing.md),
                    ],
                    Theme(
                      data: Theme.of(context).copyWith(
                        inputDecorationTheme: InputDecorationTheme(
                          filled: true,
                          fillColor: Colors.white.withValues(alpha: 0.08),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(LexiRadius.md),
                            borderSide: BorderSide(
                              color: Colors.white.withValues(alpha: 0.2),
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(LexiRadius.md),
                            borderSide: BorderSide(
                              color: Colors.white.withValues(alpha: 0.2),
                            ),
                          ),
                          labelStyle: const TextStyle(color: Colors.white70),
                          hintStyle: const TextStyle(color: Colors.white38),
                        ),
                      ),
                      child: TextField(
                        controller: _passwordController,
                        obscureText: _obscure,
                        style: const TextStyle(color: Colors.white),
                        onChanged: (_) => setState(() {}),
                        onSubmitted: (_) => canSubmit ? _reauth() : null,
                        decoration: InputDecoration(
                          labelText: 'كلمة المرور',
                          hintText: '••••••',
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscure
                                  ? Icons.visibility_off
                                  : Icons.visibility,
                              color: Colors.white54,
                            ),
                            onPressed: () =>
                                setState(() => _obscure = !_obscure),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: LexiSpacing.xl),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: canSubmit ? _reauth : null,
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          backgroundColor: LexiColors.brandPrimary,
                          foregroundColor: LexiColors.brandBlack,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(LexiRadius.md),
                          ),
                        ),
                        child: _loading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.4,
                                  color: LexiColors.brandBlack,
                                ),
                              )
                            : Text('متابعة', style: LexiTypography.labelLg),
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
