import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/async/debouncer.dart';
import '../../core/analytics/event_tracker.dart';
import '../product/domain/entities/product_entity.dart';
import 'recent_search_store.dart';
import 'search_api.dart';
import 'search_query_normalizer.dart';

final searchControllerProvider =
    AutoDisposeNotifierProvider<SearchController, SearchState>(
      SearchController.new,
    );

enum SearchPhase {
  idle,
  typing,
  loadingSuggestions,
  suggestionsReady,
  loadingResults,
  resultsReady,
  error,
}

class SearchController extends AutoDisposeNotifier<SearchState> {
  late final SearchApi _api;
  late final RecentSearchStore _recentStore;

  final Map<String, SearchSuggestPayload> _suggestionCache =
      <String, SearchSuggestPayload>{};

  final Debouncer _debouncer = Debouncer(
    delay: const Duration(milliseconds: 300),
  );
  CancelToken? _suggestCancelToken;
  CancelToken? _resultsCancelToken;
  int _suggestVersion = 0;
  int _resultsVersion = 0;
  bool _isDisposed = false;
  bool _didTrackSearchOpen = false;

  @override
  SearchState build() {
    _api = ref.read(searchApiProvider);
    _recentStore = ref.read(recentSearchStoreProvider);
    _isDisposed = false;

    unawaited(_loadRecentSearches());
    unawaited(_loadTrendingSearches());

    ref.onDispose(() {
      _isDisposed = true;
      _debouncer.dispose();
      _suggestCancelToken?.cancel('dispose');
      _resultsCancelToken?.cancel('dispose');
    });

    return const SearchState();
  }

  void trackSearchOpened() {
    if (_didTrackSearchOpen) {
      return;
    }
    _didTrackSearchOpen = true;
    unawaited(ref.read(eventTrackerProvider).track(eventType: 'search_open'));
  }

  Future<void> _loadRecentSearches() async {
    final recents = await _recentStore.read();
    if (_isDisposed) {
      return;
    }
    state = state.copyWith(recentSearches: recents);
  }

  Future<void> _loadTrendingSearches() async {
    state = state.copyWith(isLoadingTrending: true);
    final trending = await _api.getTrendingSearches();
    if (_isDisposed) {
      return;
    }
    state = state.copyWith(
      trendingSearches: trending,
      isLoadingTrending: false,
    );
  }

  void onQueryChanged(String rawValue) {
    final query = sanitizeSearchDisplayText(rawValue);

    state = state.copyWith(
      query: rawValue,
      phase: query.isEmpty ? SearchPhase.idle : SearchPhase.typing,
      suggestionMessage: null,
    );

    _debouncer.cancel();
    _suggestCancelToken?.cancel('query_changed');
    _suggestVersion++;

    if (query.length < 2) {
      state = state.copyWith(
        isLoadingSuggestions: false,
        suggestions: const <SearchSuggestionQuery>[],
        suggestedProducts: const <SearchSuggestionProduct>[],
        suggestedCategories: const <SearchSuggestionCategory>[],
        suggestionMessage: null,
        phase: query.isEmpty ? SearchPhase.idle : SearchPhase.typing,
      );
      return;
    }

    final cacheKey = normalizeSearchQueryKey(query);
    final cached = _suggestionCache[cacheKey];
    if (cached != null) {
      state = state.copyWith(
        isLoadingSuggestions: false,
        suggestions: cached.suggestions,
        suggestedProducts: cached.products,
        suggestedCategories: cached.categories,
        suggestionMessage: null,
        phase: SearchPhase.suggestionsReady,
      );
      return;
    }

    state = state.copyWith(
      isLoadingSuggestions: true,
      suggestionMessage: null,
      phase: SearchPhase.loadingSuggestions,
    );

    final currentVersion = _suggestVersion;
    _debouncer.run(() {
      unawaited(_fetchSuggestions(query, currentVersion));
    });
  }

