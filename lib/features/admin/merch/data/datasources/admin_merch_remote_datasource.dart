import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../config/constants/endpoints.dart';
import '../../../../../core/network/dio_client.dart';
import '../../domain/entities/admin_ad_banner.dart';
import '../../domain/entities/admin_home_section.dart';
import '../../domain/entities/admin_merch_category.dart';
import '../../domain/entities/admin_merch_product.dart';
import '../../domain/entities/admin_review.dart';

final adminMerchRemoteDatasourceProvider = Provider<AdminMerchRemoteDatasource>(
  (ref) {
    return AdminMerchRemoteDatasource(ref.watch(dioClientProvider));
  },
);

class AdminMerchRemoteDatasource {
  final DioClient _client;

  AdminMerchRemoteDatasource(this._client);

  Future<List<AdminMerchCategory>> getCategories() async {
    final response = await _client.get(Endpoints.adminMerchCategories());
    final data = extractMap(response.data);
    final rows = extractList(data['items']);
    return rows
        .whereType<Map>()
        .map(
          (row) => AdminMerchCategory.fromJson(Map<String, dynamic>.from(row)),
        )
        .toList();
  }

  Future<void> saveCategoriesOrder(List<AdminMerchCategory> items) async {
    await _client.patch(
      Endpoints.adminMerchCategories(),
      data: {'items': items.map((item) => item.toOrderJson()).toList()},
    );
  }

  Future<List<AdminMerchProduct>> getCategoryProducts({
    required int termId,
    String search = '',
    int page = 1,
    int perPage = 200,
  }) async {
    final response = await _client.get(
      Endpoints.adminMerchCategoryProducts(),
      queryParameters: {
        'term_id': termId,
        'search': search,
        'page': page,
        'per_page': perPage,
      },
    );

    final data = extractMap(response.data);
    final rows = extractList(data['items']);
    return rows
        .whereType<Map>()
        .map(
          (row) => AdminMerchProduct.fromJson(Map<String, dynamic>.from(row)),
        )
        .toList();
  }

  Future<void> saveCategoryProducts({
    required int termId,
    required List<AdminMerchProduct> items,
    bool replaceAll = false,
  }) async {
    await _client.patch(
      Endpoints.adminMerchCategoryProductsBulk(),
      data: {
        'term_id': termId,
        'replace_all': replaceAll,
        'items': List.generate(
          items.length,
          (index) => items[index].toPatchJson(index + 1),
        ),
      },
      options: Options(contentType: Headers.jsonContentType),
    );
  }

  Future<List<AdminHomeSection>> getHomeSections() async {
    final response = await _client.get(Endpoints.adminMerchHomeSections());
    final data = extractMap(response.data);
    final rows = extractList(data['items']);

    return rows
        .whereType<Map>()
        .map((row) => AdminHomeSection.fromJson(Map<String, dynamic>.from(row)))
        .toList();
  }

  Future<void> createHomeSection({
    required String titleAr,
    required String type,
    int? termId,
    bool isActive = true,
  }) async {
    await _client.post(
      Endpoints.adminMerchHomeSections(),
      data: {
        'title_ar': titleAr,
        'type': type,
        'term_id': ?termId,
        'is_active': isActive,
      },
    );
  }

  Future<void> updateHomeSection(
    int id, {
    String? titleAr,
    String? type,
    int? termId,
    bool? isActive,
    int? sortOrder,
  }) async {
    await _client.patch(
      Endpoints.adminMerchHomeSection(id),
      data: {
        'title_ar': ?titleAr,
        'type': ?type,
        'term_id': ?termId,
        'is_active': ?isActive,
        'sort_order': ?sortOrder,
      },
    );
  }

  Future<void> deleteHomeSection(int id) async {
    await _client.delete(Endpoints.adminMerchHomeSection(id));
  }

  Future<void> reorderHomeSections(List<AdminHomeSection> items) async {
    await _client.patch(
      Endpoints.adminMerchHomeSectionsReorder(),
      data: {
        'items': List.generate(
          items.length,
          (index) => {'id': items[index].id, 'sort_order': index + 1},
        ),
      },
    );
  }

  Future<List<AdminMerchProduct>> getHomeSectionItems(int sectionId) async {
    final response = await _client.get(
      Endpoints.adminMerchHomeSectionItems(sectionId),
    );
    final data = extractMap(response.data);
    final rows = extractList(data['items']);

    return rows
        .whereType<Map>()
        .map(
          (row) => AdminMerchProduct.fromJson(Map<String, dynamic>.from(row)),
        )
        .toList();
  }

  Future<void> saveHomeSectionItems({
    required int sectionId,
    required List<AdminMerchProduct> items,
  }) async {
    final payload = {
      'items': List.generate(
        items.length,
        (index) => items[index].toPatchJson(index + 1),
      ),
    };

    try {
      await _client.patch(
        Endpoints.adminMerchHomeSectionItems(sectionId),
        data: payload,
      );
    } on DioException {
      // Some hosts/proxies are stricter with PATCH. Route accepts EDITABLE,
      // so POST is a safe fallback.
      await _client.post(
        Endpoints.adminMerchHomeSectionItems(sectionId),
        data: payload,
      );
    }
  }

  Future<List<AdminAdBanner>> getAdBanners() async {
    final response = await _client.get(Endpoints.adminMerchAdBanners());
    final data = extractMap(response.data);
    final rows = extractList(data['items']);
    return rows
        .whereType<Map>()
        .map((row) => AdminAdBanner.fromJson(Map<String, dynamic>.from(row)))
        .toList();
  }

  Future<void> saveAdBanners(List<AdminAdBanner> items) async {
    final payload = {
      'items': List.generate(
        items.length,
        (index) => items[index].toJson(index + 1),
      ),
    };

    try {
      await _client.patch(Endpoints.adminMerchAdBanners(), data: payload);
    } on DioException {
      // Some hosts/proxies are stricter with PATCH. Route accepts EDITABLE,
      // so POST is a safe fallback.
      await _client.post(Endpoints.adminMerchAdBanners(), data: payload);
    }
  }

  Future<List<AdminMerchProduct>> getFlashDeals() async {
    final response = await _client.get(Endpoints.adminMerchDeals());
    final data = extractMap(response.data);
    final rows = extractList(data['items']);
    return rows
        .whereType<Map>()
        .map(
          (row) => AdminMerchProduct.fromJson(Map<String, dynamic>.from(row)),
        )
        .toList();
  }

  Future<void> scheduleFlashDeal({
    required int productId,
    required double salePrice,
    required DateTime startsAt,
    required DateTime endsAt,
  }) async {
    await _client.post(
      Endpoints.adminMerchDealsSchedule(),
      data: {
        'product_id': productId,
        'sale_price': salePrice,
        'date_from': startsAt.toIso8601String(),
        'date_to': endsAt.toIso8601String(),
      },
    );
  }

  Future<List<AdminReview>> getReviews({
    required String status,
    int page = 1,
    int perPage = 50,
  }) async {
    final response = await _client.get(
      Endpoints.adminMerchReviews(),
      queryParameters: {'status': status, 'page': page, 'per_page': perPage},
    );

    final data = extractMap(response.data);
    final rows = extractList(data['items']);
    return rows
        .whereType<Map>()
        .map((row) => AdminReview.fromJson(Map<String, dynamic>.from(row)))
        .toList();
  }

  Future<void> updateReviewStatus({
    required int id,
    required String status,
  }) async {
    await _client.patch(
      Endpoints.adminMerchReview(id),
      data: {'status': status},
    );
  }
}
