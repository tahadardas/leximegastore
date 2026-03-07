import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../config/constants/endpoints.dart';
import '../../core/network/dio_client.dart';
import '../../core/utils/safe_parsers.dart';
import '../../core/utils/text_normalizer.dart';
import '../product/data/models/product_model.dart';
import '../product/domain/entities/product_entity.dart';
import '../product/domain/entities/product_mapper.dart';
import 'search_query_normalizer.dart';

final searchApiProvider = Provider<SearchApi>((ref) {
  return SearchApi(ref.watch(dioClientProvider));
});

class SearchApi {
  final DioClient _client;

  SearchApi(this._client);

  Future<SearchSuggestPayload> suggest(
    String query, {
    int limit = 10,
    CancelToken? cancelToken,
  }) async {
    final normalized = sanitizeSearchDisplayText(query);
    if (normalized.length < 2) {
      return const SearchSuggestPayload();
    }

    try {
      final response = await _getWithFallback(
        primaryPath: Endpoints.searchSuggestions(),
        fallbackPath: Endpoints.searchSuggest(),
        queryParameters: {'q': normalized, 'limit': limit.clamp(1, 20)},
        options: Options(extra: const {'requiresAuth': false}),
        cancelToken: cancelToken,
      );

      final root = extractMap(response.data);
      final payload = _extractPayload(root);

      final suggestionsRaw = payload['suggestions'];
      final productsRaw = payload['products'];
      final categoriesRaw = payload['categories'];

      final suggestions = _parseSuggestions(
        raw: suggestionsRaw,
        fallbackHighlight: normalized,
      );

      final products = productsRaw is List
          ? productsRaw
                .whereType<Map>()
                .map(
                  (item) => SearchSuggestionProduct.fromJson(
                    item.map((k, v) => MapEntry(k.toString(), v)),
                  ),
                )
                .toList(growable: false)
          : const <SearchSuggestionProduct>[];

      final categories = categoriesRaw is List
          ? categoriesRaw
                .whereType<Map>()
                .map(
                  (item) => SearchSuggestionCategory.fromJson(
                    item.map((k, v) => MapEntry(k.toString(), v)),
                  ),
                )
                .toList(growable: false)
          : const <SearchSuggestionCategory>[];

      return SearchSuggestPayload(
        suggestions: suggestions,
        products: products,
        categories: categories,
      );
    } on DioException catch (e) {
      if (e.type == DioExceptionType.badResponse &&
          (e.response?.statusCode == 404 || e.response?.statusCode == 401)) {
        return const SearchSuggestPayload();
      }
      rethrow;
    } catch (_) {
      return const SearchSuggestPayload();
    }
  }

