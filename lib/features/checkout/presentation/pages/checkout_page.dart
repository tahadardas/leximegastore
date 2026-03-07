import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../core/analytics/event_tracker.dart';
import '../../../../core/errors/app_failure.dart';
import '../../../../core/services/location_address_service.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../l10n/l10n.dart';
import '../../../../design_system/lexi_tokens.dart';
import '../../../../design_system/lexi_typography.dart';
import '../../../../ui/forms/focus_chain.dart';
import '../../../../shared/ui/lexi_alert.dart';
import '../../../../shared/widgets/lexi_network_image.dart';
import '../../../../shared/widgets/lexi_ui/lexi_app_bar.dart';
import '../../../../shared/widgets/lexi_ui/lexi_button.dart';
import '../../../../shared/widgets/lexi_ui/lexi_card.dart';
import '../../../auth/domain/entities/customer_user.dart';
import '../../../auth/presentation/controllers/customer_auth_controller.dart';
import '../../../cart/presentation/controllers/cart_controller.dart';
import '../../../payment/domain/entities/payment_method.dart';
import '../../../shipping/presentation/controllers/shipping_controller.dart';
import '../../../shipping/domain/entities/city.dart';
import '../controllers/checkout_controller.dart';
import '../../../orders/data/local/pending_shamcash_store.dart';

@immutable
class CheckoutDraft {
  final int step;
  final String firstName;
  final String lastName;
  final String phone;
  final String street;
  final String addressDetails;
  final String deliveryArea;
  final String deliveryBuilding;
  final String deliveryPostalCode;
  final String note;
  final bool usedGpsLocation;
  final double? deliveryLat;
  final double? deliveryLng;
  final double? deliveryAccuracy;
  final String deliveryGeoAddress;
  final String deliveryGeoCity;
  final String deliveryGeoStreet;
  final String deliveryGeoCountry;
  final String deliveryCapturedAtIso;

  const CheckoutDraft({
    this.step = 0,
    this.firstName = '',
    this.lastName = '',
    this.phone = '',
    this.street = '',
    this.addressDetails = '',
    this.deliveryArea = '',
    this.deliveryBuilding = '',
    this.deliveryPostalCode = '',
    this.note = '',
    this.usedGpsLocation = false,
    this.deliveryLat,
    this.deliveryLng,
    this.deliveryAccuracy,
    this.deliveryGeoAddress = '',
    this.deliveryGeoCity = '',
    this.deliveryGeoStreet = '',
    this.deliveryGeoCountry = '',
    this.deliveryCapturedAtIso = '',
  });

  bool get hasAnyData =>
      firstName.trim().isNotEmpty ||
      lastName.trim().isNotEmpty ||
      phone.trim().isNotEmpty ||
      street.trim().isNotEmpty ||
      addressDetails.trim().isNotEmpty ||
      deliveryArea.trim().isNotEmpty ||
      deliveryBuilding.trim().isNotEmpty ||
      deliveryPostalCode.trim().isNotEmpty ||
      deliveryBuilding.trim().isNotEmpty ||
      deliveryPostalCode.trim().isNotEmpty ||
      note.trim().isNotEmpty ||
      usedGpsLocation ||
      deliveryLat != null ||
      deliveryLng != null ||
      deliveryGeoAddress.trim().isNotEmpty ||
      deliveryGeoCity.trim().isNotEmpty ||
      deliveryGeoStreet.trim().isNotEmpty ||
      deliveryGeoCountry.trim().isNotEmpty ||
      deliveryCapturedAtIso.trim().isNotEmpty;

  CheckoutDraft copyWith({
    int? step,
    String? firstName,
    String? lastName,
    String? phone,
    String? street,
    String? addressDetails,
    String? deliveryArea,
    String? deliveryBuilding,
    String? deliveryPostalCode,
    String? note,
    bool? usedGpsLocation,
    double? deliveryLat,
    double? deliveryLng,
    double? deliveryAccuracy,
    String? deliveryGeoAddress,
    String? deliveryGeoCity,
    String? deliveryGeoStreet,
    String? deliveryGeoCountry,
    String? deliveryCapturedAtIso,
  }) {
    return CheckoutDraft(
      step: step ?? this.step,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      phone: phone ?? this.phone,
      street: street ?? this.street,
      addressDetails: addressDetails ?? this.addressDetails,
      deliveryArea: deliveryArea ?? this.deliveryArea,
      deliveryBuilding: deliveryBuilding ?? this.deliveryBuilding,
      deliveryPostalCode: deliveryPostalCode ?? this.deliveryPostalCode,
      note: note ?? this.note,
      usedGpsLocation: usedGpsLocation ?? this.usedGpsLocation,
      deliveryLat: deliveryLat ?? this.deliveryLat,
      deliveryLng: deliveryLng ?? this.deliveryLng,
      deliveryAccuracy: deliveryAccuracy ?? this.deliveryAccuracy,
      deliveryGeoAddress: deliveryGeoAddress ?? this.deliveryGeoAddress,
      deliveryGeoCity: deliveryGeoCity ?? this.deliveryGeoCity,
      deliveryGeoStreet: deliveryGeoStreet ?? this.deliveryGeoStreet,
      deliveryGeoCountry: deliveryGeoCountry ?? this.deliveryGeoCountry,
      deliveryCapturedAtIso:
          deliveryCapturedAtIso ?? this.deliveryCapturedAtIso,
    );
  }
}

