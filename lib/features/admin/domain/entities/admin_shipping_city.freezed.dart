// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'admin_shipping_city.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

AdminShippingCity _$AdminShippingCityFromJson(Map<String, dynamic> json) {
  return _AdminShippingCity.fromJson(json);
}

/// @nodoc
mixin _$AdminShippingCity {
  int get id => throw _privateConstructorUsedError;
  String get name => throw _privateConstructorUsedError;
  double get price => throw _privateConstructorUsedError;
  @JsonKey(name: 'is_active')
  @BoolParser()
  bool get isActive => throw _privateConstructorUsedError;
  @JsonKey(name: 'sort_order')
  int get sortOrder => throw _privateConstructorUsedError;

  /// Serializes this AdminShippingCity to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of AdminShippingCity
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $AdminShippingCityCopyWith<AdminShippingCity> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $AdminShippingCityCopyWith<$Res> {
  factory $AdminShippingCityCopyWith(
    AdminShippingCity value,
    $Res Function(AdminShippingCity) then,
  ) = _$AdminShippingCityCopyWithImpl<$Res, AdminShippingCity>;
  @useResult
  $Res call({
    int id,
    String name,
    double price,
    @JsonKey(name: 'is_active') @BoolParser() bool isActive,
    @JsonKey(name: 'sort_order') int sortOrder,
  });
}

/// @nodoc
class _$AdminShippingCityCopyWithImpl<$Res, $Val extends AdminShippingCity>
    implements $AdminShippingCityCopyWith<$Res> {
  _$AdminShippingCityCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of AdminShippingCity
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? name = null,
    Object? price = null,
    Object? isActive = null,
    Object? sortOrder = null,
  }) {
    return _then(
      _value.copyWith(
            id: null == id
                ? _value.id
                : id // ignore: cast_nullable_to_non_nullable
                      as int,
            name: null == name
                ? _value.name
                : name // ignore: cast_nullable_to_non_nullable
                      as String,
            price: null == price
                ? _value.price
                : price // ignore: cast_nullable_to_non_nullable
                      as double,
            isActive: null == isActive
                ? _value.isActive
                : isActive // ignore: cast_nullable_to_non_nullable
                      as bool,
            sortOrder: null == sortOrder
                ? _value.sortOrder
                : sortOrder // ignore: cast_nullable_to_non_nullable
                      as int,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$AdminShippingCityImplCopyWith<$Res>
    implements $AdminShippingCityCopyWith<$Res> {
  factory _$$AdminShippingCityImplCopyWith(
    _$AdminShippingCityImpl value,
    $Res Function(_$AdminShippingCityImpl) then,
  ) = __$$AdminShippingCityImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    int id,
    String name,
    double price,
    @JsonKey(name: 'is_active') @BoolParser() bool isActive,
    @JsonKey(name: 'sort_order') int sortOrder,
  });
}

/// @nodoc
class __$$AdminShippingCityImplCopyWithImpl<$Res>
    extends _$AdminShippingCityCopyWithImpl<$Res, _$AdminShippingCityImpl>
    implements _$$AdminShippingCityImplCopyWith<$Res> {
  __$$AdminShippingCityImplCopyWithImpl(
    _$AdminShippingCityImpl _value,
    $Res Function(_$AdminShippingCityImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of AdminShippingCity
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? name = null,
    Object? price = null,
    Object? isActive = null,
    Object? sortOrder = null,
  }) {
    return _then(
      _$AdminShippingCityImpl(
        id: null == id
            ? _value.id
            : id // ignore: cast_nullable_to_non_nullable
                  as int,
        name: null == name
            ? _value.name
            : name // ignore: cast_nullable_to_non_nullable
                  as String,
        price: null == price
            ? _value.price
            : price // ignore: cast_nullable_to_non_nullable
                  as double,
        isActive: null == isActive
            ? _value.isActive
            : isActive // ignore: cast_nullable_to_non_nullable
                  as bool,
        sortOrder: null == sortOrder
            ? _value.sortOrder
            : sortOrder // ignore: cast_nullable_to_non_nullable
                  as int,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$AdminShippingCityImpl implements _AdminShippingCity {
  const _$AdminShippingCityImpl({
    required this.id,
    required this.name,
    required this.price,
    @JsonKey(name: 'is_active') @BoolParser() required this.isActive,
    @JsonKey(name: 'sort_order') required this.sortOrder,
  });

  factory _$AdminShippingCityImpl.fromJson(Map<String, dynamic> json) =>
      _$$AdminShippingCityImplFromJson(json);

  @override
  final int id;
  @override
  final String name;
  @override
  final double price;
  @override
  @JsonKey(name: 'is_active')
  @BoolParser()
  final bool isActive;
  @override
  @JsonKey(name: 'sort_order')
  final int sortOrder;

  @override
  String toString() {
    return 'AdminShippingCity(id: $id, name: $name, price: $price, isActive: $isActive, sortOrder: $sortOrder)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$AdminShippingCityImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.name, name) || other.name == name) &&
            (identical(other.price, price) || other.price == price) &&
            (identical(other.isActive, isActive) ||
                other.isActive == isActive) &&
            (identical(other.sortOrder, sortOrder) ||
                other.sortOrder == sortOrder));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode =>
      Object.hash(runtimeType, id, name, price, isActive, sortOrder);

  /// Create a copy of AdminShippingCity
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$AdminShippingCityImplCopyWith<_$AdminShippingCityImpl> get copyWith =>
      __$$AdminShippingCityImplCopyWithImpl<_$AdminShippingCityImpl>(
        this,
        _$identity,
      );

  @override
  Map<String, dynamic> toJson() {
    return _$$AdminShippingCityImplToJson(this);
  }
}

abstract class _AdminShippingCity implements AdminShippingCity {
  const factory _AdminShippingCity({
    required final int id,
    required final String name,
    required final double price,
    @JsonKey(name: 'is_active') @BoolParser() required final bool isActive,
    @JsonKey(name: 'sort_order') required final int sortOrder,
  }) = _$AdminShippingCityImpl;

  factory _AdminShippingCity.fromJson(Map<String, dynamic> json) =
      _$AdminShippingCityImpl.fromJson;

  @override
  int get id;
  @override
  String get name;
  @override
  double get price;
  @override
  @JsonKey(name: 'is_active')
  @BoolParser()
  bool get isActive;
  @override
  @JsonKey(name: 'sort_order')
  int get sortOrder;

  /// Create a copy of AdminShippingCity
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$AdminShippingCityImplCopyWith<_$AdminShippingCityImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
