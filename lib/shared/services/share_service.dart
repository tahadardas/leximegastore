import 'dart:typed_data';

import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../config/env/app_environment.dart';
import '../../core/utils/currency_formatter.dart';
import '../../core/deeplink/share_links.dart';
import '../../features/orders/domain/entities/order.dart';
import '../../features/product/domain/entities/product_entity.dart';
import '../../features/support/domain/entities/support_ticket.dart';

class ShareEntity {
  final String type;
  final String id;
  final String? title;
  final String? summary;
  final String? priceText;

  const ShareEntity({
    required this.type,
    required this.id,
    this.title,
    this.summary,
    this.priceText,
  });
}

class ShareService {
  ShareService._();

  static final ShareService instance = ShareService._();

  Uri buildCanonicalUri({required String type, required String id}) {
    return ShareLinks.buildCanonical(
      baseUrl: AppEnvironment.baseUrl,
      type: type,
      id: id,
    );
  }

  Uri buildProductUri({required String productRef}) {
    return ShareLinks.buildProductUri(
      baseUrl: AppEnvironment.baseUrl,
      productRef: productRef,
    );
  }

  String buildCanonicalUrl({required String type, required String id}) {
    return buildCanonicalUri(type: type, id: id).toString();
  }

  String buildProductUrl({required String productRef}) {
    return buildProductUri(productRef: productRef).toString();
  }

  Future<void> shareEntity(ShareEntity entity, {String? subject}) async {
    final normalizedType = entity.type.trim().toLowerCase();
    final normalizedId = entity.id.trim();
    final url = normalizedType == ShareLinkTypes.product
        ? buildProductUrl(productRef: normalizedId)
        : buildCanonicalUrl(type: normalizedType, id: normalizedId);

    final text = _buildEntityText(
      type: normalizedType,
      title: entity.title?.trim() ?? '',
      summary: entity.summary?.trim() ?? '',
      priceText: entity.priceText?.trim() ?? '',
      url: url,
    );

    await Share.share(text, subject: subject);
  }

  Future<void> shareProduct(
    ProductEntity product, {
    String? priceText,
    String? subject,
  }) async {
    await shareEntity(
      ShareEntity(
        type: ShareLinkTypes.product,
        id: product.id.toString(),
        title: product.name.trim(),
        priceText: (priceText ?? '').trim(),
      ),
      subject: subject ?? product.name.trim(),
    );
  }

  Future<void> shareProductById({
    required int productId,
    required String name,
    String? priceText,
    String? subject,
  }) async {
    await shareEntity(
      ShareEntity(
        type: ShareLinkTypes.product,
        id: productId.toString(),
        title: name.trim(),
        priceText: (priceText ?? '').trim(),
      ),
      subject: subject ?? name.trim(),
    );
  }

  Future<void> shareOrder(Order order, {String? subject}) async {
    await shareOrderById(orderId: order.id, subject: subject);
  }

  Future<void> shareOrderDetails({
    required Order order,
    String? subject,
    int maxItems = 8,
  }) async {
    final orderNumber = _resolveOrderDisplayNumber(order);
    final dateLabel = DateFormat(
      'yyyy-MM-dd HH:mm',
      'ar',
    ).format(order.date.toLocal());

    final limitedItems = order.items.take(maxItems).toList(growable: false);
    final extraItemsCount = order.items.length - limitedItems.length;

    final lines = <String>[
      'تفاصيل الطلب #$orderNumber',
      'الحالة: ${_orderStatusLabel(order.status)}',
      'التاريخ: $dateLabel',
      'عدد المنتجات: ${order.resolvedItemCount}',
      'المجموع الفرعي: ${CurrencyFormatter.formatAmount(order.subtotal)}',
      'تكلفة الشحن: ${CurrencyFormatter.formatAmount(order.shippingCost)}',
      'الإجمالي الكلي: ${CurrencyFormatter.formatAmount(order.total)}',
      '',
      'المنتجات:',
      if (limitedItems.isEmpty) '- لا توجد منتجات في هذا الطلب',
      ...limitedItems.map((item) {
        final name = item.name.trim().isEmpty ? 'منتج' : item.name.trim();
        return '- $name × ${item.qty} = ${CurrencyFormatter.formatAmount(item.lineTotal)}';
      }),
      if (extraItemsCount > 0) '- ... و$extraItemsCount منتج آخر',
    ];

    await Share.share(
      lines.join('\n'),
      subject: subject ?? 'تفاصيل الطلب #$orderNumber',
    );
  }

  Future<void> shareOrderToWhatsApp(Order order) async {
    final orderNumber = _resolveOrderDisplayNumber(order);
    final dateLabel = DateFormat(
      'yyyy-MM-dd HH:mm',
      'ar',
    ).format(order.date.toLocal());

    final lines = <String>[
      'تفاصيل الطلب #$orderNumber',
      'الحالة: ${_orderStatusLabel(order.status)}',
      'التاريخ: $dateLabel',
      'عدد المنتجات: ${order.resolvedItemCount}',
      'المجموع الفرعي: ${CurrencyFormatter.formatAmount(order.subtotal)}',
      'تكلفة الشحن: ${CurrencyFormatter.formatAmount(order.shippingCost)}',
      'الإجمالي الكلي: ${CurrencyFormatter.formatAmount(order.total)}',
      '',
      'المنتجات:',
      ...order.items.map((item) {
        final name = item.name.trim().isEmpty ? 'منتج' : item.name.trim();
        return '- $name × ${item.qty} = ${CurrencyFormatter.formatAmount(item.lineTotal)}';
      }),
    ];

    final text = lines.join('\n');
    final encodedText = Uri.encodeComponent(text);
    final whatsappUrl = Uri.parse("https://wa.me/?text=$encodedText");

    if (await canLaunchUrl(whatsappUrl)) {
      await launchUrl(whatsappUrl, mode: LaunchMode.externalApplication);
    } else {
      await Share.share(text);
    }
  }

