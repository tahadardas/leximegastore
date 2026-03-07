import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../../design_system/lexi_tokens.dart';
import '../../../design_system/lexi_typography.dart';

class SearchSuggestionTile extends StatelessWidget {
  final String text;
  final String highlight;
  final VoidCallback onTap;

  const SearchSuggestionTile({
    super.key,
    required this.text,
    required this.highlight,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(LexiRadius.md),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: LexiSpacing.sm,
          vertical: LexiSpacing.sm,
        ),
        child: Row(
          children: [
            const FaIcon(
              FontAwesomeIcons.magnifyingGlass,
              size: 13,
              color: LexiColors.neutral500,
            ),
            const SizedBox(width: LexiSpacing.sm),
            Expanded(
              child: _HighlightedText(text: text, highlight: highlight),
            ),
            const Icon(
              Icons.north_west,
              size: 16,
              color: LexiColors.neutral500,
            ),
          ],
        ),
      ),
    );
  }
}

class _HighlightedText extends StatelessWidget {
  final String text;
  final String highlight;

  const _HighlightedText({required this.text, required this.highlight});

  @override
  Widget build(BuildContext context) {
    final baseStyle = LexiTypography.bodyMd.copyWith(
      color: LexiColors.brandBlack,
      fontWeight: FontWeight.w600,
    );

    if (highlight.trim().isEmpty) {
      return Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: baseStyle,
      );
    }

    final normalizedText = text.toLowerCase();
    final normalizedHighlight = highlight.toLowerCase();
    final index = normalizedText.indexOf(normalizedHighlight);

    if (index < 0) {
      return Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: baseStyle,
      );
    }

    final prefix = text.substring(0, index);
    final hitLength = highlight.length.clamp(0, text.length - index).toInt();
    final hit = text.substring(index, index + hitLength);
    final suffix = text.substring(index + hit.length);

    return RichText(
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      text: TextSpan(
        style: baseStyle,
        children: [
          TextSpan(text: prefix),
          TextSpan(
            text: hit,
            style: baseStyle.copyWith(
              fontWeight: FontWeight.w800,
              color: LexiColors.brandPrimary,
            ),
          ),
          TextSpan(text: suffix),
        ],
      ),
    );
  }
}
