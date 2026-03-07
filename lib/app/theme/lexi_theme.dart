import 'package:flutter/material.dart';

import '../../design_system/lexi_theme.dart' as ds;
import '../../design_system/lexi_tokens.dart' as tokens;

// Legacy compatibility surface for files still importing app/theme/lexi_theme.dart.
abstract final class LexiColors {
  static const primary = LexiColorsTokens.primary;
  static const onPrimary = LexiColorsTokens.onPrimary;
  static const black = LexiColorsTokens.black;
  static const white = LexiColorsTokens.white;
  static const lightGray = LexiColorsTokens.lightGray;
  static const error = LexiColorsTokens.error;
  static const onError = LexiColorsTokens.onError;
  static const surface = LexiColorsTokens.surface;
  static const onSurface = LexiColorsTokens.onSurface;
  static const outline = LexiColorsTokens.outline;
  static const secondaryText = LexiColorsTokens.secondaryText;
}

abstract final class LexiColorsTokens {
  static const Color primary = tokens.LexiColors.brandPrimary;
  static const Color onPrimary = tokens.LexiColors.brandBlack;
  static const Color black = tokens.LexiColors.brandBlack;
  static const Color white = tokens.LexiColors.brandWhite;
  static const Color lightGray = tokens.LexiColors.background;
  static const Color error = tokens.LexiColors.error;
  static const Color onError = tokens.LexiColors.brandWhite;
  static const Color surface = tokens.LexiColors.surface;
  static const Color onSurface = tokens.LexiColors.textPrimary;
  static const Color outline = tokens.LexiColors.borderSubtle;
  static const Color secondaryText = tokens.LexiColors.textSecondary;
}

abstract final class LexiSpacing {
  static const xs = tokens.LexiSpacing.xs;
  static const sm = tokens.LexiSpacing.sm;
  static const md = tokens.LexiSpacing.md;
  static const lg = tokens.LexiSpacing.lg;
  static const xl = tokens.LexiSpacing.xl;
  static const xxl = tokens.LexiSpacing.xxl;
}

abstract final class LexiRadius {
  static const xs = 4.0;
  static const sm = tokens.LexiRadius.sm;
  static const md = tokens.LexiRadius.md;
  static const lg = tokens.LexiRadius.lg;
  static const xl = tokens.LexiRadius.xl;
  static const full = tokens.LexiRadius.full;
}

abstract final class LexiTheme {
  static ThemeData get light => ds.LexiTheme.light;
}
