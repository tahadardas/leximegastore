import '../../domain/entities/cart_item.dart';
import '../../domain/repositories/cart_repository.dart';
import '../datasources/cart_local_datasource.dart';
import '../datasources/cart_remote_datasource.dart';

/// Concrete implementation of [CartRepository] using local persistence.
class CartRepositoryImpl implements CartRepository {
  final CartLocalDatasource _localDatasource;
  final CartRemoteDatasource _remoteDatasource;

  CartRepositoryImpl({
    required CartLocalDatasource localDatasource,
    required CartRemoteDatasource remoteDatasource,
  })  : _localDatasource = localDatasource,
        _remoteDatasource = remoteDatasource;

  @override
  Future<List<CartItem>> getCart() => _localDatasource.getItems();

  @override
  Future<List<CartItem>> addItem(CartItem item) async {
    final items = await _localDatasource.getItems();

    // Check if same product+variation already exists
    final existingIndex = items.indexWhere((e) => e.cartKey == item.cartKey);

    if (existingIndex >= 0) {
      // Increment quantity
      items[existingIndex].qty += item.qty;
    } else {
      items.add(item);
    }

    await _localDatasource.saveItems(items);
    return List.of(items);
  }

  @override
  Future<List<CartItem>> removeItem(String cartKey) async {
    final items = await _localDatasource.getItems();
    items.removeWhere((e) => e.cartKey == cartKey);
    await _localDatasource.saveItems(items);
    return List.of(items);
  }

  @override
  Future<List<CartItem>> updateQty(String cartKey, int qty) async {
    final items = await _localDatasource.getItems();

    if (qty <= 0) {
      items.removeWhere((e) => e.cartKey == cartKey);
    } else {
      final index = items.indexWhere((e) => e.cartKey == cartKey);
      if (index >= 0) {
        items[index].qty = qty;
      }
    }

    await _localDatasource.saveItems(items);
    return List.of(items);
  }

  @override
  Future<List<CartItem>> clearCart() async {
    await _localDatasource.clear();
    return [];
  }

  @override
  Future<dynamic> validateCoupon(String code, double total, List<CartItem> items) {
    return _remoteDatasource.validateCoupon(code, total, items);
  }
}
