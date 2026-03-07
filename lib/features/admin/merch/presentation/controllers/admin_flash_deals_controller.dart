import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/admin_merch_product.dart';
import '../../../../admin/merch/data/repositories/admin_merch_repository.dart';

final adminFlashDealsControllerProvider =
    AsyncNotifierProvider<AdminFlashDealsController, List<AdminMerchProduct>>(
        AdminFlashDealsController.new);

class AdminFlashDealsController
    extends AsyncNotifier<List<AdminMerchProduct>> {
  @override
  Future<List<AdminMerchProduct>> build() {
    return _fetch();
  }

  Future<List<AdminMerchProduct>> _fetch() async {
    return ref.read(adminMerchRepositoryProvider).getFlashDeals();
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(_fetch);
  }

  Future<void> scheduleDeal({
    required int productId,
    required double salePrice,
    required DateTime startsAt,
    required DateTime endsAt,
  }) async {
    state = const AsyncLoading();
    try {
      await ref.read(adminMerchRepositoryProvider).scheduleFlashDeal(
            productId: productId,
            salePrice: salePrice,
            startsAt: startsAt,
            endsAt: endsAt,
          );
      state = await AsyncValue.guard(_fetch);
    } catch (e, st) {
      state = AsyncError(e, st);
      rethrow;
    }
  }

  Future<void> cancelDeal(int productId) async {
    state = const AsyncLoading();
    try {
      // Sending sale_price 0 or null cancels the deal in our backend implementation
      await ref.read(adminMerchRepositoryProvider).scheduleFlashDeal(
            productId: productId,
            salePrice: 0,
            startsAt: DateTime.now(),
            endsAt: DateTime.now().add(const Duration(minutes: 1)),
          );
      state = await AsyncValue.guard(_fetch);
    } catch (e, st) {
      state = AsyncError(e, st);
      rethrow;
    }
  }
}

