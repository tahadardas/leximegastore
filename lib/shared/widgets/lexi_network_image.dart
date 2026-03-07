import 'package:flutter/material.dart';

import '../../core/utils/url_utils.dart';
import '../../design_system/lexi_tokens.dart';
import 'lexi_ui/lexi_skeleton.dart';
import '../../ui/widgets/lexi_image.dart';

class LexiNetworkImage extends StatelessWidget {
  final String? imageUrl;
  final BoxFit fit;
  final double? width;
  final double? height;
  final Alignment alignment;
  final Widget? placeholder;
  final Widget? errorWidget;

  const LexiNetworkImage({
    super.key,
    required this.imageUrl,
    this.fit = BoxFit.cover,
    this.width,
    this.height,
    this.alignment = Alignment.center,
    this.placeholder,
    this.errorWidget,
  });

  @override
  Widget build(BuildContext context) {
    final normalized = normalizeNullableHttpUrl(imageUrl);
    final fallback = errorWidget ?? _defaultError();
    final loading = placeholder ?? _defaultLoading();

    if (normalized == null) {
      return fallback;
    }

    return LexiImage(
      imageUrl: normalized,
      fit: fit,
      width: width,
      height: height,
      alignment: alignment,
      placeholder: loading,
      errorWidget: fallback,
    );
  }

  Widget _defaultLoading() {
    return const SizedBox.expand(child: LexiSkeleton());
  }

  Widget _defaultError() {
    return const Center(
      child: Icon(Icons.broken_image_outlined, color: LexiColors.neutral400),
    );
  }
}
