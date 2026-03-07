import 'package:freezed_annotation/freezed_annotation.dart';

part 'shamcash_order.freezed.dart';
part 'shamcash_order.g.dart';

/// ShamCash order proof information
@freezed
class ShamCashProof with _$ShamCashProof {
  const factory ShamCashProof({
    @JsonKey(name: 'has_proof') required bool hasProof,
    @JsonKey(name: 'image_url') String? imageUrl,
    @JsonKey(name: 'uploaded_at') String? uploadedAt,
    String? note,
  }) = _ShamCashProof;

  factory ShamCashProof.fromJson(Map<String, dynamic> json) =>
      _$ShamCashProofFromJson(json);
}

/// ShamCash order awaiting verification
@freezed
class ShamCashOrder with _$ShamCashOrder {
  const factory ShamCashOrder({
    required int id,
    @JsonKey(name: 'order_number') required String orderNumber,
    required String status,
    @JsonKey(name: 'status_label_ar') required String statusLabelAr,
    required double total,
    @Default('SYP') String currency,
    @JsonKey(name: 'customer_name') required String customerName,
    @JsonKey(name: 'customer_phone') required String customerPhone,
    @JsonKey(name: 'date_created') required String dateCreated,
    ShamCashProof? proof,
  }) = _ShamCashOrder;

  factory ShamCashOrder.fromJson(Map<String, dynamic> json) =>
      _$ShamCashOrderFromJson(json);
}

/// Response for pending ShamCash orders list
@freezed
class ShamCashOrdersResponse with _$ShamCashOrdersResponse {
  const factory ShamCashOrdersResponse({
    required List<ShamCashOrder> orders,
    required int total,
    required int page,
    @JsonKey(name: 'per_page') required int perPage,
    @JsonKey(name: 'total_pages') required int totalPages,
  }) = _ShamCashOrdersResponse;

  factory ShamCashOrdersResponse.fromJson(Map<String, dynamic> json) =>
      _$ShamCashOrdersResponseFromJson(json);
}

/// Result of ShamCash verification (approve/reject)
@freezed
class ShamCashVerificationResult with _$ShamCashVerificationResult {
  const factory ShamCashVerificationResult({
    required int id,
    required String status,
    @JsonKey(name: 'status_label_ar') required String statusLabelAr,
    required String message,
  }) = _ShamCashVerificationResult;

  factory ShamCashVerificationResult.fromJson(Map<String, dynamic> json) =>
      _$ShamCashVerificationResultFromJson(json);
}
