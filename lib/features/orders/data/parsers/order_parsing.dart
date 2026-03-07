import 'package:flutter/foundation.dart';

import '../../domain/entities/order.dart';

const int _isolateThreshold = 40;

Future<List<Order>> parseOrdersInBackground(
  List<Map<String, dynamic>> rawItems,
) async {
  if (rawItems.length < _isolateThreshold || kIsWeb) {
    return _parseOrders(rawItems);
  }

  return compute(_parseOrdersEntryPoint, rawItems);
}

@pragma('vm:entry-point')
List<Order> _parseOrdersEntryPoint(List<Map<String, dynamic>> rawItems) {
  return _parseOrders(rawItems);
}

List<Order> _parseOrders(List<Map<String, dynamic>> rawItems) {
  return rawItems.map(Order.fromJson).toList(growable: false);
}
