import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../core/images/image_prefetcher.dart';
import '../../design_system/lexi_motion.dart';
import '../../design_system/lexi_tokens.dart';
import '../../design_system/lexi_typography.dart';
import '../ui/lexi_alert.dart';
import 'add_to_cart_button.dart';
import 'lexi_countdown_timer.dart';
import 'lexi_ui/lexi_icon_circle_button.dart';
import 'product_card_image.dart';

class ProductCard extends StatefulWidget {
  final int? productId;
  final String name;
  final String? descriptionSnippet;
  final String price;
  final String? oldPrice;
  final String? imageUrl;
  final List<String>? imageUrls;
  final double rating;
  final int reviewsCount;
  final bool isWishlisted;
  final String? brandName;
  final String? badgeText;
  final int discountPercent;
  final String? heroTag;
  final int? imageMemCacheWidth;
  final bool canAddToCart;
  final bool showSaleCountdown;
  final bool showAddToCartSuccessAlert;
  final VoidCallback? onTap;
  final FutureOr<void> Function()? onAddToCart;
  final VoidCallback? onIncrement;
  final VoidCallback? onDecrement;
  final int cartQty;
  final FutureOr<void> Function()? onShare;
  final FutureOr<void> Function()? onComment;
  final FutureOr<void> Function()? onBrandTap;
  final FutureOr<void> Function()? onWishlistToggle;
  final int wishlistCount;

  const ProductCard({
    super.key,
    required this.name,
    this.productId,
    this.descriptionSnippet,
    required this.price,
    this.oldPrice,
    this.imageUrl,
    this.imageUrls,
    this.rating = 0,
    this.reviewsCount = 0,
    this.isWishlisted = false,
    this.brandName,
    this.badgeText,
    this.discountPercent = 0,
    this.heroTag,
    this.imageMemCacheWidth,
    this.canAddToCart = true,
    this.showSaleCountdown = false,
    this.showAddToCartSuccessAlert = false,
    this.onTap,
    this.onAddToCart,
    this.onIncrement,
    this.onDecrement,
    this.cartQty = 0,
    this.onShare,
    this.onComment,
    this.onBrandTap,
    this.onWishlistToggle,
    this.wishlistCount = 0,
    this.saleEndDate,
  });

  final DateTime? saleEndDate;

  @override
  State<ProductCard> createState() => _ProductCardState();
}

