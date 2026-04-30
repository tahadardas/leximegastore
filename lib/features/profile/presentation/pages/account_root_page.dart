import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/auth/auth_session_controller.dart';
import '../../../../core/errors/app_failure.dart';
import '../../../../core/session/app_session.dart';
import '../../../../design_system/lexi_tokens.dart';
import '../../../../design_system/lexi_typography.dart';
import '../../../../shared/widgets/lexi_ui/lexi_app_bar.dart';
import '../../../../shared/widgets/lexi_ui/lexi_button.dart';
import '../../../../shared/widgets/lexi_ui/lexi_card.dart';
import '../../../../shared/widgets/lexi_ui/lexi_input.dart';
import '../../../auth/presentation/controllers/customer_auth_controller.dart';
import 'profile_page.dart';

class AccountRootPage extends ConsumerWidget {
  const AccountRootPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authSessionControllerProvider).state;

    if (authState.status == AuthSessionStatus.authenticated) {
      return const ProfilePage();
    }

    return Scaffold(
      backgroundColor: LexiColors.neutral100,
      appBar: const LexiAppBar(title: 'حسابي'),
      body: SafeArea(
        child: authState.status == AuthSessionStatus.unknown
            ? const Center(child: CircularProgressIndicator())
            : const _AccountAuthPanel(),
      ),
    );
  }
}

class _AccountAuthPanel extends StatefulWidget {
  const _AccountAuthPanel();

  @override
  State<_AccountAuthPanel> createState() => _AccountAuthPanelState();
}

class _AccountAuthPanelState extends State<_AccountAuthPanel>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final tabBodyHeight = constraints.maxHeight >= 720 ? 560.0 : 460.0;
        return SingleChildScrollView(
          padding: const EdgeInsets.all(LexiSpacing.md),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: LexiCard(
                padding: const EdgeInsets.all(LexiSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'إدارة حسابك',
                      style: LexiTypography.h3,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: LexiSpacing.xs),
                    Text(
                      'سجّل الدخول أو أنشئ حساباً جديداً',
                      style: LexiTypography.bodySm,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: LexiSpacing.md),
                    TabBar(
                      controller: _tabController,
                      labelColor: LexiColors.brandBlack,
                      indicatorColor: LexiColors.brandPrimary,
                      tabs: const [
                        Tab(text: 'تسجيل الدخول'),
                        Tab(text: 'إنشاء حساب'),
                      ],
                    ),
                    const SizedBox(height: LexiSpacing.md),
                    SizedBox(
                      height: tabBodyHeight,
                      child: TabBarView(
                        controller: _tabController,
                        children: const [
                          _AccountLoginForm(),
                          _AccountRegisterForm(),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _AccountLoginForm extends ConsumerStatefulWidget {
  const _AccountLoginForm();

  @override
  ConsumerState<_AccountLoginForm> createState() => _AccountLoginFormState();
}

class _AccountLoginFormState extends ConsumerState<_AccountLoginForm>
    with AutomaticKeepAliveClientMixin {
  final _formKey = GlobalKey<FormState>();
  final _identifierController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isLoading = false;
  bool _obscurePassword = true;
  String? _errorText;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _identifierController.addListener(_onFieldChanged);
    _passwordController.addListener(_onFieldChanged);
  }

  @override
  void dispose() {
    _identifierController.removeListener(_onFieldChanged);
    _passwordController.removeListener(_onFieldChanged);
    _identifierController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final canSubmit = _canSubmit;

    return SingleChildScrollView(
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_errorText != null && _errorText!.trim().isNotEmpty)
              _InlineError(message: _errorText!),
            if (_errorText != null && _errorText!.trim().isNotEmpty)
              const SizedBox(height: LexiSpacing.sm),
            LexiInput(
              label: 'رقم الهاتف',
              hint: '09xxxxxxxx',
              controller: _identifierController,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.username],
              validator: (value) {
                if ((value ?? '').trim().isEmpty) {
                  return 'هذا الحقل مطلوب';
                }
                return null;
              },
            ),
            const SizedBox(height: LexiSpacing.sm),
            LexiInput(
              label: 'كلمة المرور',
              hint: '******',
              controller: _passwordController,
              textInputAction: TextInputAction.done,
              autofillHints: const [AutofillHints.password],
              obscureText: _obscurePassword,
              suffixIcon: IconButton(
                icon: Icon(
                  _obscurePassword ? Icons.visibility_off : Icons.visibility,
                  color: LexiColors.neutral500,
                ),
                onPressed: () =>
                    setState(() => _obscurePassword = !_obscurePassword),
              ),
              validator: (value) {
                if ((value ?? '').trim().isEmpty) {
                  return 'هذا الحقل مطلوب';
                }
                return null;
              },
            ),
            const SizedBox(height: LexiSpacing.md),
            LexiButton(
              label: 'تسجيل الدخول',
              isLoading: _isLoading,
              isFullWidth: true,
              onPressed: canSubmit ? _submit : null,
            ),
          ],
        ),
      ),
    );
  }

  bool get _canSubmit {
    return !_isLoading &&
        _identifierController.text.trim().isNotEmpty &&
        _passwordController.text.trim().isNotEmpty;
  }

  void _onFieldChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    setState(() {
      _isLoading = true;
      _errorText = null;
    });

    try {
      await ref
          .read(appSessionProvider)
          .login(_identifierController.text.trim(), _passwordController.text);
      await ref.read(customerAuthControllerProvider.notifier).refreshProfile();
      if (!mounted) return;
      // Success snackbar removed as requested
    } catch (e) {
      if (!mounted) return;
      setState(() => _errorText = _friendlyError(e));
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  String _friendlyError(Object error) {
    if (error is AppFailure) {
      return error.message;
    }
    return 'تعذر تسجيل الدخول. حاول مرة أخرى.';
  }
}

