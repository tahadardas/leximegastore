// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'admin_order.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$AdminOrderImpl _$$AdminOrderImplFromJson(Map<String, dynamic> json) =>
    _$AdminOrderImpl(
      id: (json['id'] as num).toInt(),
      orderNumber: json['order_number'] as String,
      status: json['status'] as String,
      total: (json['total'] as num).toDouble(),
      subtotal: (json['subtotal'] as num).toDouble(),
      shippingCost: (json['shipping_cost'] as num).toDouble(),
      paymentMethod: json['payment_method'] as String,
      date: json['date'] as String?,
      billing: AdminOrderBilling.fromJson(
        json['billing'] as Map<String, dynamic>,
      ),
      customerNote: json['customer_note'] as String?,
      items:
          (json['items'] as List<dynamic>?)
              ?.map((e) => AdminOrderItem.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      deliveryLocation: json['delivery_location'] == null
          ? null
          : AdminOrderDeliveryLocation.fromJson(
              json['delivery_location'] as Map<String, dynamic>,
            ),
      paymentProof: json['payment_proof'] == null
          ? null
          : AdminOrderPaymentProof.fromJson(
              json['payment_proof'] as Map<String, dynamic>,
            ),
    );

Map<String, dynamic> _$$AdminOrderImplToJson(_$AdminOrderImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'order_number': instance.orderNumber,
      'status': instance.status,
      'total': instance.total,
      'subtotal': instance.subtotal,
      'shipping_cost': instance.shippingCost,
      'payment_method': instance.paymentMethod,
      'date': instance.date,
      'billing': instance.billing,
      'customer_note': instance.customerNote,
      'items': instance.items,
      'delivery_location': instance.deliveryLocation,
      'payment_proof': instance.paymentProof,
    };

_$AdminOrderPaymentProofImpl _$$AdminOrderPaymentProofImplFromJson(
  Map<String, dynamic> json,
) => _$AdminOrderPaymentProofImpl(
  imageUrl: json['image_url'] as String,
  attachmentId: (json['attachment_id'] as num).toInt(),
  uploadedAt: json['uploaded_at'] as String,
);

Map<String, dynamic> _$$AdminOrderPaymentProofImplToJson(
  _$AdminOrderPaymentProofImpl instance,
) => <String, dynamic>{
  'image_url': instance.imageUrl,
  'attachment_id': instance.attachmentId,
  'uploaded_at': instance.uploadedAt,
};

_$AdminOrderDeliveryLocationImpl _$$AdminOrderDeliveryLocationImplFromJson(
  Map<String, dynamic> json,
) => _$AdminOrderDeliveryLocationImpl(
  lat: (json['lat'] as num?)?.toDouble(),
  lng: (json['lng'] as num?)?.toDouble(),
  accuracyMeters: (json['accuracy_meters'] as num?)?.toDouble(),
  fullAddress: json['full_address'] as String? ?? '',
  city: json['city'] as String? ?? '',
  area: json['area'] as String? ?? '',
  street: json['street'] as String? ?? '',
  building: json['building'] as String? ?? '',
  notes: json['notes'] as String? ?? '',
  capturedAt: json['captured_at'] as String? ?? '',
  mapsOpenUrl: json['maps_open_url'] as String? ?? '',
  mapsNavigateUrl: json['maps_navigate_url'] as String? ?? '',
);

Map<String, dynamic> _$$AdminOrderDeliveryLocationImplToJson(
  _$AdminOrderDeliveryLocationImpl instance,
) => <String, dynamic>{
  'lat': instance.lat,
  'lng': instance.lng,
  'accuracy_meters': instance.accuracyMeters,
  'full_address': instance.fullAddress,
  'city': instance.city,
  'area': instance.area,
  'street': instance.street,
  'building': instance.building,
  'notes': instance.notes,
  'captured_at': instance.capturedAt,
  'maps_open_url': instance.mapsOpenUrl,
  'maps_navigate_url': instance.mapsNavigateUrl,
};

_$AdminOrderBillingImpl _$$AdminOrderBillingImplFromJson(
  Map<String, dynamic> json,
) => _$AdminOrderBillingImpl(
  firstName: json['first_name'] as String,
  lastName: json['last_name'] as String,
  phone: json['phone'] as String,
  email: json['email'] as String,
  address1: json['address_1'] as String,
  city: json['city'] as String,
);

Map<String, dynamic> _$$AdminOrderBillingImplToJson(
  _$AdminOrderBillingImpl instance,
) => <String, dynamic>{
  'first_name': instance.firstName,
  'last_name': instance.lastName,
  'phone': instance.phone,
  'email': instance.email,
  'address_1': instance.address1,
  'city': instance.city,
};

_$AdminOrderItemImpl _$$AdminOrderItemImplFromJson(Map<String, dynamic> json) =>
    _$AdminOrderItemImpl(
      productId: (json['product_id'] as num).toInt(),
      name: json['name'] as String,
      sku: json['sku'] as String? ?? '',
      qty: (json['qty'] as num).toInt(),
      price: (json['price'] as num?)?.toDouble() ?? 0,
      subtotal: (json['subtotal'] as num?)?.toDouble() ?? 0,
      total: (json['total'] as num).toDouble(),
      image: json['image'] as String? ?? '',
      variationLabel: json['variation_label'] as String?,
    );

Map<String, dynamic> _$$AdminOrderItemImplToJson(
  _$AdminOrderItemImpl instance,
) => <String, dynamic>{
  'product_id': instance.productId,
  'name': instance.name,
  'sku': instance.sku,
  'qty': instance.qty,
  'price': instance.price,
  'subtotal': instance.subtotal,
  'total': instance.total,
  'image': instance.image,
  'variation_label': instance.variationLabel,
};

_$AdminOrdersResponseImpl _$$AdminOrdersResponseImplFromJson(
  Map<String, dynamic> json,
) => _$AdminOrdersResponseImpl(
  items:
      (json['items'] as List<dynamic>?)
          ?.map((e) => AdminOrder.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const [],
  page: (json['page'] as num).toInt(),
  perPage: (json['per_page'] as num).toInt(),
  total: (json['total'] as num).toInt(),
  totalPages: (json['total_pages'] as num).toInt(),
);

Map<String, dynamic> _$$AdminOrdersResponseImplToJson(
  _$AdminOrdersResponseImpl instance,
) => <String, dynamic>{
  'items': instance.items,
  'page': instance.page,
  'per_page': instance.perPage,
  'total': instance.total,
  'total_pages': instance.totalPages,
};