  Future<SearchResultsPage> search({
    required String query,
    int page = 1,
    int perPage = 20,
    String? sort,
    double? minPrice,
    double? maxPrice,
    bool? inStock,
    int? categoryId,
    CancelToken? cancelToken,
  }) async {
    final normalized = sanitizeSearchDisplayText(query);
    if (normalized.isEmpty) {
      return SearchResultsPage.empty(page: page, perPage: perPage);
    }

    final queryParameters = <String, dynamic>{
      'q': normalized,
      'page': page,
      'limit': perPage,
      'per_page': perPage,
      'sort': (sort ?? '').trim().isEmpty ? null : sort!.trim(),
      'min_price': minPrice,
      'max_price': maxPrice,
      'in_stock': inStock == null ? null : (inStock ? 1 : 0),
      'category_id': (categoryId ?? 0) > 0 ? categoryId : null,
    }..removeWhere((_, value) => value == null);

    try {
      final response = await _getWithFallback(
        primaryPath: Endpoints.searchProducts(),
        fallbackPath: Endpoints.search(),
        queryParameters: queryParameters,
        options: Options(extra: const {'requiresAuth': false}),
        cancelToken: cancelToken,
      );

      final root = extractMap(response.data);
      final payload = _extractPayload(root);

      final rawItems = payload['items'] is List
          ? (payload['items'] as List)
          : (root['data'] is List ? (root['data'] as List) : const <dynamic>[]);

      final items = <ProductEntity>[];
      for (final raw in rawItems) {
        if (raw is! Map) {
          continue;
        }
        try {
          final item = raw.map((k, v) => MapEntry(k.toString(), v));
          final model = ProductModel.fromJson(item);
          items.add(model.toEntity());
        } catch (_) {
          // Keep parsing resilient.
        }
      }

      final meta = extractMap(root['meta']);
      final currentPage = _pickFirstPositiveInt(<dynamic>[
        payload['page'],
        meta['page'],
        page,
      ], fallback: page);
      final resolvedPerPage = _pickFirstPositiveInt(<dynamic>[
        payload['limit'],
        payload['per_page'],
        meta['per_page'],
        perPage,
      ], fallback: perPage);
      final total = _pickFirstNonNegativeInt(<dynamic>[
        payload['total'],
        meta['total'],
      ]);
      final nextPageRaw = parseInt(payload['next_page']);

      var totalPages = _pickFirstPositiveInt(<dynamic>[
        payload['total_pages'],
        meta['total_pages'],
      ], fallback: 0);

      if (totalPages <= 0) {
        if (nextPageRaw > 0) {
          totalPages = nextPageRaw;
        } else if (total > 0 && resolvedPerPage > 0) {
          totalPages = (total / resolvedPerPage).ceil();
        } else {
          totalPages = 1;
        }
      }

      return SearchResultsPage(
        items: items,
        page: currentPage,
        perPage: resolvedPerPage,
        total: total,
        totalPages: totalPages,
        nextPage: nextPageRaw > 0 ? nextPageRaw : null,
      );
    } on DioException catch (e) {
      if (e.type == DioExceptionType.badResponse &&
          (e.response?.statusCode == 404 || e.response?.statusCode == 401)) {
        return SearchResultsPage.empty(page: page, perPage: perPage);
      }
      rethrow;
    } catch (_) {
      return SearchResultsPage.empty(page: page, perPage: perPage);
    }
  }

  Future<List<String>> getTrendingSearches({
    int limit = 10,
    CancelToken? cancelToken,
  }) async {
    try {
      final response = await _client.get(
        Endpoints.searchTrending(),
        queryParameters: {'limit': limit},
        options: Options(extra: const {'requiresAuth': false}),
        cancelToken: cancelToken,
      );

      final root = extractMap(response.data);
      final payload = _extractPayload(root);
      final raw =
          payload['items'] ??
          payload['queries'] ??
          root['items'] ??
          root['queries'];

      if (raw is! List) {
        return const <String>[];
      }

      final output = <String>[];
      final seen = <String>{};
      for (final item in raw) {
        final value = sanitizeSearchDisplayText(item.toString());
        if (value.isEmpty) {
          continue;
        }
        final key = normalizeSearchQueryKey(value);
        if (!seen.add(key)) {
          continue;
        }
        output.add(value);
      }
      return output;
    } catch (_) {
      return const <String>[];
    }
  }

  Future<Response<dynamic>> _getWithFallback({
    required String primaryPath,
    String? fallbackPath,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
  }) async {
    try {
      return await _client.get(
        primaryPath,
        queryParameters: queryParameters,
        options: options,
        cancelToken: cancelToken,
      );
    } on DioException catch (e) {
      if (fallbackPath == null || e.response?.statusCode != 404) {
        rethrow;
      }
      return _client.get(
        fallbackPath,
        queryParameters: queryParameters,
        options: options,
        cancelToken: cancelToken,
      );
    }
  }

  Map<String, dynamic> _extractPayload(Map<String, dynamic> root) {
    if (root['data'] is Map) {
      return extractMap(root['data']);
    }
    return root;
  }

