import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../core/cache/lexi_cache_manager.dart';
import '../../core/images/image_url_optimizer.dart';
import '../../core/utils/url_utils.dart';
import '../../design_system/lexi_tokens.dart';
import '../../shared/widgets/lexi_ui/lexi_skeleton.dart';

class LexiImage extends StatefulWidget {
  final String? imageUrl;
  final BoxFit fit;
  final double? width;
  final double? height;
  final Alignment alignment;
  final BorderRadius? borderRadius;
  final double? aspectRatio;
  final int? memCacheWidth;
  final int? memCacheHeight;
  final Widget? placeholder;
  final Widget? errorWidget;

  const LexiImage({
    super.key,
    required this.imageUrl,
    this.fit = BoxFit.cover,
    this.width,
    this.height,
    this.alignment = Alignment.center,
    this.borderRadius,
    this.aspectRatio,
    this.memCacheWidth,
    this.memCacheHeight,
    this.placeholder,
    this.errorWidget,
  });

  @override
  State<LexiImage> createState() => _LexiImageState();
}

class _LexiImageState extends State<LexiImage> {
  String? _originalUrl;
  String? _fallbackUrl;
  int _retryTick = 0;

  @override
  void initState() {
    super.initState();
    _syncUrls();
  }

  @override
  void didUpdateWidget(covariant LexiImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imageUrl != widget.imageUrl) {
      _syncUrls();
    }
  }

  void _syncUrls() {
    final normalized = normalizeNullableHttpUrl(widget.imageUrl);
    _originalUrl = normalized;
    _retryTick = 0;
    if (normalized == null) {
      _fallbackUrl = null;
      return;
    }
    _fallbackUrl = kIsWeb
        ? normalized
        : ImageUrlOptimizer.optimize(normalized, preferWebp: false);
  }

  @override
  Widget build(BuildContext context) {
    final primary = _originalUrl == null
        ? null
        : ImageUrlOptimizer.optimize(_originalUrl!, preferWebp: true);

    if (primary == null || primary.trim().isEmpty) {
      return _wrap(_buildDefaultError());
    }

    final image = _buildCached(
      url: primary,
      fallbackUrl: _fallbackUrl,
      canFallback: true,
    );

    return _wrap(image);
  }

  Widget _buildCached({
    required String url,
    required String? fallbackUrl,
    required bool canFallback,
  }) {
    if (kIsWeb) {
      return _buildWebImage(
        url: url,
        fallbackUrl: fallbackUrl,
        canFallback: canFallback,
      );
    }

    return CachedNetworkImage(
      imageUrl: _withRetryParam(url),
      cacheManager: LexiCacheManager.instance,
      fit: widget.fit,
      width: widget.width,
      height: widget.height,
      alignment: widget.alignment,
      imageBuilder: (context, imageProvider) {
        final provider =
            (widget.memCacheWidth != null || widget.memCacheHeight != null)
            ? ResizeImage(
                imageProvider,
                width: widget.memCacheWidth,
                height: widget.memCacheHeight,
              )
            : imageProvider;

        return Image(
          image: provider,
          fit: widget.fit,
          width: widget.width,
          height: widget.height,
          alignment: widget.alignment,
          filterQuality: FilterQuality.medium,
        );
      },
      placeholder: (context, url) => widget.placeholder ?? _buildSkeleton(),
      errorWidget: (context, failedUrl, error) {
        if (canFallback &&
            fallbackUrl != null &&
            fallbackUrl.trim().isNotEmpty &&
            fallbackUrl != url) {
          return _buildCached(
            url: fallbackUrl,
            fallbackUrl: null,
            canFallback: false,
          );
        }

        return GestureDetector(
          onTap: _retry,
          behavior: HitTestBehavior.opaque,
          child: widget.errorWidget ?? _buildDefaultError(),
        );
      },
    );
  }

  Widget _buildWebImage({
    required String url,
    required String? fallbackUrl,
    required bool canFallback,
  }) {
    return Image.network(
      _withRetryParam(url),
      fit: widget.fit,
      width: widget.width,
      height: widget.height,
      alignment: widget.alignment,
      filterQuality: FilterQuality.medium,
      // Allow browser-native image rendering as a resilient fallback path
      // when strict CORS/canvas decoding fails on Flutter Web.
      webHtmlElementStrategy: WebHtmlElementStrategy.prefer,
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) {
          return child;
        }
        return widget.placeholder ?? _buildSkeleton();
      },
      errorBuilder: (context, error, stackTrace) {
        if (canFallback &&
            fallbackUrl != null &&
            fallbackUrl.trim().isNotEmpty &&
            fallbackUrl != url) {
          return _buildWebImage(
            url: fallbackUrl,
            fallbackUrl: null,
            canFallback: false,
          );
        }

        return GestureDetector(
          onTap: _retry,
          behavior: HitTestBehavior.opaque,
          child: widget.errorWidget ?? _buildDefaultError(),
        );
      },
    );
  }

  String _withRetryParam(String url) {
    if (_retryTick <= 0) {
      return url;
    }

    final uri = Uri.tryParse(url);
    if (uri == null) {
      return '$url?retry=$_retryTick';
    }

    final params = Map<String, String>.from(uri.queryParameters);
    params['retry'] = _retryTick.toString();
    return uri.replace(queryParameters: params).toString();
  }

  Widget _wrap(Widget child) {
    Widget wrapped = child;

    if (widget.borderRadius != null) {
      wrapped = ClipRRect(borderRadius: widget.borderRadius!, child: wrapped);
    }

    if (widget.aspectRatio != null && widget.aspectRatio! > 0) {
      wrapped = AspectRatio(aspectRatio: widget.aspectRatio!, child: wrapped);
    }

    return wrapped;
  }

  Widget _buildSkeleton() {
    return LexiSkeleton(
      width: widget.width,
      height: widget.height,
      borderRadius: widget.borderRadius?.topLeft.x,
    );
  }

  Widget _buildDefaultError() {
    return Container(
      width: widget.width,
      height: widget.height,
      color: LexiColors.neutral100,
      alignment: Alignment.center,
      padding: const EdgeInsets.all(8),
      child: const Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.broken_image_outlined, color: LexiColors.neutral500),
          SizedBox(height: 4),
          Text(
            'تعذر تحميل الصورة',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Cairo',
              fontSize: 11,
              color: LexiColors.neutral600,
            ),
          ),
        ],
      ),
    );
  }

  void _retry() {
    setState(() {
      _retryTick++;
    });
  }
}
