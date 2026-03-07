import '../../../../core/utils/safe_parsers.dart';

class AdminIntelStats {
  final int sessions;
  final int productViews;
  final int addToCart;
  final int checkoutStart;
  final int purchases;
  final double revenue;
  final double conversionRate;
  final double addToCartRate;
  final double checkoutRate;
  final double avgOrderValue;

  AdminIntelStats({
    required this.sessions,
    required this.productViews,
    required this.addToCart,
    required this.checkoutStart,
    required this.purchases,
    required this.revenue,
    required this.conversionRate,
    required this.addToCartRate,
    required this.checkoutRate,
    required this.avgOrderValue,
  });

  factory AdminIntelStats.fromJson(Map<String, dynamic> json) {
    return AdminIntelStats(
      sessions: parseInt(json['sessions']),
      productViews: parseInt(json['product_views']),
      addToCart: parseInt(json['add_to_cart']),
      checkoutStart: parseInt(json['checkout_start']),
      purchases: parseInt(json['purchases']),
      revenue: parseDouble(json['revenue']),
      conversionRate: parseDouble(json['conversion_rate']),
      addToCartRate: parseDouble(json['add_to_cart_rate']),
      checkoutRate: parseDouble(json['checkout_rate']),
      avgOrderValue: parseDouble(json['avg_order_value']),
    );
  }
}
