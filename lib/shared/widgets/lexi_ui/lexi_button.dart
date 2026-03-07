import 'package:flutter/material.dart';
import '../../../design_system/lexi_tokens.dart';
import '../../../design_system/lexi_typography.dart';

enum LexiButtonType { primary, secondary, outline, text, icon }

enum LexiButtonVariant { primary, secondary, outline, text }

enum LexiButtonSize { small, medium, large }

class LexiButton extends StatefulWidget {
  final String? text; // Make nullable for icon button
  final IconData? icon; // Add icon support
  final String? label; // Alias for text to match usage in existing code
  final VoidCallback? onPressed;
  final bool isLoading;
  final bool isOutlined; // Deprecated, use type or variant
  final bool isFullWidth; // Added parameter
  final LexiButtonType type;
  final LexiButtonVariant? variant; // Legacy support
  final LexiButtonSize? size; // Legacy support
  final Color? backgroundColor;
  final Color? textColor;
  final Color? customColor; // For icon button

  const LexiButton({
    super.key,
    this.text,
    this.label,
    this.icon,
    this.onPressed,
    this.isLoading = false,
    this.isOutlined = false,
    this.isFullWidth = false,
    this.type = LexiButtonType.primary,
    this.variant,
    this.size,
    this.backgroundColor,
    this.textColor,
    this.customColor,
  });

  @override
  State<LexiButton> createState() => _LexiButtonState();
}

