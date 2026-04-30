import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../config/constants/endpoints.dart';
import '../../../../core/errors/arabic_error_mapper.dart';
import '../../../../core/network/dio_client.dart';
import '../../data/models/product_model.dart';
import '../../domain/entities/product_entity.dart';
import '../../domain/entities/product_extras.dart';
import '../../domain/entities/product_mapper.dart';
import 'product_details_controller.dart';

final productExtrasApiProvider = Provider<ProductExtrasApi>((ref) {
  return ProductExtrasApi(ref.watch(dioClientProvider));
});

final productDetailsExtrasProvider = FutureProvider.family
    .autoDispose<ProductDetailsExtras, int>((ref, id) async {
      final product = await ref.watch(
        productDetailsControllerProvider(id.toString()).future,
      );
      return ref
          .read(productExtrasApiProvider)
          .fetchExtras(id, includeVariations: product.isVariable);
    });

final similarProductsProvider = FutureProvider.family
    .autoDispose<List<ProductEntity>, int>((ref, id) async {
      return ref.read(productExtrasApiProvider).fetchSimilar(id);
    });

class ProductExtrasApi {
  final DioClient _client;

  ProductExtrasApi(this._client);

  Future<ProductDetailsExtras> fetchExtras(
    int productId, {
    bool includeVariations = true,
  }) async {
    List<ProductVariationOption> variations = const [];
    List<ProductReviewItem> reviews = const [];

    if (includeVariations) {
      try {
        final details = await _client.get(
          Endpoints.productById(productId.toString()),
          options: Options(extra: const {'requiresAuth': false}),
        );
        final detailsMap = extractMap(details.data);
        final variationsRaw =
            detailsMap['variations'] ??
            extractMap(detailsMap['data'])['variations'] ??
            const <dynamic>[];
        if (variationsRaw is List) {
          variations = variationsRaw
              .whereType<Map>()
              .map(
                (e) => ProductVariationOption.fromJson(
                  e.map((key, value) => MapEntry(key.toString(), value)),
                ),
              )
              .where((e) => e.id > 0)
              .toList();
        }
      } catch (_) {
        // Keep fallback empty variation list.
      }
    }

    try {
      final response = await _client.get(
        Endpoints.productReviews(productId.toString()),
        options: Options(extra: const {'requiresAuth': false}),
      );
      final rows = extractList(response.data);
      reviews = rows
          .whereType<Map>()
          .map(
            (e) => ProductReviewItem.fromJson(
              e.map((key, value) => MapEntry(key.toString(), value)),
            ),
          )
          .toList();
    } on DioException catch (e) {
      if ((e.response?.statusCode ?? 0) == 404) {
        reviews = const [];
      } else {
        rethrow;
      }
    }

    return ProductDetailsExtras(variations: variations, reviews: reviews);
  }

  Future<List<ProductEntity>> fetchSimilar(int productId) async {
    try {
      final response = await _client.get(
        Endpoints.productSimilar(productId.toString()),
        options: Options(extra: const {'requiresAuth': false}),
      );
      final rows = extractList(response.data);
      return rows
          .whereType<Map>()
          .map(
            (e) => ProductModel.fromJson(
              e.map((key, value) => MapEntry(key.toString(), value)),
            ),
          )
          .map((model) => model.toEntity())
          .toList();
    } on DioException catch (e) {
      if ((e.response?.statusCode ?? 0) == 404) {
        return const [];
      }
      rethrow;
    }
  }

  Future<String?> submitReview({
    required int productId,
    required int rating,
    required String review,
  }) async {
    try {
      await _client.post(
        Endpoints.productReviews(productId.toString()),
        options: Options(extra: const {'requiresAuth': true}),
        data: {
          'rating': rating,
          'content': review.trim(),
          'comment': review.trim(),
          'review': review.trim(),
        },
      );
      return null;
    } catch (e) {
      return ArabicErrorMapper.map(
        e,
        fallback: 'تعذر إرسال التقييم حالياً. حاول لاحقاً.',
      );
    }
  }
}
