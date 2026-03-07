import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/product_entity.dart';
import '../../domain/repositories/product_repository.dart';
import 'products_controller.dart';

@immutable
class PaginatedProductsQuery {
  final int perPage;
  final String? search;
  final int? categoryId;
  final int? brandId;
  final String? brandName;
  final String? sort;

  const PaginatedProductsQuery({
    this.perPage = 20,
    this.search,
    this.categoryId,
    this.brandId,
    this.brandName,
    this.sort,
  });

  const PaginatedProductsQuery.home()
    : this(
        perPage: 20,
        search: null,
        categoryId: null,
        brandId: null,
        brandName: null,
        sort: 'newest',
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PaginatedProductsQuery &&
          runtimeType == other.runtimeType &&
          perPage == other.perPage &&
          search == other.search &&
          categoryId == other.categoryId &&
          brandId == other.brandId &&
          brandName == other.brandName &&
          sort == other.sort;

  @override
  int get hashCode =>
      Object.hash(perPage, search, categoryId, brandId, brandName, sort);
}

@immutable
class PaginatedProductsState {
  final List<ProductEntity> items;
  final bool isLoadingInitial;
  final bool isLoadingNext;
  final bool hasMore;
  final Object? errorInitial;
  final Object? errorNext;
  final int currentPage;
  final int totalPages;
  final int perPage;
  final int totalItems;

  const PaginatedProductsState({
    required this.items,
    required this.isLoadingInitial,
    required this.isLoadingNext,
    required this.hasMore,
    required this.errorInitial,
    required this.errorNext,
    required this.currentPage,
    required this.totalPages,
    required this.perPage,
    required this.totalItems,
  });

  factory PaginatedProductsState.initial({required int perPage}) {
    return PaginatedProductsState(
      items: const <ProductEntity>[],
      isLoadingInitial: false,
      isLoadingNext: false,
      hasMore: true,
      errorInitial: null,
      errorNext: null,
      currentPage: 0,
      totalPages: 1,
      perPage: perPage,
      totalItems: 0,
    );
  }

