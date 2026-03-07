import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../config/constants/endpoints.dart';
import '../../../../../core/network/dio_client.dart';
import '../../../../../core/network/dio_exception_mapper.dart';
import '../../domain/entities/admin_intel_models.dart';

final adminIntelRemoteDatasourceProvider = Provider<AdminIntelRemoteDatasource>(
  (ref) {
    return AdminIntelRemoteDatasource(ref.watch(dioClientProvider));
  },
);

class AdminIntelRemoteDatasource {
  final DioClient _client;

  AdminIntelRemoteDatasource(this._client);

  Future<AdminIntelOverview> getOverview({required String range}) async {
    try {
      final response = await _client.get(
        Endpoints.adminIntelOverview(),
        queryParameters: {'range': range},
      );
      return AdminIntelOverview.fromJson(
        extractMap(extractData(response.data)),
      );
    } on DioException catch (e) {
      throw DioExceptionMapper.fromDioException(e);
    }
  }

  Future<List<AdminIntelTrendingProduct>> getTrendingProducts({
    required String range,
    required int limit,
  }) async {
    try {
      final response = await _client.get(
        Endpoints.adminIntelTrendingProducts(),
        queryParameters: {'range': range, 'limit': limit},
      );
      final list = _extractRows(response.data);
      return list
          .map(AdminIntelTrendingProduct.fromJson)
          .toList(growable: false);
    } on DioException catch (e) {
      throw DioExceptionMapper.fromDioException(e);
    }
  }

  Future<List<AdminIntelOpportunity>> getOpportunities({
    required String range,
    required int limit,
  }) async {
    try {
      final response = await _client.get(
        Endpoints.adminIntelOpportunities(),
        queryParameters: {'range': range, 'limit': limit},
      );
      final list = _extractRows(response.data);
      return list.map(AdminIntelOpportunity.fromJson).toList(growable: false);
    } on DioException catch (e) {
      throw DioExceptionMapper.fromDioException(e);
    }
  }

  Future<List<AdminIntelWishlistItem>> getWishlistTop({
    required String range,
    required int limit,
  }) async {
    try {
      final response = await _client.get(
        Endpoints.adminIntelWishlistTop(),
        queryParameters: {'range': range, 'limit': limit},
      );
      final list = _extractRows(response.data);
      return list.map(AdminIntelWishlistItem.fromJson).toList(growable: false);
    } on DioException catch (e) {
      throw DioExceptionMapper.fromDioException(e);
    }
  }

  Future<AdminIntelSearchData> getSearchIntelligence({
    required String range,
    required int limit,
  }) async {
    try {
      final response = await _client.get(
        Endpoints.adminIntelSearch(),
        queryParameters: {'range': range, 'limit': limit},
      );
      return AdminIntelSearchData.fromJson(
        extractMap(extractData(response.data)),
      );
    } on DioException catch (e) {
      throw DioExceptionMapper.fromDioException(e);
    }
  }

  Future<AdminIntelBundlesData> getBundles({
    required String range,
    required int productId,
    required int limit,
  }) async {
    try {
      final response = await _client.get(
        Endpoints.adminIntelBundles(),
        queryParameters: {
          'range': range,
          'product_id': productId,
          'limit': limit,
        },
      );
      return AdminIntelBundlesData.fromJson(
        extractMap(extractData(response.data)),
      );
    } on DioException catch (e) {
      throw DioExceptionMapper.fromDioException(e);
    }
  }

  Future<AdminIntelStockAlertsData> getStockAlerts() async {
    try {
      final response = await _client.get(Endpoints.adminIntelStockAlerts());
      return AdminIntelStockAlertsData.fromJson(
        extractMap(extractData(response.data)),
      );
    } on DioException catch (e) {
      throw DioExceptionMapper.fromDioException(e);
    }
  }

  Future<AdminIntelActionResult> createOfferDraft({
    required String titleAr,
    required List<int> productIds,
    String type = 'flash',
    String? startAt,
    String? endAt,
  }) async {
    try {
      final response = await _client.post(
        Endpoints.adminIntelCreateOfferDraft(),
        data: {
          'title_ar': titleAr,
          'product_ids': productIds,
          'type': type,
          if ((startAt ?? '').trim().isNotEmpty) 'start_at': startAt,
          if ((endAt ?? '').trim().isNotEmpty) 'end_at': endAt,
        },
      );
      return AdminIntelActionResult.fromJson(
        extractMap(extractData(response.data)),
      );
    } on DioException catch (e) {
      throw DioExceptionMapper.fromDioException(e);
    }
  }

  Future<AdminIntelActionResult> pinHome({
    required int productId,
    required String section,
  }) async {
    try {
      final response = await _client.post(
        Endpoints.adminIntelPinHome(),
        data: {'product_id': productId, 'section': section},
      );
      return AdminIntelActionResult.fromJson(
        extractMap(extractData(response.data)),
      );
    } on DioException catch (e) {
      throw DioExceptionMapper.fromDioException(e);
    }
  }

  List<Map<String, dynamic>> _extractRows(dynamic responseData) {
    final raw = extractData(responseData);
    if (raw is List) {
      return raw
          .map((e) => e is Map<String, dynamic> ? e : extractMap(e))
          .toList(growable: false);
    }
    final wrapped = extractList(responseData);
    return wrapped
        .map((e) => e is Map<String, dynamic> ? e : extractMap(e))
        .toList(growable: false);
  }
}
