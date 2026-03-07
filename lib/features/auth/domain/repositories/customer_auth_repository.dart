import '../entities/customer_user.dart';

abstract class CustomerAuthRepository {
  Future<CustomerUser> login(String emailOrUsername, String password);

  Future<void> register({
    required String email,
    required String password,
    String? username,
    String? firstName,
    String? lastName,
    String? phone,
    String? address1,
    String? city,
  });

  Future<CustomerUser> getCurrentUser();

  Future<CustomerUser> updateProfile({
    String? firstName,
    String? lastName,
    String? displayName,
    String? email,
    String? phone,
    String? address1,
    String? city,
  });

  Future<CustomerUser> uploadAvatar(String filePath);

  Future<void> forgotPassword(String email);

  Future<void> resetPassword(String email, String code, String newPassword);

  Future<void> changePassword(String currentPassword, String newPassword);

  Future<void> logout();
}
