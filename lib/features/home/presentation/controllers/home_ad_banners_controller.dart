import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/home_sections_repository_impl.dart';
import '../../domain/entities/home_ad_banner_entity.dart';

final homeAdBannersControllerProvider =
    AsyncNotifierProvider<HomeAdBannersController, List<HomeAdBannerEntity>>(
      HomeAdBannersController.new,
    );

class HomeAdBannersController extends AsyncNotifier<List<HomeAdBannerEntity>> {
  static const Duration _minimumLoadingDuration = Duration(milliseconds: 450);

  @override
  FutureOr<List<HomeAdBannerEntity>> build() async {
    return _fetchWithMinimumDelay();
  }

  Future<List<HomeAdBannerEntity>> _fetch() {
    return ref.read(homeSectionsRepositoryProvider).getAdBanners();
  }

  Future<List<HomeAdBannerEntity>> _fetchWithMinimumDelay() async {
    final startedAt = DateTime.now();
    try {
      return await _fetch();
    } finally {
      final elapsed = DateTime.now().difference(startedAt);
      final remaining = _minimumLoadingDuration - elapsed;
      if (remaining > Duration.zero) {
        await Future<void>.delayed(remaining);
      }
    }
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(_fetchWithMinimumDelay);
  }
}