class _AccountRegisterForm extends ConsumerStatefulWidget {
  const _AccountRegisterForm();

  @override
  ConsumerState<_AccountRegisterForm> createState() =>
      _AccountRegisterFormState();
}

class _AccountRegisterFormState extends ConsumerState<_AccountRegisterForm>
    with AutomaticKeepAliveClientMixin {
  final _formKey = GlobalKey<FormState>();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _cityController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  String? _errorText;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    for (final controller in _controllers) {
      controller.addListener(_onFieldChanged);
    }
  }

  @override
  void dispose() {
    for (final controller in _controllers) {
      controller.removeListener(_onFieldChanged);
      controller.dispose();
    }
    super.dispose();
  }

  List<TextEditingController> get _controllers => [
    _firstNameController,
    _lastNameController,
    _phoneController,
    _addressController,
    _cityController,
    _passwordController,
    _confirmPasswordController,
  ];

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final canSubmit = _canSubmit;

    return SingleChildScrollView(
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_errorText != null && _errorText!.trim().isNotEmpty)
              _InlineError(message: _errorText!),
            if (_errorText != null && _errorText!.trim().isNotEmpty)
              const SizedBox(height: LexiSpacing.sm),
            Row(
              children: [
                Expanded(
                  child: LexiInput(
                    label: 'الاسم الأول',
                    controller: _firstNameController,
                    validator: _required,
                    autofillHints: const [AutofillHints.givenName],
                  ),
                ),
                const SizedBox(width: LexiSpacing.sm),
                Expanded(
                  child: LexiInput(
                    label: 'الاسم الأخير',
                    controller: _lastNameController,
                    validator: _required,
                    autofillHints: const [AutofillHints.familyName],
                  ),
                ),
              ],
            ),
            LexiInput(
              label: 'رقم الهاتف',
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              autofillHints: const [AutofillHints.telephoneNumber],
              validator: (value) {
                final phone = (value ?? '').trim();
                if (phone.isEmpty) {
                  return 'هذا الحقل مطلوب';
                }
                if (phone.length < 9) {
                  return 'رقم الهاتف غير صحيح';
                }
                return null;
              },
            ),
            const SizedBox(height: LexiSpacing.sm),
            LexiInput(
              label: 'العنوان (اختياري)',
              controller: _addressController,
              autofillHints: const [AutofillHints.streetAddressLine1],
            ),
            const SizedBox(height: LexiSpacing.sm),
            LexiInput(
              label: 'المدينة (اختياري)',
              controller: _cityController,
              autofillHints: const [AutofillHints.addressCity],
            ),
            const SizedBox(height: LexiSpacing.sm),
            LexiInput(
              label: 'كلمة المرور',
              controller: _passwordController,
              obscureText: _obscurePassword,
              autofillHints: const [AutofillHints.newPassword],
              suffixIcon: IconButton(
                icon: Icon(
                  _obscurePassword ? Icons.visibility_off : Icons.visibility,
                  color: LexiColors.neutral500,
                ),
                onPressed: () =>
                    setState(() => _obscurePassword = !_obscurePassword),
              ),
              validator: (value) {
                if ((value ?? '').trim().isEmpty) {
                  return 'هذا الحقل مطلوب';
                }
                if ((value ?? '').trim().length < 6) {
                  return 'كلمة المرور يجب أن تكون 6 أحرف على الأقل';
                }
                return null;
              },
            ),
            const SizedBox(height: LexiSpacing.sm),
            LexiInput(
              label: 'تأكيد كلمة المرور',
              controller: _confirmPasswordController,
              obscureText: _obscureConfirmPassword,
              autofillHints: const [AutofillHints.newPassword],
              suffixIcon: IconButton(
                icon: Icon(
                  _obscureConfirmPassword
                      ? Icons.visibility_off
                      : Icons.visibility,
                  color: LexiColors.neutral500,
                ),
                onPressed: () => setState(
                  () => _obscureConfirmPassword = !_obscureConfirmPassword,
                ),
              ),
              validator: (value) {
                if ((value ?? '').trim().isEmpty) {
                  return 'هذا الحقل مطلوب';
                }
                if ((value ?? '').trim() != _passwordController.text.trim()) {
                  return 'كلمتا المرور غير متطابقتين';
                }
                return null;
              },
            ),
            const SizedBox(height: LexiSpacing.md),
            LexiButton(
              label: 'إنشاء حساب',
              isLoading: _isLoading,
              isFullWidth: true,
              onPressed: canSubmit ? _submit : null,
            ),
          ],
        ),
      ),
    );
  }

  bool get _canSubmit {
    final phone = _phoneController.text.trim();
    final password = _passwordController.text.trim();
    final confirm = _confirmPasswordController.text.trim();
    return !_isLoading &&
        _firstNameController.text.trim().isNotEmpty &&
        _lastNameController.text.trim().isNotEmpty &&
        phone.length >= 9 &&
        password.length >= 6 &&
        confirm == password;
  }

  void _onFieldChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  String? _required(String? value) {
    if ((value ?? '').trim().isEmpty) {
      return 'هذا الحقل مطلوب';
    }
    return null;
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    setState(() {
      _isLoading = true;
      _errorText = null;
    });

    try {
      final phone = _phoneController.text.trim();
      final generatedEmail = '$phone@leximega.store';

      await ref
          .read(appSessionProvider)
          .register(
            email: generatedEmail,
            password: _passwordController.text,
            username: phone,
            firstName: _firstNameController.text.trim(),
            lastName: _lastNameController.text.trim(),
            phone: phone,
            address1: _addressController.text.trim(),
            city: _cityController.text.trim(),
          );
      await ref.read(customerAuthControllerProvider.notifier).refreshProfile();
      if (!mounted) return;
      // Success snackbar removed as requested
    } catch (e) {
      if (!mounted) return;
      setState(() => _errorText = _friendlyError(e));
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  String _friendlyError(Object error) {
    if (error is AppFailure) {
      return error.message;
    }
    return 'تعذر إنشاء الحساب. حاول مرة أخرى.';
  }
}

class _InlineError extends StatelessWidget {
  final String message;

  const _InlineError({required this.message});

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
