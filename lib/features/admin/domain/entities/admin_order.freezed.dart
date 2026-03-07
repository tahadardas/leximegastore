// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'admin_order.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

AdminOrder _$AdminOrderFromJson(Map<String, dynamic> json) {
  return _AdminOrder.fromJson(json);
}

/// @nodoc
mixin _$AdminOrder {
  int get id => throw _privateConstructorUsedError;
  @JsonKey(name: 'order_number')
  String get orderNumber => throw _privateConstructorUsedError;
  String get status => throw _privateConstructorUsedError;
  double get total => throw _privateConstructorUsedError;
  double get subtotal => throw _privateConstructorUsedError;
  @JsonKey(name: 'shipping_cost')
  double get shippingCost => throw _privateConstructorUsedError;
  @JsonKey(name: 'payment_method')
  String get paymentMethod => throw _privateConstructorUsedError;
  String? get date => throw _privateConstructorUsedError;
  AdminOrderBilling get billing => throw _privateConstructorUsedError;
  @JsonKey(name: 'customer_note')
  String? get customerNote => throw _privateConstructorUsedError;
  List<AdminOrderItem> get items => throw _privateConstructorUsedError;
  @JsonKey(name: 'delivery_location')
  AdminOrderDeliveryLocation? get deliveryLocation =>
      throw _privateConstructorUsedError;
  @JsonKey(name: 'payment_proof')
  AdminOrderPaymentProof? get paymentProof =>
      throw _privateConstructorUsedError;

  /// Serializes this AdminOrder to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of AdminOrder
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $AdminOrderCopyWith<AdminOrder> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $AdminOrderCopyWith<$Res> {
  factory $AdminOrderCopyWith(
    AdminOrder value,
    $Res Function(AdminOrder) then,
  ) = _$AdminOrderCopyWithImpl<$Res, AdminOrder>;
  @useResult
  $Res call({
    int id,
    @JsonKey(name: 'order_number') String orderNumber,
    String status,
    double total,
    double subtotal,
    @JsonKey(name: 'shipping_cost') double shippingCost,
    @JsonKey(name: 'payment_method') String paymentMethod,
    String? date,
    AdminOrderBilling billing,
    @JsonKey(name: 'customer_note') String? customerNote,
    List<AdminOrderItem> items,
    @JsonKey(name: 'delivery_location')
    AdminOrderDeliveryLocation? deliveryLocation,
    @JsonKey(name: 'payment_proof') AdminOrderPaymentProof? paymentProof,
  });

  $AdminOrderBillingCopyWith<$Res> get billing;
  $AdminOrderDeliveryLocationCopyWith<$Res>? get deliveryLocation;
  $AdminOrderPaymentProofCopyWith<$Res>? get paymentProof;
}

/// @nodoc
class _$AdminOrderCopyWithImpl<$Res, $Val extends AdminOrder>
    implements $AdminOrderCopyWith<$Res> {
  _$AdminOrderCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of AdminOrder
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? orderNumber = null,
    Object? status = null,
    Object? total = null,
    Object? subtotal = null,
    Object? shippingCost = null,
    Object? paymentMethod = null,
    Object? date = freezed,
    Object? billing = null,
    Object? customerNote = freezed,
    Object? items = null,
    Object? deliveryLocation = freezed,
    Object? paymentProof = freezed,
  }) {
    return _then(
      _value.copyWith(
            id: null == id
                ? _value.id
                : id // ignore: cast_nullable_to_non_nullable
                      as int,
            orderNumber: null == orderNumber
                ? _value.orderNumber
                : orderNumber // ignore: cast_nullable_to_non_nullable
                      as String,
            status: null == status
                ? _value.status
                : status // ignore: cast_nullable_to_non_nullable
                      as String,
            total: null == total
                ? _value.total
                : total // ignore: cast_nullable_to_non_nullable
                      as double,
            subtotal: null == subtotal
                ? _value.subtotal
                : subtotal // ignore: cast_nullable_to_non_nullable
                      as double,
            shippingCost: null == shippingCost
                ? _value.shippingCost
                : shippingCost // ignore: cast_nullable_to_non_nullable
                      as double,
            paymentMethod: null == paymentMethod
                ? _value.paymentMethod
                : paymentMethod // ignore: cast_nullable_to_non_nullable
                      as String,
            date: freezed == date
                ? _value.date
                : date // ignore: cast_nullable_to_non_nullable
                      as String?,
            billing: null == billing
                ? _value.billing
                : billing // ignore: cast_nullable_to_non_nullable
                      as AdminOrderBilling,
            customerNote: freezed == customerNote
                ? _value.customerNote
                : customerNote // ignore: cast_nullable_to_non_nullable
                      as String?,
            items: null == items
                ? _value.items
                : items // ignore: cast_nullable_to_non_nullable
                      as List<AdminOrderItem>,
            deliveryLocation: freezed == deliveryLocation
                ? _value.deliveryLocation
                : deliveryLocation // ignore: cast_nullable_to_non_nullable
                      as AdminOrderDeliveryLocation?,
            paymentProof: freezed == paymentProof
                ? _value.paymentProof
                : paymentProof // ignore: cast_nullable_to_non_nullable
                      as AdminOrderPaymentProof?,
          )
          as $Val,
    );
  }

  /// Create a copy of AdminOrder
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $AdminOrderBillingCopyWith<$Res> get billing {
    return $AdminOrderBillingCopyWith<$Res>(_value.billing, (value) {
      return _then(_value.copyWith(billing: value) as $Val);
    });
  }

  /// Create a copy of AdminOrder
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $AdminOrderDeliveryLocationCopyWith<$Res>? get deliveryLocation {
    if (_value.deliveryLocation == null) {
      return null;
    }

    return $AdminOrderDeliveryLocationCopyWith<$Res>(_value.deliveryLocation!, (
      value,
    ) {
      return _then(_value.copyWith(deliveryLocation: value) as $Val);
    });
  }

  /// Create a copy of AdminOrder
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $AdminOrderPaymentProofCopyWith<$Res>? get paymentProof {
    if (_value.paymentProof == null) {
      return null;
    }

    return $AdminOrderPaymentProofCopyWith<$Res>(_value.paymentProof!, (value) {
      return _then(_value.copyWith(paymentProof: value) as $Val);
    });
  }
}

/// @nodoc
abstract class _$$AdminOrderImplCopyWith<$Res>
    implements $AdminOrderCopyWith<$Res> {
  factory _$$AdminOrderImplCopyWith(
    _$AdminOrderImpl value,
    $Res Function(_$AdminOrderImpl) then,
  ) = __$$AdminOrderImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    int id,
    @JsonKey(name: 'order_number') String orderNumber,
    String status,
    double total,
    double subtotal,
    @JsonKey(name: 'shipping_cost') double shippingCost,
    @JsonKey(name: 'payment_method') String paymentMethod,
    String? date,
    AdminOrderBilling billing,
    @JsonKey(name: 'customer_note') String? customerNote,
    List<AdminOrderItem> items,
    @JsonKey(name: 'delivery_location')
    AdminOrderDeliveryLocation? deliveryLocation,
    @JsonKey(name: 'payment_proof') AdminOrderPaymentProof? paymentProof,
  });

  @override
  $AdminOrderBillingCopyWith<$Res> get billing;
  @override
  $AdminOrderDeliveryLocationCopyWith<$Res>? get deliveryLocation;
  @override
  $AdminOrderPaymentProofCopyWith<$Res>? get paymentProof;
}