  List<SearchSuggestionQuery> _parseSuggestions({
    required dynamic raw,
    required String fallbackHighlight,
  }) {
    if (raw is! List) {
      return const <SearchSuggestionQuery>[];
    }

    final suggestions = <SearchSuggestionQuery>[];

    for (final item in raw) {
      if (item is Map) {
        suggestions.add(
          SearchSuggestionQuery.fromJson(
            item.map((k, v) => MapEntry(k.toString(), v)),
          ),
        );
        continue;
      }
      final value = sanitizeSearchDisplayText(item.toString());
      if (value.isEmpty) {
        continue;
      }
      suggestions.add(
        SearchSuggestionQuery(
          type: 'query',
          text: value,
          highlight: fallbackHighlight,
        ),
      );
    }

    return suggestions;
  }

  int _pickFirstPositiveInt(List<dynamic> values, {required int fallback}) {
    for (final value in values) {
      final parsed = parseInt(value);
      if (parsed > 0) {
        return parsed;
      }
    }
    return fallback;
  }

  int _pickFirstNonNegativeInt(List<dynamic> values) {
    for (final value in values) {
      final parsed = parseInt(value);
      if (parsed >= 0) {
        return parsed;
      }
    }
    return 0;
  }
}

class SearchSuggestPayload {
  final List<SearchSuggestionQuery> suggestions;
  final List<SearchSuggestionProduct> products;
  final List<SearchSuggestionCategory> categories;

  const SearchSuggestPayload({
    this.suggestions = const [],
    this.products = const [],
    this.categories = const [],
  });
}

class SearchSuggestionQuery {
  final String type;
  final String text;
  final String highlight;

  const SearchSuggestionQuery({
    required this.type,
    required this.text,
    required this.highlight,
  });

  factory SearchSuggestionQuery.fromJson(Map<String, dynamic> json) {
    return SearchSuggestionQuery(
      type: (json['type'] ?? 'query').toString(),
      text: TextNormalizer.normalize(json['text']),
      highlight: TextNormalizer.normalize(json['highlight']),
    );
  }
}

class SearchSuggestionProduct {
  final int id;
  final String name;
  final double price;
  final double salePrice;
  final double regularPrice;
  final String currency;
  final String image;
  final double rating;
  final int reviewsCount;
  final bool inStock;

  const SearchSuggestionProduct({
    required this.id,
    required this.name,
    required this.price,
    required this.salePrice,
    required this.regularPrice,
    required this.currency,
    required this.image,
    required this.rating,
    required this.reviewsCount,
    required this.inStock,
  });

  factory SearchSuggestionProduct.fromJson(Map<String, dynamic> json) {
    return SearchSuggestionProduct(
      id: parseInt(json['id']),
      name: TextNormalizer.normalize(json['name']),
      price: parseDouble(json['price']),
      salePrice: parseDouble(json['sale_price']),
      regularPrice: parseDouble(json['regular_price']),
      currency: (json['currency'] ?? 'SYP').toString(),
      image: (json['image'] ?? '').toString(),
      rating: parseDouble(json['rating']),
      reviewsCount: parseInt(json['reviews_count']),
      inStock: parseBool(json['in_stock']),
    );
  }

  bool get hasDiscount =>
      salePrice > 0 && regularPrice > 0 && salePrice < regularPrice;
}

class SearchSuggestionCategory {
  final int id;
  final String name;
  final String image;

  const SearchSuggestionCategory({
    required this.id,
    required this.name,
    required this.image,
  });

  factory SearchSuggestionCategory.fromJson(Map<String, dynamic> json) {
    return SearchSuggestionCategory(
      id: parseInt(json['id']),
      name: TextNormalizer.normalize(json['name']),
      image: (json['image'] ?? '').toString(),
    );
  }
}

class SearchResultsPage {
  final List<ProductEntity> items;
  final int page;
  final int perPage;
  final int total;
  final int totalPages;
  final int? nextPage;

  const SearchResultsPage({
    required this.items,
    required this.page,
    required this.perPage,
    required this.total,
    required this.totalPages,
    this.nextPage,
  });

  factory SearchResultsPage.empty({required int page, required int perPage}) {
    return SearchResultsPage(
      items: const [],
      page: page,
      perPage: perPage,
      total: 0,
      totalPages: 1,
      nextPage: null,
    );
  }
}
