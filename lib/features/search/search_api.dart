import 'dart:math' as math;

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
  final Map<String, _RelevanceSearchCache> _relevanceCache =
      <String, _RelevanceSearchCache>{};
  static const int _relevanceFetchPerPage = 40;
  static const int _maxRelevanceCacheEntries = 8;
  static const Map<String, List<String>> _searchSynonyms =
      <String, List<String>>{
        'حقيبه': <String>['حقيبة', 'حقيبه', 'حقائب', 'شنطة', 'شنطه', 'شنط'],
      };

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

    final normalizedSort = sanitizeSearchDisplayText(sort ?? '').trim();
    final effectiveSort = normalizedSort.isEmpty ? 'relevance' : normalizedSort;
    final currentPage = page <= 0 ? 1 : page;
    final effectivePerPage = perPage <= 0 ? 20 : perPage;

    if (effectiveSort == 'relevance') {
      return _searchWithLocalRelevanceRanking(
        query: normalized,
        page: currentPage,
        perPage: effectivePerPage,
        sort: effectiveSort,
        minPrice: minPrice,
        maxPrice: maxPrice,
        inStock: inStock,
        categoryId: categoryId,
        cancelToken: cancelToken,
      );
    }

    final queryParameters = <String, dynamic>{
      'q': normalized,
      'page': currentPage,
      'limit': effectivePerPage,
      'per_page': effectivePerPage,
      'sort': effectiveSort,
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

      final parsed = _parseSearchResultsResponse(
        data: response.data,
        fallbackPage: currentPage,
        fallbackPerPage: effectivePerPage,
      );
      return SearchResultsPage(
        items: parsed.items,
        page: parsed.page,
        perPage: parsed.perPage,
        total: parsed.total,
        totalPages: parsed.totalPages,
        nextPage: parsed.nextPage,
      );
    } on DioException catch (e) {
      if (e.type == DioExceptionType.badResponse &&
          (e.response?.statusCode == 404 || e.response?.statusCode == 401)) {
        return SearchResultsPage.empty(
          page: currentPage,
          perPage: effectivePerPage,
        );
      }
      rethrow;
    } catch (_) {
      return SearchResultsPage.empty(
        page: currentPage,
        perPage: effectivePerPage,
      );
    }
  }

  Future<SearchResultsPage> _searchWithLocalRelevanceRanking({
    required String query,
    required int page,
    required int perPage,
    required String sort,
    double? minPrice,
    double? maxPrice,
    bool? inStock,
    int? categoryId,
    CancelToken? cancelToken,
  }) async {
    final cacheKey = _buildRelevanceCacheKey(
      query: query,
      minPrice: minPrice,
      maxPrice: maxPrice,
      inStock: inStock,
      categoryId: categoryId,
    );
    if (page <= 1) {
      _relevanceCache.remove(cacheKey);
    }
    final cache =
        _relevanceCache[cacheKey] ??
        _putRelevanceCache(cacheKey, _RelevanceSearchCache());

    final normalizedQuery = _normalizeForSearchIndex(query);
    final baseTerms = _expandSearchTerms(normalizedQuery);
    final requiredResults = page * perPage;
    final fetchPerPage = math.max(perPage, _relevanceFetchPerPage);

    while (cache.scoredById.length < requiredResults &&
        cache.fetchedPages < cache.totalPages &&
        !(cancelToken?.isCancelled ?? false)) {
      final remotePage = cache.fetchedPages + 1;
      final parsed = await _fetchSearchResultsPage(
        query: query,
        page: remotePage,
        perPage: fetchPerPage,
        sort: sort,
        minPrice: minPrice,
        maxPrice: maxPrice,
        inStock: inStock,
        categoryId: categoryId,
        cancelToken: cancelToken,
      );

      cache.fetchedPages = math.max(cache.fetchedPages, parsed.page);
      cache.totalPages = math.max(cache.totalPages, parsed.totalPages);
      cache.totalFromApi = math.max(cache.totalFromApi, parsed.total);

      for (final item in parsed.items) {
        final score = _computeRelevanceScore(
          product: item,
          normalizedQuery: normalizedQuery,
          terms: baseTerms,
        );
        if (score <= 0) {
          continue;
        }
        final previous = cache.scoredById[item.id];
        if (previous == null || score > previous.score) {
          cache.scoredById[item.id] = _ScoredProduct(item: item, score: score);
        }
      }

      final exhaustedFromPayload =
          parsed.items.isEmpty ||
          parsed.nextPage == null ||
          parsed.page >= parsed.totalPages;
      if (exhaustedFromPayload) {
        cache.fetchedPages = cache.totalPages;
      }
    }

    final ranked = cache.scoredById.values.toList(growable: false)
      ..sort(_compareScoredProducts);

    final total = ranked.length;
    final totalPages = total <= 0 ? 1 : (total / perPage).ceil();
    final safePage = page <= 0 ? 1 : page;
    final start = (safePage - 1) * perPage;
    final end = math.min(start + perPage, total);

    final pageItems = start >= total
        ? const <ProductEntity>[]
        : ranked
              .sublist(start, end)
              .map((entry) => entry.item)
              .toList(growable: false);

    return SearchResultsPage(
      items: pageItems,
      page: safePage,
      perPage: perPage,
      total: total,
      totalPages: totalPages,
      nextPage: safePage < totalPages ? safePage + 1 : null,
    );
  }

  Future<_ParsedSearchResults> _fetchSearchResultsPage({
    required String query,
    required int page,
    required int perPage,
    required String sort,
    double? minPrice,
    double? maxPrice,
    bool? inStock,
    int? categoryId,
    CancelToken? cancelToken,
  }) async {
    final queryParameters = <String, dynamic>{
      'q': query,
      'page': page,
      'limit': perPage,
      'per_page': perPage,
      'sort': sort,
      'min_price': minPrice,
      'max_price': maxPrice,
      'in_stock': inStock == null ? null : (inStock ? 1 : 0),
      'category_id': (categoryId ?? 0) > 0 ? categoryId : null,
    }..removeWhere((_, value) => value == null);

    final response = await _getWithFallback(
      primaryPath: Endpoints.searchProducts(),
      fallbackPath: Endpoints.search(),
      queryParameters: queryParameters,
      options: Options(extra: const {'requiresAuth': false}),
      cancelToken: cancelToken,
    );

    return _parseSearchResultsResponse(
      data: response.data,
      fallbackPage: page,
      fallbackPerPage: perPage,
    );
  }

  String _buildRelevanceCacheKey({
    required String query,
    double? minPrice,
    double? maxPrice,
    bool? inStock,
    int? categoryId,
  }) {
    final normalizedQuery = _normalizeForSearchIndex(query);
    final normalizedMinPrice = minPrice?.toStringAsFixed(2) ?? '';
    final normalizedMaxPrice = maxPrice?.toStringAsFixed(2) ?? '';
    final normalizedStock = inStock == null
        ? 'any'
        : (inStock ? 'instock' : 'outofstock');
    final normalizedCategory = ((categoryId ?? 0) > 0) ? categoryId : 0;
    return [
      normalizedQuery,
      normalizedMinPrice,
      normalizedMaxPrice,
      normalizedStock,
      normalizedCategory.toString(),
    ].join('|');
  }

  double _computeRelevanceScore({
    required ProductEntity product,
    required String normalizedQuery,
    required List<String> terms,
  }) {
    if (normalizedQuery.isEmpty) {
      return 0;
    }

    final name = _normalizeForSearchIndex(product.name);
    if (name.isEmpty) {
      return 0;
    }
    final brand = _normalizeForSearchIndex(product.brandName);
    final shortDescription = _normalizeForSearchIndex(product.shortDescription);
    final description = _normalizeForSearchIndex(product.description);

    var score = 0.0;
    var matchedNameOrBrand = false;
    var matchedBaseTokens = 0;
    final normalizedTokens = normalizedQuery
        .split(' ')
        .where((token) => token.length >= 2)
        .toSet();

    if (name == normalizedQuery) {
      score += 260;
      matchedNameOrBrand = true;
    } else if (name.startsWith(normalizedQuery)) {
      score += 190;
      matchedNameOrBrand = true;
    } else if (name.contains(normalizedQuery)) {
      score += 150;
      matchedNameOrBrand = true;
    }

    if (brand.isNotEmpty && brand.contains(normalizedQuery)) {
      score += 90;
      matchedNameOrBrand = true;
    }

    for (final token in normalizedTokens) {
      final inName = name.contains(token);
      final inBrand = brand.isNotEmpty && brand.contains(token);
      if (inName) {
        score += 42;
        matchedNameOrBrand = true;
      }
      if (inBrand) {
        score += 24;
        matchedNameOrBrand = true;
      }
      if (inName || inBrand) {
        matchedBaseTokens++;
      }
    }

    for (final term in terms) {
      if (term.isEmpty || normalizedTokens.contains(term)) {
        continue;
      }
      if (name.contains(term)) {
        score += 16;
        matchedNameOrBrand = true;
      } else if (brand.isNotEmpty && brand.contains(term)) {
        score += 10;
        matchedNameOrBrand = true;
      }
    }

    if (!matchedNameOrBrand) {
      return 0;
    }

    if (shortDescription.isNotEmpty &&
        _containsAnyTerm(shortDescription, normalizedTokens)) {
      score += 6;
    }
    if (description.isNotEmpty &&
        _containsAnyTerm(description, normalizedTokens)) {
      score += 2;
    }
    if (normalizedTokens.isNotEmpty &&
        matchedBaseTokens >= normalizedTokens.length) {
      score += 26;
    }
    if (product.inStock) {
      score += 2;
    }

    final ratingBoost = product.rating.clamp(0, 5) * 0.4;
    return score + ratingBoost;
  }

  String _normalizeForSearchIndex(String raw) {
    final cleaned = normalizeSearchQueryKey(raw);
    if (cleaned.isEmpty) {
      return '';
    }

    return cleaned
        .replaceAll(RegExp('[أإآٱ]'), 'ا')
        .replaceAll('ؤ', 'و')
        .replaceAll('ئ', 'ي')
        .replaceAll('ى', 'ي')
        .replaceAll('ة', 'ه')
        .replaceAll(RegExp(r'[^0-9a-z\u0600-\u06FF\s]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  List<String> _expandSearchTerms(String normalizedQuery) {
    if (normalizedQuery.isEmpty) {
      return const <String>[];
    }

    final tokens = normalizedQuery
        .split(' ')
        .map((token) => token.trim())
        .where((token) => token.length >= 2)
        .toSet();

    final expanded = <String>{normalizedQuery, ...tokens};
    for (final token in tokens) {
      final synonyms = _searchSynonyms[token];
      if (synonyms == null) {
        continue;
      }
      for (final synonym in synonyms) {
        final normalized = _normalizeForSearchIndex(synonym);
        if (normalized.length >= 2) {
          expanded.add(normalized);
        }
      }
    }
    return expanded.toList(growable: false);
  }

  bool _containsAnyTerm(String haystack, Set<String> terms) {
    for (final term in terms) {
      if (term.isEmpty) {
        continue;
      }
      if (haystack.contains(term)) {
        return true;
      }
    }
    return false;
  }

  int _compareScoredProducts(_ScoredProduct a, _ScoredProduct b) {
    final byScore = b.score.compareTo(a.score);
    if (byScore != 0) {
      return byScore;
    }

    final aCreatedAt = a.item.createdAt;
    final bCreatedAt = b.item.createdAt;
    if (aCreatedAt != null && bCreatedAt != null) {
      final byDate = bCreatedAt.compareTo(aCreatedAt);
      if (byDate != 0) {
        return byDate;
      }
    } else if (aCreatedAt != null) {
      return -1;
    } else if (bCreatedAt != null) {
      return 1;
    }

    return b.item.id.compareTo(a.item.id);
  }

  _RelevanceSearchCache _putRelevanceCache(
    String key,
    _RelevanceSearchCache value,
  ) {
    if (!_relevanceCache.containsKey(key) &&
        _relevanceCache.length >= _maxRelevanceCacheEntries) {
      _relevanceCache.remove(_relevanceCache.keys.first);
    }
    _relevanceCache[key] = value;
    return value;
  }

  _ParsedSearchResults _parseSearchResultsResponse({
    required dynamic data,
    required int fallbackPage,
    required int fallbackPerPage,
  }) {
    final root = extractMap(data);
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
    final page = _pickFirstPositiveInt(<dynamic>[
      payload['page'],
      meta['page'],
      fallbackPage,
    ], fallback: fallbackPage);
    final perPage = _pickFirstPositiveInt(<dynamic>[
      payload['limit'],
      payload['per_page'],
      meta['per_page'],
      fallbackPerPage,
    ], fallback: fallbackPerPage);
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
      } else if (total > 0 && perPage > 0) {
        totalPages = (total / perPage).ceil();
      } else {
        totalPages = 1;
      }
    }

    return _ParsedSearchResults(
      items: items,
      page: page,
      perPage: perPage,
      total: total,
      totalPages: totalPages,
      nextPage: nextPageRaw > 0 ? nextPageRaw : null,
    );
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

class _ParsedSearchResults {
  final List<ProductEntity> items;
  final int page;
  final int perPage;
  final int total;
  final int totalPages;
  final int? nextPage;

  const _ParsedSearchResults({
    required this.items,
    required this.page,
    required this.perPage,
    required this.total,
    required this.totalPages,
    required this.nextPage,
  });
}

class _RelevanceSearchCache {
  int fetchedPages = 0;
  int totalPages = 1;
  int totalFromApi = 0;
  final Map<int, _ScoredProduct> scoredById;

  _RelevanceSearchCache({Map<int, _ScoredProduct>? scoredById})
    : scoredById = scoredById ?? <int, _ScoredProduct>{};
}

class _ScoredProduct {
  final ProductEntity item;
  final double score;

  const _ScoredProduct({required this.item, required this.score});
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
