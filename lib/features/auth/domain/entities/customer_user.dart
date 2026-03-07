import '../../../../core/utils/safe_parsers.dart';

class CustomerUser {
  final int id;
  final String username;
  final String email;
  final String displayName;
  final List<String> roles;
  final String firstName;
  final String lastName;
  final String phone;
  final String address1;
  final String city;
  final String country;
  final String avatarUrl;
  final String token;

  const CustomerUser({
    required this.id,
    required this.username,
    required this.email,
    required this.displayName,
    required this.roles,
    required this.firstName,
    required this.lastName,
    required this.phone,
    required this.address1,
    required this.city,
    required this.country,
    this.avatarUrl = '',
    this.token = '',
  });

  String get fullName {
    final value = '$firstName $lastName'.trim();
    if (value.isNotEmpty) return value;
    if (displayName.trim().isNotEmpty) return displayName.trim();
    if (username.trim().isNotEmpty) return username.trim();
    return email;
  }

  CustomerUser copyWith({
    int? id,
    String? username,
    String? email,
    String? displayName,
    List<String>? roles,
    String? firstName,
    String? lastName,
    String? phone,
    String? address1,
    String? city,
    String? country,
    String? avatarUrl,
    String? token,
  }) {
    return CustomerUser(
      id: id ?? this.id,
      username: username ?? this.username,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      roles: roles ?? this.roles,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      phone: phone ?? this.phone,
      address1: address1 ?? this.address1,
      city: city ?? this.city,
      country: country ?? this.country,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      token: token ?? this.token,
    );
  }

  factory CustomerUser.fromJson(
    Map<String, dynamic> json, {
    String token = '',
  }) {
    final rolesRaw = json['roles'];
    final roles = <String>[];
    if (rolesRaw is List) {
      for (final role in rolesRaw) {
        final value = role.toString().trim();
        if (value.isNotEmpty) {
          roles.add(value);
        }
      }
    }

    final firstName = (json['first_name'] ?? json['billing_first_name'] ?? '')
        .toString()
        .trim();
    final lastName = (json['last_name'] ?? json['billing_last_name'] ?? '')
        .toString()
        .trim();

    return CustomerUser(
      id: parseInt(json['id']),
      username: (json['user_login'] ?? json['username'] ?? '').toString(),
      email: (json['email'] ?? '').toString(),
      displayName: (json['display_name'] ?? '').toString(),
      roles: roles,
      firstName: firstName,
      lastName: lastName,
      phone: (json['billing_phone'] ?? json['phone'] ?? '').toString().trim(),
      address1: (json['billing_address_1'] ?? json['address_1'] ?? '')
          .toString()
          .trim(),
      city: (json['billing_city'] ?? json['city'] ?? '').toString().trim(),
      country: (json['billing_country'] ?? json['country'] ?? 'SY')
          .toString()
          .trim(),
      avatarUrl: (json['avatar_url'] ?? '').toString().trim(),
      token: token,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'user_login': username,
    'email': email,
    'display_name': displayName,
    'roles': roles,
    'first_name': firstName,
    'last_name': lastName,
    'billing_phone': phone,
    'billing_address_1': address1,
    'billing_city': city,
    'billing_country': country,
    'avatar_url': avatarUrl,
    'token': token,
  };
}
