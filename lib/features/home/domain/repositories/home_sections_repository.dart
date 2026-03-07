import '../entities/home_ad_banner_entity.dart';
import '../entities/home_section_entity.dart';

abstract class HomeSectionsRepository {
  Future<List<HomeSectionEntity>> getSections({bool preferCache = true});
  Future<List<HomeAdBannerEntity>> getAdBanners();
}
