import 'package:flutter/material.dart';
import 'lexi_tokens.dart';

class LexiTypography {
  static const String fontFamily = 'Cairo';

  static const TextStyle h1 = TextStyle(
    fontFamily: fontFamily,
    fontSize: 28,
    fontWeight: FontWeight.w800,
    color: LexiColors.brandBlack,
    height: 1.35,
  );
  static const TextStyle h2 = TextStyle(
    fontFamily: fontFamily,
    fontSize: 22,
    fontWeight: FontWeight.w800,
    color: LexiColors.brandBlack,
    height: 1.35,
  );
  static const TextStyle h3 = TextStyle(
    fontFamily: fontFamily,
    fontSize: 18,
    fontWeight: FontWeight.w700,
    color: LexiColors.brandBlack,
    height: 1.35,
  );
  static const TextStyle h4 = h3;

  static const TextStyle bodyLg = TextStyle(
    fontFamily: fontFamily,
    fontSize: 16,
    fontWeight: FontWeight.w500,
    color: LexiColors.neutral800,
    height: 1.35,
  );
  static const TextStyle bodyMd = TextStyle(
    fontFamily: fontFamily,
    fontSize: 14,
    fontWeight: FontWeight.w500,
    color: LexiColors.neutral600,
    height: 1.35,
  );
  static const TextStyle bodySm = TextStyle(
    fontFamily: fontFamily,
    fontSize: 12,
    fontWeight: FontWeight.w500,
    color: LexiColors.neutral500,
    height: 1.35,
  );
  static const TextStyle body = bodyMd;
  static const TextStyle bodySmall = bodySm;

  static const TextStyle labelLg = TextStyle(
    fontFamily: fontFamily,
    fontSize: 16,
    fontWeight: FontWeight.w700,
    color: LexiColors.brandBlack,
    height: 1.35,
  );
  static const TextStyle labelMd = TextStyle(
    fontFamily: fontFamily,
    fontSize: 14,
    fontWeight: FontWeight.w700,
    color: LexiColors.brandBlack,
    height: 1.35,
  );
  static const TextStyle labelSm = TextStyle(
    fontFamily: fontFamily,
    fontSize: 12,
    fontWeight: FontWeight.w600,
    color: LexiColors.neutral500,
    height: 1.35,
  );
  static const TextStyle bodyBold = labelMd;
  static const TextStyle bodySmallBold = labelSm;

  static const TextStyle priceLg = TextStyle(
    fontFamily: fontFamily,
    fontSize: 22,
    fontWeight: FontWeight.w800,
    color: LexiColors.brandBlack,
    height: 1.35,
  );
  static const TextStyle priceMd = TextStyle(
    fontFamily: fontFamily,
    fontSize: 18,
    fontWeight: FontWeight.w800,
    color: LexiColors.brandBlack,
    height: 1.35,
  );
  static const TextStyle titleLarge = h2;
  static const TextStyle titleMedium = h3;
  static const TextStyle caption = bodySm;
  static const TextStyle button = TextStyle(
    fontFamily: fontFamily,
    fontSize: 14,
    fontWeight: FontWeight.w700,
    color: LexiColors.brandBlack,
    height: 1.35,
  );

  static const TextStyle priceStyle = priceLg;

  // Aliases
  static const TextStyle title = h3;
}
