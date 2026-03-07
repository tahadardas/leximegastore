import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/admin_coupon.dart';
import '../datasources/admin_coupons_datasource.dart';

final adminCouponsRepositoryProvider = Provider<AdminCouponsRepository>((ref) {
  return AdminCouponsRepository(ref.read(adminCouponsRemoteDatasourceProvider));
});

class AdminCouponsRepository {
  final AdminCouponsRemoteDatasource _datasource;

  AdminCouponsRepository(this._datasource);

  Future<List<AdminCoupon>> getCoupons() {
    return _datasource.getCoupons();
  }

  Future<AdminCoupon> createCoupon({
    required String code,
    required String discountType,
    required double amount,
    String? description,
    DateTime? dateExpires,
    int? usageLimit,
    double? minimumAmount,
    double? maximumAmount,
    bool individualUse = false,
    bool excludeSaleItems = false,
  }) {
    final data = <String, dynamic>{
      'code': code,
      'discount_type': discountType,
      'amount': amount,
      'individual_use': individualUse,
      'exclude_sale_items': excludeSaleItems,
    };

    if (description != null) data['description'] = description;
    if (dateExpires != null) {
      data['date_expires'] = dateExpires.toIso8601String();
    }
    if (usageLimit != null) data['usage_limit'] = usageLimit;
    if (minimumAmount != null) data['minimum_amount'] = minimumAmount;
    if (maximumAmount != null) data['maximum_amount'] = maximumAmount;

    return _datasource.createCoupon(data);
  }

  Future<AdminCoupon> updateCoupon(
    int id, {
    String? code,
    String? discountType,
    double? amount,
    String? description,
    DateTime? dateExpires,
    // Using nullable wrapper logic here would be overkill given the simple update nature,
    // but typically we'd send only what's changed.
    // For simplicity, we just send non-null values.
    int? usageLimit,
    double? minimumAmount,
    double? maximumAmount,
    bool? individualUse,
    bool? excludeSaleItems,
    bool clearDateExpires = false,
  }) {
    final data = <String, dynamic>{};
    if (code != null) data['code'] = code;
    if (discountType != null) data['discount_type'] = discountType;
    if (amount != null) data['amount'] = amount;
    if (description != null) data['description'] = description;
    if (dateExpires != null) {
      data['date_expires'] = dateExpires.toIso8601String();
    } else if (clearDateExpires) {
      data['date_expires'] = ''; // Send empty to clear on backend
    }
    if (usageLimit != null) data['usage_limit'] = usageLimit;
    if (minimumAmount != null) data['minimum_amount'] = minimumAmount;
    if (maximumAmount != null) data['maximum_amount'] = maximumAmount;
    if (individualUse != null) data['individual_use'] = individualUse;
    if (excludeSaleItems != null) data['exclude_sale_items'] = excludeSaleItems;

    return _datasource.updateCoupon(id, data);
  }

  Future<void> deleteCoupon(int id) {
    return _datasource.deleteCoupon(id);
  }
}
