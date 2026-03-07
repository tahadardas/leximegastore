import 'package:flutter/material.dart';

class LexiColors {
  // Brand
  static const Color brandPrimary = Color(0xFFFACB21);
  static const Color brandBlack = Color(0xFF0C0B0A);
  static const Color brandWhite = Color(0xFFFFFFFF);
  static const Color brandAccent = Color(0xFF7C3AED);

  // Status
  static const Color success = Color(0xFF1FAF38);
  static const Color error = Color(0xFFE33538);
  static const Color warning = Color(0xFFF59E0B);
  static const Color info = Color(0xFF2563EB);

  // Neutrals / surfaces
  static const Color neutral50 = Color(0xFFFAFAFA);
  static const Color neutral100 = Color(0xFFF5F5F5);
  static const Color neutral200 = Color(0xFFEAEAEA);
  static const Color neutral300 = Color(0xFFD8D8D8);
  static const Color neutral400 = Color(0xFF9F9F9F);
  static const Color neutral500 = Color(0xFF6E6E6E);
  static const Color neutral600 = Color(0xFF555555);
  static const Color neutral700 = Color(0xFF3D3D3D);
  static const Color neutral800 = Color(0xFF232323);
  static const Color neutral900 = Color(0xFF111111);

  // Dark Mode Neutrals
  static const Color darkBackground = Color(0xFF090909);
  static const Color darkSurface = Color(0xFF151515);
  static const Color darkBorder = Color(0xFF292524);

  // Semantic text/surface aliases
  static const Color background = neutral100;
  static const Color surface = brandWhite;
  static const Color surfaceAlt = neutral50;
  static const Color borderSubtle = neutral200;
  static const Color borderStrong = neutral300;
  static const Color textPrimary = neutral900;
  static const Color textSecondary = neutral600;
  static const Color textMuted = neutral500;

  // Aliases for compatibility
  static const Color brandGrey = neutral500;
  static const Color brandSecondary = warning;
  static const Color discountRed = error;
  static const Color primaryYellow = brandPrimary;
  static const Color darkBlack = brandBlack;
  static const Color white = brandWhite;
  static const Color gray50 = neutral50;
  static const Color gray100 = neutral100;
  static const Color gray200 = neutral200;
  static const Color gray300 = neutral300;
  static const Color gray500 = neutral500;
  static const Color gray700 = neutral700;
  static const Color gray900 = neutral900;
  static const Color successGreen = success;
  static const Color primaryPurple = brandAccent;
}

class LexiSpacing {
  // 8pt grid
  static const double s4 = 4.0;
  static const double s8 = 8.0;
  static const double s12 = 12.0;
  static const double s16 = 16.0;
  static const double s20 = 20.0;
  static const double s24 = 24.0;
  static const double s32 = 32.0;
  static const double s40 = 40.0;
  static const double s48 = 48.0;

  // Compatibility aliases
  static const double xs = s4;
  static const double sm = s8;
  static const double md = s16;
  static const double lg = s24;
  static const double xl = s32;
  static const double xxl = s40;
}

class LexiRadius {
  // Core
  static const double card = 16.0;
  static const double button = 14.0;
  static const double sheet = 24.0;
  static const double full = 999.0;

  // Compatibility aliases
  static const double sm = 12.0;
  static const double md = button;
  static const double lg = card;
  static const double xl = sheet;
  static const double bottomSheet = sheet;
}

class LexiShadows {
  static const List<BoxShadow> cardLow = [
    BoxShadow(
      color: Color(0x12000000),
      offset: Offset(0, 4),
      blurRadius: 14,
      spreadRadius: -6,
    ),
  ];

  static const List<BoxShadow> card = [
    BoxShadow(
      color: Color(0x17000000),
      offset: Offset(0, 8),
      blurRadius: 20,
      spreadRadius: -8,
    ),
  ];

  static const List<BoxShadow> elevation = [
    BoxShadow(
      color: Color(0x1F000000),
      offset: Offset(0, 12),
      blurRadius: 24,
      spreadRadius: -10,
    ),
  ];

  // Compatibility aliases
  static const List<BoxShadow> sm = cardLow;
  static const List<BoxShadow> md = card;
  static const List<BoxShadow> lg = elevation;
  static const List<BoxShadow> cta = [
    BoxShadow(
      color: Color(0x52FACB21),
      offset: Offset(0, 10),
      blurRadius: 24,
      spreadRadius: -10,
    ),
  ];
}

class LexiDurations {
  static const Duration fast = Duration(milliseconds: 120);
  static const Duration medium = Duration(milliseconds: 220);
  static const Duration slow = Duration(milliseconds: 320);
}

class LexiIconSizes {
  static const double sm = 16.0;
  static const double md = 20.0;
  static const double lg = 24.0;
  static const double xl = 28.0;
}

class LexiTouchTargets {
  static const double min = 44.0;
  static const double comfortable = 48.0;
}
