// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'shamcash_order.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

ShamCashProof _$ShamCashProofFromJson(Map<String, dynamic> json) {
  return _ShamCashProof.fromJson(json);
}

/// @nodoc
mixin _$ShamCashProof {
  @JsonKey(name: 'has_proof')
  bool get hasProof => throw _privateConstructorUsedError;
  @JsonKey(name: 'image_url')
  String? get imageUrl => throw _privateConstructorUsedError;
  @JsonKey(name: 'uploaded_at')
  String? get uploadedAt => throw _privateConstructorUsedError;
  String? get note => throw _privateConstructorUsedError;

  /// Serializes this ShamCashProof to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of ShamCashProof
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $ShamCashProofCopyWith<ShamCashProof> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $ShamCashProofCopyWith<$Res> {
  factory $ShamCashProofCopyWith(
    ShamCashProof value,
    $Res Function(ShamCashProof) then,
  ) = _$ShamCashProofCopyWithImpl<$Res, ShamCashProof>;
  @useResult
  $Res call({
    @JsonKey(name: 'has_proof') bool hasProof,
    @JsonKey(name: 'image_url') String? imageUrl,
    @JsonKey(name: 'uploaded_at') String? uploadedAt,
    String? note,
  });
}

/// @nodoc
class _$ShamCashProofCopyWithImpl<$Res, $Val extends ShamCashProof>
    implements $ShamCashProofCopyWith<$Res> {
  _$ShamCashProofCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of ShamCashProof
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? hasProof = null,
    Object? imageUrl = freezed,
    Object? uploadedAt = freezed,
    Object? note = freezed,
  }) {
    return _then(
      _value.copyWith(
            hasProof: null == hasProof
                ? _value.hasProof
                : hasProof // ignore: cast_nullable_to_non_nullable
                      as bool,
            imageUrl: freezed == imageUrl
                ? _value.imageUrl
                : imageUrl // ignore: cast_nullable_to_non_nullable
                      as String?,
            uploadedAt: freezed == uploadedAt
                ? _value.uploadedAt
                : uploadedAt // ignore: cast_nullable_to_non_nullable
                      as String?,
            note: freezed == note
                ? _value.note
                : note // ignore: cast_nullable_to_non_nullable
                      as String?,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$ShamCashProofImplCopyWith<$Res>
    implements $ShamCashProofCopyWith<$Res> {
  factory _$$ShamCashProofImplCopyWith(
    _$ShamCashProofImpl value,
    $Res Function(_$ShamCashProofImpl) then,
  ) = __$$ShamCashProofImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    @JsonKey(name: 'has_proof') bool hasProof,
    @JsonKey(name: 'image_url') String? imageUrl,
    @JsonKey(name: 'uploaded_at') String? uploadedAt,
    String? note,
  });
}

/// @nodoc
class __$$ShamCashProofImplCopyWithImpl<$Res>
    extends _$ShamCashProofCopyWithImpl<$Res, _$ShamCashProofImpl>
    implements _$$ShamCashProofImplCopyWith<$Res> {
  __$$ShamCashProofImplCopyWithImpl(
    _$ShamCashProofImpl _value,
    $Res Function(_$ShamCashProofImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of ShamCashProof
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? hasProof = null,
    Object? imageUrl = freezed,
    Object? uploadedAt = freezed,
    Object? note = freezed,
  }) {
    return _then(
      _$ShamCashProofImpl(
        hasProof: null == hasProof
            ? _value.hasProof
            : hasProof // ignore: cast_nullable_to_non_nullable
                  as bool,
        imageUrl: freezed == imageUrl
            ? _value.imageUrl
            : imageUrl // ignore: cast_nullable_to_non_nullable
                  as String?,
        uploadedAt: freezed == uploadedAt
            ? _value.uploadedAt
            : uploadedAt // ignore: cast_nullable_to_non_nullable
                  as String?,
        note: freezed == note
            ? _value.note
            : note // ignore: cast_nullable_to_non_nullable
                  as String?,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$ShamCashProofImpl implements _ShamCashProof {
  const _$ShamCashProofImpl({
    @JsonKey(name: 'has_proof') required this.hasProof,
    @JsonKey(name: 'image_url') this.imageUrl,
    @JsonKey(name: 'uploaded_at') this.uploadedAt,
    this.note,
  });

  factory _$ShamCashProofImpl.fromJson(Map<String, dynamic> json) =>
      _$$ShamCashProofImplFromJson(json);

  @override
  @JsonKey(name: 'has_proof')
  final bool hasProof;
  @override
  @JsonKey(name: 'image_url')
  final String? imageUrl;
  @override
  @JsonKey(name: 'uploaded_at')
  final String? uploadedAt;
  @override
  final String? note;

  @override
  String toString() {
    return 'ShamCashProof(hasProof: $hasProof, imageUrl: $imageUrl, uploadedAt: $uploadedAt, note: $note)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$ShamCashProofImpl &&
            (identical(other.hasProof, hasProof) ||
                other.hasProof == hasProof) &&
            (identical(other.imageUrl, imageUrl) ||
                other.imageUrl == imageUrl) &&
            (identical(other.uploadedAt, uploadedAt) ||
                other.uploadedAt == uploadedAt) &&
            (identical(other.note, note) || other.note == note));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode =>
      Object.hash(runtimeType, hasProof, imageUrl, uploadedAt, note);

  /// Create a copy of ShamCashProof
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$ShamCashProofImplCopyWith<_$ShamCashProofImpl> get copyWith =>
      __$$ShamCashProofImplCopyWithImpl<_$ShamCashProofImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$ShamCashProofImplToJson(this);
  }
}

abstract class _ShamCashProof implements ShamCashProof {
  const factory _ShamCashProof({
    @JsonKey(name: 'has_proof') required final bool hasProof,
    @JsonKey(name: 'image_url') final String? imageUrl,
    @JsonKey(name: 'uploaded_at') final String? uploadedAt,
    final String? note,
  }) = _$ShamCashProofImpl;

  factory _ShamCashProof.fromJson(Map<String, dynamic> json) =
      _$ShamCashProofImpl.fromJson;

  @override
  @JsonKey(name: 'has_proof')
  bool get hasProof;
  @override
  @JsonKey(name: 'image_url')
  String? get imageUrl;
  @override
  @JsonKey(name: 'uploaded_at')
  String? get uploadedAt;
  @override
  String? get note;

  /// Create a copy of ShamCashProof
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$ShamCashProofImplCopyWith<_$ShamCashProofImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

ShamCashOrder _$ShamCashOrderFromJson(Map<String, dynamic> json) {
  return _ShamCashOrder.fromJson(json);
}

/// @nodoc
mixin _$ShamCashOrder {
  int get id => throw _privateConstructorUsedError;
  @JsonKey(name: 'order_number')
  String get orderNumber => throw _privateConstructorUsedError;
  String get status => throw _privateConstructorUsedError;
  @JsonKey(name: 'status_label_ar')
  String get statusLabelAr => throw _privateConstructorUsedError;
  double get total => throw _privateConstructorUsedError;
  String get currency => throw _privateConstructorUsedError;
  @JsonKey(name: 'customer_name')
  String get customerName => throw _privateConstructorUsedError;
  @JsonKey(name: 'customer_phone')
  String get customerPhone => throw _privateConstructorUsedError;
  @JsonKey(name: 'date_created')
  String get dateCreated => throw _privateConstructorUsedError;
  ShamCashProof? get proof => throw _privateConstructorUsedError;

  /// Serializes this ShamCashOrder to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of ShamCashOrder
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $ShamCashOrderCopyWith<ShamCashOrder> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $ShamCashOrderCopyWith<$Res> {
  factory $ShamCashOrderCopyWith(
    ShamCashOrder value,
    $Res Function(ShamCashOrder) then,
  ) = _$ShamCashOrderCopyWithImpl<$Res, ShamCashOrder>;
  @useResult
  $Res call({
    int id,
    @JsonKey(name: 'order_number') String orderNumber,
    String status,
    @JsonKey(name: 'status_label_ar') String statusLabelAr,
    double total,
    String currency,
    @JsonKey(name: 'customer_name') String customerName,
    @JsonKey(name: 'customer_phone') String customerPhone,
    @JsonKey(name: 'date_created') String dateCreated,
    ShamCashProof? proof,
  });

  $ShamCashProofCopyWith<$Res>? get proof;
}

/// @nodoc
class _$ShamCashOrderCopyWithImpl<$Res, $Val extends ShamCashOrder>
    implements $ShamCashOrderCopyWith<$Res> {
  _$ShamCashOrderCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of ShamCashOrder
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? orderNumber = null,
    Object? status = null,
    Object? statusLabelAr = null,
    Object? total = null,
    Object? currency = null,
    Object? customerName = null,
    Object? customerPhone = null,
    Object? dateCreated = null,
    Object? proof = freezed,
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
            statusLabelAr: null == statusLabelAr
                ? _value.statusLabelAr
                : statusLabelAr // ignore: cast_nullable_to_non_nullable
                      as String,
            total: null == total
                ? _value.total
                : total // ignore: cast_nullable_to_non_nullable
                      as double,
            currency: null == currency
                ? _value.currency
                : currency // ignore: cast_nullable_to_non_nullable
                      as String,
            customerName: null == customerName
                ? _value.customerName
                : customerName // ignore: cast_nullable_to_non_nullable
                      as String,
            customerPhone: null == customerPhone
                ? _value.customerPhone
                : customerPhone // ignore: cast_nullable_to_non_nullable
                      as String,
            dateCreated: null == dateCreated
                ? _value.dateCreated
                : dateCreated // ignore: cast_nullable_to_non_nullable
                      as String,
            proof: freezed == proof
                ? _value.proof
                : proof // ignore: cast_nullable_to_non_nullable
                      as ShamCashProof?,
          )
          as $Val,
    );
  }

  /// Create a copy of ShamCashOrder
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $ShamCashProofCopyWith<$Res>? get proof {
    if (_value.proof == null) {
      return null;
    }

    return $ShamCashProofCopyWith<$Res>(_value.proof!, (value) {
      return _then(_value.copyWith(proof: value) as $Val);
    });
  }
}

/// @nodoc
abstract class _$$ShamCashOrderImplCopyWith<$Res>
    implements $ShamCashOrderCopyWith<$Res> {
  factory _$$ShamCashOrderImplCopyWith(
    _$ShamCashOrderImpl value,
    $Res Function(_$ShamCashOrderImpl) then,
  ) = __$$ShamCashOrderImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    int id,
    @JsonKey(name: 'order_number') String orderNumber,
    String status,
    @JsonKey(name: 'status_label_ar') String statusLabelAr,
    double total,
    String currency,
    @JsonKey(name: 'customer_name') String customerName,
    @JsonKey(name: 'customer_phone') String customerPhone,
    @JsonKey(name: 'date_created') String dateCreated,
    ShamCashProof? proof,
  });

  @override
  $ShamCashProofCopyWith<$Res>? get proof;
}

/// @nodoc
class __$$ShamCashOrderImplCopyWithImpl<$Res>
    extends _$ShamCashOrderCopyWithImpl<$Res, _$ShamCashOrderImpl>
    implements _$$ShamCashOrderImplCopyWith<$Res> {
  __$$ShamCashOrderImplCopyWithImpl(
    _$ShamCashOrderImpl _value,
    $Res Function(_$ShamCashOrderImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of ShamCashOrder
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? orderNumber = null,
    Object? status = null,
    Object? statusLabelAr = null,
    Object? total = null,
    Object? currency = null,
    Object? customerName = null,
    Object? customerPhone = null,
    Object? dateCreated = null,
    Object? proof = freezed,
  }) {
    return _then(
      _$ShamCashOrderImpl(
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
        statusLabelAr: null == statusLabelAr
            ? _value.statusLabelAr
            : statusLabelAr // ignore: cast_nullable_to_non_nullable
                  as String,
        total: null == total
            ? _value.total
            : total // ignore: cast_nullable_to_non_nullable
                  as double,
        currency: null == currency
            ? _value.currency
            : currency // ignore: cast_nullable_to_non_nullable
                  as String,
        customerName: null == customerName
            ? _value.customerName
            : customerName // ignore: cast_nullable_to_non_nullable
                  as String,
        customerPhone: null == customerPhone
            ? _value.customerPhone
            : customerPhone // ignore: cast_nullable_to_non_nullable
                  as String,
        dateCreated: null == dateCreated
            ? _value.dateCreated
            : dateCreated // ignore: cast_nullable_to_non_nullable
                  as String,
        proof: freezed == proof
            ? _value.proof
            : proof // ignore: cast_nullable_to_non_nullable
                  as ShamCashProof?,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$ShamCashOrderImpl implements _ShamCashOrder {
  const _$ShamCashOrderImpl({
    required this.id,
    @JsonKey(name: 'order_number') required this.orderNumber,
    required this.status,
    @JsonKey(name: 'status_label_ar') required this.statusLabelAr,
    required this.total,
    this.currency = 'SYP',
    @JsonKey(name: 'customer_name') required this.customerName,
    @JsonKey(name: 'customer_phone') required this.customerPhone,
    @JsonKey(name: 'date_created') required this.dateCreated,
    this.proof,
  });

  factory _$ShamCashOrderImpl.fromJson(Map<String, dynamic> json) =>
      _$$ShamCashOrderImplFromJson(json);

  @override
  final int id;
  @override
  @JsonKey(name: 'order_number')
  final String orderNumber;
  @override
  final String status;
  @override
  @JsonKey(name: 'status_label_ar')
  final String statusLabelAr;
  @override
  final double total;
  @override
  @JsonKey()
  final String currency;
  @override
  @JsonKey(name: 'customer_name')
  final String customerName;
  @override
  @JsonKey(name: 'customer_phone')
  final String customerPhone;
  @override
  @JsonKey(name: 'date_created')
  final String dateCreated;
  @override
  final ShamCashProof? proof;

  @override
  String toString() {
    return 'ShamCashOrder(id: $id, orderNumber: $orderNumber, status: $status, statusLabelAr: $statusLabelAr, total: $total, currency: $currency, customerName: $customerName, customerPhone: $customerPhone, dateCreated: $dateCreated, proof: $proof)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$ShamCashOrderImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.orderNumber, orderNumber) ||
                other.orderNumber == orderNumber) &&
            (identical(other.status, status) || other.status == status) &&
            (identical(other.statusLabelAr, statusLabelAr) ||
                other.statusLabelAr == statusLabelAr) &&
            (identical(other.total, total) || other.total == total) &&
            (identical(other.currency, currency) ||
                other.currency == currency) &&
            (identical(other.customerName, customerName) ||
                other.customerName == customerName) &&
            (identical(other.customerPhone, customerPhone) ||
                other.customerPhone == customerPhone) &&
            (identical(other.dateCreated, dateCreated) ||
                other.dateCreated == dateCreated) &&
            (identical(other.proof, proof) || other.proof == proof));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    id,
    orderNumber,
    status,
    statusLabelAr,
    total,
    currency,
    customerName,
    customerPhone,
    dateCreated,
    proof,
  );

  /// Create a copy of ShamCashOrder
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$ShamCashOrderImplCopyWith<_$ShamCashOrderImpl> get copyWith =>
      __$$ShamCashOrderImplCopyWithImpl<_$ShamCashOrderImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$ShamCashOrderImplToJson(this);
  }
}

abstract class _ShamCashOrder implements ShamCashOrder {
  const factory _ShamCashOrder({
    required final int id,
    @JsonKey(name: 'order_number') required final String orderNumber,
    required final String status,
    @JsonKey(name: 'status_label_ar') required final String statusLabelAr,
    required final double total,
    final String currency,
    @JsonKey(name: 'customer_name') required final String customerName,
    @JsonKey(name: 'customer_phone') required final String customerPhone,
    @JsonKey(name: 'date_created') required final String dateCreated,
    final ShamCashProof? proof,
  }) = _$ShamCashOrderImpl;

  factory _ShamCashOrder.fromJson(Map<String, dynamic> json) =
      _$ShamCashOrderImpl.fromJson;

  @override
  int get id;
  @override
  @JsonKey(name: 'order_number')
  String get orderNumber;
  @override
  String get status;
  @override
  @JsonKey(name: 'status_label_ar')
  String get statusLabelAr;
  @override
  double get total;
  @override
  String get currency;
  @override
  @JsonKey(name: 'customer_name')
  String get customerName;
  @override
  @JsonKey(name: 'customer_phone')
  String get customerPhone;
  @override
  @JsonKey(name: 'date_created')
  String get dateCreated;
  @override
  ShamCashProof? get proof;

  /// Create a copy of ShamCashOrder
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$ShamCashOrderImplCopyWith<_$ShamCashOrderImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

ShamCashOrdersResponse _$ShamCashOrdersResponseFromJson(
  Map<String, dynamic> json,
) {
  return _ShamCashOrdersResponse.fromJson(json);
}

/// @nodoc
mixin _$ShamCashOrdersResponse {
  List<ShamCashOrder> get orders => throw _privateConstructorUsedError;
  int get total => throw _privateConstructorUsedError;
  int get page => throw _privateConstructorUsedError;
  @JsonKey(name: 'per_page')
  int get perPage => throw _privateConstructorUsedError;
  @JsonKey(name: 'total_pages')
  int get totalPages => throw _privateConstructorUsedError;

  /// Serializes this ShamCashOrdersResponse to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of ShamCashOrdersResponse
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $ShamCashOrdersResponseCopyWith<ShamCashOrdersResponse> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $ShamCashOrdersResponseCopyWith<$Res> {
  factory $ShamCashOrdersResponseCopyWith(
    ShamCashOrdersResponse value,
    $Res Function(ShamCashOrdersResponse) then,
  ) = _$ShamCashOrdersResponseCopyWithImpl<$Res, ShamCashOrdersResponse>;
  @useResult
  $Res call({
    List<ShamCashOrder> orders,
    int total,
    int page,
    @JsonKey(name: 'per_page') int perPage,
    @JsonKey(name: 'total_pages') int totalPages,
  });
}

/// @nodoc
class _$ShamCashOrdersResponseCopyWithImpl<
  $Res,
  $Val extends ShamCashOrdersResponse
>
    implements $ShamCashOrdersResponseCopyWith<$Res> {
  _$ShamCashOrdersResponseCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of ShamCashOrdersResponse
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? orders = null,
    Object? total = null,
    Object? page = null,
    Object? perPage = null,
    Object? totalPages = null,
  }) {
    return _then(
      _value.copyWith(
            orders: null == orders
                ? _value.orders
                : orders // ignore: cast_nullable_to_non_nullable
                      as List<ShamCashOrder>,
            total: null == total
                ? _value.total
                : total // ignore: cast_nullable_to_non_nullable
                      as int,
            page: null == page
                ? _value.page
                : page // ignore: cast_nullable_to_non_nullable
                      as int,
            perPage: null == perPage
                ? _value.perPage
                : perPage // ignore: cast_nullable_to_non_nullable
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
abstract class _$$ShamCashOrdersResponseImplCopyWith<$Res>
    implements $ShamCashOrdersResponseCopyWith<$Res> {
  factory _$$ShamCashOrdersResponseImplCopyWith(
    _$ShamCashOrdersResponseImpl value,
    $Res Function(_$ShamCashOrdersResponseImpl) then,
  ) = __$$ShamCashOrdersResponseImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    List<ShamCashOrder> orders,
    int total,
    int page,
    @JsonKey(name: 'per_page') int perPage,
    @JsonKey(name: 'total_pages') int totalPages,
  });
}

/// @nodoc
class __$$ShamCashOrdersResponseImplCopyWithImpl<$Res>
    extends
        _$ShamCashOrdersResponseCopyWithImpl<$Res, _$ShamCashOrdersResponseImpl>
    implements _$$ShamCashOrdersResponseImplCopyWith<$Res> {
  __$$ShamCashOrdersResponseImplCopyWithImpl(
    _$ShamCashOrdersResponseImpl _value,
    $Res Function(_$ShamCashOrdersResponseImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of ShamCashOrdersResponse
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? orders = null,
    Object? total = null,
    Object? page = null,
    Object? perPage = null,
    Object? totalPages = null,
  }) {
    return _then(
      _$ShamCashOrdersResponseImpl(
        orders: null == orders
            ? _value._orders
            : orders // ignore: cast_nullable_to_non_nullable
                  as List<ShamCashOrder>,
        total: null == total
            ? _value.total
            : total // ignore: cast_nullable_to_non_nullable
                  as int,
        page: null == page
            ? _value.page
            : page // ignore: cast_nullable_to_non_nullable
                  as int,
        perPage: null == perPage
            ? _value.perPage
            : perPage // ignore: cast_nullable_to_non_nullable
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
class _$ShamCashOrdersResponseImpl implements _ShamCashOrdersResponse {
  const _$ShamCashOrdersResponseImpl({
    required final List<ShamCashOrder> orders,
    required this.total,
    required this.page,
    @JsonKey(name: 'per_page') required this.perPage,
    @JsonKey(name: 'total_pages') required this.totalPages,
  }) : _orders = orders;

  factory _$ShamCashOrdersResponseImpl.fromJson(Map<String, dynamic> json) =>
      _$$ShamCashOrdersResponseImplFromJson(json);

  final List<ShamCashOrder> _orders;
  @override
  List<ShamCashOrder> get orders {
    if (_orders is EqualUnmodifiableListView) return _orders;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_orders);
  }

  @override
  final int total;
  @override
  final int page;
  @override
  @JsonKey(name: 'per_page')
  final int perPage;
  @override
  @JsonKey(name: 'total_pages')
  final int totalPages;

  @override
  String toString() {
    return 'ShamCashOrdersResponse(orders: $orders, total: $total, page: $page, perPage: $perPage, totalPages: $totalPages)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$ShamCashOrdersResponseImpl &&
            const DeepCollectionEquality().equals(other._orders, _orders) &&
            (identical(other.total, total) || other.total == total) &&
            (identical(other.page, page) || other.page == page) &&
            (identical(other.perPage, perPage) || other.perPage == perPage) &&
            (identical(other.totalPages, totalPages) ||
                other.totalPages == totalPages));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    const DeepCollectionEquality().hash(_orders),
    total,
    page,
    perPage,
    totalPages,
  );

  /// Create a copy of ShamCashOrdersResponse
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$ShamCashOrdersResponseImplCopyWith<_$ShamCashOrdersResponseImpl>
  get copyWith =>
      __$$ShamCashOrdersResponseImplCopyWithImpl<_$ShamCashOrdersResponseImpl>(
        this,
        _$identity,
      );

  @override
  Map<String, dynamic> toJson() {
    return _$$ShamCashOrdersResponseImplToJson(this);
  }
}

abstract class _ShamCashOrdersResponse implements ShamCashOrdersResponse {
  const factory _ShamCashOrdersResponse({
    required final List<ShamCashOrder> orders,
    required final int total,
    required final int page,
    @JsonKey(name: 'per_page') required final int perPage,
    @JsonKey(name: 'total_pages') required final int totalPages,
  }) = _$ShamCashOrdersResponseImpl;

  factory _ShamCashOrdersResponse.fromJson(Map<String, dynamic> json) =
      _$ShamCashOrdersResponseImpl.fromJson;

  @override
  List<ShamCashOrder> get orders;
  @override
  int get total;
  @override
  int get page;
  @override
  @JsonKey(name: 'per_page')
  int get perPage;
  @override
  @JsonKey(name: 'total_pages')
  int get totalPages;

  /// Create a copy of ShamCashOrdersResponse
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$ShamCashOrdersResponseImplCopyWith<_$ShamCashOrdersResponseImpl>
  get copyWith => throw _privateConstructorUsedError;
}

ShamCashVerificationResult _$ShamCashVerificationResultFromJson(
  Map<String, dynamic> json,
) {
  return _ShamCashVerificationResult.fromJson(json);
}

/// @nodoc
mixin _$ShamCashVerificationResult {
  int get id => throw _privateConstructorUsedError;
  String get status => throw _privateConstructorUsedError;
  @JsonKey(name: 'status_label_ar')
  String get statusLabelAr => throw _privateConstructorUsedError;
  String get message => throw _privateConstructorUsedError;

  /// Serializes this ShamCashVerificationResult to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of ShamCashVerificationResult
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $ShamCashVerificationResultCopyWith<ShamCashVerificationResult>
  get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $ShamCashVerificationResultCopyWith<$Res> {
  factory $ShamCashVerificationResultCopyWith(
    ShamCashVerificationResult value,
    $Res Function(ShamCashVerificationResult) then,
  ) =
      _$ShamCashVerificationResultCopyWithImpl<
        $Res,
        ShamCashVerificationResult
      >;
  @useResult
  $Res call({
    int id,
    String status,
    @JsonKey(name: 'status_label_ar') String statusLabelAr,
    String message,
  });
}

/// @nodoc
class _$ShamCashVerificationResultCopyWithImpl<
  $Res,
  $Val extends ShamCashVerificationResult
>
    implements $ShamCashVerificationResultCopyWith<$Res> {
  _$ShamCashVerificationResultCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of ShamCashVerificationResult
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? status = null,
    Object? statusLabelAr = null,
    Object? message = null,
  }) {
    return _then(
      _value.copyWith(
            id: null == id
                ? _value.id
                : id // ignore: cast_nullable_to_non_nullable
                      as int,
            status: null == status
                ? _value.status
                : status // ignore: cast_nullable_to_non_nullable
                      as String,
            statusLabelAr: null == statusLabelAr
                ? _value.statusLabelAr
                : statusLabelAr // ignore: cast_nullable_to_non_nullable
                      as String,
            message: null == message
                ? _value.message
                : message // ignore: cast_nullable_to_non_nullable
                      as String,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$ShamCashVerificationResultImplCopyWith<$Res>
    implements $ShamCashVerificationResultCopyWith<$Res> {
  factory _$$ShamCashVerificationResultImplCopyWith(
    _$ShamCashVerificationResultImpl value,
    $Res Function(_$ShamCashVerificationResultImpl) then,
  ) = __$$ShamCashVerificationResultImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    int id,
    String status,
    @JsonKey(name: 'status_label_ar') String statusLabelAr,
    String message,
  });
}

/// @nodoc
class __$$ShamCashVerificationResultImplCopyWithImpl<$Res>
    extends
        _$ShamCashVerificationResultCopyWithImpl<
          $Res,
          _$ShamCashVerificationResultImpl
        >
    implements _$$ShamCashVerificationResultImplCopyWith<$Res> {
  __$$ShamCashVerificationResultImplCopyWithImpl(
    _$ShamCashVerificationResultImpl _value,
    $Res Function(_$ShamCashVerificationResultImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of ShamCashVerificationResult
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? status = null,
    Object? statusLabelAr = null,
    Object? message = null,
  }) {
    return _then(
      _$ShamCashVerificationResultImpl(
        id: null == id
            ? _value.id
            : id // ignore: cast_nullable_to_non_nullable
                  as int,
        status: null == status
            ? _value.status
            : status // ignore: cast_nullable_to_non_nullable
                  as String,
        statusLabelAr: null == statusLabelAr
            ? _value.statusLabelAr
            : statusLabelAr // ignore: cast_nullable_to_non_nullable
                  as String,
        message: null == message
            ? _value.message
            : message // ignore: cast_nullable_to_non_nullable
                  as String,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$ShamCashVerificationResultImpl implements _ShamCashVerificationResult {
  const _$ShamCashVerificationResultImpl({
    required this.id,
    required this.status,
    @JsonKey(name: 'status_label_ar') required this.statusLabelAr,
    required this.message,
  });

  factory _$ShamCashVerificationResultImpl.fromJson(
    Map<String, dynamic> json,
  ) => _$$ShamCashVerificationResultImplFromJson(json);

  @override
  final int id;
  @override
  final String status;
  @override
  @JsonKey(name: 'status_label_ar')
  final String statusLabelAr;
  @override
  final String message;

  @override
  String toString() {
    return 'ShamCashVerificationResult(id: $id, status: $status, statusLabelAr: $statusLabelAr, message: $message)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$ShamCashVerificationResultImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.status, status) || other.status == status) &&
            (identical(other.statusLabelAr, statusLabelAr) ||
                other.statusLabelAr == statusLabelAr) &&
            (identical(other.message, message) || other.message == message));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode =>
      Object.hash(runtimeType, id, status, statusLabelAr, message);

  /// Create a copy of ShamCashVerificationResult
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$ShamCashVerificationResultImplCopyWith<_$ShamCashVerificationResultImpl>
  get copyWith =>
      __$$ShamCashVerificationResultImplCopyWithImpl<
        _$ShamCashVerificationResultImpl
      >(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$ShamCashVerificationResultImplToJson(this);
  }
}

abstract class _ShamCashVerificationResult
    implements ShamCashVerificationResult {
  const factory _ShamCashVerificationResult({
    required final int id,
    required final String status,
    @JsonKey(name: 'status_label_ar') required final String statusLabelAr,
    required final String message,
  }) = _$ShamCashVerificationResultImpl;

  factory _ShamCashVerificationResult.fromJson(Map<String, dynamic> json) =
      _$ShamCashVerificationResultImpl.fromJson;

  @override
  int get id;
  @override
  String get status;
  @override
  @JsonKey(name: 'status_label_ar')
  String get statusLabelAr;
  @override
  String get message;

  /// Create a copy of ShamCashVerificationResult
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$ShamCashVerificationResultImplCopyWith<_$ShamCashVerificationResultImpl>
  get copyWith => throw _privateConstructorUsedError;
}
