import 'dart:convert';

import '../../../../core/utils/safe_parsers.dart';
import '../../../../core/utils/text_normalizer.dart';
import '../../../../core/utils/url_utils.dart';
import '../../../../features/cart/domain/entities/cart_item.dart';
import '../../../../features/payment/domain/entities/payment_method.dart';
import '../../../../features/payment/domain/entities/payment_proof.dart';
import 'order_address.dart';

class Order {
  final String id;
  final String orderNumber;
  final DateTime date;
  final String status;
  final double subtotal;
  final double shippingCost;
  final double total;
  final double? discountTotal;
  final double? tax;
  final double? finalTotal;
  final double? amountToCollect;
  final String? currency;
  final List<CartItem> items;
  final int? itemCount;
  final PaymentMethod? paymentMethod;
  final PaymentProof? paymentProof;
  final OrderAddress? billing;
  final OrderAddress? shipping;
  final String courierName;
  final String courierPhone;
  final String invoiceVerificationUrl;

  const Order({
    required this.id,
    required this.orderNumber,
    required this.date,
    required this.status,
    required this.subtotal,
    required this.shippingCost,
    required this.total,
    this.discountTotal,
    this.tax,
    this.finalTotal,
    this.amountToCollect,
    this.currency,
    required this.items,
    this.itemCount,
    this.paymentMethod,
    this.paymentProof,
    this.billing,
    this.shipping,
    this.courierName = '',
    this.courierPhone = '',
    this.invoiceVerificationUrl = '',
  });

  int get resolvedItemCount => itemCount ?? items.length;

  factory Order.fromJson(Map<String, dynamic> json) {
    final payload = _unwrap(json);
    final nestedOrder = _mapOrNull(payload['order']);
    final normalizedPayload = nestedOrder == null || nestedOrder.isEmpty
        ? payload
        : <String, dynamic>{...payload, ...nestedOrder};
    final parsedItems = _resolveItems(normalizedPayload);

    final dateRaw =
        normalizedPayload['date'] ??
        normalizedPayload['date_created'] ??
        normalizedPayload['created_at'] ??
        normalizedPayload['createdAt'];
    final currencyRaw = TextNormalizer.normalize(normalizedPayload['currency']);
    final orderId = TextNormalizer.normalize(
      normalizedPayload['id'] ?? normalizedPayload['order_id'],
    );
    final orderNumber = TextNormalizer.normalize(
      normalizedPayload['order_number'] ??
          normalizedPayload['orderNumber'] ??
          normalizedPayload['number'],
    );

    return Order(
      id: orderId,
      orderNumber: orderNumber.isNotEmpty ? orderNumber : orderId,
      date: _parseOrderDate(dateRaw),
      status: TextNormalizer.normalize(
        normalizedPayload['status'] ?? 'pending',
      ),
      subtotal: parseDouble(normalizedPayload['subtotal']),
      shippingCost: parseDouble(
        normalizedPayload['shipping_cost'] ??
            normalizedPayload['shipping_total'],
      ),
      total: parseDouble(normalizedPayload['total']),
      discountTotal: normalizedPayload['discount_total'] != null
          ? parseDouble(normalizedPayload['discount_total'])
          : null,
      tax: normalizedPayload['tax'] != null
          ? parseDouble(normalizedPayload['tax'])
          : null,
      finalTotal: normalizedPayload['final_total'] != null
          ? parseDouble(normalizedPayload['final_total'])
          : null,
      amountToCollect: normalizedPayload['amount_to_collect'] != null
          ? parseDouble(normalizedPayload['amount_to_collect'])
          : null,
      currency: currencyRaw.isEmpty ? null : currencyRaw,
      items: parsedItems,
      itemCount: _resolveItemCount(normalizedPayload, parsedItems),
      paymentMethod: _parsePaymentMethod(normalizedPayload['payment_method']),
      paymentProof: normalizedPayload['payment_proof'] is Map<String, dynamic>
          ? PaymentProof.fromJson(
              normalizedPayload['payment_proof'] as Map<String, dynamic>,
            )
          : normalizedPayload['payment_proof'] is Map
          ? PaymentProof.fromJson(
              (normalizedPayload['payment_proof'] as Map).map(
                (key, value) => MapEntry(key.toString(), value),
              ),
            )
          : null,
      billing: _mapOrNull(normalizedPayload['billing']) != null
          ? OrderAddress.fromJson(_mapOrNull(normalizedPayload['billing'])!)
          : null,
      shipping: _mapOrNull(normalizedPayload['shipping']) != null
          ? OrderAddress.fromJson(_mapOrNull(normalizedPayload['shipping'])!)
          : null,
      courierName: _resolveCourierName(normalizedPayload),
      courierPhone: _resolveCourierPhone(normalizedPayload),
      invoiceVerificationUrl: TextNormalizer.normalize(
        normalizedPayload['invoice_verification_url'] ??
            normalizedPayload['verification_url'],
      ),
    );
  }

