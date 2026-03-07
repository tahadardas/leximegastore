import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/home_ad_banner_entity.dart';
import '../../domain/entities/home_section_entity.dart';
import '../../domain/repositories/home_sections_repository.dart';
import '../datasources/home_sections_remote_datasource.dart';

final homeSectionsRepositoryProvider = Provider<HomeSectionsRepository>((ref) {
  return HomeSectionsRepositoryImpl(
    ref.watch(homeSectionsRemoteDatasourceProvider),
  );
});

class HomeSectionsRepositoryImpl implements HomeSectionsRepository {
  final HomeSectionsRemoteDatasource _datasource;

  HomeSectionsRepositoryImpl(this._datasource);

  @override
  Future<List<HomeSectionEntity>> getSections({bool preferCache = true}) async {
    final sections = await _datasource.getSections(preferCache: preferCache);

    return sections
        .map(
          (section) => HomeSectionEntity(
            id: section.id,
            titleAr: section.titleAr,
            type: section.type,
            sortOrder: section.sortOrder,
            termId: section.termId,
            isActive: section.isActive,
            items: section.items,
          ),
        )
        .toList();
  }

  @override
  Future<List<HomeAdBannerEntity>> getAdBanners() async {
    final items = await _datasource.getAdBanners();
    return items.map((item) => item.toEntity()).toList();
  }
}
