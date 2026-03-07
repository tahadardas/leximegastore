import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../../design_system/lexi_tokens.dart';
import '../../../design_system/lexi_typography.dart';
import '../../../shared/widgets/lexi_network_image.dart';
import '../domain/entities/category_entity.dart';

class CategoryParentTile extends StatelessWidget {
  final CategoryEntity category;
  final bool hasChildren;
  final bool isExpanded;
  final VoidCallback onTap;
  final VoidCallback? onArrowTap;

  const CategoryParentTile({
    super.key,
    required this.category,
    required this.hasChildren,
    required this.isExpanded,
    required this.onTap,
    required this.onArrowTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: LexiColors.brandWhite,
        borderRadius: BorderRadius.circular(LexiRadius.lg),
        border: Border.all(color: LexiColors.neutral200),
        boxShadow: LexiShadows.sm,
      ),
      child: Row(
        children: [
          Expanded(
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(LexiRadius.lg),
                onTap: onTap,
                child: Padding(
                  padding: const EdgeInsetsDirectional.fromSTEB(12, 10, 6, 10),
                  child: Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(LexiRadius.sm),
                        child: Container(
                          width: 56,
                          height: 56,
                          color: LexiColors.neutral100,
                          child:
                              category.image != null &&
                                  category.image!.trim().isNotEmpty
                              ? LexiNetworkImage(
                                  imageUrl: category.image,
                                  fit: BoxFit.cover,
                                  errorWidget: const Icon(
                                    FontAwesomeIcons.shapes,
                                    size: 18,
                                    color: LexiColors.neutral400,
                                  ),
                                )
                              : const Icon(
                                  FontAwesomeIcons.shapes,
                                  size: 18,
                                  color: LexiColors.neutral400,
                                ),
                        ),
                      ),
                      const SizedBox(width: LexiSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              category.name,
                              style: LexiTypography.labelLg,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${category.count} منتج',
                              style: LexiTypography.bodySm.copyWith(
                                color: LexiColors.neutral600,
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
          ),
          if (hasChildren)
            IconButton(
              tooltip: isExpanded
                  ? 'إغلاق الأقسام الفرعية'
                  : 'عرض الأقسام الفرعية',
              onPressed: onArrowTap,
              icon: AnimatedRotation(
                turns: isExpanded ? 0.5 : 0,
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                child: const Icon(
                  Icons.keyboard_arrow_down_rounded,
                  size: 24,
                  color: LexiColors.neutral600,
                ),
              ),
            )
          else
            const SizedBox(width: 44),
        ],
      ),
    );
  }
}
