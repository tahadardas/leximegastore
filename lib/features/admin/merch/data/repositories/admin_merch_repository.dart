import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/admin_ad_banner.dart';
import '../../domain/entities/admin_home_section.dart';
import '../../domain/entities/admin_merch_category.dart';
import '../../domain/entities/admin_merch_product.dart';
import '../../domain/entities/admin_review.dart';
import '../datasources/admin_merch_remote_datasource.dart';

final adminMerchRepositoryProvider = Provider<AdminMerchRepository>((ref) {
  return AdminMerchRepository(ref.watch(adminMerchRemoteDatasourceProvider));
});

class AdminMerchRepository {
  final AdminMerchRemoteDatasource _remote;

  AdminMerchRepository(this._remote);

  Future<List<AdminMerchCategory>> getCategories() => _remote.getCategories();

  Future<void> saveCategoriesOrder(List<AdminMerchCategory> items) {
    return _remote.saveCategoriesOrder(items);
  }

  Future<List<AdminMerchProduct>> getCategoryProducts({
    required int termId,
    String search = '',
    int page = 1,
    int perPage = 200,
  }) {
    return _remote.getCategoryProducts(
      termId: termId,
      search: search,
      page: page,
      perPage: perPage,
    );
  }

  Future<void> saveCategoryProducts({
    required int termId,
    required List<AdminMerchProduct> items,
    bool replaceAll = false,
  }) {
    return _remote.saveCategoryProducts(
      termId: termId,
      items: items,
      replaceAll: replaceAll,
    );
  }

  Future<List<AdminHomeSection>> getHomeSections() => _remote.getHomeSections();

  Future<void> createHomeSection({
    required String titleAr,
    required String type,
    int? termId,
    bool isActive = true,
  }) {
    return _remote.createHomeSection(
      titleAr: titleAr,
      type: type,
      termId: termId,
      isActive: isActive,
    );
  }

  Future<void> updateHomeSection(
    int id, {
    String? titleAr,
    String? type,
    int? termId,
    bool? isActive,
    int? sortOrder,
  }) {
    return _remote.updateHomeSection(
      id,
      titleAr: titleAr,
      type: type,
      termId: termId,
      isActive: isActive,
      sortOrder: sortOrder,
    );
  }

  Future<void> deleteHomeSection(int id) => _remote.deleteHomeSection(id);

  Future<void> reorderHomeSections(List<AdminHomeSection> items) {
    return _remote.reorderHomeSections(items);
  }

  Future<List<AdminMerchProduct>> getHomeSectionItems(int sectionId) {
    return _remote.getHomeSectionItems(sectionId);
  }

  Future<void> saveHomeSectionItems({
    required int sectionId,
    required List<AdminMerchProduct> items,
  }) {
    return _remote.saveHomeSectionItems(sectionId: sectionId, items: items);
  }

  Future<List<AdminAdBanner>> getAdBanners() => _remote.getAdBanners();

  Future<void> saveAdBanners(List<AdminAdBanner> items) {
    return _remote.saveAdBanners(items);
  }

  Future<List<AdminMerchProduct>> getFlashDeals() => _remote.getFlashDeals();

  Future<void> scheduleFlashDeal({
    required int productId,
    required double salePrice,
    required DateTime startsAt,
    required DateTime endsAt,
  }) {
    return _remote.scheduleFlashDeal(
      productId: productId,
      salePrice: salePrice,
      startsAt: startsAt,
      endsAt: endsAt,
    );
  }

  Future<List<AdminReview>> getReviews({required String status, int page = 1}) {
    return _remote.getReviews(status: status, page: page);
  }

  Future<void> updateReviewStatus({required int id, required String status}) {
    return _remote.updateReviewStatus(id: id, status: status);
  }
}
