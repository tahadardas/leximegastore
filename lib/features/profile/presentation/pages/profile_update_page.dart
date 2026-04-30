import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/errors/app_exception.dart';
import '../../../../core/errors/app_failure.dart';
import '../../../../core/services/location_address_service.dart';
import '../../../../core/services/location_permission_rationale.dart';
import '../../../../core/session/app_session.dart';
import '../../../../design_system/lexi_tokens.dart';
import '../../../../design_system/lexi_typography.dart';
import '../../../../ui/widgets/lexi_safe_bottom.dart';
import '../../../../ui/forms/focus_chain.dart';
import '../../../../shared/widgets/lexi_network_image.dart';
import '../../../../shared/widgets/lexi_ui/lexi_app_bar.dart';
import '../../../../shared/widgets/lexi_ui/lexi_button.dart';
import '../../../../shared/widgets/lexi_ui/lexi_card.dart';
import '../../../../shared/widgets/lexi_ui/lexi_input.dart';
import '../../../../shared/ui/lexi_alert.dart';
import '../../../auth/presentation/controllers/customer_auth_controller.dart';

class ProfileUpdatePage extends ConsumerStatefulWidget {
  const ProfileUpdatePage({super.key});

  @override
  ConsumerState<ProfileUpdatePage> createState() => _ProfileUpdatePageState();
}

class _ProfileUpdatePageState extends ConsumerState<ProfileUpdatePage> {
  final _formKey = GlobalKey<FormState>();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _displayNameController = TextEditingController();
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _cityController = TextEditingController();
  final _displayNameFocus = FocusNode();
  final _firstNameFocus = FocusNode();
  final _lastNameFocus = FocusNode();
  final _emailFocus = FocusNode();
  final _phoneFocus = FocusNode();
  final _addressFocus = FocusNode();
  final _cityFocus = FocusNode();
  late final FocusChain _focusChain;

  bool _isSaving = false;
  bool _isResolvingLocation = false;
  bool _isUploadingAvatar = false;
  String _avatarUrl = '';