  Future<void> _fetchSuggestions(String query, int version) async {
    _suggestCancelToken?.cancel('new_suggestion_request');
    final cancelToken = CancelToken();
    _suggestCancelToken = cancelToken;

    try {
      final payload = await _api.suggest(
        query,
        limit: 10,
        cancelToken: cancelToken,
      );

      if (_isDisposed || version != _suggestVersion) {
        return;
      }

      _putSuggestionCache(normalizeSearchQueryKey(query), payload);

      state = state.copyWith(
        isLoadingSuggestions: false,
        suggestions: payload.suggestions,
        suggestedProducts: payload.products,
        suggestedCategories: payload.categories,
        suggestionMessage: null,
        phase: SearchPhase.suggestionsReady,
      );
    } on DioException catch (e) {
      if (CancelToken.isCancel(e)) {
        return;
      }
      if (_isDisposed || version != _suggestVersion) {
        return;
      }
      state = state.copyWith(
        isLoadingSuggestions: false,
        suggestions: const <SearchSuggestionQuery>[],
        suggestedProducts: const <SearchSuggestionProduct>[],
        suggestedCategories: const <SearchSuggestionCategory>[],
        suggestionMessage:
            '\u062a\u0639\u0630\u0631 \u062a\u062d\u0645\u064a\u0644 \u0627\u0644\u0627\u0642\u062a\u0631\u0627\u062d\u0627\u062a \u062d\u0627\u0644\u064a\u0627\u064b.',
        phase: SearchPhase.error,
      );
    } catch (_) {
      if (_isDisposed || version != _suggestVersion) {
        return;
      }
      state = state.copyWith(
        isLoadingSuggestions: false,
        suggestions: const <SearchSuggestionQuery>[],
        suggestedProducts: const <SearchSuggestionProduct>[],
        suggestedCategories: const <SearchSuggestionCategory>[],
        suggestionMessage:
            '\u062a\u0639\u0630\u0631 \u062a\u062d\u0645\u064a\u0644 \u0627\u0644\u0627\u0642\u062a\u0631\u0627\u062d\u0627\u062a \u062d\u0627\u0644\u064a\u0627\u064b.',
        phase: SearchPhase.error,
      );
    }
  }

  Future<void> searchProducts({
    String? rawQuery,
    bool reset = true,
    int perPage = 20,
    String? sort,
  }) async {
    final query = sanitizeSearchDisplayText(rawQuery ?? state.query);
    final effectiveSort = sanitizeSearchDisplayText(sort ?? state.resultsSort);
    final normalizedSort = effectiveSort.isEmpty ? 'relevance' : effectiveSort;

    if (query.isEmpty) {
      clearResults();
      return;
    }

    final hasMore = state.resultsPage < state.resultsTotalPages;
    if (!reset) {
      if (state.isLoadingResults || state.isLoadingMoreResults || !hasMore) {
        return;
      }
    }

    if (reset) {
      _resultsCancelToken?.cancel('new_results_request');
    }

    final requestVersion = ++_resultsVersion;
    final targetPage = reset ? 1 : (state.resultsPage + 1);
    final cancelToken = CancelToken();
    _resultsCancelToken = cancelToken;

    if (reset) {
      state = state.copyWith(
        query: query,
        isLoadingResults: true,
        isLoadingMoreResults: false,
        results: const <ProductEntity>[],
        resultsPage: 0,
        resultsTotalPages: 1,
        resultsTotal: 0,
        resultsSort: normalizedSort,
        resultsMessage: null,
        phase: SearchPhase.loadingResults,
      );
    } else {
      state = state.copyWith(
        isLoadingMoreResults: true,
        resultsSort: normalizedSort,
        resultsMessage: null,
        phase: SearchPhase.loadingResults,
      );
    }

    try {
      final response = await _api.search(
        query: query,
        page: targetPage,
        perPage: perPage,
        sort: normalizedSort,
        cancelToken: cancelToken,
      );

      if (_isDisposed || requestVersion != _resultsVersion) {
        return;
      }

      final merged = reset
          ? response.items
          : _mergeUniqueById(state.results, response.items);

      state = state.copyWith(
        query: query,
        results: merged,
        resultsPage: response.page,
        resultsTotalPages: response.totalPages,
        resultsTotal: response.total,
        isLoadingResults: false,
        isLoadingMoreResults: false,
        resultsMessage: null,
        phase: SearchPhase.resultsReady,
      );

      if (reset) {
        unawaited(saveRecentSearch(query, resultsCount: response.total));
      }
      if (response.total <= 0) {
        unawaited(
          ref
              .read(eventTrackerProvider)
              .track(eventType: 'no_results', queryText: query),
        );
      }
    } on DioException catch (e) {
      if (CancelToken.isCancel(e)) {
        return;
      }
      if (_isDisposed || requestVersion != _resultsVersion) {
        return;
      }
      _setResultsError(reset);
    } catch (_) {
      if (_isDisposed || requestVersion != _resultsVersion) {
        return;
      }
      _setResultsError(reset);
    }
  }

