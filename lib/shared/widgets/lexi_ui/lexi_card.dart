import 'package:flutter/material.dart';

import '../../../design_system/lexi_motion.dart';
import '../../../design_system/lexi_tokens.dart';

class LexiCard extends StatefulWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final VoidCallback? onTap;
  final Color? color;
  final double? width;
  final double? height;
  final BorderRadius? borderRadius;
  final List<BoxShadow>? boxShadow;

  const LexiCard({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.onTap,
    this.color,
    this.width,
    this.height,
    this.borderRadius,
    this.boxShadow,
  });

  @override
  State<LexiCard> createState() => _LexiCardState();
}

class _LexiCardState extends State<LexiCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final radius = widget.borderRadius ?? BorderRadius.circular(LexiRadius.lg);
    final tapEnabled = widget.onTap != null;

    return AnimatedScale(
      scale: tapEnabled && _pressed ? LexiMotion.tapScale : 1,
      duration: LexiMotion.tap,
      curve: LexiMotion.standardCurve,
      child: Container(
        width: widget.width,
        height: widget.height,
        margin: widget.margin,
        decoration: BoxDecoration(
          color: widget.color ?? LexiColors.brandWhite,
          borderRadius: radius,
          boxShadow: widget.boxShadow ?? LexiShadows.md,
          border: Border.all(color: LexiColors.neutral200),
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: radius,
          child: InkWell(
            onTap: widget.onTap,
            borderRadius: radius,
            splashFactory: tapEnabled
                ? InkRipple.splashFactory
                : NoSplash.splashFactory,
            highlightColor: Colors.transparent,
            onTapDown: tapEnabled
                ? (_) => setState(() => _pressed = true)
                : null,
            onTapCancel: tapEnabled
                ? () => setState(() => _pressed = false)
                : null,
            onTapUp: tapEnabled
                ? (_) => setState(() => _pressed = false)
                : null,
            child: Padding(
              padding: widget.padding ?? const EdgeInsets.all(LexiSpacing.md),
              child: widget.child,
            ),
          ),
        ),
      ),
    );
  }
}
