import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/ai/ai_tracker.dart';
import '../../../../core/network/dio_client.dart';
import '../../data/datasources/cart_local_datasource.dart';
import '../../data/datasources/cart_remote_datasource.dart';
import '../../data/models/coupon_model.dart';
import '../../data/repositories/cart_repository_impl.dart';
import '../../domain/entities/cart_item.dart';
import '../../domain/repositories/cart_repository.dart';
import '../../domain/usecases/cart_usecases.dart';

// "?"? Datasource "?"?
final cartLocalDatasourceProvider = Provider<CartLocalDatasource>((ref) {
  return CartLocalDatasource();
});

final cartRemoteDatasourceProvider = Provider<CartRemoteDatasource>((ref) {
  return CartRemoteDatasource(ref.watch(dioClientProvider));
});

// "?"? Repository "?"?
final cartRepositoryProvider = Provider<CartRepository>((ref) {
  return CartRepositoryImpl(
    localDatasource: ref.watch(cartLocalDatasourceProvider),
    remoteDatasource: ref.watch(cartRemoteDatasourceProvider),
  );
});

// "?"? Use cases "?"?
final getCartUseCaseProvider = Provider<GetCart>((ref) {
  return GetCart(repository: ref.watch(cartRepositoryProvider));
});

final addItemToCartUseCaseProvider = Provider<AddItemToCart>((ref) {
  return AddItemToCart(repository: ref.watch(cartRepositoryProvider));
});

final removeItemFromCartUseCaseProvider = Provider<RemoveItemFromCart>((ref) {
  return RemoveItemFromCart(repository: ref.watch(cartRepositoryProvider));
});

final updateCartItemQtyUseCaseProvider = Provider<UpdateCartItemQty>((ref) {
  return UpdateCartItemQty(repository: ref.watch(cartRepositoryProvider));
});

final clearCartUseCaseProvider = Provider<ClearCart>((ref) {
  return ClearCart(repository: ref.watch(cartRepositoryProvider));
});

// "?"? Cart State "?"?

/// Immutable snapshot of cart state with computed totals.
class CartState {
  final List<CartItem> items;
  final CouponModel? appliedCoupon;
  final bool isCouponApplying;

  const CartState({
    this.items = const [],
    this.appliedCoupon,
    this.isCouponApplying = false,
  });

  /// Total number of individual items (sum of all quantities).
  int get totalQty => items.fold(0, (sum, e) => sum + e.qty);

  /// Number of distinct line items.
  int get lineCount => items.length;

  /// Cart subtotal before shipping/tax.
  double get subtotal => items.fold(0, (sum, e) => sum + e.lineTotal);

  /// Discount amount from coupon
  double get discountAmount {
    if (appliedCoupon == null) return 0;
    // For simplicity, we use the amount returned by backend.
    // Ideally we should re-calculate if percent.
    // But for now, let's treat it as fixed check.
    // If backend returns validated amount for THIS cart, it's correct at moment of application.
    return appliedCoupon!.discountAmount;
  }

  /// Final total after discount
  double get total => (subtotal - discountAmount).clamp(0, double.infinity);

  /// Whether the cart is empty.
  bool get isEmpty => items.isEmpty;

  /// Whether the cart has items.
  bool get isNotEmpty => items.isNotEmpty;

  CartState copyWith({
    List<CartItem>? items,
    CouponModel? appliedCoupon,
    bool? isCouponApplying,
    bool clearCoupon = false,
  }) {
    return CartState(
      items: items ?? this.items,
      appliedCoupon: clearCoupon ? null : (appliedCoupon ?? this.appliedCoupon),
      isCouponApplying: isCouponApplying ?? this.isCouponApplying,
    );
  }
}

// "?"? Controller "?"?

/// Cart controller managing local cart state with computed totals.
///
/// Usage in widgets:
/// ```dart
/// final cart = ref.watch(cartControllerProvider);
/// Text('${cart.totalQty} ع?صر');
/// Text('${cart.subtotal} ل.س');
/// ```
final cartControllerProvider = AsyncNotifierProvider<CartController, CartState>(
  CartController.new,
);