  Future<void> loadMoreResults() async {
    await searchProducts(reset: false);
  }

  void setResultsSort(String value) {
    final next = sanitizeSearchDisplayText(value);
    if (next.isEmpty || next == state.resultsSort) {
      return;
    }
    state = state.copyWith(resultsSort: next);
  }

  void clearResults() {
    _resultsCancelToken?.cancel('clear_results');
    state = state.copyWith(
      query: '',
      isLoadingResults: false,
      isLoadingMoreResults: false,
      results: const <ProductEntity>[],
      resultsPage: 0,
      resultsTotalPages: 1,
      resultsTotal: 0,
      resultsMessage: null,
      phase: SearchPhase.idle,
    );
  }

  Future<void> saveRecentSearch(String query, {int? resultsCount}) async {
    final displayText = sanitizeSearchDisplayText(query);
    if (displayText.isEmpty) {
      return;
    }

    final next = await _recentStore.add(displayText);
    if (!_isDisposed) {
      state = state.copyWith(recentSearches: next);
    }

    unawaited(
      ref
          .read(eventTrackerProvider)
          .track(
            eventType: 'search_query_submitted',
            queryText: displayText,
            resultsCount: resultsCount,
          ),
    );
  }

  Future<void> recordSuggestionClick(String query) async {
    final displayText = sanitizeSearchDisplayText(query);
    if (displayText.isEmpty) {
      return;
    }
    await saveRecentSearch(displayText);
    unawaited(
      ref
          .read(eventTrackerProvider)
          .track(eventType: 'suggestion_clicked', queryText: displayText),
    );
  }

  Future<void> recordProductClick({required int productId}) async {
    if (productId <= 0) {
      return;
    }
    unawaited(
      ref
          .read(eventTrackerProvider)
          .track(
            eventType: 'product_clicked_from_search',
            productId: productId,
            queryText: sanitizeSearchDisplayText(state.query),
          ),
    );
  }

  Future<void> removeRecentSearch(String query) async {
    final next = await _recentStore.remove(query);
    if (_isDisposed) {
      return;
    }
    state = state.copyWith(recentSearches: next);
  }

  Future<void> clearRecentSearches() async {
    await _recentStore.clear();
    if (_isDisposed) {
      return;
    }
    state = state.copyWith(recentSearches: const <String>[]);
  }

  void setQueryWithoutSearch(String query) {
    final normalized = sanitizeSearchDisplayText(query);
    state = state.copyWith(
      query: query,
      phase: normalized.isEmpty ? SearchPhase.idle : SearchPhase.typing,
      suggestionMessage: null,
      resultsMessage: null,
    );
  }

  Future<void> refreshTrendingSearches() async {
    await _loadTrendingSearches();
  }

  List<ProductEntity> _mergeUniqueById(
    List<ProductEntity> base,
    List<ProductEntity> incoming,
  ) {
    final seen = base.map((item) => item.id).toSet();
    final output = List<ProductEntity>.from(base);
    for (final item in incoming) {
      if (seen.add(item.id)) {
        output.add(item);
      }
    }
    return output;
  }

  void _putSuggestionCache(String key, SearchSuggestPayload payload) {
    if (key.isEmpty) {
      return;
    }
    if (_suggestionCache.length >= 20 && !_suggestionCache.containsKey(key)) {
      _suggestionCache.remove(_suggestionCache.keys.first);
    }
    _suggestionCache[key] = payload;
  }