final checkoutDraftProvider = StateProvider<CheckoutDraft>(
  (_) => const CheckoutDraft(),
);

class CheckoutPage extends ConsumerStatefulWidget {
  const CheckoutPage({super.key});

  @override
  ConsumerState<CheckoutPage> createState() => _CheckoutPageState();
}

class _CheckoutPageState extends ConsumerState<CheckoutPage> {
  final _formKey = GlobalKey<FormState>();
  late final StateController<CheckoutDraft> _draftController;
  final _firstName = TextEditingController();
  final _lastName = TextEditingController();
  final _phone = TextEditingController();
  final _street = TextEditingController();
  final _addressDetails = TextEditingController();
  final _deliveryArea = TextEditingController();
  final _deliveryBuilding = TextEditingController();
  final _deliveryPostalCode = TextEditingController();
  final _note = TextEditingController();
  final _firstNameFocus = FocusNode();
  final _lastNameFocus = FocusNode();
  final _phoneFocus = FocusNode();
  final _streetFocus = FocusNode();
  final _addressDetailsFocus = FocusNode();
  final _deliveryAreaFocus = FocusNode();
  final _deliveryBuildingFocus = FocusNode();
  final _deliveryPostalCodeFocus = FocusNode();
  final _noteFocus = FocusNode();
  late final FocusChain _focusChain;

  bool _didAutoFillFromAccount = false;
  bool _isResolvingDeliveryLocation = false;
  bool _usedGpsLocation = false;
  int _step = 0;
  double? _deliveryLat;
  double? _deliveryLng;
  double? _deliveryAccuracy;
  String _deliveryGeoAddress = '';
  String _deliveryGeoCity = '';
  String _deliveryGeoStreet = '';
  String _deliveryGeoCountry = '';
  DateTime? _deliveryCapturedAt;

  List<TextEditingController> get _controllers => [
    _firstName,
    _lastName,
    _phone,
    _street,
    _addressDetails,
    _deliveryArea,
    _deliveryBuilding,
    _deliveryPostalCode,
    _note,
  ];

