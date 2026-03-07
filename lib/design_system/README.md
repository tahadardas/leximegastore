# Lexi Design System

This directory contains the core design system for the Lexi application.

## 🎨 Design Tokens (`lexi_tokens.dart`)
- **Colors**: `LexiColors.brandPrimary` (Yellow), `LexiColors.brandBlack`, etc.
- **Spacing**: `LexiSpacing.md` (16.0), `LexiSpacing.lg` (24.0).
- **Radius**: `LexiRadius.lg` (16.0) for cards, `LexiRadius.md` (12.0) for inputs.
- **Shadows**: `LexiShadows.sm`, `LexiShadows.md`.

## ✍️ Typography (`lexi_typography.dart`)
- Use `LexiTypography.h1`, `h2`, `bodyMd`, etc.
- Font Family: **Cairo** (Ensures good Arabic support).

## 🎭 Theme (`lexi_theme.dart`)
- `LexiTheme.light`: The main `ThemeData` for the app.
- Automatically wires up `InputDecoration`, `ButtonStyles`, etc.

## 🧩 Usage
Import the design system in your widgets:
```dart
import 'package:lexi_mega_store/design_system/lexi_tokens.dart';
import 'package:lexi_mega_store/design_system/lexi_typography.dart';
```

Use tokens instead of hardcoded values:
```dart
Container(
  padding: const EdgeInsets.all(LexiSpacing.md),
  decoration: BoxDecoration(
    color: LexiColors.brandWhite,
    borderRadius: BorderRadius.circular(LexiRadius.lg),
    boxShadow: LexiShadows.sm,
  ),
  child: Text('Hello', style: LexiTypography.h3),
)
```

## Internal Lint
- Run: `dart run scripts/design_token_lint.dart`
- Checks:
  - Prevent mixing `design_system/*` and `ui/lexi_design/*` imports in the same file.
  - Prints hints for potential hard-coded colors/spacing to migrate to tokens.