  Order copyWith({
    String? id,
    String? orderNumber,
    DateTime? date,
    String? status,
    double? subtotal,
    double? shippingCost,
    double? total,
    double? discountTotal,
    double? tax,
    double? finalTotal,
    double? amountToCollect,
    String? currency,
    List<CartItem>? items,
    int? itemCount,
    PaymentMethod? paymentMethod,
    PaymentProof? paymentProof,
    OrderAddress? billing,
    OrderAddress? shipping,
    String? courierName,
    String? courierPhone,
    String? invoiceVerificationUrl,
  }) {
    return Order(
      id: id ?? this.id,
      orderNumber: orderNumber ?? this.orderNumber,
      date: date ?? this.date,
      status: status ?? this.status,
      subtotal: subtotal ?? this.subtotal,
      shippingCost: shippingCost ?? this.shippingCost,
      total: total ?? this.total,
      discountTotal: discountTotal ?? this.discountTotal,
      tax: tax ?? this.tax,
      finalTotal: finalTotal ?? this.finalTotal,
      amountToCollect: amountToCollect ?? this.amountToCollect,
      currency: currency ?? this.currency,
      items: items ?? this.items,
      itemCount: itemCount ?? this.itemCount,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      paymentProof: paymentProof ?? this.paymentProof,
      billing: billing ?? this.billing,
      shipping: shipping ?? this.shipping,
      courierName: courierName ?? this.courierName,
      courierPhone: courierPhone ?? this.courierPhone,
      invoiceVerificationUrl:
          invoiceVerificationUrl ?? this.invoiceVerificationUrl,
    );
  }

  static Map<String, dynamic> _unwrap(Map<String, dynamic> json) {
    final data = json['data'];
    if (data is Map<String, dynamic>) {
      return data;
    }
    if (data is Map) {
      return data.map((key, value) => MapEntry(key.toString(), value));
    }
    return json;
  }

  static List<CartItem> _resolveItems(Map<String, dynamic> payload) {
    final candidates = <dynamic>[
      payload['line_items'],
      payload['items'],
      payload['order_items'],
      payload['products'],
      payload['cart_items'],
    ];

    List<CartItem> best = const <CartItem>[];
    var bestQtyScore = -1;

    for (final candidate in candidates) {
      final parsed = _parseItems(candidate);
      if (parsed.isEmpty) {
        continue;
      }

      final qtyScore = parsed.fold<int>(
        0,
        (sum, item) => sum + (item.qty > 0 ? item.qty : 1),
      );

      if (parsed.length > best.length ||
          (parsed.length == best.length && qtyScore > bestQtyScore)) {
        best = parsed;
        bestQtyScore = qtyScore;
      }
    }

    return best;
  }

  static int? _resolveItemCount(
    Map<String, dynamic> payload,
    List<CartItem> items,
  ) {
    final rawCount = parseInt(
      payload['item_count'] ??
          payload['items_count'] ??
          payload['itemsCount'] ??
          payload['count'],
    );
    if (rawCount > 0) {
      return rawCount;
    }

    if (items.isEmpty) {
      return null;
    }

    final totalQty = items.fold<int>(
      0,
      (sum, item) => sum + (item.qty > 0 ? item.qty : 1),
    );
    return totalQty > 0 ? totalQty : items.length;
  }

  static DateTime _parseOrderDate(dynamic raw) {
    if (raw == null) {
      return DateTime.now();
    }

    if (raw is DateTime) {
      return raw;
    }

    if (raw is num) {
      final timestamp = raw.toInt();
      if (timestamp > 0) {
        final millis = timestamp > 1000000000000 ? timestamp : timestamp * 1000;
        return DateTime.fromMillisecondsSinceEpoch(millis);
      }
      return DateTime.now();
    }

    final text = raw.toString().trim();
    if (text.isEmpty) {
      return DateTime.now();
    }

    final parsed = DateTime.tryParse(text);
    if (parsed != null) {
      return parsed;
    }

    final asInt = parseInt(text);
    if (asInt > 0) {
      final millis = asInt > 1000000000000 ? asInt : asInt * 1000;
      return DateTime.fromMillisecondsSinceEpoch(millis);
    }

    return DateTime.now();
  }

