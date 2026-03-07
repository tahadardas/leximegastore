import '../services/share_service.dart';

@Deprecated('Use ShareService instead.')
class LexiShare {
  static Future<void> shareProduct({
    required String name,
    String? slug,
    int? productId,
    String? priceText,
  }) async {
    final resolvedId = productId?.toString().trim();
    if ((resolvedId ?? '').isNotEmpty) {
      await ShareService.instance.shareEntity(
        ShareEntity(
          type: 'p',
          id: resolvedId!,
          title: name.trim(),
          priceText: (priceText ?? '').trim(),
        ),
      );
      return;
    }

    final slugId = (slug ?? '').trim();
    if (slugId.isNotEmpty) {
      await ShareService.instance.shareEntity(
        ShareEntity(
          type: 'p',
          id: slugId,
          title: name.trim(),
          priceText: (priceText ?? '').trim(),
        ),
      );
      return;
    }

    await ShareService.instance.shareTextOnly(
      title: name.trim(),
      message: (priceText ?? '').trim(),
    );
  }

  static Future<void> shareOrder({
    required int orderId,
    required String statusText,
  }) async {
    await ShareService.instance.shareOrderById(orderId: orderId.toString());
  }

  static Future<void> shareText(String text) async {
    final normalized = text.trim();
    if (normalized.isEmpty) {
      return;
    }

    await ShareService.instance.shareTextOnly(
      title: 'Lexi Mega Store',
      message: normalized,
    );
  }

  static Future<void> shareProductWithUrl({
    required String name,
    required String productUrl,
    String? priceText,
  }) async {
    await ShareService.instance.shareTextOnly(
      title: name.trim(),
      message: (priceText ?? '').trim(),
      url: productUrl.trim(),
    );
  }
}
