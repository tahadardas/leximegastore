import 'dart:ui';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persistent settings for the hero product slider overlay.
class HeroBannerSettings {
  /// Hex color of the glassmorphism panel (e.g. "FFFFFF" for white, "000000" for black).
  final String overlayColorHex;

  /// Opacity of the glassmorphism panel [0.0 – 1.0].
  final double overlayOpacity;

  const HeroBannerSettings({
    this.overlayColorHex = 'FFFFFF',
    this.overlayOpacity = 0.18,
  });

  static const _kOverlayColorKey = 'hero_banner_overlay_color';
  static const _kOverlayOpacityKey = 'hero_banner_overlay_opacity';

  Color get overlayColor {
    final hex = overlayColorHex.replaceAll('#', '');
    final value = int.tryParse(hex, radix: 16);
    if (value == null) return const Color(0xFFFFFFFF);
    return Color(0xFF000000 | value);
  }

  Color get overlayColorWithOpacity =>
      overlayColor.withValues(alpha: overlayOpacity.clamp(0.0, 1.0));

  static Future<HeroBannerSettings> load() async {
    final prefs = await SharedPreferences.getInstance();
    return HeroBannerSettings(
      overlayColorHex: prefs.getString(_kOverlayColorKey) ?? 'FFFFFF',
      overlayOpacity: prefs.getDouble(_kOverlayOpacityKey) ?? 0.18,
    );
  }

  Future<void> save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kOverlayColorKey, overlayColorHex);
    await prefs.setDouble(_kOverlayOpacityKey, overlayOpacity);
  }

  HeroBannerSettings copyWith({
    String? overlayColorHex,
    double? overlayOpacity,
  }) {
    return HeroBannerSettings(
      overlayColorHex: overlayColorHex ?? this.overlayColorHex,
      overlayOpacity: overlayOpacity ?? this.overlayOpacity,
    );
  }
}

/// Provider for the hero banner overlay settings.
final heroBannerSettingsProvider = FutureProvider<HeroBannerSettings>(
  (ref) => HeroBannerSettings.load(),
);
