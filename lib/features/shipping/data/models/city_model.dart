import '../../domain/entities/city.dart';
import '../../../../core/utils/safe_parsers.dart';
import '../../../../core/utils/text_normalizer.dart';

class CityModel {
  final String id;
  final String name;
  final double price;

  const CityModel({required this.id, required this.name, required this.price});

  factory CityModel.fromJson(Map<String, dynamic> json) {
    return CityModel(
      id: json['id'].toString(),
      name: TextNormalizer.normalize(json['name']),
      price: parseDouble(json['price'] ?? json['rate']),
    );
  }

  City toEntity() => City(id: id, name: name, price: price);
}