  @override
  void initState() {
    super.initState();
    _draftController = ref.read(checkoutDraftProvider.notifier);
    _focusChain = FocusChain([
      _firstNameFocus,
      _lastNameFocus,
      _phoneFocus,
      _streetFocus,
      _addressDetailsFocus,
      _deliveryAreaFocus,
      _deliveryBuildingFocus,
      _deliveryPostalCodeFocus,
      _noteFocus,
    ]);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusChain.enableAutoScroll();
    });
    _restoreDraft();
    for (final controller in _controllers) {
      controller.addListener(_persistDraft);
    }
    unawaited(
      ref.read(eventTrackerProvider).track(eventType: 'checkout_start'),
    );
  }

  @override
  void dispose() {
    for (final controller in _controllers) {
      controller.removeListener(_persistDraft);
    }
    _persistDraft();
    _firstName.dispose();
    _lastName.dispose();
    _phone.dispose();
    _street.dispose();
    _addressDetails.dispose();
    _deliveryArea.dispose();
    _deliveryBuilding.dispose();
    _deliveryPostalCode.dispose();
    _note.dispose();
    _focusChain.dispose();
    super.dispose();
  }

  void _restoreDraft() {
    final draft = _draftController.state;
    if (!draft.hasAnyData && draft.step == 0) {
      return;
    }

    _step = draft.step.clamp(0, 3);
    _firstName.text = draft.firstName;
    _lastName.text = draft.lastName;
    _phone.text = draft.phone;
    _street.text = draft.street;
    _addressDetails.text = draft.addressDetails;
    _deliveryArea.text = draft.deliveryArea;
    _deliveryBuilding.text = draft.deliveryBuilding;
    _deliveryPostalCode.text = draft.deliveryPostalCode;
    _note.text = draft.note;
    _usedGpsLocation = draft.usedGpsLocation;
    _deliveryLat = draft.deliveryLat;
    _deliveryLng = draft.deliveryLng;
    _deliveryAccuracy = draft.deliveryAccuracy;
    _deliveryGeoAddress = draft.deliveryGeoAddress;
    _deliveryGeoCity = draft.deliveryGeoCity;
    _deliveryGeoStreet = draft.deliveryGeoStreet;
    _deliveryGeoCountry = draft.deliveryGeoCountry;
    _deliveryCapturedAt = draft.deliveryCapturedAtIso.trim().isEmpty
        ? null
        : DateTime.tryParse(draft.deliveryCapturedAtIso);
    _didAutoFillFromAccount = draft.hasAnyData;
  }

  void _persistDraft() {
    _draftController.state = CheckoutDraft(
      step: _step,
      firstName: _firstName.text,
      lastName: _lastName.text,
      phone: _phone.text,
      street: _street.text,
      addressDetails: _addressDetails.text,
      deliveryArea: _deliveryArea.text,
      deliveryBuilding: _deliveryBuilding.text,
      deliveryPostalCode: _deliveryPostalCode.text,
      note: _note.text,
      usedGpsLocation: _usedGpsLocation,
      deliveryLat: _deliveryLat,
      deliveryLng: _deliveryLng,
      deliveryAccuracy: _deliveryAccuracy,
      deliveryGeoAddress: _deliveryGeoAddress,
      deliveryGeoCity: _deliveryGeoCity,
      deliveryGeoStreet: _deliveryGeoStreet,
      deliveryGeoCountry: _deliveryGeoCountry,
      deliveryCapturedAtIso: _deliveryCapturedAt?.toIso8601String() ?? '',
    );
  }

  void _clearDraft() {
    _draftController.state = const CheckoutDraft();
  }

  void _setStep(int step) {
    setState(() => _step = step.clamp(0, 3));
    _persistDraft();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final checkoutState = ref.watch(checkoutControllerProvider);
    final checkoutController = ref.read(checkoutControllerProvider.notifier);
    final cartAsync = ref.watch(cartControllerProvider);
    final selectedCity = ref.watch(selectedCityProvider);
    final shippingCostAsync = ref.watch(shippingCostProvider);
    final accountUser = ref.watch(customerAuthControllerProvider).asData?.value;

    if (accountUser != null) {
      _applyAccountPrefill(accountUser);
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) {
          return;
        }
        await _handleCheckoutBack(context, checkoutState: checkoutState);
      },
      child: Scaffold(
        appBar: LexiAppBar(title: l10n.appCheckoutTitle),
        body: cartAsync.when(
          loading: () => const _CheckoutLoadingSkeleton(),
          error: (_, _) => _ErrorView(
            message: l10n.checkoutLoadCartFailed,
            onRetry: () => ref.invalidate(cartControllerProvider),
          ),
          data: (cart) {
            if (cart.isEmpty) {
              return _ErrorView(
                message: l10n.checkoutCartEmpty,
                actionLabel: l10n.checkoutGoToCart,
                onRetry: () => context.goNamedSafe(AppRouteNames.cart),
              );
            }

            final shippingCost = shippingCostAsync.valueOrNull ?? 0.0;
            final total = cart.subtotal + shippingCost;
            final bottomInset = MediaQuery.paddingOf(context).bottom;
            final keyboardInset = MediaQuery.viewInsetsOf(context).bottom;
            final bottomContentPadding =
                LexiSpacing.md +
                (keyboardInset > 0
                    ? keyboardInset
                    : (bottomInset + LexiSpacing.md));

            return SingleChildScrollView(
              padding: EdgeInsetsDirectional.fromSTEB(
                LexiSpacing.md,
                LexiSpacing.md,
                LexiSpacing.md,
                bottomContentPadding,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _CheckoutStepper(currentStep: _step),
                  const SizedBox(height: LexiSpacing.lg),
                  if (_step == 0) _CartReviewStep(),
                  if (_step == 1)
                    _CityStep(
                      selectedCityName: selectedCity?.name,
                      shippingCostText: selectedCity == null
                          ? '--'
                          : CurrencyFormatter.formatAmount(shippingCost),
                      isLoadingCost: shippingCostAsync.isLoading,
                    ),
                  if (_step == 2)
                    _CustomerInfoStep(formKey: _formKey, parent: this),
                  if (_step == 3)
                    _PaymentStep(
                      state: checkoutState,
                      subtotalText: CurrencyFormatter.formatAmount(
                        cart.subtotal,
                      ),
                      shippingText: selectedCity == null
                          ? '--'
                          : CurrencyFormatter.formatAmount(shippingCost),
                      totalText: CurrencyFormatter.formatAmount(total),
                    ),
                  const SizedBox(height: LexiSpacing.lg),
                  if (checkoutState.error != null &&
                      checkoutState.error!.trim().isNotEmpty)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(LexiSpacing.sm),
                      margin: const EdgeInsets.only(bottom: LexiSpacing.md),
                      decoration: BoxDecoration(
                        color: LexiColors.error.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(LexiRadius.sm),
                        border: Border.all(color: LexiColors.error),
                      ),
                      child: Text(
                        checkoutState.error!,
                        style: const TextStyle(color: LexiColors.error),
                      ),
                    ),
                  Row(
                    children: [
                      if (_step > 0)
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: checkoutState.isProcessing
                                ? null
                                : () => _setStep(_step - 1),
                            icon: const Icon(Icons.arrow_back),
                            label: Text(l10n.checkoutPrev),
                          ),
                        ),
                      if (_step > 0) const SizedBox(width: LexiSpacing.sm),
                      Expanded(
                        child: LexiButton(
                          label: _step == 3
                              ? l10n.checkoutConfirmOrder
                              : l10n.checkoutNext,
                          icon: _step == 3 ? Icons.check : Icons.arrow_forward,
                          isLoading: checkoutState.isProcessing,
                          onPressed: checkoutState.isProcessing
                              ? null
                              : () => _onNextStep(
                                  context,
                                  checkoutController,
                                  selectedCity?.id,
                                ),
                          isFullWidth: true,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Future<void> _handleCheckoutBack(
    BuildContext context, {
    required CheckoutState checkoutState,
  }) async {
    final hasUnsavedChanges = _hasUnsavedCheckoutData(
      checkoutState: checkoutState,
    );

    if (hasUnsavedChanges) {
      final shouldLeave = await _confirmLeaveCheckout(context);
      if (shouldLeave != true) {
        return;
      }
    }

    _persistDraft();
    if (!context.mounted) {
      return;
    }
    context.goNamedSafe(AppRouteNames.cart);
  }

  bool _hasUnsavedCheckoutData({required CheckoutState checkoutState}) {
    final currentDraft = CheckoutDraft(
      step: _step,
      firstName: _firstName.text,
      lastName: _lastName.text,
      phone: _phone.text,
      street: _street.text,
      addressDetails: _addressDetails.text,
      deliveryArea: _deliveryArea.text,
      deliveryBuilding: _deliveryBuilding.text,
      deliveryPostalCode: _deliveryPostalCode.text,
      note: _note.text,
      usedGpsLocation: _usedGpsLocation,
      deliveryLat: _deliveryLat,
      deliveryLng: _deliveryLng,
      deliveryAccuracy: _deliveryAccuracy,
      deliveryGeoAddress: _deliveryGeoAddress,
      deliveryGeoCity: _deliveryGeoCity,
      deliveryGeoStreet: _deliveryGeoStreet,
      deliveryGeoCountry: _deliveryGeoCountry,
      deliveryCapturedAtIso: _deliveryCapturedAt?.toIso8601String() ?? '',
    );

    return currentDraft.hasAnyData ||
        _step > 0 ||
        checkoutState.selectedPaymentMethod != PaymentMethod.cod;
  }

  Future<bool?> _confirmLeaveCheckout(BuildContext context) {
    return showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(context.l10n.checkoutLeaveTitle),
          content: Text(context.l10n.checkoutLeaveBody),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(context.l10n.commonCancel),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(context.l10n.checkoutLeaveAction),
            ),
          ],
        );
      },
    );
  }

  void _focusFirstInvalidField() {
    if (_firstName.text.trim().isEmpty) {
      _firstNameFocus.requestFocus();
      return;
    }
    if (_lastName.text.trim().isEmpty) {
      _lastNameFocus.requestFocus();
      return;
    }
    final phone = _phone.text.trim();
    if (phone.isEmpty || phone.length < 9) {
      _phoneFocus.requestFocus();
      return;
    }
    if (_street.text.trim().isEmpty) {
      _streetFocus.requestFocus();
      return;
    }
  }

  Future<void> _onNextStep(
    BuildContext context,
    CheckoutNotifier controller,
    String? cityId,
  ) async {
    if (_step == 0) {
      _setStep(1);
      return;
    }

    if (_step == 1) {
      if (cityId == null || cityId.trim().isEmpty) {
        await LexiAlert.error(context, text: 'اختر مدينة الشحن أولاً.');
        return;
      }
      _setStep(2);
      return;
    }

    if (_step == 2) {
      if (!_formKey.currentState!.validate()) {
        _focusFirstInvalidField();
        return;
      }
      _setStep(3);
      return;
    }

    final parsedCityId = int.tryParse(cityId ?? '');
    if (parsedCityId == null || parsedCityId <= 0) {
      await LexiAlert.error(context, text: 'معرّف مدينة الشحن غير صالح.');
      return;
    }

    await controller.placeOrder(
      billing: CheckoutBillingData(
        firstName: _firstName.text.trim(),
        lastName: _lastName.text.trim(),
        phone: _phone.text.trim(),
        address1: _mergeAddress(),
        cityName: ref.read(selectedCityProvider)?.name ?? '',
        note: _note.text.trim().isEmpty ? null : _note.text.trim(),
      ),
      deliveryLocation: _buildDeliveryLocationData(),
      shippingCityId: parsedCityId,
      onCodSuccess: (orderId) {
        _clearDraft();
        context.goNamedSafe(
          AppRouteNames.orderSuccess,
          pathParameters: {'id': orderId},
        );
      },
      onShamCash:
          ({
            required orderId,
            required total,
            required currency,
            required phone,
            required accountName,
            required qrValue,
            required barcodeValue,
            required instructionsAr,
            required uploadEndpoint,
          }) {
            _clearDraft();

            // Save to pending store
            ref
                .read(pendingShamCashStoreProvider)
                .save(
                  PendingShamCashOrder(
                    orderId: orderId,
                    amount: total,
                    currency: currency,
                    phone: phone,
                    accountName: accountName ?? '',
                    qrValue: qrValue ?? '',
                    barcodeValue: barcodeValue ?? '',
                    instructionsAr: instructionsAr ?? '',
                    uploadEndpoint: uploadEndpoint ?? '',
                    createdAt: DateTime.now().toIso8601String(),
                  ),
                );

            context.pushNamedIfNotCurrent(
              AppRouteNames.shamCashPayment,
              extra: {
                'orderId': orderId,
                'amount': total,
                'currency': currency,
                'phone': phone,
                'accountName': accountName,
                'qrValue': qrValue,
                'barcodeValue': barcodeValue,
                'instructionsAr': instructionsAr,
                'uploadEndpoint': uploadEndpoint,
              },
            );
          },
    );
  }

  CheckoutDeliveryLocationData _buildDeliveryLocationData() {
    final selectedCityName = ref.read(selectedCityProvider)?.name.trim();

    return CheckoutDeliveryLocationData(
      lat: _usedGpsLocation ? _deliveryLat : null,
      lng: _usedGpsLocation ? _deliveryLng : null,
      accuracyMeters: _usedGpsLocation ? _deliveryAccuracy : null,
      fullAddress: _mergeAddress(),
      city: _firstNonEmpty([_deliveryGeoCity, selectedCityName]),
      area: _valueOrNull(_deliveryArea.text),
      street: _valueOrNull(_street.text),
      building: _valueOrNull(_deliveryBuilding.text),
      postalCode: _valueOrNull(_deliveryPostalCode.text),
      notes: _valueOrNull(_note.text),
      capturedAt: _usedGpsLocation ? _deliveryCapturedAt : null,
    );
  }

  Future<void> _fillDeliveryFromCurrentLocation(BuildContext context) async {
    if (_isResolvingDeliveryLocation) {
      return;
    }

    setState(() => _isResolvingDeliveryLocation = true);

    try {
      final result = await LocationAddressService.getCurrentLocationDetails();
      if (!mounted) {
        return;
      }

      setState(() {
        _usedGpsLocation = true;
        _deliveryLat = result.latitude;
        _deliveryLng = result.longitude;
        _deliveryAccuracy = result.accuracyMeters;
        _deliveryGeoAddress = result.fullAddress;
        _deliveryGeoCity = result.city;
        _deliveryGeoStreet = result.street;
        _deliveryGeoCountry = result.country;
        _deliveryCapturedAt = result.capturedAt;

        if (result.street.trim().isNotEmpty) {
          _street.text = result.street.trim();
        } else if (_street.text.trim().isEmpty) {
          _street.text = result.fullAddress;
        }

        if (_addressDetails.text.trim().isEmpty &&
            result.area.trim().isNotEmpty) {
          _addressDetails.text = result.area.trim();
        }
        if (result.area.trim().isNotEmpty) {
          _deliveryArea.text = result.area.trim();
        }
        if (result.building.trim().isNotEmpty) {
          _deliveryBuilding.text = result.building.trim();
        }
        if (result.postalCode.trim().isNotEmpty) {
          _deliveryPostalCode.text = result.postalCode.trim();
        }
      });
      _persistDraft();

      if (!context.mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'تم تحديد موقع التوصيل. يمكنك تعديل حقول العنوان يدويًا.',
          ),
        ),
      );
    } on LocationAddressException catch (error) {
      if (!context.mounted) {
        return;
      }
      await _showLocationErrorDialog(context, error);
    } catch (error) {
      if (!context.mounted) {
        return;
      }
      final message = error is AppFailure
          ? error.message
          : 'تعذر تحديد موقعك الحالي. يرجى إدخال العنوان يدويًا.';
      await LexiAlert.error(context, text: message);
    } finally {
      if (mounted) {
        setState(() => _isResolvingDeliveryLocation = false);
      }
    }
  }

  Future<void> _showLocationErrorDialog(
    BuildContext context,
    LocationAddressException error,
  ) async {
    String title = 'الموقع غير متاح';
    String message = error.message;
    String? actionLabel;
    Future<void> Function()? onAction;

    if (error.errorCode == LocationAddressErrorCode.permissionDeniedForever) {
      title = 'صلاحية الموقع محظورة';
      message =
          'تم رفض صلاحية الموقع بشكل دائم. يمكنك المتابعة يدويًا أو فتح الإعدادات.';
      actionLabel = 'فتح الإعدادات';
      onAction = LocationAddressService.openAppSettings;
    } else if (error.errorCode ==
        LocationAddressErrorCode.locationServicesDisabled) {
      title = 'خدمات الموقع متوقفة';
      message =
          'يرجى تفعيل خدمات الموقع لاستخدام تحديد العنوان عبر GPS. ويمكنك إدخال العنوان يدويًا.';
      actionLabel = 'تفعيل GPS';
      onAction = LocationAddressService.openLocationSettings;
    } else if (error.errorCode == LocationAddressErrorCode.permissionDenied) {
      title = 'تم رفض صلاحية الموقع';
      message =
          'نستخدم موقعك لتسريع التوصيل. يمكنك منح الصلاحية أو متابعة إدخال العنوان يدويًا.';
      actionLabel = 'فتح الإعدادات';
      onAction = LocationAddressService.openAppSettings;
    }

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        final dialogActionLabel = actionLabel;
        final dialogAction = onAction;

        return AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('إغلاق'),
            ),
            if (dialogActionLabel != null && dialogAction != null)
              TextButton(
                onPressed: () async {
                  Navigator.of(dialogContext).pop();
                  await dialogAction();
                },
                child: Text(dialogActionLabel),
              ),
          ],
        );
      },
    );
  }

  String? _valueOrNull(String? raw) {
    final value = (raw ?? '').trim();
    if (value.isEmpty) {
      return null;
    }
    return value;
  }

  String? _firstNonEmpty(List<String?> values) {
    for (final item in values) {
      final normalized = (item ?? '').trim();
      if (normalized.isNotEmpty) {
        return normalized;
      }
    }
    return null;
  }

  String? _requiredValidator(String? value) {
    if ((value ?? '').trim().isEmpty) {
      return 'هذا الحقل مطلوب';
    }
    return null;
  }

  void _applyAccountPrefill(CustomerUser user) {
    if (_didAutoFillFromAccount) {
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _didAutoFillFromAccount) {
        return;
      }

      if (_firstName.text.trim().isEmpty && user.firstName.trim().isNotEmpty) {
        _firstName.text = user.firstName.trim();
      }
      if (_lastName.text.trim().isEmpty && user.lastName.trim().isNotEmpty) {
        _lastName.text = user.lastName.trim();
      }
      if (_phone.text.trim().isEmpty && user.phone.trim().isNotEmpty) {
        _phone.text = user.phone.trim();
      }
      if (_street.text.trim().isEmpty && user.address1.trim().isNotEmpty) {
        _street.text = user.address1.trim();
      }

      _didAutoFillFromAccount = true;
      setState(() {});
      _persistDraft();
    });
  }

  String _mergeAddress() {
    final street = _street.text.trim();
    final details = _addressDetails.text.trim();
    if (details.isEmpty) {
      return street;
    }
    return '$street - $details';
  }

  Future<void> _submitCustomerStepFromKeyboard(BuildContext context) async {
    await _onNextStep(
      context,
      ref.read(checkoutControllerProvider.notifier),
      ref.read(selectedCityProvider)?.id,
    );
  }
}

