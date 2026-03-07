import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/admin_intel_repository.dart';
import '../../domain/entities/admin_intel_models.dart';

final adminIntelOverviewRangeProvider = StateProvider<String>((ref) => 'today');
final adminIntelTrendingRangeProvider = StateProvider<String>((ref) => '24h');
final adminIntelInsightsRangeProvider = StateProvider<String>((ref) => '7d');
final adminIntelSelectedBundleProductIdProvider = StateProvider<int?>(
  (ref) => null,
);

final adminIntelRefreshControllerProvider =
    NotifierProvider<AdminIntelRefreshController, int>(
      AdminIntelRefreshController.new,
    );

class AdminIntelRefreshController extends Notifier<int> {
  @override
  int build() => 0;

  Future<void> refreshAll() async {
    ref.read(adminIntelRepositoryProvider).clearCache();
    state++;
  }
}

final adminIntelOverviewProvider =
    FutureProvider.autoDispose<AdminIntelOverview>((ref) async {
      ref.watch(adminIntelRefreshControllerProvider);
      final range = ref.watch(adminIntelOverviewRangeProvider);
      return ref
          .watch(adminIntelRepositoryProvider)
          .getOverview(range: range, forceRefresh: false);
    });

final adminIntelOverviewByRangeProvider = FutureProvider.family
    .autoDispose<AdminIntelOverview, String>((ref, range) async {
      ref.watch(adminIntelRefreshControllerProvider);
      return ref
          .watch(adminIntelRepositoryProvider)
          .getOverview(range: range, forceRefresh: false);
    });

final adminIntelTrendingProvider =
    FutureProvider.autoDispose<List<AdminIntelTrendingProduct>>((ref) async {
      ref.watch(adminIntelRefreshControllerProvider);
      final range = ref.watch(adminIntelTrendingRangeProvider);
      return ref
          .watch(adminIntelRepositoryProvider)
          .getTrendingProducts(range: range, limit: 20, forceRefresh: false);
    });

final adminIntelOpportunitiesProvider =
    FutureProvider.autoDispose<List<AdminIntelOpportunity>>((ref) async {
      ref.watch(adminIntelRefreshControllerProvider);
      final range = ref.watch(adminIntelInsightsRangeProvider);
      return ref
          .watch(adminIntelRepositoryProvider)
          .getOpportunities(range: range, limit: 30, forceRefresh: false);
    });

final adminIntelWishlistTopProvider =
    FutureProvider.autoDispose<List<AdminIntelWishlistItem>>((ref) async {
      ref.watch(adminIntelRefreshControllerProvider);
      final range = ref.watch(adminIntelInsightsRangeProvider);
      return ref
          .watch(adminIntelRepositoryProvider)
          .getWishlistTop(range: range, limit: 30, forceRefresh: false);
    });

final adminIntelSearchProvider =
    FutureProvider.autoDispose<AdminIntelSearchData>((ref) async {
      ref.watch(adminIntelRefreshControllerProvider);
      final range = ref.watch(adminIntelInsightsRangeProvider);
      return ref
          .watch(adminIntelRepositoryProvider)
          .getSearchIntelligence(range: range, limit: 50, forceRefresh: false);
    });

final adminIntelBundlesProvider =
    FutureProvider.autoDispose<AdminIntelBundlesData>((ref) async {
      ref.watch(adminIntelRefreshControllerProvider);
      final productId = ref.watch(adminIntelSelectedBundleProductIdProvider);
      if (productId == null || productId <= 0) {
        return const AdminIntelBundlesData(
          productId: 0,
          productName: '',
          withProducts: <AdminIntelBundleItem>[],
        );
      }
      return ref
          .watch(adminIntelRepositoryProvider)
          .getBundles(
            productId: productId,
            range: '30d',
            limit: 10,
            forceRefresh: false,
          );
    });

final adminIntelStockAlertsProvider =
    FutureProvider.autoDispose<AdminIntelStockAlertsData>((ref) async {
      ref.watch(adminIntelRefreshControllerProvider);
      return ref
          .watch(adminIntelRepositoryProvider)
          .getStockAlerts(forceRefresh: false);
    });

final adminIntelActionsControllerProvider =
    Provider<AdminIntelActionsController>(
      (ref) => AdminIntelActionsController(ref),
    );

class AdminIntelActionsController {
  final Ref _ref;

  AdminIntelActionsController(this._ref);

  Future<AdminIntelActionResult> createOfferDraftForProduct({
    required int productId,
    required String productName,
  }) async {
    return _ref
        .read(adminIntelRepositoryProvider)
        .createOfferDraft(
          titleAr: 'عرض تجريبي: $productName',
          productIds: <int>[productId],
          type: 'flash',
        );
  }

  Future<AdminIntelActionResult> pinHome({
    required int productId,
    required String section,
  }) async {
    return _ref
        .read(adminIntelRepositoryProvider)
        .pinHome(productId: productId, section: section);
  }

  void selectBundleProduct(int productId) {
    _ref.read(adminIntelSelectedBundleProductIdProvider.notifier).state =
        productId;
  }
}
