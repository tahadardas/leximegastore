// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'admin_shipping_city.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$AdminShippingCityImpl _$$AdminShippingCityImplFromJson(
  Map<String, dynamic> json,
) => _$AdminShippingCityImpl(
  id: (json['id'] as num).toInt(),
  name: json['name'] as String,
  price: (json['price'] as num).toDouble(),
  isActive: const BoolParser().fromJson(json['is_active']),
  sortOrder: (json['sort_order'] as num).toInt(),
);

Map<String, dynamic> _$$AdminShippingCityImplToJson(
  _$AdminShippingCityImpl instance,
) => <String, dynamic>{
  'id': instance.id,
  'name': instance.name,
  'price': instance.price,
  'is_active': const BoolParser().toJson(instance.isActive),
  'sort_order': instance.sortOrder,
};
