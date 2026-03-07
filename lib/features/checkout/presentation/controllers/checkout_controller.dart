import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../config/constants/endpoints.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../core/notifications/device_token_store.dart';
import '../../../../core/ai/ai_tracker.dart';
import '../../../../core/locks/submit_locks.dart';
import '../../../../core/utils/safe_parsers.dart';
import '../../../../core/utils/text_normalizer.dart';
import '../../../../features/cart/presentation/controllers/cart_controller.dart';
import '../../../../features/orders/data/realtime/orders_realtime_service.dart';
import '../../../../features/payment/domain/entities/payment_method.dart';

class CheckoutBillingData {
  final String firstName;
  final String lastName;
  final String phone;
  final String address1;
  final String cityName;
  final String? email;
  final String? note;

  const CheckoutBillingData({
    required this.firstName,
    required this.lastName,
    required this.phone,
    required this.address1,
    required this.cityName,
    this.email,
    this.note,
  });
}

class CheckoutDeliveryLocationData {
  final double? lat;
  final double? lng;
  final double? accuracyMeters;
  final String fullAddress;
  final String? city;
  final String? area;
  final String? street;
  final String? building;
  final String? postalCode;
  final String? notes;
  final DateTime? capturedAt;

  const CheckoutDeliveryLocationData({
    required this.fullAddress,
    this.lat,
    this.lng,
    this.accuracyMeters,
    this.city,
    this.area,
    this.street,
    this.building,
    this.postalCode,
    this.notes,
    this.capturedAt,
  });

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      if (lat != null) 'lat': lat,
      if (lng != null) 'lng': lng,
      if (accuracyMeters != null) 'accuracy_meters': accuracyMeters,
      'full_address': fullAddress,
      if (_hasText(city)) 'city': city!.trim(),
      if (_hasText(area)) 'area': area!.trim(),
      if (_hasText(street)) 'street': street!.trim(),
      if (_hasText(building)) 'building': building!.trim(),
      if (_hasText(postalCode)) 'postal_code': postalCode!.trim(),
      if (_hasText(notes)) 'notes': notes!.trim(),
      if (capturedAt != null)
        'captured_at': capturedAt!.toUtc().toIso8601String(),
    };
  }

  bool _hasText(String? value) => (value ?? '').trim().isNotEmpty;
}

class CheckoutState {
  final PaymentMethod selectedPaymentMethod;
  final bool isProcessing;
  final String? error;

  const CheckoutState({
    this.selectedPaymentMethod = PaymentMethod.cod,
    this.isProcessing = false,
    this.error,
  });

  CheckoutState copyWith({
    PaymentMethod? selectedPaymentMethod,
    bool? isProcessing,
    String? error,
  }) {
    return CheckoutState(
      selectedPaymentMethod:
          selectedPaymentMethod ?? this.selectedPaymentMethod,
      isProcessing: isProcessing ?? this.isProcessing,
      error: error,
    );
  }
}

class CheckoutNotifier extends StateNotifier<CheckoutState> {
  final Ref ref;

  CheckoutNotifier(this.ref) : super(const CheckoutState());

  void setPaymentMethod(PaymentMethod method) {
    state = state.copyWith(selectedPaymentMethod: method);
  }

