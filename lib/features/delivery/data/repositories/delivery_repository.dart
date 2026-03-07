import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/network/dio_client.dart';
import '../../../../core/utils/safe_parsers.dart';
import '../datasources/delivery_remote_datasource.dart';
import '../../domain/entities/delivery_entities.dart';

final deliveryRepositoryProvider = Provider<DeliveryRepository>((ref) {
  return DeliveryRepository(ref.read(deliveryRemoteDatasourceProvider));
});

class DeliveryRepository {
  final DeliveryRemoteDatasource _datasource;

  DeliveryRepository(this._datasource);

  static const _cacheKeyDashboard = 'delivery_dashboard_cache_v1';

  Future<DeliveryDashboardData> getDashboard() async {
    try {
      final profile = await _datasource.getMe();
      final ordersRaw = await _datasource.getOrders();

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _cacheKeyDashboard,
        jsonEncode({
          'profile': {
            'id': profile.id,
            'display_name': profile.displayName,
            'email': profile.email,
            'is_available': profile.isAvailable,
          },
          'orders_raw': ordersRaw,
        }),
      );

      return _parseDashboard(profile, ordersRaw);
    } catch (e) {
      final prefs = await SharedPreferences.getInstance();
      final cachedStr = prefs.getString(_cacheKeyDashboard);
      if (cachedStr != null) {
        try {
          final cached = jsonDecode(cachedStr) as Map<String, dynamic>;
          final profileMap = Map<String, dynamic>.from(
            cached['profile'] as Map,
          );
          final ordersRaw = Map<String, dynamic>.from(
            cached['orders_raw'] as Map,
          );
          return _parseDashboard(
            DeliveryAgentProfile.fromJson(profileMap),
            ordersRaw,
          );
        } catch (_) {} // ignore error, fallback to rethrow
      }
      rethrow;
    }
  }

  DeliveryDashboardData _parseDashboard(
    DeliveryAgentProfile profile,
    Map<String, dynamic> ordersRaw,
  ) {
    final items = extractList(ordersRaw['items'])
        .whereType<Map>()
        .map(
          (item) => DeliveryOrderCard.fromJson(
            item.map((key, value) => MapEntry(key.toString(), value)),
          ),
        )
        .toList(growable: false);

    final isAvailable = parseBool(ordersRaw['is_available']);
    final normalizedProfile = DeliveryAgentProfile(
      id: profile.id,
      displayName: profile.displayName,
      email: profile.email,
      isAvailable: isAvailable || profile.isAvailable,
    );

    return DeliveryDashboardData(
      profile: normalizedProfile,
      orders: items,
      page: parseInt(ordersRaw['page']) <= 0 ? 1 : parseInt(ordersRaw['page']),
      total: parseInt(ordersRaw['total']),
      totalPages: parseInt(ordersRaw['total_pages']) <= 0
          ? 1
          : parseInt(ordersRaw['total_pages']),
      totalCollectedToday: parseDouble(ordersRaw['total_collected_today']),
    );
  }

  Future<bool> setAvailability(bool isAvailable) {
    return _datasource.setAvailability(isAvailable);
  }

  Future<void> updateOrderStatus(
    int orderId, {
    required String status,
    String note = '',
  }) {
    return _datasource.updateOrderStatus(orderId, status: status, note: note);
  }

  Future<Map<String, dynamic>> collectCod(
    int orderId, {
    required String collectedAmount,
    String currency = 'SYP',
    String note = '',
  }) {
    return _datasource.collectCod(
      orderId,
      collectedAmount: collectedAmount,
      currency: currency,
      note: note,
    );
  }

  Future<Map<String, dynamic>> acceptAssignment(int orderId) {
    return _datasource.acceptAssignment(orderId);
  }

  Future<Map<String, dynamic>> declineAssignment(int orderId) {
    return _datasource.declineAssignment(orderId);
  }

  Future<Map<String, dynamic>> cancelAssignment(int orderId) {
    return _datasource.cancelAssignment(orderId);
  }

  Future<void> pingLocation({
    required double lat,
    required double lng,
    double? accuracy,
    double? heading,
    double? speed,
    String? deviceId,
  }) {
    return _datasource.pingLocation(
      lat: lat,
      lng: lng,
      accuracy: accuracy,
      heading: heading,
      speed: speed,
      deviceId: deviceId,
    );
  }
}
