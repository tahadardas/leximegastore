import 'dart:math';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../config/constants/endpoints.dart';
import '../../core/network/dio_client.dart';

/// AI Tracker provider
final aiTrackerProvider = Provider<AITracker>((ref) {
  return AITracker(ref.watch(dioClientProvider));
});

/// AI Event Types
enum AIEventType {
  viewProduct('view_product'),
  viewCategory('view_category'),
  search('search'),
  addToCart('add_to_cart'),
  removeFromCart('remove_from_cart'),
  addWishlist('add_wishlist'),
  removeWishlist('remove_wishlist'),
  checkoutStart('checkout_start'),
  purchase('purchase');

  final String value;
  const AIEventType(this.value);
}

/// AI Tracker - Fire-and-forget event tracking
class AITracker {
  static const _deviceIdKey = 'lexi_ai_device_id';
  static const _sessionIdKey = 'lexi_ai_session_id';

  final DioClient _client;

  String? _deviceId;
  String? _sessionId;
  String? _city;

  AITracker(this._client);

  /// Initialize device ID and session ID
  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();

    // Get or create device ID
    _deviceId = prefs.getString(_deviceIdKey);
    if (_deviceId == null || _deviceId!.isEmpty) {
      _deviceId = _generateId();
      await prefs.setString(_deviceIdKey, _deviceId!);
    }

    // Create new session ID
    _sessionId = _generateId();
    await prefs.setString(_sessionIdKey, _sessionId!);
  }

  /// Set city for tracking
  void setCity(String? city) {
    _city = city;
  }

  /// Get device ID
  String? get deviceId => _deviceId;

  /// Get session ID
  String? get sessionId => _sessionId;

  /// Track an event - fire-and-forget
  void track({
    required AIEventType eventType,
    int? productId,
    int? categoryId,
    String? queryText,
    double? valueNum,
    Map<String, dynamic>? meta,
  }) {
    // Don't block UI - fire and forget
    _trackAsync(
      eventType: eventType,
      productId: productId,
      categoryId: categoryId,
      queryText: queryText,
      valueNum: valueNum,
      meta: meta,
    );
  }

  Future<void> _trackAsync({
    required AIEventType eventType,
    int? productId,
    int? categoryId,
    String? queryText,
    double? valueNum,
    Map<String, dynamic>? meta,
  }) async {
    try {
      // Ensure initialized
      if (_deviceId == null) {
        await init();
      }

      // Validate query text
      String? sanitizedQuery;
      if (queryText != null && queryText.trim().length >= 2) {
        sanitizedQuery = queryText.trim().substring(
          0,
          min(120, queryText.length),
        );
      }

      final payload = <String, dynamic>{
        'event_type': eventType.value,
        'device_id': _deviceId,
        'session_id': _sessionId,
        'city': _city,
      };

      if (productId != null) payload['product_id'] = productId;
      if (categoryId != null) payload['category_id'] = categoryId;
      if (sanitizedQuery != null) payload['query_text'] = sanitizedQuery;
      if (valueNum != null) payload['value_num'] = valueNum;
      if (meta != null) payload['meta'] = meta;

      await _client.post(
        Endpoints.aiTrack(),
        data: payload,
        options: Options(extra: const {'requiresAuth': false}),
      );
    } catch (_) {
      // Silent failure - tracking should never block user
    }
  }

  /// Track view product
  void viewProduct(int productId, {int? categoryId}) {
    track(
      eventType: AIEventType.viewProduct,
      productId: productId,
      categoryId: categoryId,
    );
  }

  /// Track view category
  void viewCategory(int categoryId) {
    track(eventType: AIEventType.viewCategory, categoryId: categoryId);
  }

  /// Track search
  void search(String query, {int? resultsCount}) {
    track(
      eventType: AIEventType.search,
      queryText: query,
      meta: resultsCount != null ? {'results_count': resultsCount} : null,
    );
  }

  /// Track add to cart
  void addToCart(int productId, {int? quantity, double? price}) {
    track(
      eventType: AIEventType.addToCart,
      productId: productId,
      valueNum: price,
      meta: quantity != null ? {'qty': quantity} : null,
    );
  }

  /// Track remove from cart
  void removeFromCart(int productId) {
    track(eventType: AIEventType.removeFromCart, productId: productId);
  }

  /// Track add to wishlist
  void addWishlist(int productId) {
    track(eventType: AIEventType.addWishlist, productId: productId);
  }

  /// Track remove from wishlist
  void removeWishlist(int productId) {
    track(eventType: AIEventType.removeWishlist, productId: productId);
  }

  /// Track checkout start
  void checkoutStart({double? total}) {
    track(eventType: AIEventType.checkoutStart, valueNum: total);
  }

  /// Track purchase
  void purchase(int orderId, {double? total}) {
    track(
      eventType: AIEventType.purchase,
      valueNum: total,
      meta: {'order_id': orderId},
    );
  }

  String _generateId() {
    final random = Random.secure();
    final partA = DateTime.now().microsecondsSinceEpoch.toRadixString(36);
    final partB = random.nextInt(1 << 32).toRadixString(36);
    final partC = random.nextInt(1 << 32).toRadixString(36);
    return '$partA-$partB-$partC';
  }
}
