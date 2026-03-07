import '../../../../../core/utils/safe_parsers.dart';
import '../../../../../core/utils/text_normalizer.dart';

class AdminIntelOverview {
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

  const AdminIntelOverview({
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

  factory AdminIntelOverview.fromJson(Map<String, dynamic> json) {
    return AdminIntelOverview(
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

class AdminIntelTrendingProduct {
  final int productId;
  final String name;
  final String image;
  final double price;
  final int views;
  final int addToCart;
  final int wishlistAdd;
  final int purchases;
  final int score;

  const AdminIntelTrendingProduct({
    required this.productId,
    required this.name,
    required this.image,
    required this.price,
    required this.views,
    required this.addToCart,
    required this.wishlistAdd,
    required this.purchases,
    required this.score,
  });

  factory AdminIntelTrendingProduct.fromJson(Map<String, dynamic> json) {
    return AdminIntelTrendingProduct(
      productId: parseInt(json['product_id']),
      name: TextNormalizer.normalize(json['name']),
      image: (json['image'] ?? '').toString(),
      price: parseDouble(json['price']),
      views: parseInt(json['views']),
      addToCart: parseInt(json['add_to_cart']),
      wishlistAdd: parseInt(json['wishlist_add']),
      purchases: parseInt(json['purchases']),
      score: parseInt(json['score']),
    );
  }
}

class AdminIntelOpportunity {
  final int productId;
  final String name;
  final String image;
  final double price;
  final int views;
  final int addToCart;
  final int purchases;
  final double conversionRate;
  final String suggestedActionAr;

  const AdminIntelOpportunity({
    required this.productId,
    required this.name,
    required this.image,
    required this.price,
    required this.views,
    required this.addToCart,
    required this.purchases,
    required this.conversionRate,
    required this.suggestedActionAr,
  });

  factory AdminIntelOpportunity.fromJson(Map<String, dynamic> json) {
    return AdminIntelOpportunity(
      productId: parseInt(json['product_id']),
      name: TextNormalizer.normalize(json['name']),
      image: (json['image'] ?? '').toString(),
      price: parseDouble(json['price']),
      views: parseInt(json['views']),
      addToCart: parseInt(json['add_to_cart']),
      purchases: parseInt(json['purchases']),
      conversionRate: parseDouble(json['conversion_rate']),
      suggestedActionAr: TextNormalizer.normalize(json['suggested_action_ar']),
    );
  }
}

class AdminIntelWishlistItem {
  final int productId;
  final String name;
  final String image;
  final double price;
  final int favoritesCount;

  const AdminIntelWishlistItem({
    required this.productId,
    required this.name,
    required this.image,
    required this.price,
    required this.favoritesCount,
  });

  factory AdminIntelWishlistItem.fromJson(Map<String, dynamic> json) {
    return AdminIntelWishlistItem(
      productId: parseInt(json['product_id']),
      name: TextNormalizer.normalize(json['name']),
      image: (json['image'] ?? '').toString(),
      price: parseDouble(json['price']),
      favoritesCount: parseInt(json['favorites_count']),
    );
  }
}

class AdminIntelSearchQuery {
  final String query;
  final int searches;
  final int zeroResults;

  const AdminIntelSearchQuery({
    required this.query,
    required this.searches,
    required this.zeroResults,
  });

  factory AdminIntelSearchQuery.fromJson(Map<String, dynamic> json) {
    return AdminIntelSearchQuery(
      query: TextNormalizer.normalize(json['query']),
      searches: parseInt(json['searches']),
      zeroResults: parseInt(json['zero_results']),
    );
  }
}

class AdminIntelSearchData {
  final List<AdminIntelSearchQuery> topQueries;
  final List<AdminIntelSearchQuery> zeroResultQueries;

  const AdminIntelSearchData({
    required this.topQueries,
    required this.zeroResultQueries,
  });

  factory AdminIntelSearchData.fromJson(Map<String, dynamic> json) {
    final top = (json['top_queries'] as List? ?? const <dynamic>[])
        .map((e) => AdminIntelSearchQuery.fromJson(_asMap(e)))
        .toList(growable: false);
    final zero = (json['zero_result_queries'] as List? ?? const <dynamic>[])
        .map((e) => AdminIntelSearchQuery.fromJson(_asMap(e)))
        .toList(growable: false);
    return AdminIntelSearchData(topQueries: top, zeroResultQueries: zero);
  }
}

class AdminIntelBundleItem {
  final int id;
  final String name;
  final String image;
  final int count;

  const AdminIntelBundleItem({
    required this.id,
    required this.name,
    required this.image,
    required this.count,
  });

  factory AdminIntelBundleItem.fromJson(Map<String, dynamic> json) {
    return AdminIntelBundleItem(
      id: parseInt(json['id']),
      name: TextNormalizer.normalize(json['name']),
      image: (json['image'] ?? '').toString(),
      count: parseInt(json['count']),
    );
  }
}

class AdminIntelBundlesData {
  final int productId;
  final String productName;
  final List<AdminIntelBundleItem> withProducts;

  const AdminIntelBundlesData({
    required this.productId,
    required this.productName,
    required this.withProducts,
  });

  factory AdminIntelBundlesData.fromJson(Map<String, dynamic> json) {
    final rows = (json['with_products'] as List? ?? const <dynamic>[])
        .map((e) => AdminIntelBundleItem.fromJson(_asMap(e)))
        .toList(growable: false);
    return AdminIntelBundlesData(
      productId: parseInt(json['product_id']),
      productName: TextNormalizer.normalize(json['product_name']),
      withProducts: rows,
    );
  }
}

class AdminIntelStockItem {
  final int productId;
  final String name;
  final String image;
  final double price;
  final int stockQty;
  final int lowStockThreshold;
  final int views7d;

  const AdminIntelStockItem({
    required this.productId,
    required this.name,
    required this.image,
    required this.price,
    required this.stockQty,
    required this.lowStockThreshold,
    required this.views7d,
  });

  factory AdminIntelStockItem.fromJson(Map<String, dynamic> json) {
    return AdminIntelStockItem(
      productId: parseInt(json['product_id']),
      name: TextNormalizer.normalize(json['name']),
      image: (json['image'] ?? '').toString(),
      price: parseDouble(json['price']),
      stockQty: parseInt(json['stock_qty']),
      lowStockThreshold: parseInt(json['low_stock_threshold']),
      views7d: parseInt(json['views_7d']),
    );
  }
}

class AdminIntelStockAlertsData {
  final List<AdminIntelStockItem> outOfStock;
  final List<AdminIntelStockItem> lowStock;
  final List<AdminIntelStockItem> highDemandLowStock;

  const AdminIntelStockAlertsData({
    required this.outOfStock,
    required this.lowStock,
    required this.highDemandLowStock,
  });

  factory AdminIntelStockAlertsData.fromJson(Map<String, dynamic> json) {
    final out = (json['out_of_stock'] as List? ?? const <dynamic>[])
        .map((e) => AdminIntelStockItem.fromJson(_asMap(e)))
        .toList(growable: false);
    final low = (json['low_stock'] as List? ?? const <dynamic>[])
        .map((e) => AdminIntelStockItem.fromJson(_asMap(e)))
        .toList(growable: false);
    final high = (json['high_demand_low_stock'] as List? ?? const <dynamic>[])
        .map((e) => AdminIntelStockItem.fromJson(_asMap(e)))
        .toList(growable: false);
    return AdminIntelStockAlertsData(
      outOfStock: out,
      lowStock: low,
      highDemandLowStock: high,
    );
  }
}

class AdminIntelActionResult {
  final String message;
  final int offerId;
  final String section;
  final int sectionId;
  final int productId;

  const AdminIntelActionResult({
    required this.message,
    this.offerId = 0,
    this.section = '',
    this.sectionId = 0,
    this.productId = 0,
  });

  factory AdminIntelActionResult.fromJson(Map<String, dynamic> json) {
    return AdminIntelActionResult(
      message: TextNormalizer.normalize(json['message']),
      offerId: parseInt(json['offer_id']),
      section: TextNormalizer.normalize(json['section']),
      sectionId: parseInt(json['section_id']),
      productId: parseInt(json['product_id']),
    );
  }
}

Map<String, dynamic> _asMap(dynamic value) {
  if (value is Map<String, dynamic>) {
    return value;
  }
  if (value is Map) {
    return value.map((key, val) => MapEntry(key.toString(), val));
  }
  return const <String, dynamic>{};
}
