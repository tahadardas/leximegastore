import 'dart:ui' as ui;

import 'package:dio/dio.dart';
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
import '../../../../core/session/app_session.dart';
import '../../../../core/utils/pdf_file_saver.dart';
import '../../../../core/utils/text_normalizer.dart';
import '../../../../design_system/lexi_tokens.dart';
import '../../../cart/domain/entities/cart_item.dart';
import '../../../../shared/services/share_service.dart';
import '../../../../shared/widgets/error_state.dart';
import '../../../../shared/widgets/lexi_network_image.dart';
import '../../../../shared/widgets/lexi_ui/lexi_app_bar.dart';
import '../../../../ui/widgets/lexi_safe_bottom.dart';
import '../../../payment/domain/entities/payment_method.dart';
import '../../data/repositories/order_repository_impl.dart';
import '../../domain/entities/invoice_document.dart';
import '../../domain/entities/order.dart';
import '../../domain/entities/order_address.dart';
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
    this.type = 'provisional',
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
    final session = ref.watch(appSessionProvider);
    final embeddedOrder = dataEmbeddedOrder(invoiceAsync.valueOrNull);
    final orderAsync = embeddedOrder != null
        ? AsyncData<Order>(embeddedOrder)
        : widget.initialOrder != null
        ? AsyncData<Order>(widget.initialOrder!)
        : (session.isLoggedIn
              ? ref.watch(_invoiceOrderProvider(widget.orderId))
              : null);

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
          message: _invoiceErrorMessage(e),
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

  String _invoiceErrorMessage(Object error) {
    if (error is DioException) {
      final payload = _extractErrorPayload(error.response?.data);
      final code = (payload['code'] ?? '').toString().trim().toLowerCase();
      if (code == 'phone_required') {
        return '\u0631\u0642\u0645 \u0627\u0644\u0647\u0627\u062a\u0641 \u0645\u0637\u0644\u0648\u0628 \u0644\u0639\u0631\u0636 \u0641\u0627\u062a\u0648\u0631\u0629 \u0637\u0644\u0628 \u0627\u0644\u0636\u064a\u0641.';
      }
      if (code == 'phone_mismatch') {
        return '\u0631\u0642\u0645 \u0627\u0644\u0647\u0627\u062a\u0641 \u0644\u0627 \u064a\u0637\u0627\u0628\u0642 \u0628\u064a\u0627\u0646\u0627\u062a \u0647\u0630\u0627 \u0627\u0644\u0637\u0644\u0628.';
      }
      if (code == 'invoice_not_ready') {
        return '\u0627\u0644\u0641\u0627\u062a\u0648\u0631\u0629 \u0627\u0644\u0646\u0647\u0627\u0626\u064a\u0629 \u063a\u064a\u0631 \u062c\u0627\u0647\u0632\u0629 \u062d\u0627\u0644\u064a\u0627\u064b. \u064a\u062a\u0645 \u0639\u0631\u0636 \u0627\u0644\u0641\u0627\u062a\u0648\u0631\u0629 \u0627\u0644\u0645\u0628\u062f\u0626\u064a\u0629 \u0639\u0646\u062f \u062a\u0648\u0641\u0631\u0647\u0627.';
      }
    }

    return '\u062a\u0639\u0630\u0631 \u062a\u062d\u0645\u064a\u0644 \u0627\u0644\u0641\u0627\u062a\u0648\u0631\u0629. \u062d\u0627\u0648\u0644 \u0645\u0631\u0629 \u0623\u062e\u0631\u0649.';
  }

  Map<String, dynamic> _extractErrorPayload(dynamic raw) {
    if (raw is! Map) {
      return const <String, dynamic>{};
    }

    final map = raw.map((key, value) => MapEntry(key.toString(), value));
    final error = map['error'];
    if (error is Map) {
      return error.map((key, value) => MapEntry(key.toString(), value));
    }
    return map;
  }

  Order? dataEmbeddedOrder(dynamic data) {
    if (data is InvoiceDocument) {
      return data.order;
    }
    return null;
  }

  dynamic _invoiceContent(dynamic data) {
    if (data is InvoiceDocument) {
      return data.content;
    }
    return data;
  }

  Widget _buildInvoiceBody(dynamic data, AsyncValue<Order>? orderAsync) {
    final embeddedOrder = dataEmbeddedOrder(data);
    if (embeddedOrder != null) {
      return _buildModernInvoice(embeddedOrder);
    }
    data = _invoiceContent(data);

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
      final parsedInvoiceOrder = _tryBuildOrderFromInvoiceData(data);
      if (parsedInvoiceOrder != null) {
        return _buildModernInvoice(parsedInvoiceOrder);
      }

      if (orderAsync == null) {
        if (raw.isNotEmpty && raw.toLowerCase().startsWith('http')) {
          return _buildUrlFallback(raw);
        }
        return _buildHtmlFallback(raw);
      }

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

    if (orderAsync?.hasValue ?? false) {
      final order = orderAsync!.requireValue;
      return _buildModernInvoice(order);
    }

    return const Center(child: Text('صيغة الفاتورة غير مدعومة'));
  }

  Order? _tryBuildOrderFromInvoiceData(String rawData) {
    final normalized = TextNormalizer.normalize(rawData).trim();
    if (normalized.isEmpty || normalized.toLowerCase().startsWith('http')) {
      return null;
    }

    final text = _plainTextFromInvoiceHtml(normalized);
    final lines = text
        .split('\n')
        .map((line) => TextNormalizer.normalize(line).trim())
        .where((line) => line.isNotEmpty)
        .toList(growable: false);
    if (lines.isEmpty) {
      return null;
    }

    final orderNumber = _extractInvoiceOrderNumber(text) ?? widget.orderId;
    final phone = _extractInvoicePhone(text) ?? widget.phone?.trim() ?? '';
    final customerName = _valueAfterAnyLabel(lines, const [
      'العميل',
      'اسم العميل',
      'الاسم',
    ]);
    final address = _valueAfterAnyLabel(lines, const [
      'العنوان',
      'عنوان الشحن',
      'المدينة',
    ]);
    final total = _amountAfterAnyLabel(lines, const [
      'الإجمالي النهائي',
      'الاجمالي النهائي',
      'المجموع النهائي',
      'الإجمالي',
      'الاجمالي',
    ]);
    final shipping = _amountAfterAnyLabel(lines, const [
      'الشحن',
      'تكلفة الشحن',
    ]);
    final subtotal = _amountAfterAnyLabel(lines, const [
      'المجموع الفرعي',
      'المجموع',
      'Subtotal',
    ]);
    final discount = _amountAfterAnyLabel(lines, const ['الخصم', 'الحسم']);
    final tax = _amountAfterAnyLabel(lines, const ['الضريبة', 'الضرائب']);
    final itemName = _extractInvoiceItemName(lines);
    final resolvedTotal = total > 0
        ? total
        : subtotal + shipping - discount + tax;
    final resolvedSubtotal = subtotal > 0
        ? subtotal
        : (resolvedTotal > shipping ? resolvedTotal - shipping : resolvedTotal);
    final itemTotal = resolvedSubtotal > 0 ? resolvedSubtotal : resolvedTotal;

    if (resolvedTotal <= 0 &&
        customerName.isEmpty &&
        phone.isEmpty &&
        itemName.isEmpty) {
      return null;
    }

    final nameParts = customerName.split(RegExp(r'\s+'));
    final firstName = nameParts.isEmpty ? customerName : nameParts.first;
    final lastName = nameParts.length <= 1
        ? ''
        : nameParts.skip(1).join(' ').trim();
    final verificationUrl = _extractFirstUrl(text);
    final item = itemName.isEmpty
        ? null
        : CartItem(
            productId: 0,
            name: itemName,
            price: itemTotal > 0 ? itemTotal : resolvedTotal,
            qty: 1,
            lineTotalOverride: itemTotal > 0 ? itemTotal : resolvedTotal,
          );
    final digitsOnly = orderNumber.replaceAll(RegExp(r'\D+'), '');

    return Order(
      id: digitsOnly.isNotEmpty ? digitsOnly : widget.orderId,
      orderNumber: orderNumber,
      date: _extractInvoiceDate(text) ?? DateTime.now(),
      status: _extractInvoiceStatus(text),
      subtotal: resolvedSubtotal,
      shippingCost: shipping,
      total: resolvedTotal > 0 ? resolvedTotal : resolvedSubtotal,
      discountTotal: discount > 0 ? discount : null,
      tax: tax > 0 ? tax : null,
      finalTotal: resolvedTotal > 0 ? resolvedTotal : null,
      amountToCollect: resolvedTotal > 0 ? resolvedTotal : null,
      currency: 'SYP',
      items: item == null ? const <CartItem>[] : <CartItem>[item],
      itemCount: item == null ? null : 1,
      paymentMethod: _extractInvoicePaymentMethod(text),
      billing: OrderAddress(
        firstName: firstName,
        lastName: lastName,
        address1: address,
        phone: phone,
      ),
      invoiceVerificationUrl: verificationUrl,
    );
  }

  String? _extractInvoiceOrderNumber(String text) {
    final western = _westernizeDigits(text);
    for (final pattern in <RegExp>[
      RegExp(r'#\s*(\d{2,})'),
      RegExp(r'(?:order|invoice)[^\d]{0,12}(\d{2,})', caseSensitive: false),
      RegExp(r'(?:الطلب|الفاتورة|رقم الطلب)[^\d]{0,12}(\d{2,})'),
    ]) {
      final match = pattern.firstMatch(western);
      final value = match?.group(1)?.trim();
      if (value != null && value.isNotEmpty) {
        return value;
      }
    }
    return null;
  }

  String? _extractInvoicePhone(String text) {
    final western = _westernizeDigits(text);
    final match = RegExp(r'(?:\+?963)?0?9\d{8}').firstMatch(western);
    return match?.group(0);
  }

  DateTime? _extractInvoiceDate(String text) {
    final western = _westernizeDigits(text);
    final dateWithTime = RegExp(
      r'(\d{1,2}):(\d{2}).{0,24}?(\d{1,2})[-/](\d{1,2})[-/](\d{4})',
    ).firstMatch(western);
    if (dateWithTime != null) {
      final hour = dateWithTime.group(1)!.padLeft(2, '0');
      final minute = dateWithTime.group(2)!.padLeft(2, '0');
      final day = dateWithTime.group(3)!.padLeft(2, '0');
      final month = dateWithTime.group(4)!.padLeft(2, '0');
      final year = dateWithTime.group(5)!;
      return DateTime.tryParse('$year-$month-$day $hour:$minute:00');
    }

    final dateOnly = RegExp(
      r'(\d{4})[-/](\d{1,2})[-/](\d{1,2})',
    ).firstMatch(western);
    if (dateOnly != null) {
      final year = dateOnly.group(1)!;
      final month = dateOnly.group(2)!.padLeft(2, '0');
      final day = dateOnly.group(3)!.padLeft(2, '0');
      return DateTime.tryParse('$year-$month-$day');
    }
    return null;
  }

  String _extractInvoiceStatus(String text) {
    if (text.contains('مكتمل') || text.toLowerCase().contains('completed')) {
      return 'completed';
    }
    if (text.contains('قيد المعالجة') ||
        text.toLowerCase().contains('processing')) {
      return 'processing';
    }
    if (text.contains('ملغي') || text.toLowerCase().contains('cancel')) {
      return 'cancelled';
    }
    if (text.contains('فاشل') || text.toLowerCase().contains('failed')) {
      return 'failed';
    }
    return 'pending';
  }

  PaymentMethod? _extractInvoicePaymentMethod(String text) {
    if (text.contains('شام') ||
        text.toLowerCase().contains('sham') ||
        text.toLowerCase().contains('cash transfer')) {
      return PaymentMethod.shamCash;
    }
    if (text.contains('عند الاستلام') ||
        text.toLowerCase().contains('cod') ||
        text.toLowerCase().contains('cash on delivery')) {
      return PaymentMethod.cod;
    }
    return null;
  }

  String _valueAfterAnyLabel(List<String> lines, List<String> labels) {
    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      final label = labels.firstWhere(
        (candidate) => line.contains(candidate),
        orElse: () => '',
      );
      if (label.isEmpty) {
        continue;
      }

      final inline = _cleanInvoiceValue(line.replaceFirst(label, ''));
      if (_isUsefulInvoiceValue(inline)) {
        return inline;
      }

      for (var next = i + 1; next < lines.length && next <= i + 3; next++) {
        final value = _cleanInvoiceValue(lines[next]);
        if (_isUsefulInvoiceValue(value)) {
          return value;
        }
      }
    }
    return '';
  }

  double _amountAfterAnyLabel(List<String> lines, List<String> labels) {
    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      if (!labels.any(line.contains)) {
        continue;
      }

      for (var index = i; index < lines.length && index <= i + 2; index++) {
        final amount = _lastAmountInText(lines[index]);
        if (amount > 0) {
          return amount;
        }
      }
    }
    return 0;
  }

  String _extractInvoiceItemName(List<String> lines) {
    var start = -1;
    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      if (line.contains('SKU') ||
          line.contains('المنتج') ||
          line.contains('بنود الفاتورة')) {
        start = i + 1;
        break;
      }
    }
    if (start < 0 || start >= lines.length) {
      return '';
    }

    var best = '';
    for (var i = start; i < lines.length; i++) {
      final line = lines[i];
      if (line.contains('المجموع') ||
          line.contains('الإجمالي') ||
          line.contains('الاجمالي') ||
          line.contains('الشحن') ||
          line.contains('الخصم')) {
        break;
      }
      final candidate = _cleanInvoiceItemLine(line);
      if (candidate.length > best.length && candidate.length >= 4) {
        best = candidate;
      }
    }
    return best;
  }

  String _cleanInvoiceValue(String value) {
    return TextNormalizer.normalize(value)
        .replaceAll(RegExp(r'[:：#\-–—]+'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  bool _isUsefulInvoiceValue(String value) {
    if (value.isEmpty) {
      return false;
    }
    const labels = [
      'العميل',
      'الاسم',
      'الهاتف',
      'العنوان',
      'المدينة',
      'الإجمالي',
      'الاجمالي',
      'الشحن',
      'المنتج',
      'SKU',
    ];
    return !labels.any((label) => value == label || value.contains('$label:'));
  }

  String _cleanInvoiceItemLine(String line) {
    var value = _cleanInvoiceValue(line);
    final sypIndex = value.toUpperCase().indexOf('SYP');
    if (sypIndex > 8) {
      value = value.substring(0, sypIndex).trim();
    }
    return value
        .replaceAll(RegExp(r'\s{2,}'), ' ')
        .replaceAll(
          RegExp(r'^(SKU|المنتج|الكمية)\s+', caseSensitive: false),
          '',
        )
        .trim();
  }

  double _lastAmountInText(String text) {
    final western = _westernizeDigits(text);
    final matches = RegExp(
      r'(?:SYP\s*)?([0-9][0-9,.\s]*)(?:\s*SYP)?',
      caseSensitive: false,
    ).allMatches(western).toList(growable: false);
    for (final match in matches.reversed) {
      final raw = match.group(1);
      if (raw == null) {
        continue;
      }
      final normalized = raw.replaceAll(',', '').replaceAll(' ', '').trim();
      final parsed = double.tryParse(normalized);
      if (parsed != null && parsed > 0) {
        return parsed;
      }
    }
    return 0;
  }

  String _extractFirstUrl(String text) {
    final match = RegExp(r'''https?://[^\s<>"']+''').firstMatch(text);
    return match?.group(0)?.trim() ?? '';
  }

  String _westernizeDigits(String value) {
    const eastern = '٠١٢٣٤٥٦٧٨٩';
    const persian = '۰۱۲۳۴۵۶۷۸۹';
    var out = value;
    for (var i = 0; i < 10; i++) {
      out = out.replaceAll(eastern[i], '$i').replaceAll(persian[i], '$i');
    }
    return out;
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
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFF9FAFC), Color(0xFFF2F4F8)],
          ),
        ),
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
                  borderRadius: BorderRadius.circular(22),
                  gradient: const LinearGradient(
                    begin: Alignment.topRight,
                    end: Alignment.bottomLeft,
                    colors: [
                      Color(0xFF0F172A),
                      Color(0xFF1E293B),
                      Color(0xFF334155),
                    ],
                  ),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x290F172A),
                      blurRadius: 28,
                      offset: Offset(0, 16),
                    ),
                  ],
                ),
                clipBehavior: Clip.antiAlias,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    LexiSpacing.s16,
                    LexiSpacing.s16,
                    LexiSpacing.s16,
                    LexiSpacing.s20,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.96),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Image.asset(
                              'assets/images/logo_long.jpg',
                              width: 132,
                              fit: BoxFit.contain,
                            ),
                          ),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 7,
                            ),
                            decoration: BoxDecoration(
                              color: statusMeta.color.withValues(alpha: 0.22),
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.35),
                                width: 1,
                              ),
                            ),
                            child: Text(
                              invoiceTypeLabel,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                fontFamily: 'Cairo',
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: LexiSpacing.s12),
                      Text(
                        'فاتورة الطلب #${_displayOrderNumber(order)}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 23,
                          fontWeight: FontWeight.w900,
                          height: 1.3,
                          fontFamily: 'Cairo',
                        ),
                      ),
                      const SizedBox(height: LexiSpacing.s8),
                      Wrap(
                        spacing: LexiSpacing.s8,
                        runSpacing: LexiSpacing.s8,
                        children: [
                          _Badge(
                            icon: Icons.calendar_today_outlined,
                            text: formattedDate,
                            background: Colors.white.withValues(alpha: 0.15),
                            borderColor: Colors.white.withValues(alpha: 0.24),
                            iconColor: Colors.white,
                            textColor: Colors.white,
                          ),
                          _Badge(
                            icon: Icons.verified_outlined,
                            text: statusMeta.label,
                            background: statusMeta.color.withValues(
                              alpha: 0.24,
                            ),
                            borderColor: Colors.white.withValues(alpha: 0.22),
                            iconColor: Colors.white,
                            textColor: Colors.white,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: LexiSpacing.s16),
              LayoutBuilder(
                builder: (context, constraints) {
                  const spacing = LexiSpacing.s12;
                  final width = constraints.maxWidth;
                  final cardWidth = width >= 860
                      ? (width - (spacing * 2)) / 3
                      : width >= 560
                      ? (width - spacing) / 2
                      : width;

                  return Wrap(
                    spacing: spacing,
                    runSpacing: spacing,
                    children: [
                      SizedBox(
                        width: cardWidth,
                        child: _MetricCard(
                          title: 'الإجمالي',
                          value: _money(order.total, currency: currency),
                          valueColor: LexiColors.brandPrimary,
                          icon: Icons.payments_outlined,
                          accentColor: LexiColors.brandPrimary,
                        ),
                      ),
                      SizedBox(
                        width: cardWidth,
                        child: _MetricCard(
                          title: 'المنتجات',
                          value: '${order.resolvedItemCount}',
                          icon: Icons.inventory_2_outlined,
                          accentColor: const Color(0xFF0EA5E9),
                        ),
                      ),
                      SizedBox(
                        width: cardWidth,
                        child: _MetricCard(
                          title: 'طريقة الدفع',
                          value: _paymentLabel(order.paymentMethod),
                          icon: Icons.account_balance_wallet_outlined,
                          accentColor: const Color(0xFF22C55E),
                        ),
                      ),
                    ],
                  );
                },
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
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x140F172A),
                      blurRadius: 16,
                      offset: Offset(0, 8),
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(LexiSpacing.s16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.receipt_long_outlined,
                          size: 20,
                          color: LexiColors.textPrimary,
                        ),
                        const SizedBox(width: LexiSpacing.s8),
                        const Expanded(
                          child: Text(
                            'بنود الفاتورة',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                              fontFamily: 'Cairo',
                              color: LexiColors.textPrimary,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: LexiColors.neutral100,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            '${order.resolvedItemCount} منتج',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              fontFamily: 'Cairo',
                              color: LexiColors.textSecondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: LexiSpacing.s12),
                    if (order.items.isEmpty)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(LexiSpacing.s12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: const Text(
                          'لا توجد بنود متاحة لهذه الفاتورة.',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            fontFamily: 'Cairo',
                            color: LexiColors.textSecondary,
                          ),
                        ),
                      )
                    else
                      ...order.items.asMap().entries.map((entry) {
                        final item = entry.value;
                        final itemName = TextNormalizer.normalize(
                          item.name,
                        ).trim();
                        final hasImage = item.image.trim().isNotEmpty;

                        final row = Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 48,
                                height: 48,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: const Color(0xFFDCE3EC),
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
                              const SizedBox(width: 10),
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
                                        height: 1.35,
                                        fontWeight: FontWeight.w800,
                                        fontFamily: 'Cairo',
                                        color: LexiColors.textPrimary,
                                      ),
                                    ),
                                    if (item.variationLabel?.isNotEmpty ??
                                        false) ...[
                                      const SizedBox(height: 3.0),
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
                              const SizedBox(width: 10),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(9),
                                  border: Border.all(
                                    color: const Color(0xFFDCE3EC),
                                  ),
                                ),
                                child: Text(
                                  _money(item.lineTotal, currency: currency),
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                    fontFamily: 'Cairo',
                                    color: LexiColors.textPrimary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );

                        if (entry.key == order.items.length - 1) {
                          return row;
                        }
                        return row;
                      }),
                  ],
                ),
              ),
              const SizedBox(height: LexiSpacing.s16),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x140F172A),
                      blurRadius: 16,
                      offset: Offset(0, 8),
                    ),
                  ],
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
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 11,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF8DB),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: LexiColors.brandPrimary.withValues(alpha: 0.6),
                        ),
                      ),
                      child: _TotalRow(
                        label: 'الإجمالي النهائي',
                        value: _money(order.total, currency: currency),
                        emphasized: true,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: LexiSpacing.s16),
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: const Color(0xFFDBEAFE)),
                  gradient: const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0xFFF8FBFF), Color(0xFFF1F6FF)],
                  ),
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
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final compact = constraints.maxWidth < 520;
                          final qrBox = Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: const Color(0xFFBFDBFE),
                              ),
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
                          );
                          final textBlock = const Text(
                            'رمز QR مخصص للتحقق من الفاتورة.\nيمكنك فتح صفحة التحقق مباشرة من الزر أدناه.',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              fontFamily: 'Cairo',
                              color: LexiColors.textSecondary,
                              height: 1.5,
                            ),
                          );

                          if (compact) {
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                textBlock,
                                const SizedBox(height: LexiSpacing.s12),
                                qrBox,
                              ],
                            );
                          }
                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Expanded(child: textBlock),
                              const SizedBox(width: LexiSpacing.s12),
                              qrBox,
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: LexiSpacing.s12),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () =>
                              _openVerificationLink(verificationUrl),
                          icon: const Icon(Icons.open_in_new_rounded),
                          label: const Text(
                            'فتح صفحة التحقق',
                            style: TextStyle(fontFamily: 'Cairo'),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF2563EB),
                            foregroundColor: Colors.white,
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
                  color: const Color(0xFFFCFDFE),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: const Text(
                  'هذه الفاتورة من متجر Lexi Mega Store وهي لا تحتاج إلى توقيع لأنها موقعة إلكترونياً.',
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
    final embeddedOrder = dataEmbeddedOrder(data);
    if (embeddedOrder != null) {
      try {
        return await InvoicePdfExporter.buildPdfBytes(
          embeddedOrder,
          invoiceType: widget.type,
        );
      } catch (_) {
        return _buildEmergencyPdfBytes(embeddedOrder);
      }
    }
    data = _invoiceContent(data);
    final rawInvoiceData = data is String ? data.trim() : '';

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
      final parsedInvoiceOrder = _tryBuildOrderFromInvoiceData(data);
      if (parsedInvoiceOrder != null) {
        _pdfSourceOrder = parsedInvoiceOrder;
        try {
          return await InvoicePdfExporter.buildPdfBytes(
            parsedInvoiceOrder,
            invoiceType: widget.type,
          );
        } catch (_) {
          return _buildEmergencyPdfBytes(parsedInvoiceOrder);
        }
      }

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

    if (!ref.read(appSessionProvider).isLoggedIn) {
      final fallbackBytes = await _buildRawInvoiceFallbackPdf(rawInvoiceData);
      if (fallbackBytes != null) {
        return fallbackBytes;
      }
      throw const FormatException(
        '\u062a\u0639\u0630\u0631 \u062a\u062c\u0647\u064a\u0632 \u0645\u0644\u0641 \u0627\u0644\u0641\u0627\u062a\u0648\u0631\u0629 \u0644\u0637\u0644\u0628 \u0627\u0644\u0636\u064a\u0641.',
      );
    }

    try {
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
    } catch (_) {
      final fallbackBytes = await _buildRawInvoiceFallbackPdf(rawInvoiceData);
      if (fallbackBytes != null) {
        return fallbackBytes;
      }
      rethrow;
    }
  }

  Future<Order> _loadOrderForPdf() {
    final parsedId = int.tryParse(widget.orderId.trim());
    if (parsedId == null || parsedId <= 0) {
      throw const FormatException('معرف الطلب غير صالح.');
    }

    return ref.read(orderRepositoryProvider).myOrderDetails(parsedId);
  }

  Future<Uint8List?> _buildRawInvoiceFallbackPdf(String rawData) async {
    final normalized = TextNormalizer.normalize(rawData).trim();
    if (normalized.isEmpty) {
      return null;
    }

    final isUrl = normalized.toLowerCase().startsWith('http');
    final invoiceText = isUrl ? '' : _plainTextFromInvoiceHtml(normalized);
    final font = pw.Font.ttf(
      await rootBundle.load('assets/fonts/Amiri-Bold.ttf'),
    );
    final pdf = pw.Document(title: 'invoice_${widget.orderId}');

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(24),
        theme: pw.ThemeData.withFont(
          base: font,
          bold: font,
        ).copyWith(defaultTextStyle: pw.TextStyle(font: font, fontSize: 12)),
        build: (_) => [
          pw.Directionality(
            textDirection: pw.TextDirection.rtl,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.stretch,
              children: [
                pw.Text(
                  '\u0641\u0627\u062a\u0648\u0631\u0629 \u0627\u0644\u0637\u0644\u0628 #${widget.orderId}',
                  style: pw.TextStyle(
                    font: font,
                    fontSize: 20,
                    fontWeight: pw.FontWeight.bold,
                  ),
                  textAlign: pw.TextAlign.right,
                ),
                pw.SizedBox(height: 10),
                pw.Text(
                  '\u062a\u0645 \u0625\u0646\u0634\u0627\u0621 \u0647\u0630\u0627 \u0627\u0644\u0645\u0644\u0641 \u0645\u0646 \u0627\u0644\u0641\u0627\u062a\u0648\u0631\u0629 \u0627\u0644\u0645\u0639\u0631\u0648\u0636\u0629 \u0641\u064a \u0627\u0644\u062a\u0637\u0628\u064a\u0642.',
                  textAlign: pw.TextAlign.right,
                ),
                if (invoiceText.isNotEmpty) ...[
                  pw.SizedBox(height: 16),
                  pw.Text(invoiceText, textAlign: pw.TextAlign.right),
                ],
                if (isUrl) ...[
                  pw.SizedBox(height: 16),
                  pw.Text(
                    '\u0631\u0627\u0628\u0637 \u0627\u0644\u0641\u0627\u062a\u0648\u0631\u0629:',
                    textAlign: pw.TextAlign.right,
                  ),
                  pw.SizedBox(height: 6),
                  pw.Directionality(
                    textDirection: pw.TextDirection.ltr,
                    child: pw.Text(normalized),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );

    return pdf.save();
  }

  String _plainTextFromInvoiceHtml(String rawHtml) {
    var text = rawHtml;
    text = text.replaceAll(
      RegExp(r'<(script|style)[^>]*>[\s\S]*?</\1>', caseSensitive: false),
      ' ',
    );
    text = text.replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n');
    text = text.replaceAll(
      RegExp(
        r'</(p|div|section|article|tr|table|h[1-6]|li)>',
        caseSensitive: false,
      ),
      '\n',
    );
    text = text.replaceAll(RegExp(r'<[^>]+>'), ' ');
    text = text
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'");
    text = TextNormalizer.normalize(text)
        .replaceAll(RegExp(r'[ \t]+'), ' ')
        .replaceAll(RegExp(r'\n\s*\n+'), '\n')
        .trim();
    if (text.length > 3500) {
      return '${text.substring(0, 3500)}...';
    }
    return text;
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
  final Color textColor;
  final Color iconColor;
  final Color? borderColor;

  const _Badge({
    required this.icon,
    required this.text,
    required this.background,
    this.textColor = Colors.black,
    this.iconColor = Colors.black,
    this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
        border: borderColor == null ? null : Border.all(color: borderColor!),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: iconColor),
          const SizedBox(width: 6),
          Text(
            text,
            style: TextStyle(
              color: textColor,
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
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x140F172A),
            blurRadius: 16,
            offset: Offset(0, 8),
          ),
        ],
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
          const SizedBox(height: 6),
          Container(
            width: 40,
            height: 3,
            decoration: BoxDecoration(
              color: LexiColors.brandPrimary.withValues(alpha: 0.75),
              borderRadius: BorderRadius.circular(999),
            ),
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
                        bottom: BorderSide(color: Color(0xFFE2E8F0)),
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
  final IconData? icon;
  final Color accentColor;

  const _MetricCard({
    required this.title,
    required this.value,
    this.valueColor,
    this.icon,
    this.accentColor = LexiColors.brandPrimary,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(LexiSpacing.s12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x140F172A),
            blurRadius: 12,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (icon != null)
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Icon(icon, size: 16, color: accentColor),
                ),
              if (icon != null) const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    fontFamily: 'Cairo',
                    color: LexiColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            width: 42,
            height: 3,
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: 0.7),
              borderRadius: BorderRadius.circular(999),
            ),
          ),
          const SizedBox(height: 8),
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
