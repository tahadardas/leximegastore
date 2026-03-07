// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'shamcash_order.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$ShamCashProofImpl _$$ShamCashProofImplFromJson(Map<String, dynamic> json) =>
    _$ShamCashProofImpl(
      hasProof: json['has_proof'] as bool,
      imageUrl: json['image_url'] as String?,
      uploadedAt: json['uploaded_at'] as String?,
      note: json['note'] as String?,
    );

Map<String, dynamic> _$$ShamCashProofImplToJson(_$ShamCashProofImpl instance) =>
    <String, dynamic>{
      'has_proof': instance.hasProof,
      'image_url': instance.imageUrl,
      'uploaded_at': instance.uploadedAt,
      'note': instance.note,
    };

_$ShamCashOrderImpl _$$ShamCashOrderImplFromJson(Map<String, dynamic> json) =>
    _$ShamCashOrderImpl(
      id: (json['id'] as num).toInt(),
      orderNumber: json['order_number'] as String,
      status: json['status'] as String,
      statusLabelAr: json['status_label_ar'] as String,
      total: (json['total'] as num).toDouble(),
      currency: json['currency'] as String? ?? 'SYP',
      customerName: json['customer_name'] as String,
      customerPhone: json['customer_phone'] as String,
      dateCreated: json['date_created'] as String,
      proof: json['proof'] == null
          ? null
          : ShamCashProof.fromJson(json['proof'] as Map<String, dynamic>),
    );

Map<String, dynamic> _$$ShamCashOrderImplToJson(_$ShamCashOrderImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'order_number': instance.orderNumber,
      'status': instance.status,
      'status_label_ar': instance.statusLabelAr,
      'total': instance.total,
      'currency': instance.currency,
      'customer_name': instance.customerName,
      'customer_phone': instance.customerPhone,
      'date_created': instance.dateCreated,
      'proof': instance.proof,
    };

_$ShamCashOrdersResponseImpl _$$ShamCashOrdersResponseImplFromJson(
  Map<String, dynamic> json,
) => _$ShamCashOrdersResponseImpl(
  orders: (json['orders'] as List<dynamic>)
      .map((e) => ShamCashOrder.fromJson(e as Map<String, dynamic>))
      .toList(),
  total: (json['total'] as num).toInt(),
  page: (json['page'] as num).toInt(),
  perPage: (json['per_page'] as num).toInt(),
  totalPages: (json['total_pages'] as num).toInt(),
);

Map<String, dynamic> _$$ShamCashOrdersResponseImplToJson(
  _$ShamCashOrdersResponseImpl instance,
) => <String, dynamic>{
  'orders': instance.orders,
  'total': instance.total,
  'page': instance.page,
  'per_page': instance.perPage,
  'total_pages': instance.totalPages,
};

_$ShamCashVerificationResultImpl _$$ShamCashVerificationResultImplFromJson(
  Map<String, dynamic> json,
) => _$ShamCashVerificationResultImpl(
  id: (json['id'] as num).toInt(),
  status: json['status'] as String,
  statusLabelAr: json['status_label_ar'] as String,
  message: json['message'] as String,
);

Map<String, dynamic> _$$ShamCashVerificationResultImplToJson(
  _$ShamCashVerificationResultImpl instance,
) => <String, dynamic>{
  'id': instance.id,
  'status': instance.status,
  'status_label_ar': instance.statusLabelAr,
  'message': instance.message,
};
