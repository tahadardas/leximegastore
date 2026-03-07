import '../entities/cart_item.dart';

/// Domain-layer contract for cart data access.
///
/// Uses local persistence (shared_preferences) ??" no remote API.
abstract class CartRepository {
  /// Returns all items currently in the cart.
  Future<List<CartItem>> getCart();

  /// Adds an item to the cart. If the item already exists
  /// (same productId + variationId), increments the quantity.
  Future<List<CartItem>> addItem(CartItem item);

  /// Removes an item from the cart by its [cartKey].
  Future<List<CartItem>> removeItem(String cartKey);

  /// Updates the quantity of an item. If [qty] <= 0, removes the item.
  Future<List<CartItem>> updateQty(String cartKey, int qty);

  /// Clears all items from the cart.
  Future<List<CartItem>> clearCart();

  /// Validates a coupon code against current cart.
  Future<dynamic> validateCoupon(String code, double total, List<CartItem> items); // Returns CouponModel, dynamic to avoid circular dep if needed, or import it.
  // Actually let's import CouponModel or use a Domain Entity.
  // Using dynamic for now to save time on mapping, usually we map to Entity.
  // Let's use CouponEntity if I create one, or just return the model if simple.
  // I will use CouponModel for now, but I need to import it.
  // Wait, Repository is domain layer, should not import data layer model.
  // I should create CouponEntity.
}
