import 'package:flutter/material.dart';

import '../../design_system/lexi_tokens.dart';

class LoadingBodyStack extends StatelessWidget {
  final Widget child;
  final bool isLoading;
  final bool blockTouches;
  final Color? overlayColor;
  final double topInset;
  final Widget? indicator;

  const LoadingBodyStack({
    super.key,
    required this.child,
    required this.isLoading,
    this.blockTouches = false,
    this.overlayColor,
    this.topInset = 0,
    this.indicator,
  });

  @override
  Widget build(BuildContext context) {
    final resolvedTopInset = topInset < 0 ? 0.0 : topInset;

    return Stack(
      fit: StackFit.expand,
      children: [
        SafeArea(top: false, bottom: false, child: child),
        if (isLoading)
          PositionedDirectional(
            top: resolvedTopInset,
            start: 0,
            end: 0,
            bottom: 0,
            child: IgnorePointer(
              ignoring: !blockTouches,
              child: ColoredBox(
                color: overlayColor ?? Colors.black.withValues(alpha: 0.04),
                child: Center(
                  child:
                      indicator ??
                      const SizedBox(
                        width: 30,
                        height: 30,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.8,
                          color: LexiColors.brandPrimary,
                        ),
                      ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
