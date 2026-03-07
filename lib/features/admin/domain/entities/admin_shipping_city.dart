import 'package:freezed_annotation/freezed_annotation.dart';
import '../../../../core/utils/safe_parsers.dart';

part 'admin_shipping_city.freezed.dart';
part 'admin_shipping_city.g.dart';

@freezed
class AdminShippingCity with _$AdminShippingCity {
  const factory AdminShippingCity({
    required int id,
    required String name,
    required double price,
    @JsonKey(name: 'is_active') @BoolParser() required bool isActive,
    @JsonKey(name: 'sort_order') required int sortOrder,
  }) = _AdminShippingCity;

  factory AdminShippingCity.fromJson(Map<String, dynamic> json) =>
      _$AdminShippingCityFromJson(json);
}