class _LexiButtonState extends State<LexiButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
      reverseDuration: const Duration(milliseconds: 100),
    );
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.96,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onPointerDown(PointerDownEvent event) {
    if (widget.onPressed != null && !widget.isLoading) {
      _controller.forward();
    }
  }

  void _onPointerUp(PointerUpEvent event) {
    if (widget.onPressed != null && !widget.isLoading) {
      _controller.reverse();
    }
  }

  void _onPointerCancel(PointerCancelEvent event) {
    if (widget.onPressed != null && !widget.isLoading) {
      _controller.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    var effectiveType = widget.type;
    if (widget.variant != null) {
      if (widget.variant == LexiButtonVariant.outline) {
        effectiveType = LexiButtonType.outline;
      }
      if (widget.variant == LexiButtonVariant.primary) {
        effectiveType = LexiButtonType.primary;
      }
      if (widget.variant == LexiButtonVariant.secondary) {
        effectiveType = LexiButtonType.secondary;
      }
      if (widget.variant == LexiButtonVariant.text) {
        effectiveType = LexiButtonType.text;
      }
    } else if (widget.isOutlined) {
      effectiveType = LexiButtonType.outline;
    }

    final contentText = widget.text ?? widget.label ?? '';
    final button = _buildButton(context, effectiveType, contentText);

    Widget animatedButton = ScaleTransition(
      scale: _scaleAnimation,
      child: Listener(
        onPointerDown: _onPointerDown,
        onPointerUp: _onPointerUp,
        onPointerCancel: _onPointerCancel,
        child: button,
      ),
    );

    if (widget.isFullWidth) {
      return SizedBox(width: double.infinity, child: animatedButton);
    }

    return animatedButton;
  }

  Widget _buildButton(
    BuildContext context,
    LexiButtonType effectiveType,
    String contentText,
  ) {
    if (effectiveType == LexiButtonType.icon && widget.icon != null) {
      return IconButton(
        style: IconButton.styleFrom(
          minimumSize: const Size.square(LexiTouchTargets.min),
          tapTargetSize: MaterialTapTargetSize.padded,
        ),
        onPressed: widget.isLoading ? null : widget.onPressed,
        icon: widget.isLoading
            ? SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: widget.customColor ?? LexiColors.brandPrimary,
                ),
              )
            : Icon(
                widget.icon,
                color: widget.customColor ?? LexiColors.brandBlack,
              ),
        tooltip: contentText,
      );
    }

    if (effectiveType == LexiButtonType.outline) {
      return OutlinedButton(
        onPressed: widget.isLoading ? null : widget.onPressed,
        style: OutlinedButton.styleFrom(
          side: BorderSide(
            color: widget.backgroundColor ?? LexiColors.neutral300,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(LexiRadius.md),
          ),
          padding: _padding(),
          minimumSize: const Size(64, LexiTouchTargets.comfortable),
          backgroundColor: LexiColors.brandWhite,
          foregroundColor: widget.textColor ?? LexiColors.brandBlack,
          disabledForegroundColor: LexiColors.neutral400,
          textStyle: _textStyle(effectiveType),
        ),
        child: _buildContent(
          contentText,
          loadingColor: widget.textColor ?? LexiColors.brandBlack,
        ),
      );
    }

    if (effectiveType == LexiButtonType.secondary) {
      return ElevatedButton(
        onPressed: widget.isLoading ? null : widget.onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: widget.backgroundColor ?? LexiColors.brandBlack,
          foregroundColor: widget.textColor ?? LexiColors.brandWhite,
          disabledBackgroundColor: LexiColors.neutral300,
          disabledForegroundColor: LexiColors.neutral500,
          minimumSize: const Size(64, LexiTouchTargets.comfortable),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(LexiRadius.md),
          ),
          padding: _padding(),
          elevation: 0,
          textStyle: _textStyle(effectiveType),
        ),
        child: _buildContent(
          contentText,
          loadingColor: widget.textColor ?? LexiColors.brandWhite,
        ),
      );
    }

    if (effectiveType == LexiButtonType.text) {
      return TextButton(
        onPressed: widget.isLoading ? null : widget.onPressed,
        style: TextButton.styleFrom(
          foregroundColor: widget.textColor ?? LexiColors.brandBlack,
          disabledForegroundColor: LexiColors.neutral400,
          minimumSize: const Size(64, LexiTouchTargets.min),
          padding: _padding(),
          textStyle: _textStyle(effectiveType),
        ),
        child: _buildContent(
          contentText,
          loadingColor: widget.textColor ?? LexiColors.brandBlack,
        ),
      );
    }

    // Primary
    return ElevatedButton(
      onPressed: widget.isLoading ? null : widget.onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: widget.backgroundColor ?? LexiColors.brandPrimary,
        foregroundColor: widget.textColor ?? LexiColors.brandBlack,
        disabledBackgroundColor: LexiColors.neutral300,
        disabledForegroundColor: LexiColors.neutral500,
        minimumSize: const Size(64, LexiTouchTargets.comfortable),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(LexiRadius.md),
        ),
        padding: _padding(),
        elevation: 0,
        shadowColor: Colors.transparent,
        textStyle: _textStyle(effectiveType),
      ),
      child: _buildContent(
        contentText,
        loadingColor: widget.textColor ?? LexiColors.brandBlack,
      ),
    );
  }

  Widget _buildContent(String text, {required Color loadingColor}) {
    if (widget.isLoading) {
      return SizedBox(
        height: 20,
        width: 20,
        child: CircularProgressIndicator(strokeWidth: 2, color: loadingColor),
      );
    }

    if (widget.icon != null) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(widget.icon, size: 20),
          const SizedBox(width: 8),
          Text(text),
        ],
      );
    }

    return Text(text);
  }

  EdgeInsets _padding() {
    switch (widget.size) {
      case LexiButtonSize.small:
        return const EdgeInsets.symmetric(vertical: 8, horizontal: 12);
      case LexiButtonSize.large:
        return const EdgeInsets.symmetric(vertical: 14, horizontal: 24);
      case LexiButtonSize.medium:
      default:
        return const EdgeInsets.symmetric(vertical: 12, horizontal: 16);
    }
  }

  TextStyle _textStyle(LexiButtonType type) {
    if (widget.size == LexiButtonSize.small) {
      return LexiTypography.labelSm;
    }
    return LexiTypography.labelMd;
  }
}
