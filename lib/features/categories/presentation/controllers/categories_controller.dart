import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/cache/cache_store.dart';
import '../../../../core/network/dio_client.dart';
import '../../data/datasources/category_remote_datasource.dart';
import '../../data/repositories/category_repository_impl.dart';
import '../../domain/entities/category_entity.dart';
import '../../domain/repositories/category_repository.dart';
import '../../domain/usecases/get_categories.dart';

// ?"??"? Datasource ?"??"?
final categoryRemoteDatasourceProvider = Provider<CategoryRemoteDatasource>((
  ref,
) {
  return CategoryRemoteDatasource(
    client: ref.watch(dioClientProvider),
    cacheStore: ref.watch(cacheStoreProvider),
  );
});

// ?"??"? Repository ?"??"?
final categoryRepositoryProvider = Provider<CategoryRepository>((ref) {
  return CategoryRepositoryImpl(
    datasource: ref.watch(categoryRemoteDatasourceProvider),
  );
});

// ?"??"? Use cases ?"??"?
final getCategoriesUseCaseProvider = Provider<GetCategories>((ref) {
  return GetCategories(repository: ref.watch(categoryRepositoryProvider));
});

// ?"??"? Controller ?"??"?

/// Controller for the categories list with loading/error states.
///
/// Usage in widgets:
/// ```dart
/// final categoriesAsync = ref.watch(categoriesControllerProvider);
/// categoriesAsync.when(
///   data: (categories) => ...,
///   loading: () => ...,
///   error: (e, st) => ...,
/// );
/// ```
final categoriesControllerProvider =
    AutoDisposeAsyncNotifierProvider<
      CategoriesController,
      List<CategoryEntity>
    >(CategoriesController.new);

class CategoriesController
    extends AutoDisposeAsyncNotifier<List<CategoryEntity>> {
  static const Duration _minimumLoadingDuration = Duration(milliseconds: 250);

  @override
  Future<List<CategoryEntity>> build() async {
    return _fetchWithMinimumDelay(preferCache: true);
  }

  Future<List<CategoryEntity>> _fetch({required bool preferCache}) {
    final getCategories = ref.read(getCategoriesUseCaseProvider);
    return getCategories(preferCache: preferCache);
  }

  /// Reload categories (pull-to-refresh).
  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => _fetchWithMinimumDelay(preferCache: false),
    );
  }

  Future<List<CategoryEntity>> _fetchWithMinimumDelay({
    required bool preferCache,
  }) async {
    final startedAt = DateTime.now();
    try {
      return await _fetch(preferCache: preferCache);
    } finally {
      final elapsed = DateTime.now().difference(startedAt);
      final remaining = _minimumLoadingDuration - elapsed;
      if (remaining > Duration.zero) {
        await Future<void>.delayed(remaining);
      }
    }
  }
}
