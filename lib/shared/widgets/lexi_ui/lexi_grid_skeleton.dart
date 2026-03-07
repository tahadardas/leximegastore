import 'package:flutter/material.dart';
import '../../../design_system/lexi_tokens.dart';
import 'lexi_skeleton.dart';

class LexiGridSkeleton extends StatelessWidget {
  final int itemCount;
  final int crossAxisCount;
  final double childAspectRatio;

  const LexiGridSkeleton({
    super.key,
    this.itemCount = 6,
    this.crossAxisCount = 2,
    this.childAspectRatio = 0.56,
  });

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      itemCount: itemCount,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: LexiSpacing.s12),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        crossAxisSpacing: LexiSpacing.s12,
        mainAxisSpacing: LexiSpacing.s12,
        childAspectRatio: childAspectRatio,
      ),
      itemBuilder: (context, index) {
        return const LexiSkeleton(borderRadius: LexiRadius.card);
      },
    );
  }
}
