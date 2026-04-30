import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/logging/app_logger.dart';
import '../../data/repositories/home_sections_repository_impl.dart';
import '../../domain/entities/home_section_entity.dart';

final homeSectionsControllerProvider =
    AsyncNotifierProvider<HomeSectionsController, List<HomeSectionEntity>>(
      HomeSectionsController.new,
    );

class HomeSectionsController extends AsyncNotifier<List<HomeSectionEntity>> {
  static const Duration _minimumLoadingDuration = Duration(milliseconds: 280);

  @override
  FutureOr<List<HomeSectionEntity>> build() async {
    return _fetchWithMinimumDelay(preferCache: true);
  }

  Future<List<HomeSectionEntity>> _fetch({required bool preferCache}) {
    return ref
        .read(homeSectionsRepositoryProvider)
        .getSections(preferCache: preferCache);
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => _fetchWithMinimumDelay(preferCache: false),
    );
  }

  Future<List<HomeSectionEntity>> _fetchWithMinimumDelay({
    required bool preferCache,
  }) async {
    final startedAt = DateTime.now();
    try {
      return await _fetch(preferCache: preferCache);
    } catch (error, stackTrace) {
      AppLogger.warn(
        'تعذر تحديث أقسام الصفحة الرئيسية',
        extra: {'error': error.toString()},
      );
      AppLogger.error(
        'فشل تحميل أقسام الصفحة الرئيسية',
        error,
        stackTrace,
      );
      rethrow;
    } finally {
      final elapsed = DateTime.now().difference(startedAt);
      final remaining = _minimumLoadingDuration - elapsed;
      if (remaining > Duration.zero) {
        await Future<void>.delayed(remaining);
      }
    }
  }
}
