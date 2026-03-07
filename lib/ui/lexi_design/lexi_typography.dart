import 'package:flutter/material.dart';

import '../../design_system/lexi_tokens.dart';
import '../../design_system/lexi_typography.dart';

abstract final class LexiCommercialTypography {
  static const String fontFamily = LexiTypography.fontFamily;

  static final TextStyle h1 = LexiTypography.h1;
  static final TextStyle h2 = LexiTypography.h2;
  static final TextStyle h3 = LexiTypography.h3;
  static final TextStyle title = LexiTypography.labelMd;
  static final TextStyle body = LexiTypography.bodyMd.copyWith(
    color: LexiColors.textSecondary,
  );
  static final TextStyle caption = LexiTypography.caption;
  static final TextStyle price = LexiTypography.priceLg;
}
