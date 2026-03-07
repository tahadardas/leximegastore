import 'package:carousel_slider/carousel_slider.dart';
import 'package:flutter/material.dart';

import '../../../../design_system/lexi_tokens.dart';
import '../../../../design_system/lexi_typography.dart';
import '../../../../shared/widgets/lexi_network_image.dart';
import '../../domain/entities/home_ad_banner_entity.dart';

class BannerCarouselWidget extends StatelessWidget {
  final List<HomeAdBannerEntity> banners;
  final int currentIndex;
  final ValueChanged<int> onPageChanged;
  final ValueChanged<HomeAdBannerEntity> onTapBanner;

  const BannerCarouselWidget({
    super.key,
    required this.banners,
    required this.currentIndex,
    required this.onPageChanged,
    required this.onTapBanner,
  });

  @override
  Widget build(BuildContext context) {
    if (banners.isEmpty) {
      return const SizedBox.shrink();
    }

    final safeIndex = currentIndex.clamp(0, banners.length - 1);

    return Column(
      children: [
        AspectRatio(
          aspectRatio: 16 / 7,
          child: CarouselSlider.builder(
            itemCount: banners.length,
            options: CarouselOptions(
              viewportFraction: 1,
              enableInfiniteScroll: banners.length > 1,
              autoPlay: banners.length > 1,
              autoPlayInterval: const Duration(seconds: 5),
              autoPlayAnimationDuration: const Duration(milliseconds: 420),
              autoPlayCurve: Curves.easeOutCubic,
              pauseAutoPlayOnTouch: true,
              pauseAutoPlayOnManualNavigate: true,
              pauseAutoPlayInFiniteScroll: true,
              disableCenter: true,
              padEnds: false,
              onPageChanged: (index, _) => onPageChanged(index),
            ),
            itemBuilder: (context, index, realIndex) {
              final banner = banners[index];
              final title = banner.titleAr.trim().isEmpty
                  ? 'اكتشف أحدث العروض'
                  : banner.titleAr.trim();
              final subtitle = banner.subtitleAr.trim().isEmpty
                  ? 'تسوق الآن واستفد من التخفيضات'
                  : banner.subtitleAr.trim();
              final ctaText = banner.effectiveCtaText;
              final textColor = banner.textColor;
              final badgeColor = banner.badgeColor;

              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 1),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(LexiRadius.card),
                    onTap: () => onTapBanner(banner),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(LexiRadius.card),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  banner.gradientStartColor,
                                  banner.gradientEndColor,
                                ],
                                begin: Alignment.topRight,
                                end: Alignment.bottomLeft,
                              ),
                            ),
                            child: LexiNetworkImage(imageUrl: banner.imageUrl),
                          ),
                          Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Colors.black.withValues(alpha: 0.18),
                                  Colors.black.withValues(alpha: 0.6),
                                ],
                              ),
                            ),
                          ),
                          if (banner.badge.trim().isNotEmpty)
                            PositionedDirectional(
                              top: LexiSpacing.s12,
                              start: LexiSpacing.s12,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: LexiSpacing.s8,
                                  vertical: LexiSpacing.s4,
                                ),
                                decoration: BoxDecoration(
                                  color: badgeColor,
                                  borderRadius: BorderRadius.circular(
                                    LexiRadius.full,
                                  ),
                                ),
                                child: Text(
                                  banner.badge,
                                  style: LexiTypography.caption.copyWith(
                                    color: badgeColor.computeLuminance() > 0.55
                                        ? LexiColors.darkBlack
                                        : LexiColors.white,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            ),
                          PositionedDirectional(
                            start: LexiSpacing.s12,
                            end: LexiSpacing.s12,
                            bottom: LexiSpacing.s12,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: LexiTypography.h3.copyWith(
                                    color: textColor,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  subtitle,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: LexiTypography.bodySm.copyWith(
                                    color: textColor.withValues(alpha: 0.9),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 5,
                                  ),
                                  decoration: BoxDecoration(
                                    color: LexiColors.primaryYellow,
                                    borderRadius: BorderRadius.circular(
                                      LexiRadius.full,
                                    ),
                                  ),
                                  child: Text(
                                    ctaText,
                                    style: LexiTypography.labelSm.copyWith(
                                      color: LexiColors.darkBlack,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        if (banners.length > 1) ...[
          const SizedBox(height: LexiSpacing.s8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(banners.length, (index) {
              final isActive = index == safeIndex;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.symmetric(horizontal: 2),
                height: 6,
                width: isActive ? 18 : 6,
                decoration: BoxDecoration(
                  color: isActive
                      ? LexiColors.primaryYellow
                      : LexiColors.gray300,
                  borderRadius: BorderRadius.circular(LexiRadius.full),
                ),
              );
            }),
          ),
        ],
      ],
    );
  }
}
