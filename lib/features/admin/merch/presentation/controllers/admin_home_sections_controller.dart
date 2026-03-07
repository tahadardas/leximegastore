import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/admin_merch_repository.dart';
import '../../domain/entities/admin_home_section.dart';
import '../../domain/entities/admin_merch_product.dart';

final adminHomeSectionsControllerProvider =
    AsyncNotifierProvider<AdminHomeSectionsController, List<AdminHomeSection>>(
      AdminHomeSectionsController.new,
    );

class AdminHomeSectionsController
    extends AsyncNotifier<List<AdminHomeSection>> {
  @override
  FutureOr<List<AdminHomeSection>> build() {
    return _fetch();
  }

  Future<List<AdminHomeSection>> _fetch() {
    return ref.read(adminMerchRepositoryProvider).getHomeSections();
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(_fetch);
  }

  Future<void> saveReorder(List<AdminHomeSection> items) async {
    await ref.read(adminMerchRepositoryProvider).reorderHomeSections(items);
    state = AsyncData(items);
  }

  Future<void> create({
    required String titleAr,
    required String type,
    int? termId,
    bool isActive = true,
  }) async {
    await ref
        .read(adminMerchRepositoryProvider)
        .createHomeSection(
          titleAr: titleAr,
          type: type,
          termId: termId,
          isActive: isActive,
        );
    await refresh();
  }

  Future<void> toggleActive(AdminHomeSection section, bool value) async {
    await ref
        .read(adminMerchRepositoryProvider)
        .updateHomeSection(section.id, isActive: value);
    await refresh();
  }

  Future<void> deleteSection(int id) async {
    await ref.read(adminMerchRepositoryProvider).deleteHomeSection(id);
    await refresh();
  }
}

final adminHomeSectionItemsControllerProvider =
    AsyncNotifierProviderFamily<
      AdminHomeSectionItemsController,
      List<AdminMerchProduct>,
      int
    >(AdminHomeSectionItemsController.new);

class AdminHomeSectionItemsController
    extends FamilyAsyncNotifier<List<AdminMerchProduct>, int> {
  @override
  FutureOr<List<AdminMerchProduct>> build(int arg) {
    return ref.read(adminMerchRepositoryProvider).getHomeSectionItems(arg);
  }

  Future<void> save(List<AdminMerchProduct> items) async {
    await ref
        .read(adminMerchRepositoryProvider)
        .saveHomeSectionItems(sectionId: arg, items: items);
    // Re-fetch from server to confirm persistence instead of just using local state.
    final refreshed = await ref
        .read(adminMerchRepositoryProvider)
        .getHomeSectionItems(arg);
    state = AsyncData(refreshed);
  }
}
