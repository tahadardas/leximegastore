import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

final tokenStoreProvider = Provider<TokenStore>((ref) {
  return const TokenStore();
});

class TokenStore {
  static const String _accessTokenKey = 'access_token';
  static const String _refreshTokenKey = 'refresh_token';
  static const String _userRoleCacheKey = 'user_role_cache';
  static const String _lastLoginAtKey = 'last_login_at';
  static const String _legacyJwtKey = 'jwt_token';

  final FlutterSecureStorage _storage;

  const TokenStore({
    FlutterSecureStorage storage = const FlutterSecureStorage(
      aOptions: AndroidOptions(encryptedSharedPreferences: true),
    ),
  }) : _storage = storage;

  Future<void> saveAccessToken(String token) async {
    final value = token.trim();
    if (value.isEmpty) return;
    await _storage.write(key: _accessTokenKey, value: value);
    // Legacy compatibility with existing modules.
    await _storage.write(key: _legacyJwtKey, value: value);
  }

  Future<String?> readAccessToken() async {
    final token = (await _storage.read(key: _accessTokenKey))?.trim() ?? '';
    if (token.isNotEmpty) {
      return token;
    }
    final legacy = (await _storage.read(key: _legacyJwtKey))?.trim() ?? '';
    return legacy.isEmpty ? null : legacy;
  }

  Future<void> saveRefreshToken(String token) async {
    final value = token.trim();
    if (value.isEmpty) return;
    await _storage.write(key: _refreshTokenKey, value: value);
  }

  Future<String?> readRefreshToken() async {
    final value = (await _storage.read(key: _refreshTokenKey))?.trim() ?? '';
    return value.isEmpty ? null : value;
  }

  Future<void> saveUserRoleCache(String role) async {
    final value = role.trim();
    if (value.isEmpty) return;
    await _storage.write(key: _userRoleCacheKey, value: value);
  }

  Future<String?> readUserRoleCache() async {
    final value = (await _storage.read(key: _userRoleCacheKey))?.trim() ?? '';
    return value.isEmpty ? null : value;
  }

  Future<void> saveLastLoginAt(DateTime dateTime) async {
    await _storage.write(
      key: _lastLoginAtKey,
      value: dateTime.toIso8601String(),
    );
  }

  Future<String?> readLastLoginAt() async {
    final value = (await _storage.read(key: _lastLoginAtKey))?.trim() ?? '';
    return value.isEmpty ? null : value;
  }

  Future<void> clear() async {
    await _storage.delete(key: _accessTokenKey);
    await _storage.delete(key: _legacyJwtKey);
    await _storage.delete(key: _refreshTokenKey);
    await _storage.delete(key: _userRoleCacheKey);
    await _storage.delete(key: _lastLoginAtKey);
  }
}
