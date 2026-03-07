import 'package:flutter/material.dart';
import '../../../../design_system/lexi_tokens.dart';
import '../../../../shared/widgets/lexi_ui/lexi_skeleton.dart';

class HomeBannerSkeleton extends StatelessWidget {
  const HomeBannerSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 2.2,
      child: LexiSkeleton(borderRadius: LexiRadius.lg),
    );
  }
}

class HomeCategoryGridSkeleton extends StatelessWidget {
  const HomeCategoryGridSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      itemCount: 10,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 5,
        crossAxisSpacing: LexiSpacing.s8,
        mainAxisSpacing: LexiSpacing.s8,
        childAspectRatio: 0.72,
      ),
      itemBuilder: (context, index) {
        return Column(
          children: [
            LexiSkeleton(width: 54, height: 54, shape: BoxShape.circle),
            const SizedBox(height: LexiSpacing.s8),
            LexiSkeleton(width: 40, height: 8, borderRadius: LexiRadius.sm),
          ],
        );
      },
    );
  }
}

class HomeProductCardSkeleton extends StatelessWidget {
  const HomeProductCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 140,
      margin: const EdgeInsetsDirectional.only(end: LexiSpacing.s12),
      decoration: BoxDecoration(
        color: LexiColors.white,
        borderRadius: BorderRadius.circular(LexiRadius.lg),
        border: Border.all(color: LexiColors.neutral200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(
            aspectRatio: 1.0,
            child: LexiSkeleton(borderRadius: LexiRadius.lg),
          ),
          Padding(
            padding: const EdgeInsets.all(LexiSpacing.s8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                LexiSkeleton(
                  width: 100,
                  height: 12,
                  borderRadius: LexiRadius.sm,
                ),
                const SizedBox(height: LexiSpacing.s4),
                LexiSkeleton(
                  width: 60,
                  height: 12,
                  borderRadius: LexiRadius.sm,
                ),
                const SizedBox(height: LexiSpacing.s8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    LexiSkeleton(
                      width: 40,
                      height: 16,
                      borderRadius: LexiRadius.sm,
                    ),
                    LexiSkeleton(
                      width: 24,
                      height: 24,
                      borderRadius: LexiRadius.md,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class HomeSectionSkeleton extends StatelessWidget {
  const HomeSectionSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: LexiSpacing.s12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              LexiSkeleton(width: 120, height: 20, borderRadius: LexiRadius.sm),
              LexiSkeleton(width: 60, height: 16, borderRadius: LexiRadius.sm),
            ],
          ),
        ),
        const SizedBox(height: LexiSpacing.s12),
        SizedBox(
          height: 240,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: LexiSpacing.s12),
            itemCount: 4,
            itemBuilder: (context, index) => const HomeProductCardSkeleton(),
          ),
        ),
      ],
    );
  }
}

class HomeProductGridSkeleton extends StatelessWidget {
  const HomeProductGridSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      itemCount: 6,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: LexiSpacing.s12,
        mainAxisSpacing: LexiSpacing.s12,
        childAspectRatio: 0.54,
      ),
      itemBuilder: (context, index) {
        return const HomeProductCardSkeleton();
      },
    );
  }
}