  void _setResultsError(bool reset) {
    state = state.copyWith(
      isLoadingResults: false,
      isLoadingMoreResults: false,
      results: reset ? const <ProductEntity>[] : state.results,
      resultsMessage:
          '\u062a\u0639\u0630\u0631 \u062a\u062d\u0645\u064a\u0644 \u0646\u062a\u0627\u0626\u062c \u0627\u0644\u0628\u062d\u062b \u062d\u0627\u0644\u064a\u0627\u064b. \u062d\u0627\u0648\u0644 \u0645\u062c\u062f\u062f\u0627\u064b.',
      phase: SearchPhase.error,
    );
  }
}

class SearchState {
  static const _noValue = Object();

  final SearchPhase phase;
  final String query;
  final bool isLoadingSuggestions;
  final bool isLoadingTrending;
  final List<String> recentSearches;
  final List<String> trendingSearches;
  final List<SearchSuggestionQuery> suggestions;
  final List<SearchSuggestionProduct> suggestedProducts;
  final List<SearchSuggestionCategory> suggestedCategories;
  final String? suggestionMessage;

  final bool isLoadingResults;
  final bool isLoadingMoreResults;
  final List<ProductEntity> results;
  final int resultsPage;
  final int resultsTotalPages;
  final int resultsTotal;
  final String resultsSort;
  final String? resultsMessage;

  const SearchState({
    this.phase = SearchPhase.idle,
    this.query = '',
    this.isLoadingSuggestions = false,
    this.isLoadingTrending = false,
    this.recentSearches = const <String>[],
    this.trendingSearches = const <String>[],
    this.suggestions = const <SearchSuggestionQuery>[],
    this.suggestedProducts = const <SearchSuggestionProduct>[],
    this.suggestedCategories = const <SearchSuggestionCategory>[],
    this.suggestionMessage,
    this.isLoadingResults = false,
    this.isLoadingMoreResults = false,
    this.results = const <ProductEntity>[],
    this.resultsPage = 0,
    this.resultsTotalPages = 1,
    this.resultsTotal = 0,
    this.resultsSort = 'relevance',
    this.resultsMessage,
  });

  SearchState copyWith({
    SearchPhase? phase,
    String? query,
    bool? isLoadingSuggestions,
    bool? isLoadingTrending,
    List<String>? recentSearches,
    List<String>? trendingSearches,
    List<SearchSuggestionQuery>? suggestions,
    List<SearchSuggestionProduct>? suggestedProducts,
    List<SearchSuggestionCategory>? suggestedCategories,
    Object? suggestionMessage = _noValue,
    bool? isLoadingResults,
    bool? isLoadingMoreResults,
    List<ProductEntity>? results,
    int? resultsPage,
    int? resultsTotalPages,
    int? resultsTotal,
    String? resultsSort,
    Object? resultsMessage = _noValue,
  }) {
    return SearchState(
      phase: phase ?? this.phase,
      query: query ?? this.query,
      isLoadingSuggestions: isLoadingSuggestions ?? this.isLoadingSuggestions,
      isLoadingTrending: isLoadingTrending ?? this.isLoadingTrending,
      recentSearches: recentSearches ?? this.recentSearches,
      trendingSearches: trendingSearches ?? this.trendingSearches,
      suggestions: suggestions ?? this.suggestions,
      suggestedProducts: suggestedProducts ?? this.suggestedProducts,
      suggestedCategories: suggestedCategories ?? this.suggestedCategories,
      suggestionMessage: identical(suggestionMessage, _noValue)
          ? this.suggestionMessage
          : suggestionMessage as String?,
      isLoadingResults: isLoadingResults ?? this.isLoadingResults,
      isLoadingMoreResults: isLoadingMoreResults ?? this.isLoadingMoreResults,
      results: results ?? this.results,
      resultsPage: resultsPage ?? this.resultsPage,
      resultsTotalPages: resultsTotalPages ?? this.resultsTotalPages,
      resultsTotal: resultsTotal ?? this.resultsTotal,
      resultsSort: resultsSort ?? this.resultsSort,
      resultsMessage: identical(resultsMessage, _noValue)
          ? this.resultsMessage
          : resultsMessage as String?,
    );
  }
}
