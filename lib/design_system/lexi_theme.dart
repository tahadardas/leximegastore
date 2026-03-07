import 'package:flutter/material.dart';

import 'lexi_tokens.dart';
import 'lexi_typography.dart';

abstract class LexiTheme {
  static ThemeData get light {
    final scheme = const ColorScheme.light(
      primary: LexiColors.brandPrimary,
      secondary: LexiColors.brandBlack,
      surface: LexiColors.surface,
      error: LexiColors.error,
      onPrimary: LexiColors.brandBlack,
      onSecondary: LexiColors.brandWhite,
      onSurface: LexiColors.textPrimary,
      onError: LexiColors.brandWhite,
    );
    final baseText = Typography.material2021().black;
    final textTheme = baseText.copyWith(
      displayLarge: LexiTypography.h1,
      displayMedium: LexiTypography.h2,
      displaySmall: LexiTypography.h3,
      headlineMedium: LexiTypography.h2,
      headlineSmall: LexiTypography.h3,
      titleLarge: LexiTypography.h3,
      titleMedium: LexiTypography.labelLg,
      titleSmall: LexiTypography.labelMd,
      bodyLarge: LexiTypography.bodyLg,
      bodyMedium: LexiTypography.bodyMd,
      bodySmall: LexiTypography.bodySm,
      labelLarge: LexiTypography.labelMd,
      labelMedium: LexiTypography.labelSm,
      labelSmall: LexiTypography.caption,
    );

    return ThemeData(
      useMaterial3: true,
      fontFamily: LexiTypography.fontFamily,
      colorScheme: scheme,
      textTheme: textTheme,
      primaryTextTheme: textTheme,
      visualDensity: VisualDensity.standard,
      materialTapTargetSize: MaterialTapTargetSize.padded,
      scaffoldBackgroundColor: LexiColors.background,
      cardColor: LexiColors.surface,
      appBarTheme: AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: LexiColors.surface,
        foregroundColor: LexiColors.textPrimary,
        centerTitle: false,
        titleTextStyle: LexiTypography.h3,
      ),
      iconTheme: const IconThemeData(
        color: LexiColors.brandBlack,
        size: LexiIconSizes.lg,
      ),
      dividerTheme: const DividerThemeData(
        color: LexiColors.borderSubtle,
        thickness: 1,
        space: 1,
      ),
      listTileTheme: const ListTileThemeData(
        iconColor: LexiColors.brandBlack,
        textColor: LexiColors.textPrimary,
        contentPadding: EdgeInsets.symmetric(
          horizontal: LexiSpacing.s16,
          vertical: LexiSpacing.s4,
        ),
        minLeadingWidth: LexiSpacing.s24,
        minVerticalPadding: LexiSpacing.s8,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
        color: LexiColors.surface,
        shadowColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(LexiRadius.card),
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: LexiColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(LexiRadius.sheet),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: LexiColors.surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: LexiSpacing.s16,
          vertical: LexiSpacing.s12,
        ),
        hintStyle: LexiTypography.body.copyWith(color: LexiColors.textMuted),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(LexiRadius.button),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(LexiRadius.button),
          borderSide: const BorderSide(color: LexiColors.borderSubtle),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(LexiRadius.button),
          borderSide: const BorderSide(
            color: LexiColors.brandPrimary,
            width: 1.5,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(LexiRadius.button),
          borderSide: const BorderSide(color: LexiColors.error, width: 1.2),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(LexiRadius.button),
          borderSide: const BorderSide(color: LexiColors.error, width: 1.5),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 0,
          backgroundColor: LexiColors.brandPrimary,
          foregroundColor: LexiColors.brandBlack,
          minimumSize: const Size(64, LexiTouchTargets.comfortable),
          padding: const EdgeInsets.symmetric(
            horizontal: LexiSpacing.s16,
            vertical: LexiSpacing.s12,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(LexiRadius.button),
          ),
          textStyle: LexiTypography.button,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: LexiColors.brandBlack,
          minimumSize: const Size(64, LexiTouchTargets.comfortable),
          padding: const EdgeInsets.symmetric(
            horizontal: LexiSpacing.s16,
            vertical: LexiSpacing.s12,
          ),
          side: const BorderSide(color: LexiColors.borderStrong),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(LexiRadius.button),
          ),
          textStyle: LexiTypography.button,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: LexiColors.brandBlack,
          textStyle: LexiTypography.button,
          minimumSize: const Size(0, LexiTouchTargets.min),
          padding: const EdgeInsets.symmetric(
            horizontal: LexiSpacing.s8,
            vertical: LexiSpacing.s8,
          ),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: LexiColors.brandBlack,
        contentTextStyle: LexiTypography.body.copyWith(
          color: LexiColors.brandWhite,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(LexiRadius.button),
        ),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: LexiColors.brandPrimary,
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: LexiColors.surface,
        selectedItemColor: LexiColors.brandPrimary,
        unselectedItemColor: LexiColors.textMuted,
        selectedLabelStyle: TextStyle(
          fontFamily: LexiTypography.fontFamily,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
        unselectedLabelStyle: TextStyle(
          fontFamily: LexiTypography.fontFamily,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
        type: BottomNavigationBarType.fixed,
      ),
      extensions: <ThemeExtension<dynamic>>[const _LexiShadowExt()],
    );
  }
}

class _LexiShadowExt extends ThemeExtension<_LexiShadowExt> {
  const _LexiShadowExt();

  List<BoxShadow> get cardShadow => LexiShadows.card;

  @override
  ThemeExtension<_LexiShadowExt> copyWith() => const _LexiShadowExt();

  @override
  ThemeExtension<_LexiShadowExt> lerp(
    covariant ThemeExtension<_LexiShadowExt>? other,
    double t,
  ) {
    return const _LexiShadowExt();
  }
}
