import 'package:flutter/material.dart';

import '../../design_system/lexi_tokens.dart';

class ProductCardSkeleton extends StatefulWidget {
  const ProductCardSkeleton({super.key});

  @override
  State<ProductCardSkeleton> createState() => _ProductCardSkeletonState();
}

class _ProductCardSkeletonState extends State<ProductCardSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return Container(
          decoration: BoxDecoration(
            color: LexiColors.white,
            borderRadius: BorderRadius.circular(LexiRadius.card),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.02),
                blurRadius: 4,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(LexiRadius.card),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 5,
                  child: _ShimmerBlock(progress: _controller.value),
                ),
                Expanded(
                  flex: 4,
                  child: Padding(
                    padding: const EdgeInsets.all(LexiSpacing.s12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _ShimmerBlock(
                          progress: _controller.value,
                          height: 14,
                          width: double.infinity,
                        ),
                        const SizedBox(height: LexiSpacing.s8),
                        _ShimmerBlock(
                          progress: _controller.value,
                          height: 12,
                          width: 120,
                        ),
                        const SizedBox(height: LexiSpacing.s8),
                        _ShimmerBlock(
                          progress: _controller.value,
                          height: 12,
                          width: 90,
                        ),
                        const Spacer(),
                        Row(
                          children: [
                            Expanded(
                              child: _ShimmerBlock(
                                progress: _controller.value,
                                height: 16,
                                width: double.infinity,
                              ),
                            ),
                            const SizedBox(width: LexiSpacing.s8),
                            _ShimmerBlock(
                              progress: _controller.value,
                              height: 36,
                              width: 36,
                              borderRadius: LexiRadius.full,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ShimmerBlock extends StatelessWidget {
  final double progress;
  final double? height;
  final double? width;
  final double borderRadius;

  const _ShimmerBlock({
    required this.progress,
    this.height,
    this.width,
    this.borderRadius = LexiRadius.md,
  });

  @override
  Widget build(BuildContext context) {
    final begin = -1.2 + (progress * 2.4);
    final end = begin + 0.8;

    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        gradient: LinearGradient(
          begin: AlignmentDirectional(begin, 0),
          end: AlignmentDirectional(end, 0),
          colors: [
            LexiColors.neutral200,
            LexiColors.neutral100,
            LexiColors.neutral200,
          ],
          stops: const [0.2, 0.5, 0.8],
        ),
      ),
    );
  }
}
