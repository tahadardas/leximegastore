import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/repositories/admin_coupons_repository.dart';
import '../../domain/entities/admin_coupon.dart';

final adminCouponsControllerProvider =
    AsyncNotifierProvider<AdminCouponsController, List<AdminCoupon>>(() {
      return AdminCouponsController();
    });

class AdminCouponsController extends AsyncNotifier<List<AdminCoupon>> {
  @override
  FutureOr<List<AdminCoupon>> build() {
    return _fetchCoupons();
  }

  Future<List<AdminCoupon>> _fetchCoupons() async {
    final repository = ref.read(adminCouponsRepositoryProvider);
    return repository.getCoupons();
  }

  Future<void> createCoupon({
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
  }) async {
    final repository = ref.read(adminCouponsRepositoryProvider);
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      await repository.createCoupon(
        code: code,
        discountType: discountType,
        amount: amount,
        description: description,
        dateExpires: dateExpires,
        usageLimit: usageLimit,
        minimumAmount: minimumAmount,
        maximumAmount: maximumAmount,
        individualUse: individualUse,
        excludeSaleItems: excludeSaleItems,
      );
      return _fetchCoupons();
    });
  }

  Future<void> updateCoupon(
    int id, {
    String? code,
    String? discountType,
    double? amount,
    String? description,
    DateTime? dateExpires,
    bool clearDateExpires = false,
    int? usageLimit,
    double? minimumAmount,
    double? maximumAmount,
    bool? individualUse,
    bool? excludeSaleItems,
  }) async {
    final repository = ref.read(adminCouponsRepositoryProvider);
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      await repository.updateCoupon(
        id,
        code: code,
        discountType: discountType,
        amount: amount,
        description: description,
        dateExpires: dateExpires,
        clearDateExpires: clearDateExpires,
        usageLimit: usageLimit,
        minimumAmount: minimumAmount,
        maximumAmount: maximumAmount,
        individualUse: individualUse,
        excludeSaleItems: excludeSaleItems,
      );
      return _fetchCoupons();
    });
  }

  Future<void> deleteCoupon(int id) async {
    final repository = ref.read(adminCouponsRepositoryProvider);
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      await repository.deleteCoupon(id);
      return _fetchCoupons();
    });
  }
}
