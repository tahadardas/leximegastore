import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Secure storage provider
final secureStoreProvider = Provider<SecureStore>((ref) {
  return SecureStore();
});

/// Wrapper around [FlutterSecureStorage] for token management.
class SecureStore {
  // Unified token key matching AppSession
  static const _accessTokenKey = 'access_token';
  static const _legacyJwtTokenKey = 'jwt_token';
  static const _refreshTokenKey = 'refresh_token';
  static const _userIdKey = 'user_id';

  final FlutterSecureStorage _storage = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  // ── Access Token ──

  Future<String?> getAccessToken() async {
    final token = (await _storage.read(key: _accessTokenKey))?.trim() ?? '';
    if (token.isNotEmpty) {
      return token;
    }
    final legacy = (await _storage.read(key: _legacyJwtTokenKey))?.trim() ?? '';
    return legacy.isEmpty ? null : legacy;
  }

  Future<void> setAccessToken(String token) async {
    final value = token.trim();
    if (value.isEmpty) {
      return;
    }
    await _storage.write(key: _accessTokenKey, value: value);
    // Legacy compatibility with existing app/session key.
    await _storage.write(key: _legacyJwtTokenKey, value: value);
  }

  Future<void> deleteAccessToken() async {
    await _storage.delete(key: _accessTokenKey);
    await _storage.delete(key: _legacyJwtTokenKey);
  }

  // ── Refresh Token ──

  Future<String?> getRefreshToken() async {
    final value = (await _storage.read(key: _refreshTokenKey))?.trim() ?? '';
    return value.isEmpty ? null : value;
  }

  Future<void> setRefreshToken(String token) async {
    final value = token.trim();
    if (value.isEmpty) {
      return;
    }
    await _storage.write(key: _refreshTokenKey, value: value);
  }

  // ── User ID ──

  Future<String?> getUserId() async {
    return _storage.read(key: _userIdKey);
  }

  Future<void> setUserId(String id) async {
    await _storage.write(key: _userIdKey, value: id);
  }

  // ── Admin Token (Deprecated: Use Access Token) ──

  // ignore: unused_field
  static const _adminTokenKey = 'admin_jwt';

  Future<String?> getAdminToken() async {
    // Unified Auth: Admin uses the same token as customers
    return getAccessToken();
  }

  Future<void> setAdminToken(String token) async {
    await setAccessToken(token);
  }

  Future<void> deleteAdminToken() async {
    await deleteAccessToken();
  }

  // ── User Data ──

  static const _adminUserKey = 'admin_user_json';
  static const _customerUserKey = 'customer_user_json';
  static const _supportTicketsKey = 'support_tickets_v1';

  Future<String?> getAdminUserJson() async {
    return _storage.read(key: _adminUserKey);
  }

  Future<void> setAdminUserJson(String json) async {
    await _storage.write(key: _adminUserKey, value: json);
  }

  Future<void> deleteAdminUserJson() async {
    await _storage.delete(key: _adminUserKey);
  }

  Future<String?> getCustomerUserJson() async {
    return _storage.read(key: _customerUserKey);
  }

  Future<void> setCustomerUserJson(String json) async {
    await _storage.write(key: _customerUserKey, value: json);
  }

  Future<void> deleteCustomerUserJson() async {
    await _storage.delete(key: _customerUserKey);
  }

  Future<void> clearCustomerSession() async {
    await deleteAccessToken();
    await _storage.delete(key: _refreshTokenKey);
    await _storage.delete(key: _userIdKey);
    await deleteCustomerUserJson();
  }

  // ── Support Tickets (Guest-safe local secure storage) ──

  Future<String?> getSupportTicketsJson() async {
    return _storage.read(key: _supportTicketsKey);
  }

  Future<void> setSupportTicketsJson(String json) async {
    await _storage.write(key: _supportTicketsKey, value: json);
  }

  Future<void> deleteSupportTicketsJson() async {
    await _storage.delete(key: _supportTicketsKey);
  }

  // ── Clear all ──

  Future<void> clearAll() async {
    await _storage.deleteAll();
  }
}