  Future<void> shareOrderById({
    required String orderId,
    String? subject,
  }) async {
    final normalizedId = orderId.trim();
    final url = buildCanonicalUrl(type: ShareLinkTypes.order, id: normalizedId);
    await Share.share(
      'تتبع طلبك: $url',
      subject: subject ?? 'تتبع الطلب #$normalizedId',
    );
  }

  Future<void> shareInvoice({
    required String orderId,
    String? filePath,
    Uint8List? bytes,
    String? fileName,
    String? subject,
    String? text,
  }) async {
    final normalizedOrderId = orderId.trim();
    final normalizedPath = (filePath ?? '').trim();
    final hasPath = normalizedPath.isNotEmpty;
    final hasBytes = bytes != null && bytes.isNotEmpty;

    if (!hasPath && !hasBytes) {
      throw ArgumentError(
        'shareInvoice requires either a filePath or non-empty bytes.',
      );
    }

    final resolvedFileName = (fileName ?? '').trim().isNotEmpty
        ? fileName!.trim()
        : 'invoice_$normalizedOrderId.pdf';

    final files = <XFile>[];
    if (hasPath) {
      files.add(XFile(normalizedPath, mimeType: 'application/pdf'));
    } else if (bytes != null) {
      files.add(
        XFile.fromData(
          bytes,
          mimeType: 'application/pdf',
          name: resolvedFileName,
        ),
      );
    }

    final url = buildCanonicalUrl(
      type: ShareLinkTypes.invoice,
      id: normalizedOrderId,
    );
    final shareText = (text ?? '').trim().isNotEmpty
        ? '${text!.trim()}\n$url'
        : 'الفاتورة: $url';

    await Share.shareXFiles(
      files,
      text: shareText,
      subject: subject ?? 'فاتورة الطلب #$normalizedOrderId',
    );
  }

  Future<void> shareTicket(SupportTicket ticket, {String? subject}) async {
    await shareTicketById(ticketId: ticket.id, subject: subject);
  }

  Future<void> shareTicketById({required int ticketId, String? subject}) async {
    final url = buildCanonicalUrl(
      type: ShareLinkTypes.ticket,
      id: ticketId.toString(),
    );
    await Share.share(
      'تذكرة الدعم: $url',
      subject: subject ?? 'تذكرة دعم #$ticketId',
    );
  }

  Future<void> shareTextOnly({
    required String title,
    required String message,
    String? url,
    String? subject,
  }) async {
    final lines = <String>[
      title.trim(),
      message.trim(),
      if ((url ?? '').trim().isNotEmpty) url!.trim(),
    ].where((line) => line.isNotEmpty).toList(growable: false);

    await Share.share(lines.join('\n'), subject: subject);
  }

  String _buildEntityText({
    required String type,
    required String title,
    required String summary,
    required String priceText,
    required String url,
  }) {
    switch (type) {
      case ShareLinkTypes.product:
        return <String>[
          title,
          if (priceText.isNotEmpty) priceText,
          url,
        ].where((line) => line.trim().isNotEmpty).join('\n');
      case ShareLinkTypes.order:
        return 'تتبع طلبك: $url';
      case ShareLinkTypes.invoice:
        return 'الفاتورة: $url';
      case ShareLinkTypes.ticket:
        return 'تذكرة الدعم: $url';
      default:
        return <String>[
          if (title.isNotEmpty) title,
          if (summary.isNotEmpty) summary,
          url,
        ].where((line) => line.trim().isNotEmpty).join('\n');
    }
  }

  String _resolveOrderDisplayNumber(Order order) {
    final orderNumber = order.orderNumber.trim();
    if (orderNumber.isNotEmpty) {
      return orderNumber;
    }

    final id = order.id.trim();
    if (id.isNotEmpty) {
      return id;
    }

    return 'غير معروف';
  }

  String _orderStatusLabel(String rawStatus) {
    switch (rawStatus.trim().toLowerCase()) {
      case 'pending-verification':
      case 'on-hold':
        return 'بانتظار التحقق من الدفع';
      case 'pending':
        return 'قيد الانتظار';
      case 'processing':
        return 'قيد المعالجة';
      case 'shipped':
        return 'تم الشحن';
      case 'out-for-delivery':
        return 'خرج للتسليم';
      case 'delivered':
        return 'تم التوصيل';
      case 'completed':
        return 'مكتمل';
      case 'cancelled':
        return 'ملغي';
      case 'failed':
        return 'فشل';
      case 'refunded':
        return 'مسترجع';
      default:
        final fallback = rawStatus.trim();
        return fallback.isEmpty ? 'غير معروف' : fallback;
    }
  }
}
