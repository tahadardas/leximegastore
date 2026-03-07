import 'package:flutter/material.dart';

import 'lexi_colors.dart';

abstract class LexiStyleText {
  static const fontFamily = 'Cairo';

  static const h1 = TextStyle(
    fontFamily: fontFamily,
    fontSize: 22,
    fontWeight: FontWeight.w800,
    color: LexiStyleColors.textPrimary,
    height: 1.25,
  );

  static const h2 = TextStyle(
    fontFamily: fontFamily,
    fontSize: 18,
    fontWeight: FontWeight.w700,
    color: LexiStyleColors.textPrimary,
    height: 1.3,
  );

  static const body = TextStyle(
    fontFamily: fontFamily,
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: LexiStyleColors.textPrimary,
    height: 1.35,
  );

  static const label = TextStyle(
    fontFamily: fontFamily,
    fontSize: 12,
    fontWeight: FontWeight.w600,
    color: LexiStyleColors.textSecondary,
    height: 1.2,
  );
}