/// @nodoc
class __$$AdminOrderImplCopyWithImpl<$Res>
    extends _$AdminOrderCopyWithImpl<$Res, _$AdminOrderImpl>
    implements _$$AdminOrderImplCopyWith<$Res> {
  __$$AdminOrderImplCopyWithImpl(
    _$AdminOrderImpl _value,
    $Res Function(_$AdminOrderImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of AdminOrder
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? orderNumber = null,
    Object? status = null,
    Object? total = null,
    Object? subtotal = null,
    Object? shippingCost = null,
    Object? paymentMethod = null,
    Object? date = freezed,
    Object? billing = null,
    Object? customerNote = freezed,
    Object? items = null,
    Object? deliveryLocation = freezed,
    Object? paymentProof = freezed,
  }) {
    return _then(
      _$AdminOrderImpl(
        id: null == id
            ? _value.id
            : id // ignore: cast_nullable_to_non_nullable
                  as int,
        orderNumber: null == orderNumber
            ? _value.orderNumber
            : orderNumber // ignore: cast_nullable_to_non_nullable
                  as String,
        status: null == status
            ? _value.status
            : status // ignore: cast_nullable_to_non_nullable
                  as String,
        total: null == total
            ? _value.total
            : total // ignore: cast_nullable_to_non_nullable
                  as double,
        subtotal: null == subtotal
            ? _value.subtotal
            : subtotal // ignore: cast_nullable_to_non_nullable
                  as double,
        shippingCost: null == shippingCost
            ? _value.shippingCost
            : shippingCost // ignore: cast_nullable_to_non_nullable
                  as double,
        paymentMethod: null == paymentMethod
            ? _value.paymentMethod
            : paymentMethod // ignore: cast_nullable_to_non_nullable
                  as String,
        date: freezed == date
            ? _value.date
            : date // ignore: cast_nullable_to_non_nullable
                  as String?,
        billing: null == billing
            ? _value.billing
            : billing // ignore: cast_nullable_to_non_nullable
                  as AdminOrderBilling,
        customerNote: freezed == customerNote
            ? _value.customerNote
            : customerNote // ignore: cast_nullable_to_non_nullable
                  as String?,
        items: null == items
            ? _value._items
            : items // ignore: cast_nullable_to_non_nullable
                  as List<AdminOrderItem>,
        deliveryLocation: freezed == deliveryLocation
            ? _value.deliveryLocation
            : deliveryLocation // ignore: cast_nullable_to_non_nullable
                  as AdminOrderDeliveryLocation?,
        paymentProof: freezed == paymentProof
            ? _value.paymentProof
            : paymentProof // ignore: cast_nullable_to_non_nullable
                  as AdminOrderPaymentProof?,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$AdminOrderImpl implements _AdminOrder {
  const _$AdminOrderImpl({
    required this.id,
    @JsonKey(name: 'order_number') required this.orderNumber,
    required this.status,
    required this.total,
    required this.subtotal,
    @JsonKey(name: 'shipping_cost') required this.shippingCost,
    @JsonKey(name: 'payment_method') required this.paymentMethod,
    required this.date,
    required this.billing,
    @JsonKey(name: 'customer_note') this.customerNote,
    final List<AdminOrderItem> items = const [],
    @JsonKey(name: 'delivery_location') this.deliveryLocation,
    @JsonKey(name: 'payment_proof') this.paymentProof,
  }) : _items = items;

  factory _$AdminOrderImpl.fromJson(Map<String, dynamic> json) =>
      _$$AdminOrderImplFromJson(json);

  @override
  final int id;
  @override
  @JsonKey(name: 'order_number')
  final String orderNumber;
  @override
  final String status;
  @override
  final double total;
  @override
  final double subtotal;
  @override
  @JsonKey(name: 'shipping_cost')
  final double shippingCost;
  @override
  @JsonKey(name: 'payment_method')
  final String paymentMethod;
  @override
  final String? date;
  @override
  final AdminOrderBilling billing;
  @override
  @JsonKey(name: 'customer_note')
  final String? customerNote;
  final List<AdminOrderItem> _items;
  @override
  @JsonKey()
  List<AdminOrderItem> get items {
    if (_items is EqualUnmodifiableListView) return _items;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_items);
  }

  @override
  @JsonKey(name: 'delivery_location')
  final AdminOrderDeliveryLocation? deliveryLocation;
  @override
  @JsonKey(name: 'payment_proof')
  final AdminOrderPaymentProof? paymentProof;

  @override
  String toString() {
    return 'AdminOrder(id: $id, orderNumber: $orderNumber, status: $status, total: $total, subtotal: $subtotal, shippingCost: $shippingCost, paymentMethod: $paymentMethod, date: $date, billing: $billing, customerNote: $customerNote, items: $items, deliveryLocation: $deliveryLocation, paymentProof: $paymentProof)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$AdminOrderImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.orderNumber, orderNumber) ||
                other.orderNumber == orderNumber) &&
            (identical(other.status, status) || other.status == status) &&
            (identical(other.total, total) || other.total == total) &&
            (identical(other.subtotal, subtotal) ||
                other.subtotal == subtotal) &&
            (identical(other.shippingCost, shippingCost) ||
                other.shippingCost == shippingCost) &&
            (identical(other.paymentMethod, paymentMethod) ||
                other.paymentMethod == paymentMethod) &&
            (identical(other.date, date) || other.date == date) &&
            (identical(other.billing, billing) || other.billing == billing) &&
            (identical(other.customerNote, customerNote) ||
                other.customerNote == customerNote) &&
            const DeepCollectionEquality().equals(other._items, _items) &&
            (identical(other.deliveryLocation, deliveryLocation) ||
                other.deliveryLocation == deliveryLocation) &&
            (identical(other.paymentProof, paymentProof) ||
                other.paymentProof == paymentProof));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    id,
    orderNumber,
    status,
    total,
    subtotal,
    shippingCost,
    paymentMethod,
    date,
    billing,
    customerNote,
    const DeepCollectionEquality().hash(_items),
    deliveryLocation,
    paymentProof,
  );

  /// Create a copy of AdminOrder
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$AdminOrderImplCopyWith<_$AdminOrderImpl> get copyWith =>
      __$$AdminOrderImplCopyWithImpl<_$AdminOrderImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$AdminOrderImplToJson(this);
  }
}

abstract class _AdminOrder implements AdminOrder {
  const factory _AdminOrder({
    required final int id,
    @JsonKey(name: 'order_number') required final String orderNumber,
    required final String status,
    required final double total,
    required final double subtotal,
    @JsonKey(name: 'shipping_cost') required final double shippingCost,
    @JsonKey(name: 'payment_method') required final String paymentMethod,
    required final String? date,
    required final AdminOrderBilling billing,
    @JsonKey(name: 'customer_note') final String? customerNote,
    final List<AdminOrderItem> items,
    @JsonKey(name: 'delivery_location')
    final AdminOrderDeliveryLocation? deliveryLocation,
    @JsonKey(name: 'payment_proof') final AdminOrderPaymentProof? paymentProof,
  }) = _$AdminOrderImpl;

  factory _AdminOrder.fromJson(Map<String, dynamic> json) =
      _$AdminOrderImpl.fromJson;

