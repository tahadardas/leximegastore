import '../entities/admin_user.dart';

abstract class AdminAuthRepository {
  Future<AdminUser> login(String email, String password);
  Future<AdminUser> getCurrentUser();
}
