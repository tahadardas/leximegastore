import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../../design_system/lexi_tokens.dart';
import '../../../design_system/lexi_typography.dart';
import '../../../shared/widgets/lexi_network_image.dart';

class SearchCategoryChip extends StatelessWidget {
  final String name;
  final String imageUrl;
  final VoidCallback onTap;

  const SearchCategoryChip({
    super.key,
    required this.name,
    required this.imageUrl,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(LexiRadius.full),
        child: Ink(
          padding: const EdgeInsets.symmetric(
            horizontal: LexiSpacing.sm,
            vertical: 6,
          ),
          decoration: BoxDecoration(
            color: LexiColors.brandWhite,
            borderRadius: BorderRadius.circular(LexiRadius.full),
            border: Border.all(color: LexiColors.neutral200),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(LexiRadius.sm),
                child: SizedBox(
                  width: 28,
                  height: 28,
                  child: LexiNetworkImage(
                    imageUrl: imageUrl,
                    fit: BoxFit.cover,
                    errorWidget: Container(
                      color: LexiColors.neutral100,
                      alignment: Alignment.center,
                      child: const FaIcon(
                        FontAwesomeIcons.shapes,
                        size: 12,
                        color: LexiColors.neutral500,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 140),
                child: Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: LexiTypography.bodySm.copyWith(
                    color: LexiColors.brandBlack,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
