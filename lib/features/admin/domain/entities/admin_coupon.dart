class AdminCoupon {
  final int id;
  final String code;
  final String discountType; // 'percent', 'fixed_cart', 'fixed_product'
  final double amount;
  final String description;
  final DateTime? dateExpires;
  final int? usageLimit;
  final int usageCount;
  final double minimumAmount;
  final double maximumAmount;
  final bool individualUse;
  final bool excludeSaleItems;

  const AdminCoupon({
    required this.id,
    required this.code,
    required this.discountType,
    required this.amount,
    this.description = '',
    this.dateExpires,
    this.usageLimit,
    this.usageCount = 0,
    this.minimumAmount = 0.0,
    this.maximumAmount = 0.0,
    this.individualUse = false,
    this.excludeSaleItems = false,
  });

  factory AdminCoupon.fromJson(Map<String, dynamic> json) {
    return AdminCoupon(
      id: json['id'] as int,
      code: json['code'] as String,
      discountType: json['discount_type'] as String,
      amount: (json['amount'] as num).toDouble(),
      description: (json['description'] ?? '').toString(),
      dateExpires: json['date_expires'] != null
          ? DateTime.tryParse(json['date_expires'].toString())
          : null,
      usageLimit: json['usage_limit'] != null
          ? (json['usage_limit'] as num).toInt()
          : null,
      usageCount: (json['usage_count'] as num?)?.toInt() ?? 0,
      minimumAmount: (json['minimum_amount'] as num?)?.toDouble() ?? 0.0,
      maximumAmount: (json['maximum_amount'] as num?)?.toDouble() ?? 0.0,
      individualUse: json['individual_use'] == true,
      excludeSaleItems: json['exclude_sale_items'] == true,
    );
  }
}
