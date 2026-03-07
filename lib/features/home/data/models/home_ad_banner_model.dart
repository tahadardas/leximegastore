import '../../../../core/utils/safe_parsers.dart';
import '../../../../core/utils/text_normalizer.dart';
import '../../../../core/utils/url_utils.dart';
import '../../domain/entities/home_ad_banner_entity.dart';

class HomeAdBannerModel {
  final String id;
  final String imageUrl;
  final String linkUrl;
  final String titleAr;
  final String subtitleAr;
  final String badge;
  final bool isActive;
  final int sortOrder;
  final String gradientStart;
  final String gradientEnd;
  final String ctaText;
  final String textColorHex;
  final String badgeColorHex;

  const HomeAdBannerModel({
    required this.id,
    required this.imageUrl,
    required this.linkUrl,
    required this.titleAr,
    required this.subtitleAr,
    required this.badge,
    required this.isActive,
    required this.sortOrder,
    this.gradientStart = 'FF131313',
    this.gradientEnd = 'FF2A2417',
    this.ctaText = 'تسوق الآن',
    this.textColorHex = 'FFFFFFFF',
    this.badgeColorHex = 'FFFACB21',
  });

  factory HomeAdBannerModel.fromJson(Map<String, dynamic> json) {
    return HomeAdBannerModel(
      id: (json['id'] ?? '').toString(),
      imageUrl: normalizeHttpUrl((json['image_url'] ?? '').toString()),
      linkUrl: (json['link_url'] ?? '').toString(),
      titleAr: TextNormalizer.normalize(json['title_ar']),
      subtitleAr: TextNormalizer.normalize(json['subtitle_ar']),
      badge: TextNormalizer.normalize(json['badge']),
      isActive: parseBool(json['is_active']),
      sortOrder: parseInt(json['sort_order']),
      gradientStart: (json['gradient_start'] ?? '').toString(),
      gradientEnd: (json['gradient_end'] ?? '').toString(),
      ctaText: (json['cta_text'] ?? '').toString(),
      textColorHex: (json['text_color'] ?? json['text_color_hex'] ?? '')
          .toString(),
      badgeColorHex: (json['badge_color'] ?? json['badge_color_hex'] ?? '')
          .toString(),
    );
  }

  HomeAdBannerEntity toEntity() {
    return HomeAdBannerEntity(
      id: id,
      imageUrl: imageUrl,
      linkUrl: linkUrl,
      titleAr: titleAr,
      subtitleAr: subtitleAr,
      badge: badge,
      isActive: isActive,
      sortOrder: sortOrder,
      gradientStart: gradientStart.isNotEmpty ? gradientStart : 'FF131313',
      gradientEnd: gradientEnd.isNotEmpty ? gradientEnd : 'FF2A2417',
      ctaText: ctaText.isNotEmpty ? ctaText : 'تسوق الآن',
      textColorHex: textColorHex.isNotEmpty ? textColorHex : 'FFFFFFFF',
      badgeColorHex: badgeColorHex.isNotEmpty ? badgeColorHex : 'FFFACB21',
    );
  }
}
