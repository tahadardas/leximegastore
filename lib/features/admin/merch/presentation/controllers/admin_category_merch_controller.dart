import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/cache/cache_policy.dart';
import '../../../../../core/cache/cache_store.dart';
import '../../data/repositories/admin_merch_repository.dart';
import '../../domain/entities/admin_merch_product.dart';

final adminCategoryMerchControllerProvider =
    AsyncNotifierProviderFamily<
      AdminCategoryMerchController,
      List<AdminMerchProduct>,
      int
    >(AdminCategoryMerchController.new);

class AdminCategoryMerchController
    extends FamilyAsyncNotifier<List<AdminMerchProduct>, int> {
  String _search = '';

  @override
  FutureOr<List<AdminMerchProduct>> build(int arg) {
    return _fetch();
  }

  Future<List<AdminMerchProduct>> _fetch() {
    return ref
        .read(adminMerchRepositoryProvider)
        .getCategoryProducts(termId: arg, search: _search);
  }

  Future<void> search(String value) async {
    _search = value.trim();
    state = const AsyncLoading();
    state = await AsyncValue.guard(_fetch);
  }

  Future<void> save(List<AdminMerchProduct> items) async {
    await ref
        .read(adminMerchRepositoryProvider)
        .saveCategoryProducts(termId: arg, items: items);
    await _invalidateCategoryProductCache();
    state = const AsyncLoading();
    state = await AsyncValue.guard(_fetch);
  }

  Future<void> clearOrder() async {
    await ref
        .read(adminMerchRepositoryProvider)
        .saveCategoryProducts(termId: arg, items: const [], replaceAll: true);
    await _invalidateCategoryProductCache();
    await search(_search);
  }

  Future<void> _invalidateCategoryProductCache() {
    return ref
        .read(cacheStoreProvider)
        .deleteByPrefix(
          CachePolicy.key(
            CacheKey.productsByCategory,
            suffix: 'category:$arg|',
          ),
        );
  }
}
