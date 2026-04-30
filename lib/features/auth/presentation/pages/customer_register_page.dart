import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/errors/app_exception.dart';
import '../../../../core/errors/app_failure.dart';
import '../../../../core/services/location_address_service.dart';
import '../../../../core/services/location_permission_rationale.dart';
import '../../../../design_system/lexi_tokens.dart';
import '../../../../design_system/lexi_typography.dart';
import '../../../../l10n/l10n.dart';
import '../../../../ui/widgets/lexi_safe_bottom.dart';
import '../../../../ui/forms/focus_chain.dart';
import '../../../../shared/widgets/lexi_ui/lexi_app_bar.dart';
import '../../../../shared/widgets/lexi_ui/lexi_button.dart';
import '../../../../shared/widgets/lexi_ui/lexi_card.dart';
import '../../../../shared/widgets/lexi_ui/lexi_input.dart';
import '../controllers/customer_auth_controller.dart';

class CustomerRegisterPage extends ConsumerStatefulWidget {
  const CustomerRegisterPage({super.key});

  @override
  ConsumerState<CustomerRegisterPage> createState() =>
      _CustomerRegisterPageState();
}

class _CustomerRegisterPageState extends ConsumerState<CustomerRegisterPage> {
  final _formKey = GlobalKey<FormState>();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _cityController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _firstNameFocus = FocusNode();
  final _lastNameFocus = FocusNode();
  final _phoneFocus = FocusNode();
  final _addressFocus = FocusNode();
  final _cityFocus = FocusNode();
  final _passwordFocus = FocusNode();
  final _confirmPasswordFocus = FocusNode();
  late final FocusChain _focusChain;

  bool _welcomed = false;
  bool _isResolvingLocation = false;

