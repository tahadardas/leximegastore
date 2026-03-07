import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/errors/app_exception.dart';
import '../../../../design_system/lexi_tokens.dart';
import '../../../../design_system/lexi_typography.dart';
import '../../../../shared/widgets/lexi_ui/lexi_button.dart';
import '../../../../shared/widgets/lexi_ui/lexi_card.dart';
import '../../../../shared/widgets/lexi_ui/lexi_input.dart';
import '../controllers/admin_auth_controller.dart';

class AdminLoginPage extends ConsumerStatefulWidget {
  const AdminLoginPage({super.key});

  @override
  ConsumerState<AdminLoginPage> createState() => _AdminLoginPageState();
}

class _AdminLoginPageState extends ConsumerState<AdminLoginPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(adminAuthControllerProvider, (prev, next) {
      if (next.hasValue && next.value != null) {
        context.go('/admin/dashboard');
      }
    });

    final state = ref.watch(adminAuthControllerProvider);

    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              LexiColors.brandBlack,
              Color(0xFF121212),
              LexiColors.neutral100,
            ],
            stops: [0, 0.34, 0.34],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(LexiSpacing.lg),
              child: TweenAnimationBuilder<double>(
                duration: const Duration(milliseconds: 520),
                curve: Curves.easeOutCubic,
                tween: Tween(begin: 0, end: 1),
                builder: (context, value, child) {
                  return Opacity(
                    opacity: value,
                    child: Transform.translate(
                      offset: Offset(0, (1 - value) * 22),
                      child: child,
                    ),
                  );
                },
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: LexiCard(
                    padding: const EdgeInsets.all(LexiSpacing.xl),
                    boxShadow: LexiShadows.lg,
                    child: Form(
                      key: _formKey,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(LexiRadius.sm),
                            child: Image.asset(
                              'assets/images/logo_long.jpg',
                              height: 70,
                              fit: BoxFit.cover,
                            ),
                          ),
                          const SizedBox(height: LexiSpacing.md),
                          Text(
                            'تسجيل دخول الإدارة',
                            style: LexiTypography.h2,
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: LexiSpacing.xl),
                          if (state.hasError) ...[
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(LexiSpacing.sm),
                              decoration: BoxDecoration(
                                color: LexiColors.error.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(
                                  LexiRadius.sm,
                                ),
                                border: Border.all(color: LexiColors.error),
                              ),
                              child: Text(
                                _readableError(state.error),
                                textAlign: TextAlign.center,
                                style: LexiTypography.bodySm.copyWith(
                                  color: LexiColors.error,
                                ),
                              ),
                            ),
                            const SizedBox(height: LexiSpacing.md),
                          ],
                          LexiInput(
                            controller: _emailController,
                            label: 'البريد أو اسم المستخدم أو رقم الهاتف',
                            prefixIcon: const Icon(Icons.email_outlined),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'الرجاء إدخال البريد أو اسم المستخدم';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: LexiSpacing.md),
                          LexiInput(
                            controller: _passwordController,
                            label: 'كلمة المرور',
                            hint: 'أدخل كلمة المرور',
                            obscureText: true,
                            prefixIcon: const Icon(Icons.lock_outline),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'كلمة المرور مطلوبة';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: LexiSpacing.xl),
                          LexiButton(
                            label: 'دخول',
                            isLoading: state.isLoading,
                            isFullWidth: true,
                            onPressed: () {
                              if (_formKey.currentState!.validate()) {
                                ref
                                    .read(adminAuthControllerProvider.notifier)
                                    .login(
                                      _emailController.text.trim(),
                                      _passwordController.text,
                                    );
                              }
                            },
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
      ),
    );
  }

  String _readableError(Object? error) {
    if (error == null) {
      return 'فشل تسجيل الدخول، حاول مرة أخرى.';
    }

    if (error is AppException) {
      return error.message;
    }

    final raw = error.toString();

    if (raw.contains('XMLHttpRequest') ||
        raw.contains('connection error') ||
        raw.contains('connection errored')) {
      if (kIsWeb) {
        return 'تعذر الاتصال بالخادم من المتصفح. غالبًا يوجد خطأ CORS/OPTIONS على السيرفر.';
      }
      return 'تعذر الاتصال بالخادم. تحقق من الشبكة ثم حاول مرة أخرى.';
    }

    if (raw.contains('SocketException')) {
      return 'لا يوجد اتصال بالإنترنت.';
    }

    return raw
        .replaceAll('Exception: ', '')
        .replaceAll('DioException', '')
        .trim();
  }
}