  PaginatedProductsState copyWith({
    List<ProductEntity>? items,
    bool? isLoadingInitial,
    bool? isLoadingNext,
    bool? hasMore,
    int? currentPage,
    int? totalPages,
    int? perPage,
    int? totalItems,
    Object? Function()? errorInitial,
    Object? Function()? errorNext,
  }) {
    return PaginatedProductsState(
      items: items ?? this.items,
      isLoadingInitial: isLoadingInitial ?? this.isLoadingInitial,
      isLoadingNext: isLoadingNext ?? this.isLoadingNext,
      hasMore: hasMore ?? this.hasMore,
      errorInitial: errorInitial != null ? errorInitial() : this.errorInitial,
      errorNext: errorNext != null ? errorNext() : this.errorNext,
      currentPage: currentPage ?? this.currentPage,
      totalPages: totalPages ?? this.totalPages,
      perPage: perPage ?? this.perPage,
      totalItems: totalItems ?? this.totalItems,
    );
  }
}

final paginatedProductsControllerProvider =
    AutoDisposeNotifierProviderFamily<
      PaginatedProductsController,
      PaginatedProductsState,
      PaginatedProductsQuery
    >(PaginatedProductsController.new);

class PaginatedProductsController
    extends
        AutoDisposeFamilyNotifier<
          PaginatedProductsState,
          PaginatedProductsQuery
        > {
  final Map<int, List<ProductEntity>> _pages = <int, List<ProductEntity>>{};
  int _activeRequestId = 0;

  ProductRepository get _repository => ref.read(productRepositoryProvider);

  @override
  PaginatedProductsState build(PaginatedProductsQuery arg) {
    final keepAliveLink = ref.keepAlive();
    final timer = Timer(const Duration(minutes: 5), keepAliveLink.close);
    ref.onDispose(timer.cancel);

    // Always schedule an initial load when build() is called, because
    // build() resets the state to empty.
    Future<void>.microtask(loadInitial);

    return PaginatedProductsState.initial(perPage: arg.perPage);
  }

  Future<void> loadInitial() async {
    if (state.isLoadingInitial) {
      return;
    }

    _pages.clear();
    final requestId = ++_activeRequestId;
    state = state.copyWith(
      isLoadingInitial: true,
      isLoadingNext: false,
      items: const <ProductEntity>[],
      hasMore: true,
      currentPage: 0,
      totalPages: 1,
      totalItems: 0,
      errorInitial: () => null,
      errorNext: () => null,
    );

    try {
      // Always hit network first for page 1 to avoid stale cache values
      // incorrectly freezing pagination (e.g. totalPages/hasMore drift).
      // Datasource still falls back to cache automatically on request failure.
      final result = await _fetchPage(page: 1, preferCache: false);
      if (requestId != _activeRequestId) {
        return;
      }

      final uniqueItems = _dedupeProducts(result.products);
      _pages[1] = uniqueItems;

      final hasMore = _resolveHasMore(
        result: result,
        page: 1,
        pageItemsCount: uniqueItems.length,
        loadedItemsCount: uniqueItems.length,
      );

      state = state.copyWith(
        items: uniqueItems,
        isLoadingInitial: false,
        currentPage: uniqueItems.isEmpty ? 0 : 1,
        totalPages: result.totalPages > 0 ? result.totalPages : 1,
        totalItems: result.total > 0 ? result.total : uniqueItems.length,
        hasMore: hasMore,
        errorInitial: () => null,
      );
    } catch (error) {
      if (requestId != _activeRequestId) {
        return;
      }

      state = state.copyWith(
        isLoadingInitial: false,
        hasMore: false,
        currentPage: 0,
        totalItems: 0,
        errorInitial: () => error,
      );
    }
  }

  Future<void> refresh() async {
    await loadInitial();
  }

  Future<void> retryInitial() async {
    await loadInitial();
  }

  Future<void> loadNextPage() async {
    if (state.isLoadingInitial || state.isLoadingNext || !state.hasMore) {
      return;
    }

    final nextPage = state.currentPage + 1;
    if (nextPage <= 0) {
      return;
    }

    final cachedPage = _pages[nextPage];
    if (cachedPage != null) {
      _commitNextPageFromCache(nextPage, cachedPage);
      return;
    }

    final requestId = ++_activeRequestId;
    state = state.copyWith(isLoadingNext: true, errorNext: () => null);

    try {
      final result = await _fetchPage(page: nextPage, preferCache: false);
      if (requestId != _activeRequestId) {
        return;
      }

      final pageItems = _dedupeProducts(result.products);
      _pages[nextPage] = pageItems;

      final merged = _mergeUniqueById(state.items, pageItems);
      final addedCount = merged.length - state.items.length;
      final hasMore = _resolveHasMore(
        result: result,
        page: nextPage,
        pageItemsCount: pageItems.length,
        loadedItemsCount: merged.length,
      );

      state = state.copyWith(
        items: merged,
        isLoadingNext: false,
        currentPage: nextPage,
        totalPages: result.totalPages > 0
            ? result.totalPages
            : state.totalPages,
        totalItems: result.total > 0
            ? result.total
            : (state.totalItems > 0 ? state.totalItems : merged.length),
        hasMore: addedCount > 0 ? hasMore : false,
        errorNext: () => null,
      );
    } catch (error) {
      if (requestId != _activeRequestId) {
        return;
      }

      state = state.copyWith(isLoadingNext: false, errorNext: () => error);
    }
  }

  Future<void> retryNext() async {
    state = state.copyWith(errorNext: () => null);
    await loadNextPage();
  }

  Future<ProductListResult> _fetchPage({
    required int page,
    required bool preferCache,
  }) {
    return _repository.fetchProducts(
      page: page,
      perPage: arg.perPage,
      search: (arg.search ?? '').trim().isEmpty ? null : arg.search,
      categoryId: arg.categoryId,
      brandId: arg.brandId,
      brandName: (arg.brandName ?? '').trim().isEmpty ? null : arg.brandName,
      sort: arg.sort,
      preferCache: preferCache,
    );
  }

  bool _resolveHasMore({
    required ProductListResult result,
    required int page,
    required int pageItemsCount,
    required int loadedItemsCount,
  }) {
    if (result.total > 0 && loadedItemsCount >= result.total) {
      return false;
    }

    if (result.totalPages > 0) {
      if (page >= result.totalPages) {
        return false;
      }
      return true;
    }

    if (result.hasMore) {
      return true;
    }

    return pageItemsCount >= state.perPage;
  }

  void _commitNextPageFromCache(int nextPage, List<ProductEntity> pageItems) {
    final merged = _mergeUniqueById(state.items, pageItems);
    final addedCount = merged.length - state.items.length;
    final hasMore = state.totalItems > 0
        ? merged.length < state.totalItems
        : (state.totalPages <= 1 && state.hasMore)
        ? pageItems.length >= state.perPage
        : (state.totalPages > 0
              ? nextPage < state.totalPages
              : pageItems.length >= state.perPage);
    state = state.copyWith(
      items: merged,
      currentPage: nextPage,
      hasMore: addedCount > 0 ? hasMore : false,
      errorNext: () => null,
    );
  }

  List<ProductEntity> _dedupeProducts(List<ProductEntity> source) {
    final seen = <int>{};
    final deduped = <ProductEntity>[];
    for (final item in source) {
      if (seen.add(item.id)) {
        deduped.add(item);
      }
    }
    return deduped;
  }

  List<ProductEntity> _mergeUniqueById(
    List<ProductEntity> current,
    List<ProductEntity> incoming,
  ) {
    final map = <int, ProductEntity>{for (final item in current) item.id: item};
    for (final item in incoming) {
      map[item.id] = item;
    }
    return map.values.toList(growable: false);
  }
}
