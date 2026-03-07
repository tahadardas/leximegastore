import 'package:freezed_annotation/freezed_annotation.dart';

part 'admin_order.freezed.dart';
part 'admin_order.g.dart';

@freezed
class AdminOrder with _$AdminOrder {
  const factory AdminOrder({
    required int id,
    @JsonKey(name: 'order_number') required String orderNumber,
    required String status,
    required double total,
    required double subtotal,
    @JsonKey(name: 'shipping_cost') required double shippingCost,
    @JsonKey(name: 'payment_method') required String paymentMethod,
    required String? date,
    required AdminOrderBilling billing,
    @JsonKey(name: 'customer_note') String? customerNote,
    @Default([]) List<AdminOrderItem> items,
    @JsonKey(name: 'delivery_location')
    AdminOrderDeliveryLocation? deliveryLocation,
    @JsonKey(name: 'payment_proof') AdminOrderPaymentProof? paymentProof,
  }) = _AdminOrder;

  factory AdminOrder.fromJson(Map<String, dynamic> json) =>
      _$AdminOrderFromJson(json);
}

@freezed
class AdminOrderPaymentProof with _$AdminOrderPaymentProof {
  const factory AdminOrderPaymentProof({
    @JsonKey(name: 'image_url') required String imageUrl,
    @JsonKey(name: 'attachment_id') required int attachmentId,
    @JsonKey(name: 'uploaded_at') required String uploadedAt,
  }) = _AdminOrderPaymentProof;

  factory AdminOrderPaymentProof.fromJson(Map<String, dynamic> json) =>
      _$AdminOrderPaymentProofFromJson(json);
}

@freezed
class AdminOrderDeliveryLocation with _$AdminOrderDeliveryLocation {
  const factory AdminOrderDeliveryLocation({
    double? lat,
    double? lng,
    @JsonKey(name: 'accuracy_meters') double? accuracyMeters,
    @JsonKey(name: 'full_address') @Default('') String fullAddress,
    @Default('') String city,
    @Default('') String area,
    @Default('') String street,
    @Default('') String building,
    @Default('') String notes,
    @JsonKey(name: 'captured_at') @Default('') String capturedAt,
    @JsonKey(name: 'maps_open_url') @Default('') String mapsOpenUrl,
    @JsonKey(name: 'maps_navigate_url') @Default('') String mapsNavigateUrl,
  }) = _AdminOrderDeliveryLocation;

  factory AdminOrderDeliveryLocation.fromJson(Map<String, dynamic> json) =>
      _$AdminOrderDeliveryLocationFromJson(json);
}

@freezed
class AdminOrderBilling with _$AdminOrderBilling {
  const factory AdminOrderBilling({
    @JsonKey(name: 'first_name') required String firstName,
    @JsonKey(name: 'last_name') required String lastName,
    required String phone,
    required String email,
    @JsonKey(name: 'address_1') required String address1,
    required String city,
  }) = _AdminOrderBilling;

  factory AdminOrderBilling.fromJson(Map<String, dynamic> json) =>
      _$AdminOrderBillingFromJson(json);
}

@freezed
class AdminOrderItem with _$AdminOrderItem {
  const factory AdminOrderItem({
    @JsonKey(name: 'product_id') required int productId,
    required String name,
    @Default('') String sku,
    required int qty,
    @Default(0) double price,
    @Default(0) double subtotal,
    required double total,
    @Default('') String image,
    @JsonKey(name: 'variation_label') String? variationLabel,
  }) = _AdminOrderItem;

  factory AdminOrderItem.fromJson(Map<String, dynamic> json) {
    if (json['variation_label'] == null) {
      final metaData = json['meta_data'];
      if (metaData is List) {
        for (final meta in metaData) {
          if (meta is Map) {
            final key = meta['key']?.toString().toLowerCase() ?? '';
            if (key.contains('color') ||
                key.contains('اللون') ||
                key.startsWith('pa_')) {
              json['variation_label'] = meta['value'];
              break;
            }
          }
        }
      }
    }
    return _$AdminOrderItemFromJson(json);
  }
}

@freezed
class AdminOrdersResponse with _$AdminOrdersResponse {
  const factory AdminOrdersResponse({
    @Default([]) List<AdminOrder> items,
    required int page,
    @JsonKey(name: 'per_page') required int perPage,
    required int total,
    @JsonKey(name: 'total_pages') required int totalPages,
  }) = _AdminOrdersResponse;

  factory AdminOrdersResponse.fromJson(Map<String, dynamic> json) =>
      _$AdminOrdersResponseFromJson(json);
}