  @override
  int get id;
  @override
  @JsonKey(name: 'order_number')
  String get orderNumber;
  @override
  String get status;
  @override
  double get total;
  @override
  double get subtotal;
  @override
  @JsonKey(name: 'shipping_cost')
  double get shippingCost;
  @override
  @JsonKey(name: 'payment_method')
  String get paymentMethod;
  @override
  String? get date;
  @override
  AdminOrderBilling get billing;
  @override
  @JsonKey(name: 'customer_note')
  String? get customerNote;
  @override
  List<AdminOrderItem> get items;
  @override
  @JsonKey(name: 'delivery_location')
  AdminOrderDeliveryLocation? get deliveryLocation;
  @override
  @JsonKey(name: 'payment_proof')
  AdminOrderPaymentProof? get paymentProof;

  /// Create a copy of AdminOrder
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$AdminOrderImplCopyWith<_$AdminOrderImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

AdminOrderPaymentProof _$AdminOrderPaymentProofFromJson(
  Map<String, dynamic> json,
) {
  return _AdminOrderPaymentProof.fromJson(json);
}

/// @nodoc
mixin _$AdminOrderPaymentProof {
  @JsonKey(name: 'image_url')
  String get imageUrl => throw _privateConstructorUsedError;
  @JsonKey(name: 'attachment_id')
  int get attachmentId => throw _privateConstructorUsedError;
  @JsonKey(name: 'uploaded_at')
  String get uploadedAt => throw _privateConstructorUsedError;

  /// Serializes this AdminOrderPaymentProof to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of AdminOrderPaymentProof
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $AdminOrderPaymentProofCopyWith<AdminOrderPaymentProof> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $AdminOrderPaymentProofCopyWith<$Res> {
  factory $AdminOrderPaymentProofCopyWith(
    AdminOrderPaymentProof value,
    $Res Function(AdminOrderPaymentProof) then,
  ) = _$AdminOrderPaymentProofCopyWithImpl<$Res, AdminOrderPaymentProof>;
  @useResult
  $Res call({
    @JsonKey(name: 'image_url') String imageUrl,
    @JsonKey(name: 'attachment_id') int attachmentId,
    @JsonKey(name: 'uploaded_at') String uploadedAt,
  });
}

/// @nodoc
class _$AdminOrderPaymentProofCopyWithImpl<
  $Res,
  $Val extends AdminOrderPaymentProof
>
    implements $AdminOrderPaymentProofCopyWith<$Res> {
  _$AdminOrderPaymentProofCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of AdminOrderPaymentProof
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? imageUrl = null,
    Object? attachmentId = null,
    Object? uploadedAt = null,
  }) {
    return _then(
      _value.copyWith(
            imageUrl: null == imageUrl
                ? _value.imageUrl
                : imageUrl // ignore: cast_nullable_to_non_nullable
                      as String,
            attachmentId: null == attachmentId
                ? _value.attachmentId
                : attachmentId // ignore: cast_nullable_to_non_nullable
                      as int,
            uploadedAt: null == uploadedAt
                ? _value.uploadedAt
                : uploadedAt // ignore: cast_nullable_to_non_nullable
                      as String,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$AdminOrderPaymentProofImplCopyWith<$Res>
    implements $AdminOrderPaymentProofCopyWith<$Res> {
  factory _$$AdminOrderPaymentProofImplCopyWith(
    _$AdminOrderPaymentProofImpl value,
    $Res Function(_$AdminOrderPaymentProofImpl) then,
  ) = __$$AdminOrderPaymentProofImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    @JsonKey(name: 'image_url') String imageUrl,
    @JsonKey(name: 'attachment_id') int attachmentId,
    @JsonKey(name: 'uploaded_at') String uploadedAt,
  });
}

/// @nodoc
class __$$AdminOrderPaymentProofImplCopyWithImpl<$Res>
    extends
        _$AdminOrderPaymentProofCopyWithImpl<$Res, _$AdminOrderPaymentProofImpl>
    implements _$$AdminOrderPaymentProofImplCopyWith<$Res> {
  __$$AdminOrderPaymentProofImplCopyWithImpl(
    _$AdminOrderPaymentProofImpl _value,
    $Res Function(_$AdminOrderPaymentProofImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of AdminOrderPaymentProof
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? imageUrl = null,
    Object? attachmentId = null,
    Object? uploadedAt = null,
  }) {
    return _then(
      _$AdminOrderPaymentProofImpl(
        imageUrl: null == imageUrl
            ? _value.imageUrl
            : imageUrl // ignore: cast_nullable_to_non_nullable
                  as String,
        attachmentId: null == attachmentId
            ? _value.attachmentId
            : attachmentId // ignore: cast_nullable_to_non_nullable
                  as int,
        uploadedAt: null == uploadedAt
            ? _value.uploadedAt
            : uploadedAt // ignore: cast_nullable_to_non_nullable
                  as String,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$AdminOrderPaymentProofImpl implements _AdminOrderPaymentProof {
  const _$AdminOrderPaymentProofImpl({
    @JsonKey(name: 'image_url') required this.imageUrl,
    @JsonKey(name: 'attachment_id') required this.attachmentId,
    @JsonKey(name: 'uploaded_at') required this.uploadedAt,
  });

  factory _$AdminOrderPaymentProofImpl.fromJson(Map<String, dynamic> json) =>
      _$$AdminOrderPaymentProofImplFromJson(json);

  @override
  @JsonKey(name: 'image_url')
  final String imageUrl;
  @override
  @JsonKey(name: 'attachment_id')
  final int attachmentId;
  @override
  @JsonKey(name: 'uploaded_at')
  final String uploadedAt;

  @override
  String toString() {
    return 'AdminOrderPaymentProof(imageUrl: $imageUrl, attachmentId: $attachmentId, uploadedAt: $uploadedAt)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$AdminOrderPaymentProofImpl &&
            (identical(other.imageUrl, imageUrl) ||
                other.imageUrl == imageUrl) &&
            (identical(other.attachmentId, attachmentId) ||
                other.attachmentId == attachmentId) &&
            (identical(other.uploadedAt, uploadedAt) ||
                other.uploadedAt == uploadedAt));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode =>
      Object.hash(runtimeType, imageUrl, attachmentId, uploadedAt);

  /// Create a copy of AdminOrderPaymentProof
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$AdminOrderPaymentProofImplCopyWith<_$AdminOrderPaymentProofImpl>
  get copyWith =>
      __$$AdminOrderPaymentProofImplCopyWithImpl<_$AdminOrderPaymentProofImpl>(
        this,
        _$identity,
      );

  @override
  Map<String, dynamic> toJson() {
    return _$$AdminOrderPaymentProofImplToJson(this);
  }
}

abstract class _AdminOrderPaymentProof implements AdminOrderPaymentProof {
  const factory _AdminOrderPaymentProof({
    @JsonKey(name: 'image_url') required final String imageUrl,
    @JsonKey(name: 'attachment_id') required final int attachmentId,
    @JsonKey(name: 'uploaded_at') required final String uploadedAt,
  }) = _$AdminOrderPaymentProofImpl;

  factory _AdminOrderPaymentProof.fromJson(Map<String, dynamic> json) =
      _$AdminOrderPaymentProofImpl.fromJson;

  @override
  @JsonKey(name: 'image_url')
  String get imageUrl;
  @override
  @JsonKey(name: 'attachment_id')
  int get attachmentId;
  @override
  @JsonKey(name: 'uploaded_at')
  String get uploadedAt;

  /// Create a copy of AdminOrderPaymentProof
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$AdminOrderPaymentProofImplCopyWith<_$AdminOrderPaymentProofImpl>
  get copyWith => throw _privateConstructorUsedError;
}

AdminOrderDeliveryLocation _$AdminOrderDeliveryLocationFromJson(
  Map<String, dynamic> json,
) {
  return _AdminOrderDeliveryLocation.fromJson(json);
}

/// @nodoc
mixin _$AdminOrderDeliveryLocation {
  double? get lat => throw _privateConstructorUsedError;
  double? get lng => throw _privateConstructorUsedError;
  @JsonKey(name: 'accuracy_meters')
  double? get accuracyMeters => throw _privateConstructorUsedError;
  @JsonKey(name: 'full_address')
  String get fullAddress => throw _privateConstructorUsedError;
  String get city => throw _privateConstructorUsedError;
  String get area => throw _privateConstructorUsedError;
  String get street => throw _privateConstructorUsedError;
  String get building => throw _privateConstructorUsedError;
  String get notes => throw _privateConstructorUsedError;
  @JsonKey(name: 'captured_at')
  String get capturedAt => throw _privateConstructorUsedError;
  @JsonKey(name: 'maps_open_url')
  String get mapsOpenUrl => throw _privateConstructorUsedError;
  @JsonKey(name: 'maps_navigate_url')
  String get mapsNavigateUrl => throw _privateConstructorUsedError;

  /// Serializes this AdminOrderDeliveryLocation to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of AdminOrderDeliveryLocation
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $AdminOrderDeliveryLocationCopyWith<AdminOrderDeliveryLocation>
  get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $AdminOrderDeliveryLocationCopyWith<$Res> {
  factory $AdminOrderDeliveryLocationCopyWith(
    AdminOrderDeliveryLocation value,
    $Res Function(AdminOrderDeliveryLocation) then,
  ) =
      _$AdminOrderDeliveryLocationCopyWithImpl<
        $Res,
        AdminOrderDeliveryLocation
      >;
  @useResult
  $Res call({
    double? lat,
    double? lng,
    @JsonKey(name: 'accuracy_meters') double? accuracyMeters,
    @JsonKey(name: 'full_address') String fullAddress,
    String city,
    String area,
    String street,
    String building,
    String notes,
    @JsonKey(name: 'captured_at') String capturedAt,
    @JsonKey(name: 'maps_open_url') String mapsOpenUrl,
    @JsonKey(name: 'maps_navigate_url') String mapsNavigateUrl,
  });
}

/// @nodoc
class _$AdminOrderDeliveryLocationCopyWithImpl<
  $Res,
  $Val extends AdminOrderDeliveryLocation
>
    implements $AdminOrderDeliveryLocationCopyWith<$Res> {
  _$AdminOrderDeliveryLocationCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of AdminOrderDeliveryLocation
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? lat = freezed,
    Object? lng = freezed,
    Object? accuracyMeters = freezed,
    Object? fullAddress = null,
    Object? city = null,
    Object? area = null,
    Object? street = null,
    Object? building = null,
    Object? notes = null,
    Object? capturedAt = null,
    Object? mapsOpenUrl = null,
    Object? mapsNavigateUrl = null,
  }) {
    return _then(
      _value.copyWith(
            lat: freezed == lat
                ? _value.lat
                : lat // ignore: cast_nullable_to_non_nullable
                      as double?,
            lng: freezed == lng
                ? _value.lng
                : lng // ignore: cast_nullable_to_non_nullable
                      as double?,
            accuracyMeters: freezed == accuracyMeters
                ? _value.accuracyMeters
                : accuracyMeters // ignore: cast_nullable_to_non_nullable
                      as double?,
            fullAddress: null == fullAddress
                ? _value.fullAddress
                : fullAddress // ignore: cast_nullable_to_non_nullable
                      as String,
            city: null == city
                ? _value.city
                : city // ignore: cast_nullable_to_non_nullable
                      as String,
            area: null == area
                ? _value.area
                : area // ignore: cast_nullable_to_non_nullable
                      as String,
            street: null == street
                ? _value.street
                : street // ignore: cast_nullable_to_non_nullable
                      as String,
            building: null == building
                ? _value.building
                : building // ignore: cast_nullable_to_non_nullable
                      as String,
            notes: null == notes
                ? _value.notes
                : notes // ignore: cast_nullable_to_non_nullable
                      as String,
            capturedAt: null == capturedAt
                ? _value.capturedAt
                : capturedAt // ignore: cast_nullable_to_non_nullable
                      as String,
            mapsOpenUrl: null == mapsOpenUrl
                ? _value.mapsOpenUrl
                : mapsOpenUrl // ignore: cast_nullable_to_non_nullable
                      as String,
            mapsNavigateUrl: null == mapsNavigateUrl
                ? _value.mapsNavigateUrl
                : mapsNavigateUrl // ignore: cast_nullable_to_non_nullable
                      as String,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$AdminOrderDeliveryLocationImplCopyWith<$Res>
    implements $AdminOrderDeliveryLocationCopyWith<$Res> {
  factory _$$AdminOrderDeliveryLocationImplCopyWith(
    _$AdminOrderDeliveryLocationImpl value,
    $Res Function(_$AdminOrderDeliveryLocationImpl) then,
  ) = __$$AdminOrderDeliveryLocationImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    double? lat,
    double? lng,
    @JsonKey(name: 'accuracy_meters') double? accuracyMeters,
    @JsonKey(name: 'full_address') String fullAddress,
    String city,
    String area,
    String street,
    String building,
    String notes,
    @JsonKey(name: 'captured_at') String capturedAt,
    @JsonKey(name: 'maps_open_url') String mapsOpenUrl,
    @JsonKey(name: 'maps_navigate_url') String mapsNavigateUrl,
  });
}

/// @nodoc
class __$$AdminOrderDeliveryLocationImplCopyWithImpl<$Res>
    extends
        _$AdminOrderDeliveryLocationCopyWithImpl<
          $Res,
          _$AdminOrderDeliveryLocationImpl
        >
    implements _$$AdminOrderDeliveryLocationImplCopyWith<$Res> {
  __$$AdminOrderDeliveryLocationImplCopyWithImpl(
    _$AdminOrderDeliveryLocationImpl _value,
    $Res Function(_$AdminOrderDeliveryLocationImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of AdminOrderDeliveryLocation
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? lat = freezed,
    Object? lng = freezed,
    Object? accuracyMeters = freezed,
    Object? fullAddress = null,
    Object? city = null,
    Object? area = null,
    Object? street = null,
    Object? building = null,
    Object? notes = null,
    Object? capturedAt = null,
    Object? mapsOpenUrl = null,
    Object? mapsNavigateUrl = null,
  }) {
    return _then(
      _$AdminOrderDeliveryLocationImpl(
        lat: freezed == lat
            ? _value.lat
            : lat // ignore: cast_nullable_to_non_nullable
                  as double?,
        lng: freezed == lng
            ? _value.lng
            : lng // ignore: cast_nullable_to_non_nullable
                  as double?,
        accuracyMeters: freezed == accuracyMeters
            ? _value.accuracyMeters
            : accuracyMeters // ignore: cast_nullable_to_non_nullable
                  as double?,
        fullAddress: null == fullAddress
            ? _value.fullAddress
            : fullAddress // ignore: cast_nullable_to_non_nullable
                  as String,
        city: null == city
            ? _value.city
            : city // ignore: cast_nullable_to_non_nullable
                  as String,
        area: null == area
            ? _value.area
            : area // ignore: cast_nullable_to_non_nullable
                  as String,
        street: null == street
            ? _value.street
            : street // ignore: cast_nullable_to_non_nullable
                  as String,
        building: null == building
            ? _value.building
            : building // ignore: cast_nullable_to_non_nullable
                  as String,
        notes: null == notes
            ? _value.notes
            : notes // ignore: cast_nullable_to_non_nullable
                  as String,
        capturedAt: null == capturedAt
            ? _value.capturedAt
            : capturedAt // ignore: cast_nullable_to_non_nullable
                  as String,
        mapsOpenUrl: null == mapsOpenUrl
            ? _value.mapsOpenUrl
            : mapsOpenUrl // ignore: cast_nullable_to_non_nullable
                  as String,
        mapsNavigateUrl: null == mapsNavigateUrl
            ? _value.mapsNavigateUrl
            : mapsNavigateUrl // ignore: cast_nullable_to_non_nullable
                  as String,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$AdminOrderDeliveryLocationImpl implements _AdminOrderDeliveryLocation {
  const _$AdminOrderDeliveryLocationImpl({
    this.lat,
    this.lng,
    @JsonKey(name: 'accuracy_meters') this.accuracyMeters,
    @JsonKey(name: 'full_address') this.fullAddress = '',
    this.city = '',
    this.area = '',
    this.street = '',
    this.building = '',
    this.notes = '',
    @JsonKey(name: 'captured_at') this.capturedAt = '',
    @JsonKey(name: 'maps_open_url') this.mapsOpenUrl = '',
    @JsonKey(name: 'maps_navigate_url') this.mapsNavigateUrl = '',
  });

  factory _$AdminOrderDeliveryLocationImpl.fromJson(
    Map<String, dynamic> json,
  ) => _$$AdminOrderDeliveryLocationImplFromJson(json);

  @override
  final double? lat;
  @override
  final double? lng;
  @override
  @JsonKey(name: 'accuracy_meters')
  final double? accuracyMeters;
  @override
  @JsonKey(name: 'full_address')
  final String fullAddress;
  @override
  @JsonKey()
  final String city;
  @override
  @JsonKey()
  final String area;
  @override
  @JsonKey()
  final String street;
  @override
  @JsonKey()
  final String building;
  @override
  @JsonKey()
  final String notes;
  @override
  @JsonKey(name: 'captured_at')
  final String capturedAt;
  @override
  @JsonKey(name: 'maps_open_url')
  final String mapsOpenUrl;
  @override
  @JsonKey(name: 'maps_navigate_url')
  final String mapsNavigateUrl;

  @override
  String toString() {
    return 'AdminOrderDeliveryLocation(lat: $lat, lng: $lng, accuracyMeters: $accuracyMeters, fullAddress: $fullAddress, city: $city, area: $area, street: $street, building: $building, notes: $notes, capturedAt: $capturedAt, mapsOpenUrl: $mapsOpenUrl, mapsNavigateUrl: $mapsNavigateUrl)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$AdminOrderDeliveryLocationImpl &&
            (identical(other.lat, lat) || other.lat == lat) &&
            (identical(other.lng, lng) || other.lng == lng) &&
            (identical(other.accuracyMeters, accuracyMeters) ||
                other.accuracyMeters == accuracyMeters) &&
            (identical(other.fullAddress, fullAddress) ||
                other.fullAddress == fullAddress) &&
            (identical(other.city, city) || other.city == city) &&
            (identical(other.area, area) || other.area == area) &&
            (identical(other.street, street) || other.street == street) &&
            (identical(other.building, building) ||
                other.building == building) &&
            (identical(other.notes, notes) || other.notes == notes) &&
            (identical(other.capturedAt, capturedAt) ||
                other.capturedAt == capturedAt) &&
            (identical(other.mapsOpenUrl, mapsOpenUrl) ||
                other.mapsOpenUrl == mapsOpenUrl) &&
            (identical(other.mapsNavigateUrl, mapsNavigateUrl) ||
                other.mapsNavigateUrl == mapsNavigateUrl));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    lat,
    lng,
    accuracyMeters,
    fullAddress,
    city,
    area,
    street,
    building,
    notes,
    capturedAt,
    mapsOpenUrl,
    mapsNavigateUrl,
  );

  /// Create a copy of AdminOrderDeliveryLocation
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$AdminOrderDeliveryLocationImplCopyWith<_$AdminOrderDeliveryLocationImpl>
  get copyWith =>
      __$$AdminOrderDeliveryLocationImplCopyWithImpl<
        _$AdminOrderDeliveryLocationImpl
      >(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$AdminOrderDeliveryLocationImplToJson(this);
  }
}

abstract class _AdminOrderDeliveryLocation
    implements AdminOrderDeliveryLocation {
  const factory _AdminOrderDeliveryLocation({
    final double? lat,
    final double? lng,
    @JsonKey(name: 'accuracy_meters') final double? accuracyMeters,
    @JsonKey(name: 'full_address') final String fullAddress,
    final String city,
    final String area,
    final String street,
    final String building,
    final String notes,
    @JsonKey(name: 'captured_at') final String capturedAt,
    @JsonKey(name: 'maps_open_url') final String mapsOpenUrl,
    @JsonKey(name: 'maps_navigate_url') final String mapsNavigateUrl,
  }) = _$AdminOrderDeliveryLocationImpl;

  factory _AdminOrderDeliveryLocation.fromJson(Map<String, dynamic> json) =
      _$AdminOrderDeliveryLocationImpl.fromJson;

  @override
  double? get lat;
  @override
  double? get lng;
  @override
  @JsonKey(name: 'accuracy_meters')
  double? get accuracyMeters;
  @override
  @JsonKey(name: 'full_address')
  String get fullAddress;
  @override
  String get city;
  @override
  String get area;
  @override
  String get street;
  @override
  String get building;
  @override
  String get notes;
  @override
  @JsonKey(name: 'captured_at')
  String get capturedAt;
  @override
  @JsonKey(name: 'maps_open_url')
  String get mapsOpenUrl;
  @override
  @JsonKey(name: 'maps_navigate_url')
  String get mapsNavigateUrl;

  /// Create a copy of AdminOrderDeliveryLocation
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$AdminOrderDeliveryLocationImplCopyWith<_$AdminOrderDeliveryLocationImpl>
  get copyWith => throw _privateConstructorUsedError;
}

AdminOrderBilling _$AdminOrderBillingFromJson(Map<String, dynamic> json) {
  return _AdminOrderBilling.fromJson(json);
}

/// @nodoc
mixin _$AdminOrderBilling {
  @JsonKey(name: 'first_name')
  String get firstName => throw _privateConstructorUsedError;
  @JsonKey(name: 'last_name')
  String get lastName => throw _privateConstructorUsedError;
  String get phone => throw _privateConstructorUsedError;
  String get email => throw _privateConstructorUsedError;
  @JsonKey(name: 'address_1')
  String get address1 => throw _privateConstructorUsedError;
  String get city => throw _privateConstructorUsedError;

  /// Serializes this AdminOrderBilling to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of AdminOrderBilling
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $AdminOrderBillingCopyWith<AdminOrderBilling> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $AdminOrderBillingCopyWith<$Res> {
  factory $AdminOrderBillingCopyWith(
    AdminOrderBilling value,
    $Res Function(AdminOrderBilling) then,
  ) = _$AdminOrderBillingCopyWithImpl<$Res, AdminOrderBilling>;
  @useResult
  $Res call({
    @JsonKey(name: 'first_name') String firstName,
    @JsonKey(name: 'last_name') String lastName,
    String phone,
    String email,
    @JsonKey(name: 'address_1') String address1,
    String city,
  });
}

/// @nodoc
class _$AdminOrderBillingCopyWithImpl<$Res, $Val extends AdminOrderBilling>
    implements $AdminOrderBillingCopyWith<$Res> {
  _$AdminOrderBillingCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of AdminOrderBilling
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? firstName = null,
    Object? lastName = null,
    Object? phone = null,
    Object? email = null,
    Object? address1 = null,
    Object? city = null,
  }) {
    return _then(
      _value.copyWith(
            firstName: null == firstName
                ? _value.firstName
                : firstName // ignore: cast_nullable_to_non_nullable
                      as String,
            lastName: null == lastName
                ? _value.lastName
                : lastName // ignore: cast_nullable_to_non_nullable
                      as String,
            phone: null == phone
                ? _value.phone
                : phone // ignore: cast_nullable_to_non_nullable
                      as String,
            email: null == email
                ? _value.email
                : email // ignore: cast_nullable_to_non_nullable
                      as String,
            address1: null == address1
                ? _value.address1
                : address1 // ignore: cast_nullable_to_non_nullable
                      as String,
            city: null == city
                ? _value.city
                : city // ignore: cast_nullable_to_non_nullable
                      as String,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$AdminOrderBillingImplCopyWith<$Res>
    implements $AdminOrderBillingCopyWith<$Res> {
  factory _$$AdminOrderBillingImplCopyWith(
    _$AdminOrderBillingImpl value,
    $Res Function(_$AdminOrderBillingImpl) then,
  ) = __$$AdminOrderBillingImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    @JsonKey(name: 'first_name') String firstName,
    @JsonKey(name: 'last_name') String lastName,
    String phone,
    String email,
    @JsonKey(name: 'address_1') String address1,
    String city,
  });
}

/// @nodoc
class __$$AdminOrderBillingImplCopyWithImpl<$Res>
    extends _$AdminOrderBillingCopyWithImpl<$Res, _$AdminOrderBillingImpl>
    implements _$$AdminOrderBillingImplCopyWith<$Res> {
  __$$AdminOrderBillingImplCopyWithImpl(
    _$AdminOrderBillingImpl _value,
    $Res Function(_$AdminOrderBillingImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of AdminOrderBilling
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? firstName = null,
    Object? lastName = null,
    Object? phone = null,
    Object? email = null,
    Object? address1 = null,
    Object? city = null,
  }) {
    return _then(
      _$AdminOrderBillingImpl(
        firstName: null == firstName
            ? _value.firstName
            : firstName // ignore: cast_nullable_to_non_nullable
                  as String,
        lastName: null == lastName
            ? _value.lastName
            : lastName // ignore: cast_nullable_to_non_nullable
                  as String,
        phone: null == phone
            ? _value.phone
            : phone // ignore: cast_nullable_to_non_nullable
                  as String,
        email: null == email
            ? _value.email
            : email // ignore: cast_nullable_to_non_nullable
                  as String,
        address1: null == address1
            ? _value.address1
            : address1 // ignore: cast_nullable_to_non_nullable
                  as String,
        city: null == city
            ? _value.city
            : city // ignore: cast_nullable_to_non_nullable
                  as String,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$AdminOrderBillingImpl implements _AdminOrderBilling {
  const _$AdminOrderBillingImpl({
    @JsonKey(name: 'first_name') required this.firstName,
    @JsonKey(name: 'last_name') required this.lastName,
    required this.phone,
    required this.email,
    @JsonKey(name: 'address_1') required this.address1,
    required this.city,
  });

  factory _$AdminOrderBillingImpl.fromJson(Map<String, dynamic> json) =>
      _$$AdminOrderBillingImplFromJson(json);

  @override
  @JsonKey(name: 'first_name')
  final String firstName;
  @override
  @JsonKey(name: 'last_name')
  final String lastName;
  @override
  final String phone;
  @override
  final String email;
  @override
  @JsonKey(name: 'address_1')
  final String address1;
  @override
  final String city;

  @override
  String toString() {
    return 'AdminOrderBilling(firstName: $firstName, lastName: $lastName, phone: $phone, email: $email, address1: $address1, city: $city)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$AdminOrderBillingImpl &&
            (identical(other.firstName, firstName) ||
                other.firstName == firstName) &&
            (identical(other.lastName, lastName) ||
                other.lastName == lastName) &&
            (identical(other.phone, phone) || other.phone == phone) &&
            (identical(other.email, email) || other.email == email) &&
            (identical(other.address1, address1) ||
                other.address1 == address1) &&
            (identical(other.city, city) || other.city == city));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    firstName,
    lastName,
    phone,
    email,
    address1,
    city,
  );

  /// Create a copy of AdminOrderBilling
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$AdminOrderBillingImplCopyWith<_$AdminOrderBillingImpl> get copyWith =>
      __$$AdminOrderBillingImplCopyWithImpl<_$AdminOrderBillingImpl>(
        this,
        _$identity,
      );

  @override
  Map<String, dynamic> toJson() {
    return _$$AdminOrderBillingImplToJson(this);
  }
}

abstract class _AdminOrderBilling implements AdminOrderBilling {
  const factory _AdminOrderBilling({
    @JsonKey(name: 'first_name') required final String firstName,
    @JsonKey(name: 'last_name') required final String lastName,
    required final String phone,
    required final String email,
    @JsonKey(name: 'address_1') required final String address1,
    required final String city,
  }) = _$AdminOrderBillingImpl;

  factory _AdminOrderBilling.fromJson(Map<String, dynamic> json) =
      _$AdminOrderBillingImpl.fromJson;

  @override
  @JsonKey(name: 'first_name')
  String get firstName;
  @override
  @JsonKey(name: 'last_name')
  String get lastName;
  @override
  String get phone;
  @override
  String get email;
  @override
  @JsonKey(name: 'address_1')
  String get address1;
  @override
  String get city;

  /// Create a copy of AdminOrderBilling
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$AdminOrderBillingImplCopyWith<_$AdminOrderBillingImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

AdminOrderItem _$AdminOrderItemFromJson(Map<String, dynamic> json) {
  return _AdminOrderItem.fromJson(json);
}

/// @nodoc
mixin _$AdminOrderItem {
  @JsonKey(name: 'product_id')
  int get productId => throw _privateConstructorUsedError;
  String get name => throw _privateConstructorUsedError;
  String get sku => throw _privateConstructorUsedError;
  int get qty => throw _privateConstructorUsedError;
  double get price => throw _privateConstructorUsedError;
  double get subtotal => throw _privateConstructorUsedError;
  double get total => throw _privateConstructorUsedError;
  String get image => throw _privateConstructorUsedError;
  @JsonKey(name: 'variation_label')
  String? get variationLabel => throw _privateConstructorUsedError;

  /// Serializes this AdminOrderItem to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of AdminOrderItem
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $AdminOrderItemCopyWith<AdminOrderItem> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $AdminOrderItemCopyWith<$Res> {
  factory $AdminOrderItemCopyWith(
    AdminOrderItem value,
    $Res Function(AdminOrderItem) then,
  ) = _$AdminOrderItemCopyWithImpl<$Res, AdminOrderItem>;
  @useResult
  $Res call({
    @JsonKey(name: 'product_id') int productId,
    String name,
    String sku,
    int qty,
    double price,
    double subtotal,
    double total,
    String image,
    @JsonKey(name: 'variation_label') String? variationLabel,
  });
}

/// @nodoc
class _$AdminOrderItemCopyWithImpl<$Res, $Val extends AdminOrderItem>
    implements $AdminOrderItemCopyWith<$Res> {
  _$AdminOrderItemCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of AdminOrderItem
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? productId = null,
    Object? name = null,
    Object? sku = null,
    Object? qty = null,
    Object? price = null,
    Object? subtotal = null,
    Object? total = null,
    Object? image = null,
    Object? variationLabel = freezed,
  }) {
    return _then(
      _value.copyWith(
            productId: null == productId
                ? _value.productId
                : productId // ignore: cast_nullable_to_non_nullable
                      as int,
            name: null == name
                ? _value.name
                : name // ignore: cast_nullable_to_non_nullable
                      as String,
            sku: null == sku
                ? _value.sku
                : sku // ignore: cast_nullable_to_non_nullable
                      as String,
            qty: null == qty
                ? _value.qty
                : qty // ignore: cast_nullable_to_non_nullable
                      as int,
            price: null == price
                ? _value.price
                : price // ignore: cast_nullable_to_non_nullable
                      as double,
            subtotal: null == subtotal
                ? _value.subtotal
                : subtotal // ignore: cast_nullable_to_non_nullable
                      as double,
            total: null == total
                ? _value.total
                : total // ignore: cast_nullable_to_non_nullable
                      as double,
            image: null == image
                ? _value.image
                : image // ignore: cast_nullable_to_non_nullable
                      as String,
            variationLabel: freezed == variationLabel
                ? _value.variationLabel
                : variationLabel // ignore: cast_nullable_to_non_nullable
                      as String?,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$AdminOrderItemImplCopyWith<$Res>
    implements $AdminOrderItemCopyWith<$Res> {
  factory _$$AdminOrderItemImplCopyWith(
    _$AdminOrderItemImpl value,
    $Res Function(_$AdminOrderItemImpl) then,
  ) = __$$AdminOrderItemImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    @JsonKey(name: 'product_id') int productId,
    String name,
    String sku,
    int qty,
    double price,
    double subtotal,
    double total,
    String image,
    @JsonKey(name: 'variation_label') String? variationLabel,
  });
}

/// @nodoc
class __$$AdminOrderItemImplCopyWithImpl<$Res>
    extends _$AdminOrderItemCopyWithImpl<$Res, _$AdminOrderItemImpl>
    implements _$$AdminOrderItemImplCopyWith<$Res> {
  __$$AdminOrderItemImplCopyWithImpl(
    _$AdminOrderItemImpl _value,
    $Res Function(_$AdminOrderItemImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of AdminOrderItem
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? productId = null,
    Object? name = null,
    Object? sku = null,
    Object? qty = null,
    Object? price = null,
    Object? subtotal = null,
    Object? total = null,
    Object? image = null,
    Object? variationLabel = freezed,
  }) {
    return _then(
      _$AdminOrderItemImpl(
        productId: null == productId
            ? _value.productId
            : productId // ignore: cast_nullable_to_non_nullable
                  as int,
        name: null == name
            ? _value.name
            : name // ignore: cast_nullable_to_non_nullable
                  as String,
        sku: null == sku
            ? _value.sku
            : sku // ignore: cast_nullable_to_non_nullable
                  as String,
        qty: null == qty
            ? _value.qty
            : qty // ignore: cast_nullable_to_non_nullable
                  as int,
        price: null == price
            ? _value.price
            : price // ignore: cast_nullable_to_non_nullable
                  as double,
        subtotal: null == subtotal
            ? _value.subtotal
            : subtotal // ignore: cast_nullable_to_non_nullable
                  as double,
        total: null == total
            ? _value.total
            : total // ignore: cast_nullable_to_non_nullable
                  as double,
        image: null == image
            ? _value.image
            : image // ignore: cast_nullable_to_non_nullable
                  as String,
        variationLabel: freezed == variationLabel
            ? _value.variationLabel
            : variationLabel // ignore: cast_nullable_to_non_nullable
                  as String?,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$AdminOrderItemImpl implements _AdminOrderItem {
  const _$AdminOrderItemImpl({
    @JsonKey(name: 'product_id') required this.productId,
    required this.name,
    this.sku = '',
    required this.qty,
    this.price = 0,
    this.subtotal = 0,
    required this.total,
    this.image = '',
    @JsonKey(name: 'variation_label') this.variationLabel,
  });

  factory _$AdminOrderItemImpl.fromJson(Map<String, dynamic> json) =>
      _$$AdminOrderItemImplFromJson(json);

  @override
  @JsonKey(name: 'product_id')
  final int productId;
  @override
  final String name;
  @override
  @JsonKey()
  final String sku;
  @override
  final int qty;
  @override
  @JsonKey()
  final double price;
  @override
  @JsonKey()
  final double subtotal;
  @override
  final double total;
  @override
  @JsonKey()
  final String image;
  @override
  @JsonKey(name: 'variation_label')
  final String? variationLabel;

  @override
  String toString() {
    return 'AdminOrderItem(productId: $productId, name: $name, sku: $sku, qty: $qty, price: $price, subtotal: $subtotal, total: $total, image: $image, variationLabel: $variationLabel)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$AdminOrderItemImpl &&
            (identical(other.productId, productId) ||
                other.productId == productId) &&
            (identical(other.name, name) || other.name == name) &&
            (identical(other.sku, sku) || other.sku == sku) &&
            (identical(other.qty, qty) || other.qty == qty) &&
            (identical(other.price, price) || other.price == price) &&
            (identical(other.subtotal, subtotal) ||
                other.subtotal == subtotal) &&
            (identical(other.total, total) || other.total == total) &&
            (identical(other.image, image) || other.image == image) &&
            (identical(other.variationLabel, variationLabel) ||
                other.variationLabel == variationLabel));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    productId,
    name,
    sku,
    qty,
    price,
    subtotal,
    total,
    image,
    variationLabel,
  );

  /// Create a copy of AdminOrderItem
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$AdminOrderItemImplCopyWith<_$AdminOrderItemImpl> get copyWith =>
      __$$AdminOrderItemImplCopyWithImpl<_$AdminOrderItemImpl>(
        this,
        _$identity,
      );

  @override
  Map<String, dynamic> toJson() {
    return _$$AdminOrderItemImplToJson(this);
  }
}

abstract class _AdminOrderItem implements AdminOrderItem {
  const factory _AdminOrderItem({
    @JsonKey(name: 'product_id') required final int productId,
    required final String name,
    final String sku,
    required final int qty,
    final double price,
    final double subtotal,
    required final double total,
    final String image,
    @JsonKey(name: 'variation_label') final String? variationLabel,
  }) = _$AdminOrderItemImpl;

  factory _AdminOrderItem.fromJson(Map<String, dynamic> json) =
      _$AdminOrderItemImpl.fromJson;

  @override
  @JsonKey(name: 'product_id')
  int get productId;
  @override
  String get name;
  @override
  String get sku;
  @override
  int get qty;
  @override
  double get price;
  @override
  double get subtotal;
  @override
  double get total;
  @override
  String get image;
  @override
  @JsonKey(name: 'variation_label')
  String? get variationLabel;

  /// Create a copy of AdminOrderItem
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$AdminOrderItemImplCopyWith<_$AdminOrderItemImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

AdminOrdersResponse _$AdminOrdersResponseFromJson(Map<String, dynamic> json) {
  return _AdminOrdersResponse.fromJson(json);
}

/// @nodoc
mixin _$AdminOrdersResponse {
  List<AdminOrder> get items => throw _privateConstructorUsedError;
  int get page => throw _privateConstructorUsedError;
  @JsonKey(name: 'per_page')
  int get perPage => throw _privateConstructorUsedError;
  int get total => throw _privateConstructorUsedError;
  @JsonKey(name: 'total_pages')
  int get totalPages => throw _privateConstructorUsedError;

  /// Serializes this AdminOrdersResponse to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of AdminOrdersResponse
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $AdminOrdersResponseCopyWith<AdminOrdersResponse> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $AdminOrdersResponseCopyWith<$Res> {
  factory $AdminOrdersResponseCopyWith(
    AdminOrdersResponse value,
    $Res Function(AdminOrdersResponse) then,
  ) = _$AdminOrdersResponseCopyWithImpl<$Res, AdminOrdersResponse>;
  @useResult
  $Res call({
    List<AdminOrder> items,
    int page,
    @JsonKey(name: 'per_page') int perPage,
    int total,
    @JsonKey(name: 'total_pages') int totalPages,
  });
}

/// @nodoc
class _$AdminOrdersResponseCopyWithImpl<$Res, $Val extends AdminOrdersResponse>
    implements $AdminOrdersResponseCopyWith<$Res> {
  _$AdminOrdersResponseCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of AdminOrdersResponse
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? items = null,
    Object? page = null,
    Object? perPage = null,
    Object? total = null,
    Object? totalPages = null,
  }) {
    return _then(
      _value.copyWith(
            items: null == items
                ? _value.items
                : items // ignore: cast_nullable_to_non_nullable
                      as List<AdminOrder>,
            page: null == page
                ? _value.page
                : page // ignore: cast_nullable_to_non_nullable
                      as int,
            perPage: null == perPage
                ? _value.perPage
                : perPage // ignore: cast_nullable_to_non_nullable
                      as int,
            total: null == total
                ? _value.total
                : total // ignore: cast_nullable_to_non_nullable
                      as int,
            totalPages: null == totalPages
                ? _value.totalPages
                : totalPages // ignore: cast_nullable_to_non_nullable
                      as int,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$AdminOrdersResponseImplCopyWith<$Res>
    implements $AdminOrdersResponseCopyWith<$Res> {
  factory _$$AdminOrdersResponseImplCopyWith(
    _$AdminOrdersResponseImpl value,
    $Res Function(_$AdminOrdersResponseImpl) then,
  ) = __$$AdminOrdersResponseImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    List<AdminOrder> items,
    int page,
    @JsonKey(name: 'per_page') int perPage,
    int total,
    @JsonKey(name: 'total_pages') int totalPages,
  });
}

/// @nodoc
class __$$AdminOrdersResponseImplCopyWithImpl<$Res>
    extends _$AdminOrdersResponseCopyWithImpl<$Res, _$AdminOrdersResponseImpl>
    implements _$$AdminOrdersResponseImplCopyWith<$Res> {
  __$$AdminOrdersResponseImplCopyWithImpl(
    _$AdminOrdersResponseImpl _value,
    $Res Function(_$AdminOrdersResponseImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of AdminOrdersResponse
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? items = null,
    Object? page = null,
    Object? perPage = null,
    Object? total = null,
    Object? totalPages = null,
  }) {
    return _then(
      _$AdminOrdersResponseImpl(
        items: null == items
            ? _value._items
            : items // ignore: cast_nullable_to_non_nullable
                  as List<AdminOrder>,
        page: null == page
            ? _value.page
            : page // ignore: cast_nullable_to_non_nullable
                  as int,
        perPage: null == perPage
            ? _value.perPage
            : perPage // ignore: cast_nullable_to_non_nullable
                  as int,
        total: null == total
            ? _value.total
            : total // ignore: cast_nullable_to_non_nullable
                  as int,
        totalPages: null == totalPages
            ? _value.totalPages
            : totalPages // ignore: cast_nullable_to_non_nullable
                  as int,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$AdminOrdersResponseImpl implements _AdminOrdersResponse {
  const _$AdminOrdersResponseImpl({
    final List<AdminOrder> items = const [],
    required this.page,
    @JsonKey(name: 'per_page') required this.perPage,
    required this.total,
    @JsonKey(name: 'total_pages') required this.totalPages,
  }) : _items = items;

  factory _$AdminOrdersResponseImpl.fromJson(Map<String, dynamic> json) =>
      _$$AdminOrdersResponseImplFromJson(json);

  final List<AdminOrder> _items;
  @override
  @JsonKey()
  List<AdminOrder> get items {
    if (_items is EqualUnmodifiableListView) return _items;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_items);
  }

  @override
  final int page;
  @override
  @JsonKey(name: 'per_page')
  final int perPage;
  @override
  final int total;
  @override
  @JsonKey(name: 'total_pages')
  final int totalPages;

  @override
  String toString() {
    return 'AdminOrdersResponse(items: $items, page: $page, perPage: $perPage, total: $total, totalPages: $totalPages)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$AdminOrdersResponseImpl &&
            const DeepCollectionEquality().equals(other._items, _items) &&
            (identical(other.page, page) || other.page == page) &&
            (identical(other.perPage, perPage) || other.perPage == perPage) &&
            (identical(other.total, total) || other.total == total) &&
            (identical(other.totalPages, totalPages) ||
                other.totalPages == totalPages));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    const DeepCollectionEquality().hash(_items),
    page,
    perPage,
    total,
    totalPages,
  );

  /// Create a copy of AdminOrdersResponse
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$AdminOrdersResponseImplCopyWith<_$AdminOrdersResponseImpl> get copyWith =>
      __$$AdminOrdersResponseImplCopyWithImpl<_$AdminOrdersResponseImpl>(
        this,
        _$identity,
      );

  @override
  Map<String, dynamic> toJson() {
    return _$$AdminOrdersResponseImplToJson(this);
  }
}

abstract class _AdminOrdersResponse implements AdminOrdersResponse {
  const factory _AdminOrdersResponse({
    final List<AdminOrder> items,
    required final int page,
    @JsonKey(name: 'per_page') required final int perPage,
    required final int total,
    @JsonKey(name: 'total_pages') required final int totalPages,
  }) = _$AdminOrdersResponseImpl;

  factory _AdminOrdersResponse.fromJson(Map<String, dynamic> json) =
      _$AdminOrdersResponseImpl.fromJson;

  @override
  List<AdminOrder> get items;
  @override
  int get page;
  @override
  @JsonKey(name: 'per_page')
  int get perPage;
  @override
  int get total;
  @override
  @JsonKey(name: 'total_pages')
  int get totalPages;

  /// Create a copy of AdminOrdersResponse
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$AdminOrdersResponseImplCopyWith<_$AdminOrdersResponseImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
