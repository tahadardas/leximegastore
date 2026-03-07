import '../../../../core/utils/safe_parsers.dart';

class AdminUser {
  final int id;
  final String username;
  final String email;
  final String displayName;
  final List<String> roles;
  final String token;

  const AdminUser({
    required this.id,
    required this.username,
    required this.email,
    required this.displayName,
    required this.roles,
    required this.token,
  });

  factory AdminUser.fromJson(Map<String, dynamic> json, {String? token}) {
    // Handling extraction from /lexi/v1/admin/me response
    final rolesList =
        (json['roles'] as List?)?.map((e) => e.toString()).toList() ?? [];

    return AdminUser(
      id: parseInt(json['id']),
      username: json['user_login']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      displayName: json['display_name']?.toString() ?? '',
      roles: rolesList,
      token: token ?? json['token']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_login': username,
      'email': email,
      'display_name': displayName,
      'roles': roles,
      'token': token,
    };
  }
}
