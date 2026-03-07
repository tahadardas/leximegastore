import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

final deviceTokenStoreProvider = Provider<DeviceTokenStore>((ref) {
  return DeviceTokenStore();
});

class DeviceTokenStore {
  static const _deviceTokenKey = 'lexi_device_token';

  Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getString(_deviceTokenKey)?.trim() ?? '';
    return value.isEmpty ? null : value;
  }

  Future<void> setToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_deviceTokenKey, token.trim());
  }
}
