import 'package:flutter/material.dart';

class HomeAdBannerEntity {
  final String id;
  final String imageUrl;
  final String linkUrl;
  final String titleAr;
  final String subtitleAr;
  final String badge;
  final bool isActive;
  final int sortOrder;

  /// Gradient start color hex (e.g. "FF131313")
  final String gradientStart;

  /// Gradient end color hex (e.g. "FF2A2417")
  final String gradientEnd;

  /// CTA button text (defaults to "تسوق الآن")
  final String ctaText;

  /// Text color hex for title/subtitle (defaults to white)
  final String textColorHex;

  /// Badge background color hex (defaults to primaryYellow)
  final String badgeColorHex;

  const HomeAdBannerEntity({
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

  static Color _parseHex(String hex, Color fallback) {
    try {
      final cleaned = hex.replaceAll('#', '').trim();
      if (cleaned.isEmpty) return fallback;
      final value = int.parse(
        cleaned.length == 6 ? 'FF$cleaned' : cleaned,
        radix: 16,
      );
      return Color(value);
    } catch (_) {
      return fallback;
    }
  }

  Color get gradientStartColor =>
      _parseHex(gradientStart, const Color(0xFF131313));
  Color get gradientEndColor => _parseHex(gradientEnd, const Color(0xFF2A2417));
  Color get textColor => _parseHex(textColorHex, const Color(0xFFFFFFFF));
  Color get badgeColor => _parseHex(badgeColorHex, const Color(0xFFFACB21));

  String get effectiveCtaText => ctaText.trim().isEmpty ? 'تسوق الآن' : ctaText;
}
