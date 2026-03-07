import 'package:flutter/material.dart';
import '../../../design_system/lexi_tokens.dart';
import 'lexi_skeleton.dart';

class LexiHorizontalStripSkeleton extends StatelessWidget {
  final double height;
  final double itemWidth;
  final int itemCount;

  const LexiHorizontalStripSkeleton({
    super.key,
    this.height = 326,
    this.itemWidth = 214,
    this.itemCount = 4,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: LexiSpacing.s12),
        itemCount: itemCount,
        separatorBuilder: (_, _) => const SizedBox(width: LexiSpacing.s12),
        itemBuilder: (context, index) {
          return SizedBox(
            width: itemWidth,
            child: const LexiSkeleton(borderRadius: LexiRadius.card),
          );
        },
      ),
    );
  }
}
