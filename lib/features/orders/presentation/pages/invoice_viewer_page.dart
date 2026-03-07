import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../config/env/app_environment.dart';
import '../../../../core/utils/pdf_file_saver.dart';
import '../../../../core/utils/text_normalizer.dart';
import '../../../../design_system/lexi_tokens.dart';
import '../../../../shared/services/share_service.dart';
import '../../../../shared/widgets/error_state.dart';
import '../../../../shared/widgets/lexi_network_image.dart';
import '../../../../shared/widgets/lexi_ui/lexi_app_bar.dart';
import '../../../../ui/widgets/lexi_safe_bottom.dart';
import '../../../payment/domain/entities/payment_method.dart';
import '../../data/repositories/order_repository_impl.dart';
import '../../domain/entities/order.dart';
import '../utils/invoice_pdf_exporter.dart';

typedef InvoiceParams = ({String orderId, String type, String? phone});

final invoiceProvider = FutureProvider.family
    .autoDispose<dynamic, InvoiceParams>((ref, params) {
      final repo = ref.watch(orderRepositoryProvider);
      return repo.getInvoice(params.orderId, params.type, phone: params.phone);
    });

final _invoiceOrderProvider = FutureProvider.family.autoDispose<Order, String>((
  ref,
  orderId,
) {
  final parsedId = int.tryParse(orderId.trim());
  if (parsedId == null || parsedId <= 0) {
    throw const FormatException('معرف الطلب غير صالح.');
  }

  final repo = ref.watch(orderRepositoryProvider);
  return repo.myOrderDetails(parsedId);
});

class InvoiceViewerPage extends ConsumerStatefulWidget {
  final String orderId;
  final String type;
  final String? phone;
  final Order? initialOrder;

  const InvoiceViewerPage({
    super.key,
    required this.orderId,
    this.type = 'final',
    this.phone,
    this.initialOrder,
  });

  @override
  ConsumerState<InvoiceViewerPage> createState() => _InvoiceViewerPageState();
}

class _InvoiceViewerPageState extends ConsumerState<InvoiceViewerPage> {
  bool _isDownloading = false;
  bool _isSharing = false;
  Order? _pdfSourceOrder;

  @override
  void initState() {
    super.initState();
    _pdfSourceOrder = widget.initialOrder;
  }

