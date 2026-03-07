import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/errors/app_exception.dart';
import '../../../../design_system/lexi_tokens.dart';
import '../../../../design_system/lexi_typography.dart';
import '../../../../shared/widgets/lexi_ui/lexi_button.dart';
import '../../../../shared/widgets/lexi_ui/lexi_card.dart';
import '../../../../shared/widgets/lexi_ui/lexi_input.dart';
import '../controllers/customer_auth_controller.dart';

class CustomerLoginPage extends ConsumerStatefulWidget {
  const CustomerLoginPage({super.key});

  @override
  ConsumerState<CustomerLoginPage> createState() => _CustomerLoginPageState();
}

class _CustomerLoginPageState extends ConsumerState<CustomerLoginPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  bool _welcomed = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(customerAuthControllerProvider, (prev, next) {
      final prevUser = prev?.asData?.value;
      final user = next.asData?.value;
      if (!_welcomed && prevUser == null && user != null) {
        _welcomed = true;
        context.go('/profile');
      }
    });

    final state = ref.watch(customerAuthControllerProvider);

    return Scaffold(
      backgroundColor: LexiColors.neutral100,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(LexiSpacing.lg),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 430),
              child: LexiCard(
                padding: const EdgeInsets.all(LexiSpacing.xl),
                boxShadow: LexiShadows.md,
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
                        'تسجيل دخول المستخدم',
                        style: LexiTypography.h2,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: LexiSpacing.xl),
                      if (state.hasError) ...[
                        _ErrorBox(message: _readableError(state.error)),
                        const SizedBox(height: LexiSpacing.md),
                      ],
                      LexiInput(
                        controller: _emailController,
                        label: 'البريد أو اسم المستخدم أو رقم الهاتف',
                        prefixIcon: const Padding(
                          padding: EdgeInsets.only(top: 10),
                          child: FaIcon(
                            FontAwesomeIcons.user,
                            size: 15,
                            color: LexiColors.neutral500,
                          ),
                        ),
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
                        prefixIcon: const Padding(
                          padding: EdgeInsets.only(top: 10),
                          child: FaIcon(
                            FontAwesomeIcons.lock,
                            size: 15,
                            color: LexiColors.neutral500,
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'كلمة المرور مطلوبة';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: LexiSpacing.xl),
                      LexiButton(
                        label: 'تسجيل الدخول',
                        isLoading: state.isLoading,
                        isFullWidth: true,
                        onPressed: () {
                          if (!_formKey.currentState!.validate()) {
                            return;
                          }
                          ref
                              .read(customerAuthControllerProvider.notifier)
                              .login(
                                _emailController.text.trim(),
                                _passwordController.text,
                              );
                        },
                      ),
                      const SizedBox(height: LexiSpacing.md),
                      TextButton(
                        onPressed: () => context.push('/register'),
                        child: const Text('ليس لديك حساب؟ إنشاء حساب جديد'),
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
        return 'تعذر الاتصال بالخادم من المتصفح. تحقق من إعدادات CORS.';
      }
      return 'تعذر الاتصال بالخادم. تحقق من الشبكة.';
    }
    return raw.replaceAll('Exception: ', '').trim();
  }
}

class _ErrorBox extends StatelessWidget {
  final String message;

  const _ErrorBox({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(LexiSpacing.sm),
      decoration: BoxDecoration(
        color: LexiColors.error.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(LexiRadius.sm),
        border: Border.all(color: LexiColors.error),
      ),
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: LexiTypography.bodySm.copyWith(color: LexiColors.error),
      ),
    );
  }
}
