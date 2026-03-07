import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/admin_merch_repository.dart';
import '../../domain/entities/admin_ad_banner.dart';

final adminAdBannersControllerProvider =
    AsyncNotifierProvider<AdminAdBannersController, List<AdminAdBanner>>(
      AdminAdBannersController.new,
    );

class AdminAdBannersController extends AsyncNotifier<List<AdminAdBanner>> {
  @override
  FutureOr<List<AdminAdBanner>> build() {
    return _fetch();
  }

  Future<List<AdminAdBanner>> _fetch() {
    return ref.read(adminMerchRepositoryProvider).getAdBanners();
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(_fetch);
  }

  Future<void> save(List<AdminAdBanner> items) async {
    await ref.read(adminMerchRepositoryProvider).saveAdBanners(items);
    state = AsyncData(items);
  }
}