  @override
  Widget build(BuildContext context) {
    final invoiceAsync = ref.watch(
      invoiceProvider((
        orderId: widget.orderId,
        type: widget.type,
        phone: widget.phone,
      )),
    );
    final orderAsync = ref.watch(_invoiceOrderProvider(widget.orderId));

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: LexiAppBar(
        title: 'الفاتورة',
        actions: [
          invoiceAsync.when(
            data: (data) => Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: _isSharing
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.ios_share_outlined),
                  tooltip: 'مشاركة PDF',
                  onPressed: _isDownloading || _isSharing
                      ? null
                      : () => _sharePdf(data),
                ),
                IconButton(
                  icon: _isDownloading
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.download_for_offline_outlined),
                  tooltip: 'تحميل PDF',
                  onPressed: _isDownloading || _isSharing
                      ? null
                      : () => _downloadPdf(data),
                ),
              ],
            ),
            loading: () => const SizedBox.shrink(),
            error: (_, _) => const SizedBox.shrink(),
          ),
        ],
      ),
      body: invoiceAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: LexiColors.brandPrimary),
        ),
        error: (e, st) => ErrorState(
          message: 'تعذر تحميل الفاتورة. حاول مرة أخرى.',
          error: e,
          stackTrace: st,
          technicalDetails: 'source: orders/invoice',
          onRetry: () {
            ref.invalidate(
              invoiceProvider((
                orderId: widget.orderId,
                type: widget.type,
                phone: widget.phone,
              )),
            );
          },
        ),
        data: (data) => _buildInvoiceBody(data, orderAsync),
      ),
    );
  }

  Widget _buildInvoiceBody(dynamic data, AsyncValue<Order> orderAsync) {
    if (data is Uint8List) {
      return SfPdfViewer.memory(data);
    }

    if (data is List<int>) {
      return SfPdfViewer.memory(Uint8List.fromList(data));
    }

    final raw = data is String ? data.trim() : '';
    if (raw.isNotEmpty &&
        raw.toLowerCase().startsWith('http') &&
        _looksLikePdfUrl(raw)) {
      return SfPdfViewer.network(raw);
    }

    if (data is String) {
      return orderAsync.when(
        data: _buildModernInvoice,
        loading: () => const Center(
          child: CircularProgressIndicator(color: LexiColors.brandPrimary),
        ),
        error: (_, _) {
          if (raw.isNotEmpty && raw.toLowerCase().startsWith('http')) {
            return _buildUrlFallback(raw);
          }
          return _buildHtmlFallback(raw);
        },
      );
    }

    if (orderAsync.hasValue) {
      return _buildModernInvoice(orderAsync.requireValue);
    }

    return const Center(child: Text('صيغة الفاتورة غير مدعومة'));
  }

  Widget _buildModernInvoice(Order order) {
    _pdfSourceOrder = order;
    final invoiceTypeLabel = _invoiceTypeLabel(order);
    final statusMeta = _statusMeta(order.status);
    final currency = _currencyCode(order);
    final formattedDate = DateFormat(
      'yyyy-MM-dd HH:mm',
      'ar',
    ).format(order.date.toLocal());
    final verificationUrl = order.invoiceVerificationUrl.trim();
    final customerName = _displayInfo(
      order.billing?.fullName ?? order.shipping?.fullName ?? '',
    );
    final customerPhone = _displayInfo(
      order.billing?.phone ?? order.shipping?.phone ?? '',
    );
    final customerAddress = _displayInfo(
      order.billing?.fullAddress ?? order.shipping?.fullAddress ?? '',
    );
    final courierName = _displayInfo(order.courierName);
    final courierPhone = _displayInfo(order.courierPhone);

    return Directionality(
      textDirection: ui.TextDirection.rtl,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          LexiSpacing.s16,
          LexiSpacing.s16,
          LexiSpacing.s16,
          LexiSpacing.s32,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(LexiRadius.card),
                color: Colors.white,
                border: Border.all(color: Colors.black, width: 1.0),
                boxShadow: LexiShadows.cardLow,
              ),
              clipBehavior: Clip.antiAlias,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Logo
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      LexiSpacing.s16,
                      LexiSpacing.s16,
                      LexiSpacing.s16,
                      LexiSpacing.s12,
                    ),
                    child: Center(
                      child: Image.asset(
                        'assets/images/logo_long.jpg',
                        width: 180,
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),

                  // Gold accent stripe
                  Container(height: 3, color: LexiColors.brandPrimary),

                  // Info row with light gold tint
                  Container(
                    color: const Color(0xFFFFF9E0),
                    padding: const EdgeInsets.symmetric(
                      horizontal: LexiSpacing.s16,
                      vertical: LexiSpacing.s12,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'فاتورة الطلب #${_displayOrderNumber(order)}',
                          style: const TextStyle(
                            color: Colors.black,
                            fontSize: 19,
                            fontWeight: FontWeight.w800,
                            height: 1.35,
                            fontFamily: 'Cairo',
                          ),
                        ),
                        const SizedBox(height: LexiSpacing.s8),
                        Wrap(
                          spacing: LexiSpacing.s8,
                          runSpacing: LexiSpacing.s8,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(999),
                                border: Border.all(
                                  color: LexiColors.brandPrimary,
                                  width: 1.2,
                                ),
                              ),
                              child: Text(
                                invoiceTypeLabel,
                                style: const TextStyle(
                                  color: Colors.black,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                  fontFamily: 'Cairo',
                                ),
                              ),
                            ),
                            _Badge(
                              icon: Icons.schedule_outlined,
                              text: formattedDate,
                              background: Colors.black.withValues(alpha: 0.07),
                            ),
                            _Badge(
                              icon: Icons.verified_outlined,
                              text: statusMeta.label,
                              background: Colors.black.withValues(alpha: 0.07),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: LexiSpacing.s16),
            Row(
              children: [
                Expanded(
                  child: _MetricCard(
                    title: 'الإجمالي',
                    value: _money(order.total, currency: currency),
                    valueColor: LexiColors.brandPrimary,
                  ),
                ),
                const SizedBox(width: LexiSpacing.s12),
                Expanded(
                  child: _MetricCard(
                    title: 'المنتجات',
                    value: '${order.resolvedItemCount}',
                  ),
                ),
                const SizedBox(width: LexiSpacing.s12),
                Expanded(
                  child: _MetricCard(
                    title: 'طريقة الدفع',
                    value: _paymentLabel(order.paymentMethod),
                  ),
                ),
              ],
            ),
            const SizedBox(height: LexiSpacing.s16),
            _InvoiceInfoCard(
              title: 'بيانات المشتري',
              icon: Icons.person_outline_rounded,
              rows: [
                (label: 'الاسم', value: customerName),
                (label: 'الهاتف', value: customerPhone),
                (label: 'العنوان', value: customerAddress),
              ],
            ),
            const SizedBox(height: LexiSpacing.s12),
            _InvoiceInfoCard(
              title: 'بيانات المندوب',
              icon: Icons.local_shipping_outlined,
              rows: [
                (label: 'اسم المندوب', value: courierName),
                (label: 'هاتف المندوب', value: courierPhone),
              ],
            ),
            const SizedBox(height: LexiSpacing.s16),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(LexiRadius.card),
                border: Border.all(color: Colors.black, width: 1.2),
                boxShadow: LexiShadows.cardLow,
              ),
              padding: const EdgeInsets.all(LexiSpacing.s16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'بنود الفاتورة',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      fontFamily: 'Cairo',
                      color: LexiColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: LexiSpacing.s12),
                  if (order.items.isEmpty)
                    const Text(
                      'لا توجد بنود متاحة لهذه الفاتورة.',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        fontFamily: 'Cairo',
                        color: LexiColors.textSecondary,
                      ),
                    )
                  else
                    ...order.items.asMap().entries.map((entry) {
                      final item = entry.value;
                      final itemName = TextNormalizer.normalize(
                        item.name,
                      ).trim();
                      final hasImage = item.image.trim().isNotEmpty;
                      final row = Padding(
                        padding: const EdgeInsets.symmetric(
                          vertical: LexiSpacing.s8,
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: LexiColors.neutral100,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: LexiColors.neutral200,
                                ),
                              ),
                              clipBehavior: Clip.antiAlias,
                              child: hasImage
                                  ? LexiNetworkImage(
                                      imageUrl: item.image,
                                      fit: BoxFit.cover,
                                      errorWidget: const Icon(
                                        Icons.image_not_supported_outlined,
                                        color: LexiColors.neutral500,
                                      ),
                                    )
                                  : const Icon(
                                      Icons.shopping_bag_outlined,
                                      color: LexiColors.neutral500,
                                    ),
                            ),
                            const SizedBox(width: LexiSpacing.s8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    itemName.isEmpty ? 'منتج' : itemName,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 14,
                                      height: 1.4,
                                      fontWeight: FontWeight.w700,
                                      fontFamily: 'Cairo',
                                      color: LexiColors.textPrimary,
                                    ),
                                  ),
                                  if (item.variationLabel?.isNotEmpty ??
                                      false) ...[
                                    const SizedBox(height: 2.0),
                                    Text(
                                      item.variationLabel!,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        fontFamily: 'Cairo',
                                        color: LexiColors.brandPrimary,
                                      ),
                                    ),
                                  ],
                                  const SizedBox(height: LexiSpacing.s4),
                                  Text(
                                    'الكمية: ${item.qty}  •  سعر الوحدة: ${_money(item.price, currency: currency)}',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                      fontFamily: 'Cairo',
                                      color: LexiColors.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: LexiSpacing.s8),
                            Text(
                              _money(item.lineTotal, currency: currency),
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                fontFamily: 'Cairo',
                                color: LexiColors.textPrimary,
                              ),
                            ),
                          ],
                        ),
                      );

                      if (entry.key == order.items.length - 1) {
                        return row;
                      }

                      return Column(
                        children: [
                          row,
                          const Divider(
                            height: 1,
                            color: LexiColors.neutral200,
                          ),
                        ],
                      );
                    }),
                ],
              ),
            ),
            const SizedBox(height: LexiSpacing.s16),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(LexiRadius.card),
                border: Border.all(color: Colors.black, width: 1.2),
                boxShadow: LexiShadows.cardLow,
              ),
              padding: const EdgeInsets.all(LexiSpacing.s16),
              child: Column(
                children: [
                  _TotalRow(
                    label: 'المجموع الفرعي',
                    value: _money(order.subtotal, currency: currency),
                  ),
                  const SizedBox(height: LexiSpacing.s8),
                  _TotalRow(
                    label: 'الشحن',
                    value: _money(order.shippingCost, currency: currency),
                  ),
                  if ((order.discountTotal ?? 0) > 0) ...[
                    const SizedBox(height: LexiSpacing.s8),
                    _TotalRow(
                      label: 'الخصم',
                      value: _money(
                        order.discountTotal ?? 0,
                        currency: currency,
                      ),
                    ),
                  ],
                  if ((order.tax ?? 0) > 0) ...[
                    const SizedBox(height: LexiSpacing.s8),
                    _TotalRow(
                      label: 'الضريبة',
                      value: _money(order.tax ?? 0, currency: currency),
                    ),
                  ],
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: LexiSpacing.s12),
                    child: Divider(height: 1, color: LexiColors.neutral200),
                  ),
                  _TotalRow(
                    label: 'الإجمالي النهائي',
                    value: _money(order.total, currency: currency),
                    emphasized: true,
                  ),
                ],
              ),
            ),
            const SizedBox(height: LexiSpacing.s16),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(LexiRadius.card),
                border: Border.all(color: Colors.black, width: 1.2),
                boxShadow: LexiShadows.cardLow,
              ),
              padding: const EdgeInsets.all(LexiSpacing.s16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'التحقق من صحة الفاتورة',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      fontFamily: 'Cairo',
                      color: LexiColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: LexiSpacing.s8),
                  const Text(
                    'يمكنك مسح رمز QR للتحقق من الفاتورة إلكترونياً.',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      fontFamily: 'Cairo',
                      color: LexiColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: LexiSpacing.s12),
                  if (verificationUrl.isNotEmpty) ...[
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        const Expanded(
                          child: Text(
                            'رمز QR مخصص للتحقق من الفاتورة.\nيمكنك فتح صفحة التحقق مباشرة من الزر أدناه.',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              fontFamily: 'Cairo',
                              color: LexiColors.textSecondary,
                              height: 1.5,
                            ),
                          ),
                        ),
                        const SizedBox(width: LexiSpacing.s12),
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: LexiColors.neutral50,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: LexiColors.neutral200),
                          ),
                          child: QrImageView(
                            data: verificationUrl,
                            size: 108,
                            backgroundColor: Colors.white,
                            eyeStyle: const QrEyeStyle(
                              eyeShape: QrEyeShape.square,
                              color: LexiColors.textPrimary,
                            ),
                            dataModuleStyle: const QrDataModuleStyle(
                              dataModuleShape: QrDataModuleShape.square,
                              color: LexiColors.textPrimary,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: LexiSpacing.s12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () => _openVerificationLink(verificationUrl),
                        icon: const Icon(Icons.open_in_new_rounded),
                        label: const Text(
                          'فتح صفحة التحقق',
                          style: TextStyle(fontFamily: 'Cairo'),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: LexiColors.brandPrimary,
                          foregroundColor: LexiColors.brandBlack,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  ] else
                    const Text(
                      'رابط التحقق غير متوفر لهذه الفاتورة حالياً.',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        fontFamily: 'Cairo',
                        color: LexiColors.textSecondary,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: LexiSpacing.s12),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: LexiSpacing.s16,
                vertical: LexiSpacing.s12,
              ),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.black, width: 1.2),
              ),
              child: const Text(
                'هذه الفاتورة من متجر lexi mega storre وهي ليست بحاجة إلى توقيع لأنها موقعة إلكترونياً',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  height: 1.6,
                  fontFamily: 'Cairo',
                  color: LexiColors.textSecondary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUrlFallback(String url) {
    return Directionality(
      textDirection: ui.TextDirection.rtl,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(LexiSpacing.s16),
          child: Container(
            padding: const EdgeInsets.all(LexiSpacing.s16),
            decoration: BoxDecoration(
              color: LexiColors.white,
              borderRadius: BorderRadius.circular(LexiRadius.card),
              border: Border.all(color: LexiColors.neutral200),
              boxShadow: LexiShadows.cardLow,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.receipt_long_outlined,
                  size: 36,
                  color: LexiColors.textPrimary,
                ),
                const SizedBox(height: LexiSpacing.s12),
                const Text(
                  'تعذر عرض الفاتورة داخل التطبيق.',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    fontFamily: 'Cairo',
                  ),
                ),
                const SizedBox(height: LexiSpacing.s8),
                const Text(
                  'يمكنك فتح الفاتورة في المتصفح.',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    fontFamily: 'Cairo',
                    color: LexiColors.textSecondary,
                  ),
                ),
                const SizedBox(height: LexiSpacing.s12),
                ElevatedButton.icon(
                  onPressed: () => _openVerificationLink(url),
                  icon: const Icon(Icons.open_in_browser_outlined),
                  label: const Text(
                    'فتح في المتصفح',
                    style: TextStyle(fontFamily: 'Cairo'),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: LexiColors.brandPrimary,
                    foregroundColor: LexiColors.brandBlack,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHtmlFallback(String html) {
    final normalizedHtml = TextNormalizer.normalize(html);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(LexiSpacing.s16),
      child: Directionality(
        textDirection: ui.TextDirection.rtl,
        child: Container(
          padding: const EdgeInsets.all(LexiSpacing.s12),
          decoration: BoxDecoration(
            color: LexiColors.white,
            borderRadius: BorderRadius.circular(LexiRadius.card),
            border: Border.all(color: LexiColors.neutral200),
            boxShadow: LexiShadows.cardLow,
          ),
          child: Html(
            data: normalizedHtml,
            onLinkTap: (url, _, _) {
              if (url == null || url.trim().isEmpty) {
                return;
              }
              _openVerificationLink(url);
            },
            style: {
              'html': Style(
                margin: Margins.zero,
                padding: HtmlPaddings.zero,
                direction: ui.TextDirection.rtl,
                fontFamily: 'Cairo',
                color: LexiColors.textPrimary,
              ),
              'body': Style(
                margin: Margins.zero,
                padding: HtmlPaddings.zero,
                fontFamily: 'Cairo',
                lineHeight: LineHeight.number(1.6),
                fontSize: FontSize(14),
                color: LexiColors.textPrimary,
              ),
              'h1': Style(
                fontFamily: 'Cairo',
                fontWeight: FontWeight.w800,
                fontSize: FontSize(22),
                color: LexiColors.textPrimary,
              ),
              'h2': Style(
                fontFamily: 'Cairo',
                fontWeight: FontWeight.w800,
                fontSize: FontSize(19),
                color: LexiColors.textPrimary,
              ),
              'h3': Style(
                fontFamily: 'Cairo',
                fontWeight: FontWeight.w700,
                fontSize: FontSize(17),
                color: LexiColors.textPrimary,
              ),
              'table': Style(
                width: Width(100, Unit.percent),
                border: Border.all(color: LexiColors.neutral200),
              ),
              'th': Style(
                fontFamily: 'Cairo',
                fontWeight: FontWeight.w700,
                backgroundColor: LexiColors.neutral100,
                padding: HtmlPaddings.all(10),
                border: Border.all(color: LexiColors.neutral200),
              ),
              'td': Style(
                fontFamily: 'Cairo',
                padding: HtmlPaddings.all(10),
                border: Border.all(color: LexiColors.neutral200),
              ),
              'a': Style(
                color: LexiColors.info,
                fontFamily: 'Cairo',
                textDecoration: TextDecoration.none,
                direction: ui.TextDirection.ltr,
              ),
            },
          ),
        ),
      ),
    );
  }

  Future<void> _downloadPdf(dynamic data) async {
    setState(() => _isDownloading = true);
    try {
      final pdfBytes = await _resolvePdfBytes(data);
      final fileName = 'invoice_${widget.orderId}.pdf';

      final downloaded = await savePdfFile(pdfBytes, fileName);
      if (!downloaded) {
        try {
          await Printing.layoutPdf(
            name: fileName,
            onLayout: (_) async => pdfBytes,
          );
        } catch (_) {
          await Printing.sharePdf(bytes: pdfBytes, filename: fileName);
        }
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        lexiFloatingSnackBar(
          context,
          content: Text('تعذر تحميل الفاتورة: $e'),
          backgroundColor: LexiColors.error,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isDownloading = false);
      }
    }
  }

  Future<void> _sharePdf(dynamic data) async {
    setState(() => _isSharing = true);
    try {
      final pdfBytes = await _resolvePdfBytes(data);
      await ShareService.instance.shareInvoice(
        orderId: widget.orderId,
        bytes: pdfBytes,
        fileName: 'invoice_${widget.orderId}.pdf',
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        lexiFloatingSnackBar(
          context,
          content: Text('تعذرت مشاركة الفاتورة: $e'),
          backgroundColor: LexiColors.error,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isSharing = false);
      }
    }
  }

  Future<Uint8List> _resolvePdfBytes(dynamic data) async {
    if (data is Uint8List) {
      return data;
    }

    if (data is List<int>) {
      return Uint8List.fromList(data);
    }

    if (data is String && data.trim().toLowerCase().startsWith('http')) {
      try {
        final bytes = await _fetchBytesFromUrl(data.trim());
        if (_isPdfBytes(bytes)) {
          return bytes;
        }
      } catch (_) {
        // Fall through to deterministic PDF generation from order details.
      }
    }

    if (data is String) {
      final converted = await _tryConvertHtmlToPdf(data);
      if (converted != null && _isPdfBytes(converted)) {
        return converted;
      }
    }

    final cachedOrder = _pdfSourceOrder;
    if (cachedOrder != null) {
      try {
        return await InvoicePdfExporter.buildPdfBytes(
          cachedOrder,
          invoiceType: widget.type,
        );
      } catch (_) {
        return _buildEmergencyPdfBytes(cachedOrder);
      }
    }

    final order = await _loadOrderForPdf();
    _pdfSourceOrder = order;
    try {
      return await InvoicePdfExporter.buildPdfBytes(
        order,
        invoiceType: widget.type,
      );
    } catch (_) {
      return _buildEmergencyPdfBytes(order);
    }
  }

  Future<Order> _loadOrderForPdf() {
    final parsedId = int.tryParse(widget.orderId.trim());
    if (parsedId == null || parsedId <= 0) {
      throw const FormatException('معرف الطلب غير صالح.');
    }

    return ref.read(orderRepositoryProvider).myOrderDetails(parsedId);
  }

  bool _isPdfBytes(Uint8List bytes) {
    if (bytes.length < 4) {
      return false;
    }

    return bytes[0] == 0x25 &&
        bytes[1] == 0x50 &&
        bytes[2] == 0x44 &&
        bytes[3] == 0x46;
  }

  Future<Uint8List> _fetchBytesFromUrl(String url) async {
    final uri = Uri.parse(url);
    final bundle = NetworkAssetBundle(uri);
    final data = await bundle.load(uri.toString());
    return data.buffer.asUint8List();
  }

  Future<Uint8List?> _tryConvertHtmlToPdf(String rawHtml) async {
    final html = rawHtml.trim();
    if (html.isEmpty) {
      return null;
    }
    final lower = html.toLowerCase();
    final looksLikeHtml =
        lower.contains('<html') ||
        lower.contains('<!doctype html') ||
        lower.contains('<body');
    if (!looksLikeHtml) {
      return null;
    }

    try {
      final info = await Printing.info();
      if (!info.canConvertHtml) {
        return null;
      }

      // ignore: deprecated_member_use
      return await Printing.convertHtml(
        html: html,
        baseUrl: AppEnvironment.baseUrl,
      );
    } catch (_) {
      return null;
    }
  }

  Future<Uint8List> _buildEmergencyPdfBytes(Order order) async {
    final pdf = pw.Document(title: 'فاتورة ${_displayOrderNumber(order)}');
    final createdAt = DateFormat(
      'yyyy-MM-dd HH:mm',
    ).format(order.date.toLocal());
    final verificationUrl = order.invoiceVerificationUrl.trim();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(24),
        build: (_) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              'LEXI MEGA STORE',
              style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 8),
            pw.Text('فاتورة #${_displayOrderNumber(order)}'),
            pw.Text('الحالة: ${order.status}'),
            pw.Text('التاريخ: $createdAt'),
            pw.SizedBox(height: 10),
            pw.Text(
              'الإجمالي: ${_money(order.total, currency: _currencyCode(order))}',
            ),
            if (verificationUrl.isNotEmpty) ...[
              pw.SizedBox(height: 12),
              pw.Text(
                'التحقق من الفاتورة',
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
              ),
              pw.SizedBox(height: 8),
              pw.BarcodeWidget(
                barcode: pw.Barcode.qrCode(),
                data: verificationUrl,
                width: 92,
                height: 92,
              ),
              pw.SizedBox(height: 4),
              pw.Text(
                'امسح رمز QR للتحقق',
                style: const pw.TextStyle(
                  fontSize: 9,
                  color: PdfColors.grey700,
                ),
              ),
            ],
          ],
        ),
      ),
    );

    return pdf.save();
  }

  bool _looksLikePdfUrl(String url) {
    final lower = url.toLowerCase();
    return lower.endsWith('.pdf') ||
        lower.contains('format=pdf') ||
        lower.contains('type=pdf') ||
        lower.contains('application/pdf');
  }

  String _displayOrderNumber(Order order) {
    final number = order.orderNumber.trim();
    if (number.isNotEmpty) {
      return number;
    }
    return order.id.trim().isNotEmpty ? order.id.trim() : widget.orderId;
  }

  String _invoiceTypeLabel(Order order) {
    final normalizedType = widget.type.trim().toLowerCase();
    if (normalizedType == 'final') {
      return 'فاتورة نهائية';
    }
    if (normalizedType == 'provisional' || normalizedType == 'proforma') {
      return 'فاتورة مبدئية';
    }

    final status = order.status.trim().toLowerCase();
    if (status == 'processing' || status == 'completed') {
      return 'فاتورة نهائية';
    }
    return 'فاتورة مبدئية';
  }

  _InvoiceStatusMeta _statusMeta(String rawStatus) {
    final status = rawStatus.trim().toLowerCase();
    switch (status) {
      case 'completed':
      case 'delivered':
        return const _InvoiceStatusMeta('مكتمل', LexiColors.success);
      case 'processing':
        return const _InvoiceStatusMeta('قيد المعالجة', LexiColors.info);
      case 'out-for-delivery':
        return const _InvoiceStatusMeta('خرج للتسليم', LexiColors.info);
      case 'pending-verification':
      case 'on-hold':
        return const _InvoiceStatusMeta(
          'بانتظار التحقق من الدفع',
          LexiColors.warning,
        );
      case 'pending':
        return const _InvoiceStatusMeta('قيد الانتظار', LexiColors.warning);
      case 'cancelled':
        return const _InvoiceStatusMeta('ملغي', LexiColors.error);
      case 'failed':
        return const _InvoiceStatusMeta('فشل', LexiColors.error);
      case 'refunded':
        return const _InvoiceStatusMeta('مسترجع', LexiColors.neutral500);
      default:
        return _InvoiceStatusMeta(
          status.isEmpty ? 'غير معروف' : status,
          LexiColors.neutral500,
        );
    }
  }

  String _paymentLabel(PaymentMethod? method) {
    switch (method) {
      case PaymentMethod.cod:
        return 'عند الاستلام';
      case PaymentMethod.shamCash:
        return 'شام كاش';
      case null:
        return 'غير محدد';
    }
  }

  String _currencyCode(Order order) {
    final currency = order.currency?.trim();
    if (currency == null || currency.isEmpty) {
      return 'SYP';
    }
    return currency.toUpperCase();
  }

  String _displayInfo(String raw, {String fallback = 'غير متوفر'}) {
    final normalized = TextNormalizer.normalize(raw).trim();
    if (normalized.isEmpty) {
      return fallback;
    }
    return normalized;
  }

  String _money(num value, {required String currency}) {
    final formatted = NumberFormat.currency(
      locale: 'en_US',
      symbol: '',
      decimalDigits: 2,
    ).format(value);
    return '${formatted.trim()} $currency';
  }

  Future<void> _openVerificationLink(String url) async {
    final uri = Uri.tryParse(url.trim());
    if (uri == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        lexiFloatingSnackBar(
          context,
          content: const Text('رابط غير صالح.'),
          backgroundColor: LexiColors.error,
        ),
      );
      return;
    }

    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        lexiFloatingSnackBar(
          context,
          content: const Text('تعذر فتح الرابط.'),
          backgroundColor: LexiColors.error,
        ),
      );
    }
  }
}

