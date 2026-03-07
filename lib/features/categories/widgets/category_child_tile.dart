import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../../design_system/lexi_tokens.dart';
import '../../../design_system/lexi_typography.dart';
import '../domain/entities/category_entity.dart';

class CategoryChildTile extends StatelessWidget {
  final CategoryEntity category;
  final VoidCallback onTap;

  const CategoryChildTile({
    super.key,
    required this.category,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(LexiRadius.md),
        child: Ink(
          padding: const EdgeInsetsDirectional.fromSTEB(12, 10, 12, 10),
          decoration: BoxDecoration(
            color: LexiColors.neutral50,
            borderRadius: BorderRadius.circular(LexiRadius.md),
            border: Border.all(color: LexiColors.neutral200),
          ),
          child: Row(
            children: [
              const Icon(
                FontAwesomeIcons.tag,
                size: 14,
                color: LexiColors.neutral500,
              ),
              const SizedBox(width: LexiSpacing.sm),
              Expanded(
                child: Text(
                  category.name,
                  style: LexiTypography.bodyMd.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: LexiSpacing.sm),
              Text(
                '${category.count}',
                style: LexiTypography.bodySm.copyWith(
                  color: LexiColors.neutral600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