class _ProductCardState extends State<ProductCard>
    with TickerProviderStateMixin {
  final PageController _pageController = PageController();
  late final AnimationController _heartPulseController;
  int _currentPage = 0;
  bool _pressed = false;
  bool _cartFlightInProgress = false;
  String _prefetchedImageSignature = '';

  @override
  void initState() {
    super.initState();
    _heartPulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 340),
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    _heartPulseController.dispose();
    super.dispose();
  }

  List<String> get _images {
    final merged = <String>[
      ...?widget.imageUrls,
      if ((widget.imageUrl ?? '').trim().isNotEmpty) widget.imageUrl!.trim(),
    ];

    final dedup = <String>[];
    final seen = <String>{};
    for (final item in merged) {
      final key = item.trim();
      if (key.isEmpty || seen.contains(key)) {
        continue;
      }
      seen.add(key);
      dedup.add(key);
      if (dedup.length >= 6) {
        break;
      }
    }

    return dedup;
  }

  String get _heroTag {
    if ((widget.heroTag ?? '').trim().isNotEmpty) {
      return widget.heroTag!.trim();
    }
    final id = widget.productId ?? widget.name.hashCode;
    return 'product-hero-$id';
  }

  @override
  Widget build(BuildContext context) {
    final images = _images;
    final safeCurrentPage = images.isEmpty
        ? 0
        : _currentPage.clamp(0, images.length - 1).toInt();
    _scheduleSecondaryImagePrefetch(images);
    final hasOffer = (widget.oldPrice ?? '').trim().isNotEmpty;
    final hasDiscountPercent = widget.discountPercent > 0;
    final hasBadge = hasDiscountPercent || widget.badgeText != null;
    final normalizedBrandName = (widget.brandName ?? '').trim();
    final hasBrand = normalizedBrandName.isNotEmpty;
    final showSaleCountdown =
        widget.showSaleCountdown &&
        widget.saleEndDate != null &&
        widget.saleEndDate!.isAfter(DateTime.now());

    final pulse =
        TweenSequence<double>([
          TweenSequenceItem(
            tween: Tween<double>(begin: 1, end: 1.2),
            weight: 45,
          ),
          TweenSequenceItem(
            tween: Tween<double>(begin: 1.2, end: 1),
            weight: 55,
          ),
        ]).animate(
          CurvedAnimation(parent: _heartPulseController, curve: Curves.easeOut),
        );

    return LayoutBuilder(
      builder: (context, constraints) {
        final cardHeight = constraints.maxHeight.isFinite
            ? constraints.maxHeight
            : 320.0;
        final imageLayout = _resolveImageLayout(
          cardWidth: constraints.maxWidth,
          viewportWidth: MediaQuery.sizeOf(context).width,
        );

        return SizedBox(
          height: cardHeight,
          child: GestureDetector(
            onTapDown: (_) => setState(() => _pressed = true),
            onTapCancel: () => setState(() => _pressed = false),
            onTapUp: (_) => setState(() => _pressed = false),
            onTap: widget.onTap,
            child: AnimatedScale(
              scale: _pressed ? LexiMotion.tapScale : 1.0,
              duration: LexiMotion.tap,
              curve: LexiMotion.standardCurve,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: LexiColors.white,
                  borderRadius: BorderRadius.circular(LexiRadius.md),
                  border: Border.all(color: LexiColors.neutral200, width: 1.0),
                  boxShadow: LexiShadows.cardLow,
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(LexiRadius.md),
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Stack(
                        clipBehavior: Clip.hardEdge,
                        children: [
                          ProductCardImage(
                            images: images,
                            currentPage: safeCurrentPage,
                            pageController: _pageController,
                            onPageChanged: (value) {
                              if (!mounted || _currentPage == value) {
                                return;
                              }
                              setState(() => _currentPage = value);
                            },
                            heroTag: _heroTag,
                            layout: imageLayout,
                            memCacheWidth: widget.imageMemCacheWidth ?? 480,
                          ),
                          if (widget.wishlistCount >= 5)
                            PositionedDirectional(
                              start: LexiSpacing.s12,
                              bottom: LexiSpacing.s12,
                              child: const _PopularBadge(),
                            ),

                          if (hasBadge)
                            PositionedDirectional(
                              top: LexiSpacing.s8,
                              end: LexiSpacing.s8, // Top-left in RTL
                              child: _DiscountBadge(
                                text: hasDiscountPercent
                                    ? '-${widget.discountPercent}%'
                                    : widget.badgeText,
                              ),
                            ),
                          PositionedDirectional(
                            top: LexiSpacing.s8,
                            start: LexiSpacing.s8, // Top-right in RTL
                            child: ScaleTransition(
                              scale: pulse,
                              child: LexiIconCircleButton(
                                icon: widget.isWishlisted
                                    ? FontAwesomeIcons.solidHeart
                                    : FontAwesomeIcons.heart,
                                iconColor: widget.isWishlisted
                                    ? LexiColors.discountRed
                                    : LexiColors.darkBlack,
                                tooltip: 'المفضلة',
                                onTap: _handleWishlistTap,
                                boxShadow: LexiShadows.card,
                              ),
                            ),
                          ),
                          if (images.length > 1)
                            Positioned(
                              left: 0,
                              right: 0,
                              bottom: LexiSpacing.s8,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: List.generate(images.length, (index) {
                                  final isActive = index == safeCurrentPage;
                                  return AnimatedContainer(
                                    duration: const Duration(milliseconds: 180),
                                    margin: const EdgeInsets.symmetric(
                                      horizontal: 2,
                                    ),
                                    width: isActive ? 14 : 6,
                                    height: 6,
                                    decoration: BoxDecoration(
                                      color: isActive
                                          ? LexiColors.primaryYellow
                                          : LexiColors.gray300,
                                      borderRadius: BorderRadius.circular(50),
                                    ),
                                  );
                                }),
                              ),
                            ),
                        ],
                      ),
                      Expanded(
                        child: Padding(
                          padding: EdgeInsetsDirectional.fromSTEB(
                            LexiSpacing.s12,
                            showSaleCountdown ? LexiSpacing.s8 : LexiSpacing.s8,
                            LexiSpacing.s12,
                            LexiSpacing.s12,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (showSaleCountdown)
                                    Container(
                                      margin: const EdgeInsets.only(
                                        bottom: LexiSpacing.s8,
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: LexiSpacing.s8,
                                        vertical: 6,
                                      ),
                                      decoration: BoxDecoration(
                                        color: LexiColors.neutral100,
                                        borderRadius: BorderRadius.circular(
                                          LexiRadius.button,
                                        ),
                                        border: Border.all(
                                          color: LexiColors.neutral200,
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const FaIcon(
                                            FontAwesomeIcons.clock,
                                            size: 12,
                                            color: LexiColors.discountRed,
                                          ),
                                          const SizedBox(width: 6),
                                          Flexible(
                                            child: LexiCountdownTimer(
                                              endTime: widget.saleEndDate!,
                                              boxColor: LexiColors.discountRed,
                                              textStyle: LexiTypography.caption
                                                  .copyWith(
                                                    fontSize: 9,
                                                    color: LexiColors.white,
                                                    fontWeight: FontWeight.w800,
                                                  ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  if (hasBrand)
                                    Padding(
                                      padding: const EdgeInsets.only(bottom: 6),
                                      child: _BrandBadge(
                                        label: normalizedBrandName,
                                        onTap: widget.onBrandTap != null
                                            ? _handleBrandTap
                                            : null,
                                      ),
                                    ),
                                  Text(
                                    widget.name,
                                    style: LexiTypography.title.copyWith(
                                      fontSize: 14,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  if ((widget.descriptionSnippet ?? '')
                                      .trim()
                                      .isNotEmpty) ...[
                                    const SizedBox(height: LexiSpacing.s4),
                                    Text(
                                      widget.descriptionSnippet!.trim(),
                                      style: LexiTypography.caption,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                  const SizedBox(height: 1),
                                  Row(
                                    children: [
                                      const FaIcon(
                                        FontAwesomeIcons.solidStar,
                                        size: 12,
                                        color: LexiColors.warning,
                                      ),
                                      const SizedBox(width: LexiSpacing.s4),
                                      Text(
                                        widget.rating.toStringAsFixed(1),
                                        style: LexiTypography.caption.copyWith(
                                          color: LexiColors.darkBlack,
                                        ),
                                      ),
                                      const SizedBox(width: LexiSpacing.s4),
                                      Flexible(
                                        child: Text(
                                          '(${widget.reviewsCount})',
                                          style: LexiTypography.caption,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Expanded(
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          widget.price,
                                          style: LexiTypography.priceStyle
                                              .copyWith(
                                                fontSize: 16,
                                              ), // Slightly smaller
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        if (hasOffer)
                                          Text(
                                            widget.oldPrice!,
                                            style: LexiTypography.caption
                                                .copyWith(
                                                  decoration: TextDecoration
                                                      .lineThrough,
                                                  decorationThickness: 1.6,
                                                  color: LexiColors.gray500,
                                                  fontSize:
                                                      11, // Slightly smaller
                                                ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: LexiSpacing.s8),
                                  AddToCartButton(
                                    qty: widget.cartQty,
                                    canAdd: widget.canAddToCart,
                                    onAdd: _handleAddToCartTap,
                                    onIncrement: widget.onIncrement,
                                    onDecrement: widget.onDecrement,
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
              ),
            ),
          ),
        );
      },
    );
  }

  ProductCardImageLayout _resolveImageLayout({
    required double cardWidth,
    required double viewportWidth,
  }) {
    if (cardWidth >= 320) {
      return ProductCardImageLayout.list;
    }
    if (viewportWidth >= 900 && cardWidth >= 220) {
      return ProductCardImageLayout.tablet;
    }
    return ProductCardImageLayout.grid;
  }

  void _scheduleSecondaryImagePrefetch(List<String> images) {
    if (images.length <= 1) {
      return;
    }

    final signature = images.take(4).join('|');
    if (signature.isEmpty || signature == _prefetchedImageSignature) {
      return;
    }
    _prefetchedImageSignature = signature;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      unawaited(
        ImagePrefetcher.prefetchSecondaryImages(
          context,
          images,
          maxSecondary: 3,
          staggerDelay: const Duration(milliseconds: 120),
          memCacheWidth: widget.imageMemCacheWidth ?? 480,
        ),
      );
    });
  }

  Future<void> _handleWishlistTap() async {
    _heartPulseController.forward(from: 0);
    await widget.onWishlistToggle?.call();
  }

  Future<void> _handleBrandTap() async {
    if (widget.onBrandTap == null) {
      return;
    }
    await Future<void>.sync(() => widget.onBrandTap!.call());
  }

  Future<void> _handleAddToCartTap() async {
    if (!widget.canAddToCart) {
      if (!mounted) {
        return;
      }
      await LexiAlert.warning(
        context,
        text: 'هذا المنتج غير متاح للشراء حالياً',
      );
      return;
    }

    if (widget.onAddToCart == null) {
      return;
    }

    try {
      await _runFlyToCartAnimation();
      await widget.onAddToCart!.call();
    } catch (_) {
      if (!mounted) {
        return;
      }
      await LexiAlert.error(
        context,
        text: 'تعذر إضافة المنتج إلى السلة حالياً. حاول مجددًا.',
      );
    }
  }

  Future<void> _runFlyToCartAnimation() async {
    if (!mounted || kIsWeb || _cartFlightInProgress) {
      return;
    }

    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    final cardBox = context.findRenderObject() as RenderBox?;
    if (overlay == null || cardBox == null) {
      return;
    }

    final media = MediaQuery.of(context).size;
    final start = cardBox.localToGlobal(
      Offset(cardBox.size.width * 0.5, cardBox.size.height * 0.42),
    );
    final end = Offset(media.width - 28, media.height - 86);

    _cartFlightInProgress = true;
    OverlayEntry? entry;
    AnimationController? controller;

    try {
      controller = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 620),
      );
      final curve = CurvedAnimation(
        parent: controller,
        curve: Curves.easeInOutCubic,
      );

      entry = OverlayEntry(
        builder: (_) {
          final t = curve.value;
          final x = lerpDouble(start.dx, end.dx, t) ?? end.dx;
          final baseY = lerpDouble(start.dy, end.dy, t) ?? end.dy;
          final arc = math.sin(t * math.pi) * 54;
          final y = baseY - arc;
          final scale = lerpDouble(1, 0.32, t) ?? 0.32;
          final opacity = lerpDouble(1, 0.18, t) ?? 0.18;

          return Positioned(
            left: x - 16,
            top: y - 16,
            child: IgnorePointer(
              child: Opacity(
                opacity: opacity,
                child: Transform.scale(
                  scale: scale,
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: const BoxDecoration(
                      color: LexiColors.primaryYellow,
                      shape: BoxShape.circle,
                    ),
                    child: const Center(
                      child: FaIcon(
                        FontAwesomeIcons.cartShopping,
                        size: 12,
                        color: LexiColors.darkBlack,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      );

      await WidgetsBinding.instance.endOfFrame;
      if (!mounted) {
        return;
      }

      overlay.insert(entry);
      controller.addListener(() {
        if (entry != null && entry.mounted) {
          entry.markNeedsBuild();
        }
      });
      await controller.forward().orCancel;
    } on TickerCanceled {
      // Animation canceled because widget got disposed.
    } finally {
      if (entry != null && entry.mounted) {
        entry.remove();
      }
      controller?.dispose();
      _cartFlightInProgress = false;
    }
  }
}

class _BrandBadge extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;

  const _BrandBadge({required this.label, this.onTap});

  static const List<_BrandChipPalette> _palettes = <_BrandChipPalette>[
    _BrandChipPalette(
      accent: LexiColors.brandAccent,
      background: Color(0xFFF3E8FF),
      border: Color(0xFFC4B5FD),
    ),
    _BrandChipPalette(
      accent: Color(0xFF0369A1),
      background: Color(0xFFE0F2FE),
      border: Color(0xFF7DD3FC),
    ),
    _BrandChipPalette(
      accent: Color(0xFF0F766E),
      background: Color(0xFFCCFBF1),
      border: Color(0xFF5EEAD4),
    ),
    _BrandChipPalette(
      accent: Color(0xFF9A3412),
      background: Color(0xFFFFEDD5),
      border: Color(0xFFFDBA74),
    ),
    _BrandChipPalette(
      accent: Color(0xFFBE123C),
      background: Color(0xFFFFE4E6),
      border: Color(0xFFFDA4AF),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final palette = _paletteFor(label);
    final chip = Container(
      constraints: const BoxConstraints(maxWidth: 165),
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: palette.background,
        border: Border.all(color: palette.border, width: 1.1),
        borderRadius: BorderRadius.circular(LexiRadius.button),
        boxShadow: [
          BoxShadow(
            color: palette.accent.withValues(alpha: 0.16),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          FaIcon(FontAwesomeIcons.chevronLeft, size: 8, color: palette.accent),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: LexiTypography.caption.copyWith(
                color: palette.accent,
                fontSize: 10.5,
                fontWeight: FontWeight.w900,
                height: 1.05,
              ),
            ),
          ),
          const SizedBox(width: 5),
          FaIcon(FontAwesomeIcons.bagShopping, size: 8, color: palette.accent),
        ],
      ),
    );

    if (onTap == null) {
      return chip;
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(LexiRadius.button),
        child: chip,
      ),
    );
  }

  _BrandChipPalette _paletteFor(String value) {
    var hash = 0;
    for (final rune in value.runes) {
      hash = (hash * 31 + rune) & 0x7fffffff;
    }
    return _palettes[hash % _palettes.length];
  }
}

class _BrandChipPalette {
  final Color accent;
  final Color background;
  final Color border;

  const _BrandChipPalette({
    required this.accent,
    required this.background,
    required this.border,
  });
}

class _DiscountBadge extends StatelessWidget {
  final String? text;

  const _DiscountBadge({this.text});

  @override
  Widget build(BuildContext context) {
    if ((text ?? '').trim().isEmpty) {
      return const SizedBox.shrink();
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(LexiRadius.button),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: LexiSpacing.s8,
            vertical: 4,
          ),
          decoration: BoxDecoration(
            color: LexiColors.discountRed.withValues(alpha: 0.85),
            borderRadius: BorderRadius.circular(LexiRadius.button),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.2),
              width: 0.5,
            ),
          ),
          child: Text(
            text!,
            style: LexiTypography.caption.copyWith(
              color: LexiColors.white,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.5,
            ),
          ),
        ),
      ),
    );
  }
}

class _PopularBadge extends StatelessWidget {
  const _PopularBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: LexiColors.warning,
        borderRadius: BorderRadius.circular(LexiRadius.button),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const FaIcon(
            FontAwesomeIcons.fire,
            size: 10,
            color: LexiColors.white,
          ),
          const SizedBox(width: 4),
          Text(
            'رائج',
            style: LexiTypography.caption.copyWith(
              color: LexiColors.white,
              fontWeight: FontWeight.w900,
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }
}