class _InvoiceStatusMeta {
  final String label;
  final Color color;

  const _InvoiceStatusMeta(this.label, this.color);
}

class _Badge extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color background;

  const _Badge({
    required this.icon,
    required this.text,
    required this.background,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.black),
          const SizedBox(width: 6),
          Text(
            text,
            style: const TextStyle(
              color: Colors.black,
              fontSize: 12,
              fontWeight: FontWeight.w700,
              fontFamily: 'Cairo',
            ),
          ),
        ],
      ),
    );
  }
}

class _InvoiceInfoCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<({String label, String value})> rows;

  const _InvoiceInfoCard({
    required this.title,
    required this.icon,
    required this.rows,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(LexiRadius.card),
        border: Border.all(color: Colors.black, width: 1.2),
        boxShadow: LexiShadows.cardLow,
      ),
      padding: const EdgeInsets.all(LexiSpacing.s16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: LexiColors.brandBlack),
              const SizedBox(width: LexiSpacing.s8),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  fontFamily: 'Cairo',
                  color: LexiColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: LexiSpacing.s12),
          ...rows.asMap().entries.map((entry) {
            final row = entry.value;
            final isLast = entry.key == rows.length - 1;

            return Container(
              margin: EdgeInsets.only(bottom: isLast ? 0 : LexiSpacing.s8),
              padding: const EdgeInsets.only(bottom: LexiSpacing.s8),
              decoration: BoxDecoration(
                border: isLast
                    ? null
                    : const Border(
                        bottom: BorderSide(color: LexiColors.neutral200),
                      ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      row.value,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        fontFamily: 'Cairo',
                        color: LexiColors.textPrimary,
                      ),
                    ),
                  ),
                  const SizedBox(width: LexiSpacing.s8),
                  Text(
                    '${row.label}:',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      fontFamily: 'Cairo',
                      color: LexiColors.textSecondary,
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  final String title;
  final String value;
  final Color? valueColor;

  const _MetricCard({
    required this.title,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(LexiSpacing.s12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.black, width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              fontFamily: 'Cairo',
              color: LexiColors.textSecondary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              fontFamily: 'Cairo',
              color: valueColor ?? LexiColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

class _TotalRow extends StatelessWidget {
  final String label;
  final String value;
  final bool emphasized;

  const _TotalRow({
    required this.label,
    required this.value,
    this.emphasized = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: emphasized ? 16 : 14,
              fontWeight: emphasized ? FontWeight.w800 : FontWeight.w600,
              fontFamily: 'Cairo',
              color: emphasized
                  ? LexiColors.textPrimary
                  : LexiColors.textSecondary,
            ),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: emphasized ? 18 : 14,
            fontWeight: emphasized ? FontWeight.w900 : FontWeight.w700,
            fontFamily: 'Cairo',
            color: emphasized ? LexiColors.brandBlack : LexiColors.textPrimary,
          ),
        ),
      ],
    );
  }
}
