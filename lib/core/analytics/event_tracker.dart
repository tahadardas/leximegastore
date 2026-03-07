import 'dart:math';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../config/constants/endpoints.dart';
import '../network/dio_client.dart';

final eventTrackerProvider = Provider<AppEventTracker>((ref) {
  return AppEventTracker(ref.watch(dioClientProvider));
});

class AppEventTracker {
  static const _deviceIdKey = 'lexi_evt_device_id_v1';
  static const _sessionIdKey = 'lexi_evt_session_id_v1';

  final DioClient _client;

  AppEventTracker(this._client);

  Future<void> track({
    required String eventType,
    int? productId,
    int? categoryId,
    String? queryText,
    int? resultsCount,
    double? valueNum,
    String? city,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final deviceId = await _readOrCreateId(prefs, _deviceIdKey);
      final sessionId = await _readOrCreateId(prefs, _sessionIdKey);

      final payload = <String, dynamic>{
        'event_type': eventType.trim(),
        'device_id': deviceId,
        'session_id': sessionId,
      };

      if ((productId ?? 0) > 0) {
        payload['product_id'] = productId;
      }
      if ((categoryId ?? 0) > 0) {
        payload['category_id'] = categoryId;
      }
      final q = (queryText ?? '').trim();
      if (q.isNotEmpty) {
        payload['query_text'] = q;
      }
      if (resultsCount != null && resultsCount >= 0) {
        payload['results_count'] = resultsCount;
      }
      if (valueNum != null) {
        payload['value_num'] = valueNum;
      }
      final cityValue = (city ?? '').trim();
      if (cityValue.isNotEmpty) {
        payload['city'] = cityValue;
      }

      await _client.post(
        Endpoints.eventsTrack(),
        data: payload,
        options: Options(extra: const {'requiresAuth': false}),
      );
    } catch (_) {
      // Event tracking is best-effort and must never block user flows.
    }
  }

  Future<String> _readOrCreateId(SharedPreferences prefs, String key) async {
    final existing = (prefs.getString(key) ?? '').trim();
    if (existing.isNotEmpty) {
      return existing;
    }

    final created = _newId();
    await prefs.setString(key, created);
    return created;
  }

  String _newId() {
    final random = Random.secure();
    final partA = DateTime.now().microsecondsSinceEpoch.toRadixString(36);
    final partB = random.nextInt(1 << 32).toRadixString(36);
    final partC = random.nextInt(1 << 32).toRadixString(36);
    return '$partA-$partB-$partC';
  }
}
