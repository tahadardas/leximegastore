import 'package:flutter_test/flutter_test.dart';

import 'package:lexi_mega_store/features/orders/domain/entities/order.dart';

void main() {
  test('Order.fromJson parses item_count when items are absent', () {
    final order = Order.fromJson({
      'id': 100,
      'order_number': '100',
      'status': 'processing',
      'total': 35000,
      'subtotal': 30000,
      'shipping_cost': 5000,
      'date_created': '2026-02-12T10:30:00+03:00',
      'item_count': 3,
      'items': [],
    });

    expect(order.itemCount, 3);
    expect(order.resolvedItemCount, 3);
  });
}
