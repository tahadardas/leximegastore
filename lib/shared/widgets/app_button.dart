import 'package:flutter/material.dart';

import '../../design_system/lexi_tokens.dart';
import 'lexi_ui/lexi_button.dart';

/// Lexi Mega Store primary button widget.
enum AppButtonVariant { primary, secondary, outline, text }

typedef AppButtonType = AppButtonVariant;

class AppButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final AppButtonType type;
  final bool isLoading;
  final bool isExpanded;
  final IconData? icon;
  final double? height;
  final Color? textColor;

  const AppButton({
    super.key,
    required this.label,
    this.onPressed,
    this.type = AppButtonType.primary,
    this.isLoading = false,
    this.isExpanded = true,
    this.icon,
    this.height,
    this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    final button = LexiButton(
      label: label,
      icon: icon,
      onPressed: onPressed,
      isLoading: isLoading,
      isFullWidth: isExpanded,
      size: _mapSize(),
      type: _mapType(),
      textColor: textColor,
    );

    if (height == null) {
      return button;
    }

    return SizedBox(height: height, child: button);
  }

  LexiButtonType _mapType() {
    switch (type) {
      case AppButtonVariant.primary:
        return LexiButtonType.primary;
      case AppButtonVariant.secondary:
        return LexiButtonType.secondary;
      case AppButtonVariant.outline:
        return LexiButtonType.outline;
      case AppButtonVariant.text:
        return LexiButtonType.text;
    }
  }

  LexiButtonSize _mapSize() {
    final resolvedHeight = height ?? 52;
    if (resolvedHeight <= LexiTouchTargets.min) {
      return LexiButtonSize.small;
    }
    if (resolvedHeight >= 56) {
      return LexiButtonSize.large;
    }
    return LexiButtonSize.medium;
  }
}
