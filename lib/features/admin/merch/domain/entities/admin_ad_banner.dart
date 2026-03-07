import '../../../../../core/utils/safe_parsers.dart';
import '../../../../../core/utils/text_normalizer.dart';

class AdminAdBanner {
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

  const AdminAdBanner({
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

  factory AdminAdBanner.fromJson(Map<String, dynamic> json) {
    return AdminAdBanner(
      id: (json['id'] ?? '').toString(),
      imageUrl: (json['image_url'] ?? '').toString(),
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

  AdminAdBanner copyWith({
    String? id,
    String? imageUrl,
    String? linkUrl,
    String? titleAr,
    String? subtitleAr,
    String? badge,
    bool? isActive,
    int? sortOrder,
    String? gradientStart,
    String? gradientEnd,
    String? ctaText,
    String? textColorHex,
    String? badgeColorHex,
  }) {
    return AdminAdBanner(
      id: id ?? this.id,
      imageUrl: imageUrl ?? this.imageUrl,
      linkUrl: linkUrl ?? this.linkUrl,
      titleAr: titleAr ?? this.titleAr,
      subtitleAr: subtitleAr ?? this.subtitleAr,
      badge: badge ?? this.badge,
      isActive: isActive ?? this.isActive,
      sortOrder: sortOrder ?? this.sortOrder,
      gradientStart: gradientStart ?? this.gradientStart,
      gradientEnd: gradientEnd ?? this.gradientEnd,
      ctaText: ctaText ?? this.ctaText,
      textColorHex: textColorHex ?? this.textColorHex,
      badgeColorHex: badgeColorHex ?? this.badgeColorHex,
    );
  }

  Map<String, dynamic> toJson(int fallbackSortOrder) => {
    'id': id,
    'image_url': imageUrl.trim(),
    'link_url': linkUrl.trim(),
    'title_ar': titleAr.trim(),
    'subtitle_ar': subtitleAr.trim(),
    'badge': badge.trim(),
    'is_active': isActive,
    'sort_order': sortOrder > 0 ? sortOrder : fallbackSortOrder,
    'gradient_start': gradientStart.trim(),
    'gradient_end': gradientEnd.trim(),
    'cta_text': ctaText.trim(),
    'text_color': textColorHex.trim(),
    'badge_color': badgeColorHex.trim(),
  };
}
