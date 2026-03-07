import 'package:flutter/material.dart';
import '../../design_system/lexi_tokens.dart';

abstract final class LexiCommercialColors {
  // Bridge to the unified design_system tokens.
  static const Color primaryYellow = LexiColors.brandPrimary;
  static const Color discountRed = LexiColors.error;
  static const Color darkBlack = LexiColors.brandBlack;
  static const Color background = LexiColors.background;
  static const Color successGreen = LexiColors.success;

  static const Color white = LexiColors.white;
  static const Color gray50 = LexiColors.gray50;
  static const Color gray100 = LexiColors.gray100;
  static const Color gray200 = LexiColors.gray200;
  static const Color gray300 = LexiColors.gray300;
  static const Color gray500 = LexiColors.gray500;
  static const Color gray700 = LexiColors.gray700;
  static const Color primaryPurple = LexiColors.primaryPurple;
  static const Color error = discountRed;
}