  @override
  void initState() {
    super.initState();
    _focusChain = FocusChain([
      _firstNameFocus,
      _lastNameFocus,
      _phoneFocus,
      _addressFocus,
      _cityFocus,
      _passwordFocus,
      _confirmPasswordFocus,
    ]);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusChain.enableAutoScroll();
    });
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _cityController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _focusChain.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    ref.listen(customerAuthControllerProvider, (prev, next) async {
      final prevUser = prev?.asData?.value;
      final user = next.asData?.value;
      if (!_welcomed && prevUser == null && user != null) {
        _welcomed = true;
        if (!context.mounted) {
          return;
        }
        ScaffoldMessenger.of(context).showSnackBar(
          lexiFloatingSnackBar(
            context,
            content: Text(l10n.registerWelcomeMessage(user.fullName)),
          ),
        );
        context.go('/');
      }
    });

    final state = ref.watch(customerAuthControllerProvider);

    return Scaffold(
      backgroundColor: LexiColors.neutral100,
      appBar: LexiAppBar(title: l10n.registerAppBarTitle),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(LexiSpacing.md),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: LexiCard(
              padding: const EdgeInsets.all(LexiSpacing.lg),
              child: AutofillGroup(
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(l10n.registerSectionTitle, style: LexiTypography.h3),
                      const SizedBox(height: LexiSpacing.md),
                      if (state.hasError) ...[
                        _ErrorBox(message: _readableError(state.error)),
                        const SizedBox(height: LexiSpacing.md),
                      ],
                      Row(
                        children: [
                          Expanded(
                            child: LexiInput(
                              controller: _firstNameController,
                              label: 'الاسم الأول',
                              focusNode: _firstNameFocus,
                              textInputAction: TextInputAction.next,
                              onFieldSubmitted: (_) => _focusChain.focusNext(
                                context,
                                _firstNameFocus,
                              ),
                              autofillHints: const [AutofillHints.givenName],
                              validator: _required,
                            ),
                          ),
                          const SizedBox(width: LexiSpacing.sm),
                          Expanded(
                            child: LexiInput(
                              controller: _lastNameController,
                              label: 'الاسم الأخير',
                              focusNode: _lastNameFocus,
                              textInputAction: TextInputAction.next,
                              onFieldSubmitted: (_) => _focusChain.focusNext(
                                context,
                                _lastNameFocus,
                              ),
                              autofillHints: const [AutofillHints.familyName],
                              validator: _required,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: LexiSpacing.sm),
                      LexiInput(
                        controller: _phoneController,
                        label: 'رقم الهاتف',
                        focusNode: _phoneFocus,
                        textInputAction: TextInputAction.next,
                        onFieldSubmitted: (_) =>
                            _focusChain.focusNext(context, _phoneFocus),
                        autofillHints: const [AutofillHints.telephoneNumber],
                        keyboardType: TextInputType.phone,
                        validator: (value) {
                          final phone = (value ?? '').trim();
                          if (phone.isEmpty) {
                            return 'رقم الهاتف مطلوب';
                          }
                          if (phone.length < 9) {
                            return 'رقم الهاتف غير صحيح';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: LexiSpacing.sm),
                      LexiInput(
                        controller: _addressController,
                        label: 'العنوان',
                        focusNode: _addressFocus,
                        textInputAction: TextInputAction.next,
                        onFieldSubmitted: (_) =>
                            _focusChain.focusNext(context, _addressFocus),
                        autofillHints: const [AutofillHints.streetAddressLine1],
                      ),
                      const SizedBox(height: LexiSpacing.sm),
                      LexiInput(
                        controller: _cityController,
                        label: 'المدينة',
                        focusNode: _cityFocus,
                        textInputAction: TextInputAction.next,
                        onFieldSubmitted: (_) =>
                            _focusChain.focusNext(context, _cityFocus),
                        autofillHints: const [AutofillHints.addressCity],
                      ),
                      const SizedBox(height: LexiSpacing.sm),
                      OutlinedButton.icon(
                        onPressed: _isResolvingLocation
                            ? null
                            : _fillAddressFromLocation,
                        icon: _isResolvingLocation
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.my_location_outlined),
                        label: Text(l10n.registerUseCurrentLocation),
                      ),
                      const SizedBox(height: LexiSpacing.sm),
                      LexiInput(
                        controller: _passwordController,
                        label: 'كلمة المرور',
                        focusNode: _passwordFocus,
                        textInputAction: TextInputAction.next,
                        onFieldSubmitted: (_) =>
                            _focusChain.focusNext(context, _passwordFocus),
                        autofillHints: const [AutofillHints.newPassword],
                        obscureText: true,
                        validator: (value) {
                          if ((value ?? '').trim().isEmpty) {
                            return context.l10n.fieldRequired;
                          }
                          if (value!.trim().length < 6) {
                            return 'كلمة المرور يجب أن تكون 6 أحرف على الأقل';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: LexiSpacing.sm),
                      LexiInput(
                        controller: _confirmPasswordController,
                        label: 'تأكيد كلمة المرور',
                        focusNode: _confirmPasswordFocus,
                        textInputAction: TextInputAction.done,
                        onFieldSubmitted: (_) =>
                            _focusChain.focusDone(context, _submitRegister),
                        autofillHints: const [AutofillHints.newPassword],
                        obscureText: true,
                        validator: (value) {
                          if ((value ?? '').trim().isEmpty) {
                            return context.l10n.fieldRequired;
                          }
                          if (value!.trim() !=
                              _passwordController.text.trim()) {
                            return 'كلمتا المرور غير متطابقتين';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: LexiSpacing.lg),
                      LexiButton(
                        label: l10n.registerCreateAccount,
                        isLoading: state.isLoading,
                        isFullWidth: true,
                        onPressed: _submitRegister,
                      ),
                      const SizedBox(height: LexiSpacing.sm),
                      Center(
                        child: TextButton(
                          onPressed: () => context.go('/login'),
                          child: Text(l10n.registerHaveAccount),
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

  String? _required(String? value) {
    if ((value ?? '').trim().isEmpty) {
      return context.l10n.fieldRequired;
    }
    return null;
  }

  void _submitRegister() {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final phone = _phoneController.text.trim();
    final generatedEmail = '$phone@leximega.store';

    ref
        .read(customerAuthControllerProvider.notifier)
        .register(
          email: generatedEmail,
          password: _passwordController.text,
          username: phone, // Use phone as username
          firstName: _firstNameController.text.trim(),
          lastName: _lastNameController.text.trim(),
          phone: phone,
          address1: _addressController.text.trim(),
          city: _cityController.text.trim(),
        );
  }

  String _readableError(Object? error) {
    if (error is AppException) {
      return error.message;
    }
    return context.l10n.registerFailedGeneric;
  }

  Future<void> _fillAddressFromLocation() async {
    final approved = await showLocationPermissionRationaleDialog(context);
    if (!approved) {
      return;
    }

    setState(() => _isResolvingLocation = true);
    try {
      final result = await LocationAddressService.getCurrentAddress();
      if (!mounted) {
        return;
      }
      _addressController.text = result.address;
      if (result.city.trim().isNotEmpty) {
        _cityController.text = result.city;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        lexiFloatingSnackBar(
          context,
          content: Text(context.l10n.registerAddressAutoFilled),
        ),
      );
    } catch (e) {
      if (!mounted) {
        return;
      }
      final message = e is AppFailure
          ? e.message
          : context.l10n.registerAddressFetchFailed;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(lexiFloatingSnackBar(context, content: Text(message)));
    } finally {
      if (mounted) {
        setState(() => _isResolvingLocation = false);
      }
    }
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