  static List<CartItem> _parseItems(dynamic raw) {
    if (raw is Map) {
      final normalized = _mapOrNull(raw);
      if (normalized != null) {
        for (final key in const [
          'items',
          'line_items',
          'order_items',
          'products',
          'cart_items',
        ]) {
          final nestedParsed = _parseItems(normalized[key]);
          if (nestedParsed.isNotEmpty) {
            return nestedParsed;
          }
        }
      }
      return _parseItems(raw.values.toList(growable: false));
    }

    if (raw is String) {
      final text = raw.trim();
      if (text.isEmpty) {
        return const <CartItem>[];
      }
      try {
        return _parseItems(jsonDecode(text));
      } catch (_) {
        return const <CartItem>[];
      }
    }

    if (raw is! List) {
      return const <CartItem>[];
    }

    return raw
        .map<CartItem?>((item) {
          final map = _mapOrNull(item);
          if (map == null) {
            return null;
          }

          final product = _mapOrNull(map['product']);
          final qty = parseInt(map['qty'] ?? map['quantity'] ?? map['count']);
          final price = parseDouble(
            map['price'] ??
                map['unit_price'] ??
                map['unitPrice'] ??
                (qty > 0 ? parseDouble(map['subtotal']) / qty : 0.0),
          );

          // Extract variation label from meta_data if available
          String? variationLabel = map['variation_label']?.toString();
          if (variationLabel == null || variationLabel.isEmpty) {
            final metaData = map['meta_data'];
            if (metaData is List) {
              for (final meta in metaData) {
                if (meta is Map) {
                  final key = meta['key']?.toString().toLowerCase() ?? '';
                  if (key.contains('color') ||
                      key.contains('اللون') ||
                      key.startsWith('pa_')) {
                    variationLabel = meta['value']?.toString();
                    break;
                  }
                }
              }
            }
          }

          return CartItem(
            productId: parseInt(
              map['product_id'] ??
                  map['productId'] ??
                  map['id'] ??
                  product?['id'],
            ),
            variationId: parseInt(map['variation_id']) == 0
                ? null
                : parseInt(map['variation_id']),
            variationLabel: variationLabel,
            name: TextNormalizer.normalize(
              map['name'] ??
                  map['product_name'] ??
                  map['title'] ??
                  product?['name'],
            ),
            price: price,
            image: _resolveItemImage(map, product: product),
            qty: qty > 0 ? qty : 1,
            unitType: TextNormalizer.normalize(map['unit_type']),
            piecesCount: parseDouble(map['pieces_count']),
            discount: parseDouble(map['discount']),
            lineTotalOverride: parseDouble(
              map['line_total'] ?? map['total'] ?? map['subtotal'],
            ),
          );
        })
        .whereType<CartItem>()
        .toList();
  }

  static String _resolveItemImage(
    Map<String, dynamic> map, {
    Map<String, dynamic>? product,
  }) {
    final candidates = <dynamic>[
      map['image_url'],
      map['imageUrl'],
      map['thumbnail'],
      map['image_src'],
      map['image'],
      product?['image_url'],
      product?['imageUrl'],
      product?['thumbnail'],
      product?['image_src'],
      product?['image'],
      product?['images'],
    ];

    for (final candidate in candidates) {
      final resolved = _extractImageUrl(candidate);
      if (resolved.isNotEmpty) {
        return resolved;
      }
    }

    return '';
  }

  static String _extractImageUrl(dynamic raw) {
    if (raw == null) {
      return '';
    }

    if (raw is String) {
      return normalizeNullableHttpUrl(raw) ?? raw.trim();
    }

    if (raw is List) {
      for (final item in raw) {
        final resolved = _extractImageUrl(item);
        if (resolved.isNotEmpty) {
          return resolved;
        }
      }
      return '';
    }

    final map = _mapOrNull(raw);
    if (map == null) {
      return normalizeNullableHttpUrl(raw.toString()) ?? raw.toString().trim();
    }

    for (final key in const [
      'src',
      'url',
      'image_url',
      'imageUrl',
      'thumbnail',
      'thumb',
      'medium',
      'large',
      'full',
    ]) {
      final value = map[key];
      if (value == null) {
        continue;
      }
      final resolved =
          normalizeNullableHttpUrl(value.toString()) ?? value.toString().trim();
      if (resolved.isNotEmpty) {
        return resolved;
      }
    }

    for (final key in const ['sizes', 'image', 'images']) {
      final nested = _extractImageUrl(map[key]);
      if (nested.isNotEmpty) {
        return nested;
      }
    }

    return '';
  }

