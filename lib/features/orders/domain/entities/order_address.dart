import '../../../../core/utils/text_normalizer.dart';

class OrderAddress {
  final String firstName;
  final String lastName;
  final String address1;
  final String city;
  final String phone;
  final String email;

  const OrderAddress({
    this.firstName = '',
    this.lastName = '',
    this.address1 = '',
    this.city = '',
    this.phone = '',
    this.email = '',
  });

  factory OrderAddress.fromJson(Map<String, dynamic> json) {
    return OrderAddress(
      firstName: TextNormalizer.normalize(json['first_name']),
      lastName: TextNormalizer.normalize(json['last_name']),
      address1: TextNormalizer.normalize(json['address_1']),
      city: TextNormalizer.normalize(json['city']),
      phone: TextNormalizer.normalize(json['phone']),
      email: TextNormalizer.normalize(json['email']),
    );
  }

  String get fullName => '$firstName $lastName'.trim();
  String get fullAddress => '$address1, $city'.trim();
}
