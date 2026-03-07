import '../../app/router/app_routes.dart';

class ShareLinkTarget {
  final String type;
  final String id;

  const ShareLinkTarget({required this.type, required this.id});
}

abstract final class ShareLinkTypes {
  static const String product = 'p';
  static const String order = 'o';
  static const String invoice = 'i';
  static const String category = 'c';
  static const String brand = 'b';
  static const String ticket = 't';
}

abstract final class ShareLinks {
  static const String segment = 's';
  static const String productSegment = 'product';
  static const Set<String> _privateTypes = {
    ShareLinkTypes.order,
    ShareLinkTypes.invoice,
    ShareLinkTypes.ticket,
  };

  static Uri buildCanonical({
    required String baseUrl,
    required String type,
    required String id,
  }) {
    final rawBase = baseUrl.trim();
    if (rawBase.isEmpty) {
      throw ArgumentError('baseUrl is required');
    }

    final normalizedBase = rawBase.contains('://')
        ? rawBase
        : 'https://$rawBase';
    final baseUri = Uri.parse(normalizedBase);

    final normalizedType = _normalizeType(type);
    final normalizedId = id.trim();
    if (normalizedType.isEmpty || normalizedId.isEmpty) {
      throw ArgumentError('type and id are required');
    }

    return baseUri.replace(
      pathSegments: <String>[segment, normalizedType, normalizedId],
      queryParameters: null,
      fragment: null,
    );
  }

  static Uri buildProductUri({
    required String baseUrl,
    required String productRef,
  }) {
    final rawBase = baseUrl.trim();
    if (rawBase.isEmpty) {
      throw ArgumentError('baseUrl is required');
    }

    final normalizedBase = rawBase.contains('://')
        ? rawBase
        : 'https://$rawBase';
    final baseUri = Uri.parse(normalizedBase);

    final normalizedRef = productRef.trim();
    if (normalizedRef.isEmpty) {
      throw ArgumentError('productRef is required');
    }

    return baseUri.replace(
      pathSegments: <String>[productSegment, normalizedRef],
      queryParameters: null,
      fragment: null,
    );
  }

  static String entryPath({required String type, required String id}) {
    final normalizedType = _normalizeType(type);
    final normalizedId = id.trim();
    if (normalizedType.isEmpty || normalizedId.isEmpty) {
      return AppRoutePaths.home;
    }

    return Uri(pathSegments: [segment, normalizedType, normalizedId]).path;
  }

  static ShareLinkTarget? parseUri(Uri uri) {
    final segments = uri.pathSegments
        .where((segment) => segment.trim().isNotEmpty)
        .toList(growable: false);
    final shareIndex = segments.lastIndexOf(segment);
    if (shareIndex < 0 || shareIndex + 2 >= segments.length) {
      return null;
    }

    final type = _normalizeType(Uri.decodeComponent(segments[shareIndex + 1]));
    final id = Uri.decodeComponent(segments[shareIndex + 2]).trim();
    if (type.isEmpty || id.isEmpty) {
      return null;
    }

    return ShareLinkTarget(type: type, id: id);
  }

  static String? parseProductSlug(Uri uri) {
    final segments = uri.pathSegments
        .where((segment) => segment.trim().isNotEmpty)
        .toList(growable: false);
    if (segments.isEmpty) {
      return null;
    }

    final normalized = segments
        .map((segment) => segment.trim().toLowerCase())
        .toList(growable: false);
    final productIndex = normalized.lastIndexOf(productSegment);
    if (productIndex < 0 || productIndex + 1 >= segments.length) {
      return null;
    }

    String decoded;
    try {
      decoded = Uri.decodeComponent(segments[productIndex + 1]);
    } catch (_) {
      decoded = segments[productIndex + 1];
    }
    final raw = decoded.trim();
    if (raw.isEmpty) {
      return null;
    }
    return raw;
  }

  static ShareLinkTarget? fromPathParameters({
    required String? type,
    required String? id,
  }) {
    final normalizedType = _normalizeType(type ?? '');
    final normalizedId = Uri.decodeComponent((id ?? '').trim());
    if (normalizedType.isEmpty || normalizedId.isEmpty) {
      return null;
    }

    return ShareLinkTarget(type: normalizedType, id: normalizedId);
  }

  static bool requiresAuthType(String type) {
    return _privateTypes.contains(_normalizeType(type));
  }

  static String? resolveInAppPath(ShareLinkTarget target) {
    switch (_normalizeType(target.type)) {
      case ShareLinkTypes.product:
        final productRef = target.id.trim();
        if (productRef.isEmpty) return null;
        return Uri(
          path: '/$productSegment/${Uri.encodeComponent(productRef)}',
        ).path;
      case ShareLinkTypes.category:
        final categoryId = _positiveInt(target.id);
        if (categoryId == null) return null;
        return AppRoutePaths.categoryProducts(categoryId);
      case ShareLinkTypes.brand:
        final brandId = _positiveInt(target.id);
        if (brandId == null) return null;
        return AppRoutePaths.brandProducts(brandId);
      case ShareLinkTypes.order:
        final orderId = _positiveInt(target.id);
        if (orderId == null) return null;
        return AppRoutePaths.orderDetailsById(orderId.toString());
      case ShareLinkTypes.invoice:
        final invoiceOrderId = _positiveInt(target.id);
        if (invoiceOrderId == null) return null;
        return AppRoutePaths.orderInvoice(invoiceOrderId.toString());
      case ShareLinkTypes.ticket:
        final ticketId = _positiveInt(target.id);
        if (ticketId == null) return null;
        return AppRoutePaths.supportChat(ticketId);
      default:
        return null;
    }
  }

  static int? _positiveInt(String raw) {
    final parsed = int.tryParse(raw.trim());
    if (parsed == null || parsed <= 0) {
      return null;
    }
    return parsed;
  }

  static String _normalizeType(String value) {
    return value.trim().toLowerCase();
  }
}