class _CheckoutStepper extends StatelessWidget {
  final int currentStep;

  const _CheckoutStepper({required this.currentStep});

  static const _steps = ['السلة', 'المدينة', 'البيانات', 'الدفع'];

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(_steps.length, (index) {
        final isActive = index == currentStep;
        final isDone = index < currentStep;
        return Expanded(
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: isDone || isActive
                      ? LexiColors.brandPrimary
                      : LexiColors.neutral200,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Text(
                  '${index + 1}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              if (index < _steps.length - 1)
                Expanded(
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 6),
                    height: 2,
                    color: isDone
                        ? LexiColors.brandPrimary
                        : LexiColors.neutral200,
                  ),
                ),
            ],
          ),
        );
      }),
    );
  }
}

class _CartReviewStep extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cart = ref.watch(cartControllerProvider).valueOrNull;
    if (cart == null) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('1) مراجعة السلة', style: LexiTypography.h3),
        const SizedBox(height: LexiSpacing.md),
        ...cart.items.map(
          (item) => Padding(
            padding: const EdgeInsets.only(bottom: LexiSpacing.sm),
            child: LexiCard(
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(LexiRadius.sm),
                    child: SizedBox(
                      width: 64,
                      height: 64,
                      child: item.image.isEmpty
                          ? const Icon(Icons.image_outlined)
                          : LexiNetworkImage(
                              imageUrl: item.image,
                              width: 64,
                              height: 64,
                              fit: BoxFit.cover,
                            ),
                    ),
                  ),
                  const SizedBox(width: LexiSpacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text('الكمية: ${item.qty}'),
                      ],
                    ),
                  ),
                  Text(CurrencyFormatter.formatAmount(item.lineTotal)),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: LexiSpacing.sm),
        Text(
          'المجموع الفرعي: ${CurrencyFormatter.formatAmount(cart.subtotal)}',
          style: LexiTypography.labelLg,
        ),
      ],
    );
  }
}

