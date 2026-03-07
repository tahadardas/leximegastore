import 'package:flutter/material.dart';
import '../../../../design_system/lexi_tokens.dart';

class LexiSkeleton extends StatefulWidget {
  final double? width;
  final double? height;
  final double? borderRadius;
  final BoxShape shape;

  const LexiSkeleton({
    super.key,
    this.width,
    this.height,
    this.borderRadius,
    this.shape = BoxShape.rectangle,
  });

  @override
  State<LexiSkeleton> createState() => _LexiSkeletonState();
}

class _LexiSkeletonState extends State<LexiSkeleton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Color?> _colorAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    _colorAnimation = ColorTween(
      begin: LexiColors.neutral200,
      end: LexiColors.neutral50,
    ).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _colorAnimation,
      builder: (context, child) {
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            color: _colorAnimation.value,
            shape: widget.shape,
            borderRadius: widget.shape == BoxShape.rectangle
                ? BorderRadius.circular(widget.borderRadius ?? LexiRadius.md)
                : null,
          ),
        );
      },
    );
  }
}
