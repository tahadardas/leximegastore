import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/entities/cart_item.dart';

/// Local datasource for cart persistence via shared_preferences.
///
/// Maintains an in-memory cache for fast reads, with writes persisted
/// to shared_preferences as a JSON string.
class CartLocalDatasource {
  static const _storageKey = 'lexi_cart_items';

  /// In-memory cache ??" populated once on first [getItems] call.
  List<CartItem>? _cache;

  /// Load cart items from disk (or cache).
  Future<List<CartItem>> getItems() async {
    if (_cache != null) return List.of(_cache!);

    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);
    if (raw == null || raw.isEmpty) {
      _cache = [];
      return [];
    }

    _cache = CartItem.decodeList(raw);
    return List.of(_cache!);
  }

  /// Persist the current items list to disk and update cache.
  Future<void> saveItems(List<CartItem> items) async {
    _cache = List.of(items);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_storageKey, CartItem.encodeList(items));
  }

  /// Clear all cart data from disk and cache.
  Future<void> clear() async {
    _cache = [];
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_storageKey);
  }
}