  Future<void> placeOrder({
    required CheckoutBillingData billing,
    CheckoutDeliveryLocationData? deliveryLocation,
    required int shippingCityId,
    required void Function(String orderId) onCodSuccess,
    required void Function({
      required String orderId,
      required double total,
      required String currency,
      required String phone,
      required String? accountName,
      required String? qrValue,
      required String? barcodeValue,
      required String? instructionsAr,
      required String? uploadEndpoint,
    })
    onShamCash,
  }) async {
    await ref.read(submitLocksProvider).runCheckoutSubmit<void>(() async {
      state = state.copyWith(isProcessing: true, error: null);

      try {
        final cart = ref.read(cartControllerProvider).valueOrNull;
        if (cart == null || cart.items.isEmpty) {
          throw const FormatException('السلة فارغة.');
        }

        final client = ref.read(dioClientProvider);
        final paymentMethod =
            state.selectedPaymentMethod == PaymentMethod.shamCash
            ? 'sham_cash'
            : 'cod';
        final deviceToken = await ref.read(deviceTokenStoreProvider).getToken();
        final customerName = '${billing.firstName} ${billing.lastName}'.trim();
        final fallbackDelivery = CheckoutDeliveryLocationData(
          fullAddress: billing.address1.trim(),
          city: billing.cityName.trim(),
          street: billing.address1.trim(),
          notes: billing.note?.trim(),
        );
        final payloadDeliveryLocation = deliveryLocation ?? fallbackDelivery;

        final payload = <String, dynamic>{
          'customer': {
            'name': customerName,
            'phone': billing.phone.trim(),
            'email': billing.email?.trim() ?? '',
          },
          'address': {
            'city_id': shippingCityId,
            'street': billing.address1.trim(),
            'notes': billing.note?.trim() ?? '',
          },
          'delivery_location': payloadDeliveryLocation.toJson(),
          'items': cart.items
              .map(
                (e) => {
                  'product_id': e.productId,
                  'variation_id': e.variationId ?? 0,
                  'qty': e.qty,
                },
              )
              .toList(),
          'payment_method': paymentMethod,
          if (deviceToken != null && deviceToken.isNotEmpty)
            'device_token': deviceToken,
          if (cart.appliedCoupon != null) 'coupon': cart.appliedCoupon!.code,
        };

        debugPrint('[Checkout] create-order request prepared');

        final response = await client.post(
          Endpoints.checkoutCreateOrder(),
          data: payload,
          // Allow AuthInterceptor to attach token if user is logged in
        );

        final data = extractMap(response.data);
        final nextAction = extractMap(data['next_action']);

        final orderId = (data['order_id'] ?? '').toString().trim();
        final total = parseDouble(data['total']);
        final currency = (data['currency'] ?? 'SYP').toString();
        final actionType = (nextAction['type'] ?? 'done')
            .toString()
            .trim()
            .toLowerCase();

        if (orderId.isEmpty) {
          throw const FormatException('لم يتم إنشاء الطلب.');
        }

        // Track Purchase
        ref
            .read(aiTrackerProvider)
            .purchase(int.tryParse(orderId) ?? 0, total: total);

        await ref.read(cartControllerProvider.notifier).clearCart();
        await ref.read(ordersRealtimeServiceProvider).notifyOrderMutation();

        state = state.copyWith(isProcessing: false, error: null);

        if (actionType == 'done' ||
            actionType == 'cod' ||
            actionType == 'none') {
          onCodSuccess(orderId);
          return;
        }

        if (actionType == 'upload_proof' || actionType.contains('sham')) {
          onShamCash(
            orderId: orderId,
            total: total,
            currency: currency,
            phone: billing.phone.trim(),
            accountName: nextAction['account_name']?.toString(),
            qrValue: nextAction['qr_value']?.toString(),
            barcodeValue: nextAction['barcode_value']?.toString(),
            instructionsAr: nextAction['instructions_ar']?.toString(),
            uploadEndpoint:
                nextAction['upload_url']?.toString() ??
                nextAction['upload_endpoint']?.toString(),
          );
          return;
        }

        onCodSuccess(orderId);
      } on DioException catch (e) {
        state = state.copyWith(
          isProcessing: false,
          error: _friendlyDioError(e),
        );
      } on FormatException catch (e) {
        state = state.copyWith(isProcessing: false, error: e.message);
      } catch (_) {
        state = state.copyWith(
          isProcessing: false,
          error: 'تعذر إتمام عملية الطلب. حاول مرة أخرى.',
        );
      }
    });
  }

  String _friendlyDioError(DioException e) {
    final payload = extractMap(e.response?.data);
    final errorMap = extractMap(payload['error']);

    final code = e.response?.statusCode ?? 0;
    final fallback = _fallbackForStatus(code);
    final apiMessage = (errorMap['message'] ?? payload['message'] ?? '')
        .toString()
        .trim();
    final safeApiMessage = _safeUserMessage(apiMessage);
    if (safeApiMessage != null) {
      return safeApiMessage;
    }

    return fallback;
  }

  String _fallbackForStatus(int code) {
    if (code >= 500) {
      return 'حدث خطأ في الخادم. حاول مرة أخرى.';
    }
    if (code == 422) {
      return 'البيانات المدخلة غير صحيحة أو ناقصة.';
    }
    if (code == 401 || code == 403) {
      return 'يرجى تسجيل الدخول مجددًا.';
    }
    return 'تعذر إتمام عملية الطلب. حاول مرة أخرى.';
  }

  String? _safeUserMessage(String message) {
    final text = TextNormalizer.normalize(message).trim();
    if (text.isEmpty) {
      return null;
    }

    final lower = text.toLowerCase();
    const blockedTokens = <String>[
      'http://',
      'https://',
      'wp-json',
      'rest_route',
      'dioexception',
      'socketexception',
      'xmlhttprequest',
      '<html',
      '</html',
      'stacktrace',
    ];

    final hasTechnicalToken = blockedTokens.any(lower.contains);
    if (hasTechnicalToken) {
      return null;
    }

    // Ignore mojibake payloads caused by wrong server encoding.
    final looksBrokenEncoding = RegExp(
      r'[\u00D8\u00D9\u00C2\u00C3][A-Za-z0-9]',
    ).hasMatch(text);
    if (looksBrokenEncoding) {
      return null;
    }

    return text;
  }
}

final checkoutControllerProvider =
    StateNotifierProvider<CheckoutNotifier, CheckoutState>((ref) {
      return CheckoutNotifier(ref);
    });
