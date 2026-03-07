import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../../core/utils/currency_formatter.dart';
import '../../../design_system/lexi_tokens.dart';
import '../../../design_system/lexi_typography.dart';
import '../../../shared/widgets/lexi_network_image.dart';

class SearchProductTile extends StatelessWidget {
  final int id;
  final String name;
  final String imageUrl;
  final double price;
  final double regularPrice;
  final double salePrice;
  final double rating;
  final int reviewsCount;
  final bool inStock;
  final VoidCallback onTap;

  const SearchProductTile({
    super.key,
    required this.id,
    required this.name,
    required this.imageUrl,
    required this.price,
    required this.regularPrice,
    required this.salePrice,
    required this.rating,
    required this.reviewsCount,
    required this.inStock,
    required this.onTap,
  });

  bool get _hasDiscount =>
      salePrice > 0 && regularPrice > 0 && salePrice < regularPrice;

  @override
  Widget build(BuildContext context) {
    final effectivePrice = _hasDiscount ? salePrice : price;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(LexiRadius.md),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: LexiSpacing.sm,
          vertical: LexiSpacing.sm,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(
                width: 44,
                height: 44,
                child: LexiNetworkImage(
                  imageUrl: imageUrl,
                  fit: BoxFit.cover,
                  errorWidget: Container(
                    color: LexiColors.neutral100,
                    alignment: Alignment.center,
                    child: const Icon(
                      Icons.image_not_supported_outlined,
                      size: 16,
                      color: LexiColors.neutral400,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: LexiSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: LexiTypography.bodyMd.copyWith(
                      fontWeight: FontWeight.w700,
                      color: LexiColors.brandBlack,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Text(
                        CurrencyFormatter.formatAmountOrUnavailable(
                          effectivePrice,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: LexiTypography.bodySm.copyWith(
                          fontWeight: FontWeight.w800,
                          color: LexiColors.brandBlack,
                        ),
                      ),
                      if (_hasDiscount) ...[
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            CurrencyFormatter.formatAmount(regularPrice),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: LexiTypography.bodySm.copyWith(
                              color: LexiColors.neutral500,
                              decoration: TextDecoration.lineThrough,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      const FaIcon(
                        FontAwesomeIcons.solidStar,
                        size: 11,
                        color: Color(0xFFFFB400),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${rating.toStringAsFixed(1)} ($reviewsCount)',
                        style: LexiTypography.bodySm.copyWith(
                          color: LexiColors.neutral600,
                        ),
                      ),
                      if (!inStock) ...[
                        const SizedBox(width: 8),
                        Text(
                          'غير متوفر',
                          style: LexiTypography.bodySm.copyWith(
                            color: LexiColors.error,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.chevron_left, color: LexiColors.neutral400),
          ],
        ),
      ),
    );
  }
}