  @override
  void initState() {
    super.initState();
    _focusChain = FocusChain([
      _displayNameFocus,
      _firstNameFocus,
      _lastNameFocus,
      _emailFocus,
      _phoneFocus,
      _addressFocus,
      _cityFocus,
    ]);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusChain.enableAutoScroll();
      _populateInitialData();
    });
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _displayNameController.dispose();
    _usernameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _cityController.dispose();
    _focusChain.dispose();
    super.dispose();
  }

  Future<void> _populateInitialData() async {
    final session = ref.read(appSessionProvider);
    final customer = ref.read(customerAuthControllerProvider).asData?.value;

    if (!mounted) {
      return;
    }

    final displayName = session.displayName?.trim() ?? '';
    final parts = displayName.split(' ').where((e) => e.trim().isNotEmpty);
    final firstFromDisplay = parts.isNotEmpty ? parts.first : '';
    final lastFromDisplay = parts.length > 1 ? parts.skip(1).join(' ') : '';

    _firstNameController.text = customer?.firstName.trim().isNotEmpty == true
        ? customer!.firstName.trim()
        : firstFromDisplay;
    _lastNameController.text = customer?.lastName.trim().isNotEmpty == true
        ? customer!.lastName.trim()
        : lastFromDisplay;
    _displayNameController.text =
        customer?.displayName.trim().isNotEmpty == true
        ? customer!.displayName.trim()
        : displayName;
    _usernameController.text = customer?.username ?? '';
    _emailController.text = customer?.email ?? session.email ?? '';
    _phoneController.text = (customer?.phone ?? session.phone ?? '').trim();
    _addressController.text = (customer?.address1 ?? session.address1 ?? '')
        .trim();
    _cityController.text = (customer?.city ?? session.city ?? '').trim();
    _avatarUrl = customer?.avatarUrl ?? '';
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: LexiColors.neutral100,
      appBar: const LexiAppBar(title: 'تحديث البيانات'),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(LexiSpacing.md),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: LexiCard(
              padding: const EdgeInsets.all(LexiSpacing.lg),
              child: AutofillGroup(
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('بيانات الحساب', style: LexiTypography.h3),
                      const SizedBox(height: LexiSpacing.md),
                      Center(
                        child: Column(
                          children: [
                            SizedBox(
                              width: 88,
                              height: 88,
                              child: Stack(
                                children: [
                                  Positioned.fill(
                                    child: ClipOval(
                                      child: _avatarUrl.trim().isEmpty
                                          ? Image.asset(
                                              'assets/images/logo_square.jpg',
                                              fit: BoxFit.cover,
                                            )
                                          : LexiNetworkImage(
                                              imageUrl: _avatarUrl,
                                              fit: BoxFit.cover,
                                            ),
                                    ),
                                  ),
                                  Positioned(
                                    right: 0,
                                    bottom: 0,
                                    child: Material(
                                      color: LexiColors.brandPrimary,
                                      shape: const CircleBorder(),
                                      child: IconButton(
                                        onPressed: _isUploadingAvatar
                                            ? null
                                            : _pickAndUploadAvatar,
                                        icon: _isUploadingAvatar
                                            ? const SizedBox(
                                                width: 14,
                                                height: 14,
                                                child:
                                                    CircularProgressIndicator(
                                                      strokeWidth: 2,
                                                      color:
                                                          LexiColors.brandBlack,
                                                    ),
                                              )
                                            : const Icon(
                                                Icons.camera_alt_outlined,
                                                size: 16,
                                              ),
                                        splashRadius: 18,
                                        constraints:
                                            const BoxConstraints.tightFor(
                                              width: 34,
                                              height: 34,
                                            ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'تغيير الصورة الشخصية',
                              style: LexiTypography.bodySm,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: LexiSpacing.md),
                      LexiInput(
                        controller: _displayNameController,
                        label: 'الاسم المعروض',
                        focusNode: _displayNameFocus,
                        textInputAction: TextInputAction.next,
                        onFieldSubmitted: (_) =>
                            _focusChain.focusNext(context, _displayNameFocus),
                        autofillHints: const [AutofillHints.name],
                        validator: _requiredValidator,
                      ),
                      const SizedBox(height: LexiSpacing.sm),
                      LexiInput(
                        controller: _usernameController,
                        label: 'اسم المستخدم',
                        readOnly: true,
                      ),
                      const SizedBox(height: LexiSpacing.sm),
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
                              validator: _requiredValidator,
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
                              validator: _requiredValidator,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: LexiSpacing.sm),
                      LexiInput(
                        controller: _emailController,
                        label: 'البريد الإلكتروني',
                        focusNode: _emailFocus,
                        textInputAction: TextInputAction.next,
                        onFieldSubmitted: (_) =>
                            _focusChain.focusNext(context, _emailFocus),
                        autofillHints: const [AutofillHints.email],
                        keyboardType: TextInputType.emailAddress,
                        validator: _emailValidator,
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
                        validator: _phoneValidator,
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
                        validator: _requiredValidator,
                      ),
                      const SizedBox(height: LexiSpacing.sm),
                      LexiInput(
                        controller: _cityController,
                        label: 'المدينة',
                        focusNode: _cityFocus,
                        textInputAction: TextInputAction.done,
                        onFieldSubmitted: (_) =>
                            _focusChain.focusDone(context, _submit),
                        autofillHints: const [AutofillHints.addressCity],
                        validator: _requiredValidator,
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
                        label: const Text('استخدام موقعي الحالي'),
                      ),
                      const SizedBox(height: LexiSpacing.lg),
                      LexiButton(
                        label: 'حفظ التغييرات',
                        icon: Icons.save_outlined,
                        isLoading: _isSaving,
                        isFullWidth: true,
                        onPressed: _submit,
                      ),
                      const SizedBox(height: LexiSpacing.sm),
                      Center(
                        child: TextButton(
                          onPressed: _isSaving ? null : () => context.pop(),
                          child: const Text('إلغاء'),
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
          content: const Text('تم تعبئة العنوان من موقعك الحالي.'),
        ),
      );
    } catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        lexiFloatingSnackBar(context, content: Text(_friendlyError(e))),
      );
    } finally {
      if (mounted) {
        setState(() => _isResolvingLocation = false);
      }
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isSaving = true);
    try {
      final updatedUser = await ref
          .read(customerAuthControllerProvider.notifier)
          .updateProfile(
            firstName: _firstNameController.text.trim(),
            lastName: _lastNameController.text.trim(),
            displayName: _displayNameController.text.trim(),
            email: _emailController.text.trim(),
            phone: _phoneController.text.trim(),
            address1: _addressController.text.trim(),
            city: _cityController.text.trim(),
          );
      final session = ref.read(appSessionProvider);
      final token = (session.token ?? updatedUser.token).trim();

      if (token.isNotEmpty) {
        await session.saveSession(
          token: token,
          role: _resolveRole(session.role, updatedUser.roles),
          displayName: updatedUser.displayName,
          email: updatedUser.email,
          phone: updatedUser.phone,
          address1: updatedUser.address1,
          city: updatedUser.city,
        );
      }

      await session.refreshUserData();

      if (!mounted) {
        return;
      }
      await LexiAlert.success(context, text: 'تم حفظ التغييرات بنجاح.');
      if (!mounted) {
        return;
      }
      context.pop();
    } catch (e) {
      if (!mounted) {
        return;
      }
      await LexiAlert.error(context, text: _friendlyError(e));
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Future<void> _pickAndUploadAvatar() async {
    setState(() => _isUploadingAvatar = true);
    try {
      final picker = ImagePicker();
      final file = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
        maxWidth: 1200,
      );
      if (file == null) {
        return;
      }

      final user = await ref
          .read(customerAuthControllerProvider.notifier)
          .uploadAvatar(file.path);
      await ref.read(appSessionProvider).refreshUserData();
      if (!mounted) {
        return;
      }
      setState(() => _avatarUrl = user.avatarUrl);
      ScaffoldMessenger.of(context).showSnackBar(
        lexiFloatingSnackBar(
          context,
          content: const Text('تم تحديث الصورة الشخصية.'),
        ),
      );
    } catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        lexiFloatingSnackBar(context, content: Text(_friendlyError(e))),
      );
    } finally {
      if (mounted) {
        setState(() => _isUploadingAvatar = false);
      }
    }
  }

  String? _requiredValidator(String? value) {
    if ((value ?? '').trim().isEmpty) {
      return 'هذا الحقل مطلوب';
    }
    return null;
  }

  String? _emailValidator(String? value) {
    final email = (value ?? '').trim();
    if (email.isEmpty) {
      return 'البريد الإلكتروني مطلوب';
    }
    if (!email.contains('@') || !email.contains('.')) {
      return 'البريد الإلكتروني غير صحيح';
    }
    return null;
  }

  String? _phoneValidator(String? value) {
    final phone = (value ?? '').trim();
    if (phone.isEmpty) {
      return 'رقم الهاتف مطلوب';
    }
    if (phone.length < 9) {
      return 'رقم الهاتف غير صحيح';
    }
    return null;
  }

  String _friendlyError(Object error) {
    if (error is AppException) {
      return error.message;
    }
    if (error is AppFailure) {
      return error.message;
    }
    return 'تعذر تحديث البيانات. حاول مرة أخرى.';
  }

  String _resolveRole(String? currentRole, List<String> roles) {
    final fromSession = (currentRole ?? '').trim();
    if (fromSession.isNotEmpty) {
      return fromSession;
    }

    if (roles.contains('administrator')) {
      return 'administrator';
    }
    if (roles.contains('shop_manager')) {
      return 'shop_manager';
    }
    if (roles.contains('delivery_agent')) {
      return 'delivery_agent';
    }
    return 'customer';
  }
}
