import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../../core/cache/lexi_cache_manager.dart';
import '../../core/images/image_url_optimizer.dart';
import '../../core/utils/url_utils.dart';
import '../../design_system/lexi_tokens.dart';
import 'lexi_ui/lexi_skeleton.dart';

enum ProductCardImageLayout { grid, list, tablet }

/// Responsive media block used by product cards.
///
/// Keeps image area height consistent with a stable aspect ratio while still
/// supporting image carousels and hero animation.
class ProductCardImage extends StatelessWidget {
  final List<String> images;
  final int currentPage;
  final PageController pageController;
  final ValueChanged<int> onPageChanged;
  final String heroTag;
  final ProductCardImageLayout layout;
  final int? memCacheWidth;
  final BorderRadius borderRadius;
  final BoxFit fit;

  const ProductCardImage({
    super.key,
    required this.images,
    required this.currentPage,
    required this.pageController,
    required this.onPageChanged,
    required this.heroTag,
    required this.layout,
    this.memCacheWidth,
    this.borderRadius = BorderRadius.zero,
    this.fit = BoxFit.contain,
  });

  static double aspectRatioForLayout(ProductCardImageLayout layout) {
    switch (layout) {
      case ProductCardImageLayout.list:
        return 1.28;
      case ProductCardImageLayout.tablet:
        return 1.08;
      case ProductCardImageLayout.grid:
        return 1.0;
    }
  }

  @override
  Widget build(BuildContext context) {
    final safePage = images.isEmpty
        ? 0
        : currentPage.clamp(0, images.length - 1).toInt();
    final aspectRatio = aspectRatioForLayout(layout);

    return ClipRRect(
      borderRadius: borderRadius,
      clipBehavior: Clip.antiAlias,
      child: AspectRatio(
        aspectRatio: aspectRatio,
        child: ColoredBox(
          color: LexiColors.neutral100,
          child: images.isEmpty
              ? const _CardImageFallback()
              : images.length == 1
              ? Hero(
                  tag: heroTag,
                  child: _CardNetworkImage(
                    imageUrl: images.first,
                    fallbackImageUrls: images.skip(1).toList(growable: false),
                    fit: fit,
                    memCacheWidth: memCacheWidth,
                    aspectRatio: aspectRatio,
                  ),
                )
              : PageView.builder(
                  controller: pageController,
                  physics: const ClampingScrollPhysics(),
                  dragStartBehavior: DragStartBehavior.down,
                  itemCount: images.length,
                  onPageChanged: onPageChanged,
                  itemBuilder: (context, index) {
                    final image = _CardNetworkImage(
                      imageUrl: images[index],
                      fallbackImageUrls: [
                        ...images.skip(index + 1),
                        ...images.take(index),
                      ],
                      fit: fit,
                      memCacheWidth: memCacheWidth,
                      aspectRatio: aspectRatio,
                    );
                    if (index == safePage) {
                      return Hero(tag: heroTag, child: image);
                    }
                    return image;
                  },
                ),
        ),
      ),
    );
  }
}

class _CardNetworkImage extends StatelessWidget {
  final String imageUrl;
  final List<String> fallbackImageUrls;
  final BoxFit fit;
  final int? memCacheWidth;
  final double aspectRatio;

  const _CardNetworkImage({
    required this.imageUrl,
    this.fallbackImageUrls = const <String>[],
    required this.fit,
    required this.memCacheWidth,
    required this.aspectRatio,
  });

  @override
  Widget build(BuildContext context) {
    final candidates = _uniqueCandidates([imageUrl, ...fallbackImageUrls]);
    return _buildCandidate(context, candidates, 0);
  }

  Widget _buildCandidate(
    BuildContext context,
    List<String> candidates,
    int index,
  ) {
    if (index >= candidates.length) {
      return const _CardImageFallback();
    }

    final normalized = normalizeNullableHttpUrl(candidates[index]);
    if ((normalized ?? '').isEmpty) {
      return _buildCandidate(context, candidates, index + 1);
    }

    final optimized = ImageUrlOptimizer.optimize(normalized!, preferWebp: true);
    if (kIsWeb) {
      return _buildWebImage(
        url: optimized,
        rawUrl: normalized,
        candidates: candidates,
        index: index,
        canTryRaw: optimized != normalized,
      );
    }

    return CachedNetworkImage(
      imageUrl: optimized,
      cacheManager: LexiCacheManager.instance,
      fit: fit,
      fadeInDuration: const Duration(milliseconds: 120),
      fadeOutDuration: const Duration(milliseconds: 80),
      imageBuilder: (context, imageProvider) {
        final resized = (memCacheWidth != null)
            ? ResizeImage(imageProvider, width: memCacheWidth)
            : imageProvider;
        return Image(
          image: resized,
          fit: fit,
          filterQuality: FilterQuality.medium,
        );
      },
      placeholder: (context, url) => const _CardImagePlaceholder(),
      errorWidget: (context, url, error) =>
          _buildCandidate(context, candidates, index + 1),
    );
  }

  Widget _buildWebImage({
    required String url,
    required String rawUrl,
    required List<String> candidates,
    required int index,
    required bool canTryRaw,
  }) {
    return Image.network(
      url,
      fit: fit,
      filterQuality: FilterQuality.medium,
      webHtmlElementStrategy: WebHtmlElementStrategy.prefer,
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) {
          return child;
        }
        return const _CardImagePlaceholder();
      },
      errorBuilder: (context, error, stackTrace) {
        if (canTryRaw && rawUrl.trim().isNotEmpty && rawUrl != url) {
          return _buildWebImage(
            url: rawUrl,
            rawUrl: rawUrl,
            candidates: candidates,
            index: index,
            canTryRaw: false,
          );
        }
        return _buildCandidate(context, candidates, index + 1);
      },
    );
  }

  List<String> _uniqueCandidates(Iterable<String> rawUrls) {
    final output = <String>[];
    final seen = <String>{};
    for (final rawUrl in rawUrls) {
      final normalized = normalizeNullableHttpUrl(rawUrl);
      if (normalized == null || !seen.add(normalized)) {
        continue;
      }
      output.add(normalized);
    }
    return output;
  }
}

class _CardImagePlaceholder extends StatelessWidget {
  const _CardImagePlaceholder();

  @override
  Widget build(BuildContext context) {
    return const SizedBox.expand(child: LexiSkeleton(borderRadius: 0));
  }
}

class _CardImageFallback extends StatelessWidget {
  const _CardImageFallback();

  @override
  Widget build(BuildContext context) {
    return SizedBox.expand(
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [LexiColors.neutral50, LexiColors.neutral200],
          ),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.shopping_bag_outlined,
                color: LexiColors.brandPrimary.withValues(alpha: 0.6),
                size: 36,
              ),
              const SizedBox(height: 8),
              Text(
                'Lexi Store',
                style: TextStyle(
                  color: LexiColors.neutral500,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