class CartController extends AsyncNotifier<CartState> {
  bool _disposed = false;

  @override
  Future<CartState> build() async {
    _disposed = false;
    ref.onDispose(() => _disposed = true);
    final items = await ref.read(getCartUseCaseProvider)();
    return CartState(items: items);
  }

  /// Add a product to the cart.
  Future<void> addItem(CartItem item) async {
    final updated = await ref.read(addItemToCartUseCaseProvider)(item);
    if (_disposed) {
      return;
    }

    final current = state.valueOrNull ?? const CartState();
    state = AsyncData(
      current.copyWith(
        items: updated,
        clearCoupon: true, // Clear coupon on cart change to avoid invalid state
      ),
    );

    ref
        .read(aiTrackerProvider)
        .addToCart(item.productId, quantity: item.qty, price: item.price);
  }

  /// Remove an item from the cart.
  Future<void> removeItem(String cartKey) async {
    // Track remove
    final item = state.valueOrNull?.items
        .where((element) => element.cartKey == cartKey)
        .firstOrNull;

    final updated = await ref.read(removeItemFromCartUseCaseProvider)(cartKey);
    if (_disposed) {
      return;
    }

    final current = state.valueOrNull ?? const CartState();
    state = AsyncData(current.copyWith(items: updated, clearCoupon: true));

    if (item != null) {
      ref.read(aiTrackerProvider).removeFromCart(item.productId);
    }
  }

  /// Update the quantity of a cart item.
  Future<void> updateQty(String cartKey, int qty) async {
    final updated = await ref.read(updateCartItemQtyUseCaseProvider)(
      cartKey,
      qty,
    );
    if (_disposed) {
      return;
    }

    final current = state.valueOrNull ?? const CartState();
    state = AsyncData(current.copyWith(items: updated, clearCoupon: true));
  }

  /// Increment the quantity of a cart item by 1.
  Future<void> increment(String cartKey) async {
    final current = state.valueOrNull;
    if (current == null) return;
    final item = current.items.where((e) => e.cartKey == cartKey).firstOrNull;
    if (item == null) return;
    await updateQty(cartKey, item.qty + 1);
  }

  /// Decrement the quantity of a cart item by 1.
  /// Removes the item if qty reaches 0.
  Future<void> decrement(String cartKey) async {
    final current = state.valueOrNull;
    if (current == null) return;
    final item = current.items.where((e) => e.cartKey == cartKey).firstOrNull;
    if (item == null) return;
    await updateQty(cartKey, item.qty - 1);
  }

  /// Clear the entire cart.
  Future<void> clearCart() async {
    await ref.read(clearCartUseCaseProvider)();
    if (_disposed) {
      return;
    }
    state = const AsyncData(CartState());
  }

  /// Apply a coupon code
  Future<void> applyCoupon(String code) async {
    final currentState = state.valueOrNull;
    if (currentState == null || currentState.isEmpty) return;

    state = AsyncData(currentState.copyWith(isCouponApplying: true));

    try {
      final coupon = await ref
          .read(cartRepositoryProvider)
          .validateCoupon(code, currentState.subtotal, currentState.items);

      if (coupon.isValid) {
        if (_disposed) {
          return;
        }
        final latest = state.valueOrNull ?? currentState;
        state = AsyncData(
          latest.copyWith(isCouponApplying: false, appliedCoupon: coupon),
        );
      } else {
        // Handle valid=false but no error thrown (logic error)
        if (!_disposed) {
          final latest = state.valueOrNull ?? currentState;
          state = AsyncData(latest.copyWith(isCouponApplying: false));
        }
        throw Exception(coupon.message);
      }
    } catch (e) {
      if (!_disposed) {
        final latest = state.valueOrNull ?? currentState;
        state = AsyncData(latest.copyWith(isCouponApplying: false));
      }
      rethrow; // UI should catch and show toast
    }
  }

  /// Remove applied coupon
  void removeCoupon() {
    final currentState = state.value;
    if (currentState == null) return;
    state = AsyncData(currentState.copyWith(clearCoupon: true));
  }
}
