import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/admin_merch_repository.dart';
import '../../domain/entities/admin_merch_category.dart';

final adminMerchCategoriesControllerProvider =
    AsyncNotifierProvider<
      AdminMerchCategoriesController,
      List<AdminMerchCategory>
    >(AdminMerchCategoriesController.new);

class AdminMerchCategoriesController
    extends AsyncNotifier<List<AdminMerchCategory>> {
  @override
  FutureOr<List<AdminMerchCategory>> build() {
    return _fetch();
  }

  Future<List<AdminMerchCategory>> _fetch() {
    return ref.read(adminMerchRepositoryProvider).getCategories();
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(_fetch);
  }

  Future<void> saveOrder(List<AdminMerchCategory> items) async {
    await ref.read(adminMerchRepositoryProvider).saveCategoriesOrder(items);
    state = AsyncData(items);
  }
}