class _CityStep extends ConsumerWidget {
  final String? selectedCityName;
  final String shippingCostText;
  final bool isLoadingCost;

  const _CityStep({
    required this.selectedCityName,
    required this.shippingCostText,
    required this.isLoadingCost,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final citiesAsync = ref.watch(citiesProvider);
    final selectedCity = ref.watch(selectedCityProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('2) اختيار المدينة', style: LexiTypography.h3),
        const SizedBox(height: LexiSpacing.md),
        citiesAsync.when(
          loading: () => const LinearProgressIndicator(),
          error: (_, _) => _ErrorView(
            message: 'تعذر تحميل المدن.',
            actionLabel: 'إعادة المحاولة',
            onRetry: () => ref.refresh(citiesProvider),
          ),
          data: (cities) {
            if (cities.isEmpty) {
              return const Text('لا توجد مدن متاحة حالياً.');
            }
            return DropdownButtonFormField<City>(
              initialValue: selectedCity,
              decoration: const InputDecoration(
                labelText: 'مدينة الشحن',
                border: OutlineInputBorder(),
              ),
              items: cities
                  .map(
                    (city) => DropdownMenuItem<City>(
                      value: city,
                      child: Text(city.name),
                    ),
                  )
                  .toList(),
              onChanged: (City? value) {
                ref.read(selectedCityProvider.notifier).state = value;
              },
            );
          },
        ),
        const SizedBox(height: LexiSpacing.md),
        Row(
          children: [
            Text('تكلفة الشحن: ', style: LexiTypography.bodyMd),
            if (isLoadingCost)
              const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            else
              Text(
                selectedCityName == null ? '--' : shippingCostText,
                style: LexiTypography.labelLg.copyWith(
                  color: LexiColors.brandPrimary,
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _CustomerInfoStep extends StatelessWidget {
  final GlobalKey<FormState> formKey;
  final _CheckoutPageState parent;

  const _CustomerInfoStep({required this.formKey, required this.parent});

  @override
  Widget build(BuildContext context) {
    final hasGpsCoordinates =
        parent._usedGpsLocation &&
        parent._deliveryLat != null &&
        parent._deliveryLng != null;
    final resolvedAddress = parent._deliveryGeoAddress.trim().isNotEmpty
        ? parent._deliveryGeoAddress.trim()
        : parent._mergeAddress().trim();

    return Form(
      key: formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('3) بيانات المستلم', style: LexiTypography.h3),
          const SizedBox(height: LexiSpacing.md),
          LexiCard(
            color: LexiColors.neutral100,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('موقع التوصيل', style: LexiTypography.labelLg),
                const SizedBox(height: LexiSpacing.xs),
                Text(
                  'نستخدم موقعك لتسريع عملية التوصيل.',
                  style: LexiTypography.bodySm.copyWith(
                    color: LexiColors.neutral600,
                  ),
                ),
                const SizedBox(height: LexiSpacing.sm),
                OutlinedButton.icon(
                  onPressed: parent._isResolvingDeliveryLocation
                      ? null
                      : () => parent._fillDeliveryFromCurrentLocation(context),
                  icon: parent._isResolvingDeliveryLocation
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.my_location_outlined),
                  label: Text(context.l10n.registerUseCurrentLocation),
                ),
                if (resolvedAddress.isNotEmpty) ...[
                  const SizedBox(height: LexiSpacing.sm),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(LexiSpacing.sm),
                    decoration: BoxDecoration(
                      color: LexiColors.brandWhite,
                      borderRadius: BorderRadius.circular(LexiRadius.sm),
                      border: Border.all(color: LexiColors.neutral200),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(resolvedAddress, style: LexiTypography.bodyMd),
                        if (hasGpsCoordinates) ...[
                          const SizedBox(height: 4),
                          Text(
                            'إحداثيات GPS: ${parent._deliveryLat!.toStringAsFixed(6)}, ${parent._deliveryLng!.toStringAsFixed(6)}${parent._deliveryAccuracy == null ? '' : ' • ±${parent._deliveryAccuracy!.toStringAsFixed(0)}m'}',
                            style: LexiTypography.bodySm.copyWith(
                              color: LexiColors.neutral500,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: LexiSpacing.md),
          _InputField(
            controller: parent._firstName,
            label: 'الاسم الأول',
            focusNode: parent._firstNameFocus,
            textInputAction: TextInputAction.next,
            onFieldSubmitted: (_) =>
                parent._focusChain.focusNext(context, parent._firstNameFocus),
            autofillHints: const [AutofillHints.givenName],
            validator: parent._requiredValidator,
          ),
          const SizedBox(height: LexiSpacing.sm),
          _InputField(
            controller: parent._lastName,
            label: 'اسم العائلة',
            focusNode: parent._lastNameFocus,
            textInputAction: TextInputAction.next,
            onFieldSubmitted: (_) =>
                parent._focusChain.focusNext(context, parent._lastNameFocus),
            autofillHints: const [AutofillHints.familyName],
            validator: parent._requiredValidator,
          ),
          const SizedBox(height: LexiSpacing.sm),
          _InputField(
            controller: parent._phone,
            label: 'رقم الهاتف',
            focusNode: parent._phoneFocus,
            textInputAction: TextInputAction.next,
            onFieldSubmitted: (_) =>
                parent._focusChain.focusNext(context, parent._phoneFocus),
            autofillHints: const [AutofillHints.telephoneNumber],
            keyboardType: TextInputType.phone,
            validator: (value) {
              final text = (value ?? '').trim();
              if (text.isEmpty) {
                return 'رقم الهاتف مطلوب';
              }
              if (text.length < 9) {
                return 'أدخل رقم هاتف صحيح';
              }
              return null;
            },
          ),
          const SizedBox(height: LexiSpacing.sm),
          _InputField(
            controller: parent._street,
            label: 'الشارع',
            focusNode: parent._streetFocus,
            textInputAction: TextInputAction.next,
            onFieldSubmitted: (_) =>
                parent._focusChain.focusNext(context, parent._streetFocus),
            autofillHints: const [AutofillHints.streetAddressLine1],
            validator: parent._requiredValidator,
          ),
          const SizedBox(height: LexiSpacing.sm),
          _InputField(
            controller: parent._addressDetails,
            label: 'تفاصيل العنوان (اختياري)',
            focusNode: parent._addressDetailsFocus,
            textInputAction: TextInputAction.next,
            onFieldSubmitted: (_) => parent._focusChain.focusNext(
              context,
              parent._addressDetailsFocus,
            ),
            autofillHints: const [AutofillHints.fullStreetAddress],
            maxLines: 2,
          ),
          const SizedBox(height: LexiSpacing.sm),
          _InputField(
            controller: parent._deliveryArea,
            label: 'الحي / المنطقة (اختياري)',
            focusNode: parent._deliveryAreaFocus,
            textInputAction: TextInputAction.next,
            onFieldSubmitted: (_) => parent._focusChain.focusNext(
              context,
              parent._deliveryAreaFocus,
            ),
          ),
          const SizedBox(height: LexiSpacing.sm),
          _InputField(
            controller: parent._deliveryBuilding,
            label: 'المبنى / علامة مميزة (اختياري)',
            focusNode: parent._deliveryBuildingFocus,
            textInputAction: TextInputAction.next,
            onFieldSubmitted: (_) => parent._focusChain.focusNext(
              context,
              parent._deliveryBuildingFocus,
            ),
          ),
          const SizedBox(height: LexiSpacing.sm),
          _InputField(
            controller: parent._deliveryPostalCode,
            label: 'الرمز البريدي (اختياري)',
            focusNode: parent._deliveryPostalCodeFocus,
            textInputAction: TextInputAction.next,
            keyboardType: TextInputType.number,
            onFieldSubmitted: (_) => parent._focusChain.focusNext(
              context,
              parent._deliveryPostalCodeFocus,
            ),
          ),
          const SizedBox(height: LexiSpacing.sm),
          _InputField(
            controller: parent._note,
            label: 'ملاحظات التوصيل (اختياري)',
            focusNode: parent._noteFocus,
            textInputAction: TextInputAction.done,
            onFieldSubmitted: (_) => parent._focusChain.focusDone(
              context,
              () => parent._submitCustomerStepFromKeyboard(context),
            ),
            maxLines: 3,
          ),
        ],
      ),
    );
  }
}

class _PaymentStep extends ConsumerWidget {
  final CheckoutState state;
  final String subtotalText;
  final String shippingText;
  final String totalText;

  const _PaymentStep({
    required this.state,
    required this.subtotalText,
    required this.shippingText,
    required this.totalText,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(checkoutControllerProvider.notifier);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('4) طريقة الدفع', style: LexiTypography.h3),
        const SizedBox(height: LexiSpacing.md),
        _PaymentMethodCard(
          label: 'الدفع عند الاستلام',
          icon: Icons.money,
          isSelected: state.selectedPaymentMethod == PaymentMethod.cod,
          onTap: () => controller.setPaymentMethod(PaymentMethod.cod),
        ),
        const SizedBox(height: LexiSpacing.sm),
        _PaymentMethodCard(
          label: 'شام كاش',
          icon: Icons.qr_code,
          isSelected: state.selectedPaymentMethod == PaymentMethod.shamCash,
          onTap: () => controller.setPaymentMethod(PaymentMethod.shamCash),
        ),
        const SizedBox(height: LexiSpacing.lg),
        LexiCard(
          child: Column(
            children: [
              _SummaryRow(label: 'المجموع الفرعي', value: subtotalText),
              const SizedBox(height: LexiSpacing.sm),
              _SummaryRow(label: 'الشحن', value: shippingText),
              const Divider(height: 24),
              _SummaryRow(label: 'الإجمالي', value: totalText, isBold: true),
            ],
          ),
        ),
      ],
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isBold;

  const _SummaryRow({
    required this.label,
    required this.value,
    this.isBold = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: isBold ? LexiTypography.labelLg : LexiTypography.bodyMd,
        ),
        Text(
          value,
          style: (isBold ? LexiTypography.h3 : LexiTypography.labelMd).copyWith(
            color: LexiColors.brandPrimary,
          ),
        ),
      ],
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  final String actionLabel;

  const _ErrorView({
    required this.message,
    required this.onRetry,
    this.actionLabel = 'إعادة المحاولة',
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(LexiSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: LexiSpacing.md),
            OutlinedButton(onPressed: onRetry, child: Text(actionLabel)),
          ],
        ),
      ),
    );
  }
}

class _CheckoutLoadingSkeleton extends StatelessWidget {
  const _CheckoutLoadingSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(LexiSpacing.md),
      children: [
        ...List.generate(
          4,
          (_) => Container(
            margin: const EdgeInsets.only(bottom: LexiSpacing.sm),
            height: 88,
            decoration: BoxDecoration(
              color: LexiColors.neutral200,
              borderRadius: BorderRadius.circular(LexiRadius.card),
            ),
          ),
        ),
        Container(
          height: 140,
          decoration: BoxDecoration(
            color: LexiColors.neutral200,
            borderRadius: BorderRadius.circular(LexiRadius.card),
          ),
        ),
      ],
    );
  }
}

class _InputField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final TextInputType keyboardType;
  final int maxLines;
  final String? Function(String?)? validator;
  final FocusNode? focusNode;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onFieldSubmitted;
  final Iterable<String>? autofillHints;

  const _InputField({
    required this.controller,
    required this.label,
    this.keyboardType = TextInputType.text,
    this.maxLines = 1,
    this.validator,
    this.focusNode,
    this.textInputAction,
    this.onFieldSubmitted,
    this.autofillHints,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      focusNode: focusNode,
      keyboardType: keyboardType,
      maxLines: maxLines,
      textInputAction: textInputAction,
      onFieldSubmitted: onFieldSubmitted,
      autofillHints: autofillHints,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
    );
  }
}

class _PaymentMethodCard extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _PaymentMethodCard({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return LexiCard(
      padding: EdgeInsets.zero,
      color: isSelected
          ? LexiColors.brandPrimary.withValues(alpha: 0.05)
          : LexiColors.brandWhite,
      boxShadow: isSelected ? LexiShadows.md : LexiShadows.sm,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(LexiRadius.lg),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(LexiRadius.lg),
            border: Border.all(
              color: isSelected
                  ? LexiColors.brandPrimary
                  : LexiColors.neutral200,
              width: isSelected ? 2 : 1,
            ),
          ),
          padding: const EdgeInsets.all(LexiSpacing.md),
          child: Row(
            children: [
              Icon(
                isSelected
                    ? Icons.radio_button_checked
                    : Icons.radio_button_off,
                color: isSelected
                    ? LexiColors.brandPrimary
                    : LexiColors.neutral400,
              ),
              const SizedBox(width: LexiSpacing.md),
              Text(
                label,
                style: isSelected
                    ? LexiTypography.labelLg
                    : LexiTypography.bodyMd,
              ),
              const Spacer(),
              Icon(icon, color: LexiColors.neutral500),
            ],
          ),
        ),
      ),
    );
  }
}