  static PaymentMethod? _parsePaymentMethod(dynamic raw) {
    if (raw == null) {
      return null;
    }

    final normalized = raw.toString().trim().toLowerCase();
    if (normalized.isEmpty) {
      return null;
    }

    if (normalized == 'cod') {
      return PaymentMethod.cod;
    }

    if (normalized == 'shamcash' ||
        normalized == 'sham_cash' ||
        normalized == 'sham-cash') {
      return PaymentMethod.shamCash;
    }

    return null;
  }

  static Map<String, dynamic>? _mapOrNull(dynamic raw) {
    if (raw is Map<String, dynamic>) {
      return raw;
    }

    if (raw is Map) {
      return raw.map((key, value) => MapEntry(key.toString(), value));
    }

    return null;
  }

  static String _resolveCourierName(Map<String, dynamic> payload) {
    final direct = _firstNonEmpty(payload, const [
      'courier_name',
      'delivery_agent_name',
      'assigned_courier_name',
      'assigned_agent_name',
      'delivery_name',
      'driver_name',
      'agent_name',
      'delivery_person_name',
    ]);
    if (direct.isNotEmpty) {
      return direct;
    }

    final nested = _extractCourierMap(payload);
    if (nested != null) {
      final fromNested = _firstNonEmpty(nested, const [
        'display_name',
        'name',
        'full_name',
        'title',
        'username',
      ]);
      if (fromNested.isNotEmpty) {
        return fromNested;
      }
    }

    return _resolveCourierMeta(payload, const [
      'courier_name',
      'delivery_agent_name',
      'assigned_courier_name',
      'assigned_agent_name',
      'driver_name',
      'agent_name',
    ]);
  }

  static String _resolveCourierPhone(Map<String, dynamic> payload) {
    final direct = _firstNonEmpty(payload, const [
      'courier_phone',
      'delivery_agent_phone',
      'assigned_courier_phone',
      'assigned_agent_phone',
      'delivery_phone',
      'driver_phone',
      'agent_phone',
      'delivery_person_phone',
    ]);
    if (direct.isNotEmpty) {
      return direct;
    }

    final nested = _extractCourierMap(payload);
    if (nested != null) {
      final fromNested = _firstNonEmpty(nested, const [
        'phone',
        'mobile',
        'mobile_number',
        'phone_number',
      ]);
      if (fromNested.isNotEmpty) {
        return fromNested;
      }
    }

    return _resolveCourierMeta(payload, const [
      'courier_phone',
      'delivery_agent_phone',
      'assigned_courier_phone',
      'assigned_agent_phone',
      'driver_phone',
      'agent_phone',
    ]);
  }

  static Map<String, dynamic>? _extractCourierMap(
    Map<String, dynamic> payload,
  ) {
    for (final key in const [
      'courier',
      'delivery_agent',
      'assigned_courier',
      'assigned_agent',
      'courier_assignment',
      'delivery_person',
      'driver',
    ]) {
      final map = _mapOrNull(payload[key]);
      if (map != null && map.isNotEmpty) {
        return map;
      }
    }
    return null;
  }

  static String _resolveCourierMeta(
    Map<String, dynamic> payload,
    List<String> expectedKeys,
  ) {
    final candidates = <dynamic>[
      payload['meta_data'],
      payload['meta'],
      payload['metadata'],
    ];

    for (final candidate in candidates) {
      if (candidate is! List) {
        continue;
      }

      for (final rawMeta in candidate) {
        final meta = _mapOrNull(rawMeta);
        if (meta == null || meta.isEmpty) {
          continue;
        }

        final rawKey = TextNormalizer.normalize(
          meta['key'] ?? meta['meta_key'] ?? meta['name'],
        ).toLowerCase();
        if (rawKey.isEmpty) {
          continue;
        }

        if (!expectedKeys.contains(rawKey)) {
          continue;
        }

        final value = TextNormalizer.normalize(
          meta['value'] ?? meta['meta_value'] ?? meta['data'],
        );
        if (value.isNotEmpty) {
          return value;
        }
      }
    }

    return '';
  }

  static String _firstNonEmpty(
    Map<String, dynamic> payload,
    List<String> keys,
  ) {
    for (final key in keys) {
      final value = TextNormalizer.normalize(payload[key]);
      if (value.isNotEmpty) {
        return value;
      }
    }
    return '';
  }
}
