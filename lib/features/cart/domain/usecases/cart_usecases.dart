import '../entities/cart_item.dart';
import '../repositories/cart_repository.dart';

/// Fetches the current cart items.
class GetCart {
  final CartRepository _repository;
  GetCart({required CartRepository repository}) : _repository = repository;

  Future<List<CartItem>> call() => _repository.getCart();
}

/// Adds an item to the cart (merges if duplicate).
class AddItemToCart {
  final CartRepository _repository;
  AddItemToCart({required CartRepository repository})
    : _repository = repository;

  Future<List<CartItem>> call(CartItem item) => _repository.addItem(item);
}

/// Removes an item from the cart by its [cartKey].
class RemoveItemFromCart {
  final CartRepository _repository;
  RemoveItemFromCart({required CartRepository repository})
    : _repository = repository;

  Future<List<CartItem>> call(String cartKey) =>
      _repository.removeItem(cartKey);
}

/// Updates the quantity of a cart item. Removes it if qty <= 0.
class UpdateCartItemQty {
  final CartRepository _repository;
  UpdateCartItemQty({required CartRepository repository})
    : _repository = repository;

  Future<List<CartItem>> call(String cartKey, int qty) =>
      _repository.updateQty(cartKey, qty);
}

/// Clears the entire cart.
class ClearCart {
  final CartRepository _repository;
  ClearCart({required CartRepository repository}) : _repository = repository;

  Future<List<CartItem>> call() => _repository.clearCart();
}
