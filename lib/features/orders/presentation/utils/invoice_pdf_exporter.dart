import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../../payment/domain/entities/payment_method.dart';
import '../../domain/entities/order.dart';

/// Elegant PDF invoice exporter with Lexi brand identity.
///
/// Design language:
/// - White background, gold (#FACB21) accent stripe/highlights
/// - `logo_long.jpg` centred at the top
/// - Black text, thin black section borders
/// - Single page that grows when items overflow
abstract class InvoicePdfExporter {
  // ── brand palette ──────────────────────────────────────────
  static final PdfColor _brandGold = PdfColor.fromHex('#FACB21');
  static final PdfColor _brandBlack = PdfColor.fromHex('#0C0B0A');
  static const PdfColor _textSecondary = PdfColors.grey700;
  static final PdfColor _borderLight = PdfColor.fromHex('#E0E0E0');

  // ════════════════════════════════════════════════════════════
  //  PUBLIC API
  // ════════════════════════════════════════════════════════════

  static Future<void> exportCompletedOrder(Order order) async {
    if (!_canExportFinalInvoice(order.status)) {
      throw const FormatException(
        'تصدير PDF متاح فقط للطلبات المكتملة أو قيد المعالجة.',
      );
    }

    final bytes = await buildPdfBytes(order, invoiceType: 'final');
    final fileName = 'invoice-${_displayOrderNumber(order)}.pdf';

    try {
      await Printing.layoutPdf(name: fileName, onLayout: (_) async => bytes);
    } catch (_) {
      await Printing.sharePdf(bytes: bytes, filename: fileName);
    }
  }

  static Future<Uint8List> buildPdfBytes(
    Order order, {
    String? invoiceType,
  }) async {
    final mainFontByteData = await rootBundle.load('assets/fonts/Amiri-Regular.ttf');
    final mainFont = pw.Font.ttf(mainFontByteData);
    
    final boldFontByteData = await rootBundle.load('assets/fonts/Amiri-Bold.ttf');
    final boldFont = pw.Font.ttf(boldFontByteData);

    final logo = await _loadLogo();
    final currency = _currencyCode(order);
    final verificationData = _verificationData(order);
    final invoiceTitle = _invoiceTitle(order, invoiceType: invoiceType);
    final dateLabel = DateFormat(
      'yyyy-MM-dd HH:mm',
      'ar',
    ).format(order.date.toLocal());
    final customer = _customerInfo(order);

    final pdf = pw.Document(
      title: '$invoiceTitle - ${_displayOrderNumber(order)}',
      author: 'Lexi Mega Store',
    );

    // Use pw.Page with flexible height so everything fits on one sheet
    // that stretches when items are many.
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.symmetric(horizontal: 28, vertical: 24),
        theme: pw.ThemeData.withFont(
          base: mainFont,
          bold: boldFont,
          italic: mainFont,
          boldItalic: boldFont,
        ).copyWith(
          defaultTextStyle: pw.TextStyle(
            font: mainFont,
            fontFallback: [mainFont, boldFont],
            fontSize: 12,
            color: _brandBlack,
          ),
        ),
        header: (_) => pw.SizedBox.shrink(),
        footer: (_) => _footer(),
        build: (_) => [
          pw.Directionality(
            textDirection: pw.TextDirection.rtl,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.stretch,
              children: [
                // ── HEADER with logo + gold stripe ───────
                _buildHeader(
                  order: order,
                  invoiceTitle: invoiceTitle,
                  dateLabel: dateLabel,
                  logo: logo,
                ),

                pw.SizedBox(height: 14),

                // ── Two-column info: invoice data + buyer ─
                pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Expanded(
                      child: _infoBlock(
                        title: 'بيانات الفاتورة',
                        rows: [
                          ('رقم الطلب', '#${_displayOrderNumber(order)}'),
                          ('الحالة', _statusLabel(order.status)),
                          ('طريقة الدفع', _paymentLabel(order.paymentMethod)),
                        ],
                      ),
                    ),
                    pw.SizedBox(width: 12),
                    pw.Expanded(
                      child: _infoBlock(
                        title: 'بيانات المشتري',
                        rows: [
                          ('الاسم', customer.name),
                          ('الهاتف', customer.phone),
                          if (customer.email.isNotEmpty)
                            ('البريد الإلكتروني', customer.email),
                          ('العنوان', customer.address),
                        ],
                      ),
                    ),
                  ],
                ),

                pw.SizedBox(height: 10),

                // ── Courier info ─────────────────────────
                _infoBlock(
                  title: 'بيانات المندوب',
                  rows: [
                    ('اسم المندوب', _displayOrFallback(order.courierName)),
                    ('هاتف المندوب', _displayOrFallback(order.courierPhone)),
                  ],
                ),

                pw.SizedBox(height: 14),

                // ── Items table ──────────────────────────
                _buildItemsSection(order, currency: currency),

                pw.SizedBox(height: 14),

                // ── Totals + QR side by side ─────────────
                pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Expanded(
                      flex: 3,
                      child: _buildTotalsCard(order, currency: currency),
                    ),
                    pw.SizedBox(width: 12),
                    pw.Expanded(flex: 2, child: _buildQrCard(verificationData)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );

    return pdf.save();
  }

  // ════════════════════════════════════════════════════════════
  //  HEADER
  // ════════════════════════════════════════════════════════════

  static pw.Widget _buildHeader({
    required Order order,
    required String invoiceTitle,
    required String dateLabel,
    required pw.MemoryImage? logo,
  }) {
    return pw.Container(
      decoration: pw.BoxDecoration(
        color: PdfColors.white,
        borderRadius: pw.BorderRadius.circular(10),
        border: pw.Border.all(color: _borderLight, width: 0.6),
      ),
      child: pw.Column(
        children: [
          // Logo area
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
            child: logo != null
                ? pw.Center(
                    child: pw.Container(
                      width: 200,
                      child: pw.Image(logo, fit: pw.BoxFit.contain),
                    ),
                  )
                : pw.Center(
                    child: pw.Text(
                      'LEXI MEGA STORE',
                      textDirection: pw.TextDirection.ltr,
                      style: pw.TextStyle(
                        fontSize: 22,
                        fontWeight: pw.FontWeight.bold,
                        color: _brandBlack,
                      ),
                    ),
                  ),
          ),

          // Gold accent stripe ─ brand identity element
          pw.Container(height: 3, color: _brandGold),

          // Invoice meta row
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 10,
            ),
            color: PdfColors.white,
            child: pw.Row(
              children: [
                pw.Expanded(
                  child: pw.Text(
                    '$invoiceTitle  •  #${_displayOrderNumber(order)}',
                    style: pw.TextStyle(
                      fontSize: 12,
                      fontWeight: pw.FontWeight.bold,
                      color: _brandBlack,
                    ),
                  ),
                ),
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.white,
                    borderRadius: pw.BorderRadius.circular(999),
                    border: pw.Border.all(color: _brandGold, width: 1),
                  ),
                  child: pw.Text(
                    _statusLabel(order.status),
                    style: pw.TextStyle(
                      color: _brandBlack,
                      fontSize: 9,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ),
                pw.SizedBox(width: 8),
                pw.Text(
                  dateLabel,
                  textDirection: pw.TextDirection.ltr,
                  style: const pw.TextStyle(fontSize: 9, color: _textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ════════════════════════════════════════════════════════════
  //  INFO BLOCK (reusable card)
  // ════════════════════════════════════════════════════════════

  static pw.Widget _infoBlock({
    required String title,
    required List<(String, String)> rows,
  }) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        color: PdfColors.white,
        borderRadius: pw.BorderRadius.circular(8),
        border: pw.Border.all(color: _borderLight, width: 0.6),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: [
          // Section title with gold left accent
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 5),
            decoration: pw.BoxDecoration(
              color: PdfColors.white,
              borderRadius: pw.BorderRadius.circular(4),
              border: pw.Border(
                right: pw.BorderSide(color: _brandGold, width: 3),
              ),
            ),
            child: pw.Text(
              title,
              style: pw.TextStyle(
                fontSize: 10.5,
                fontWeight: pw.FontWeight.bold,
                color: _brandBlack,
              ),
            ),
          ),
          pw.SizedBox(height: 8),
          ...rows.asMap().entries.map((entry) {
            final isLast = entry.key == rows.length - 1;
            final (label, value) = entry.value;
            return pw.Container(
              padding: const pw.EdgeInsets.symmetric(vertical: 4),
              decoration: isLast
                  ? null
                  : const pw.BoxDecoration(
                      border: pw.Border(
                        bottom: pw.BorderSide(
                          color: PdfColors.grey200,
                          width: 0.4,
                        ),
                      ),
                    ),
              child: pw.Row(
                children: [
                  pw.Text(
                    '$label:',
                    style: pw.TextStyle(
                      fontSize: 9.5,
                      color: _textSecondary,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.SizedBox(width: 6),
                  pw.Expanded(
                    child: pw.Text(
                      value,
                      style: const pw.TextStyle(
                        fontSize: 9.5,
                        color: PdfColors.black,
                      ),
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

  // ════════════════════════════════════════════════════════════
  //  ITEMS TABLE
  // ════════════════════════════════════════════════════════════

  static pw.Widget _buildItemsSection(Order order, {required String currency}) {
    final rows = order.items
        .map((item) {
          String productName = item.name.trim().isEmpty
              ? 'منتج'
              : item.name.trim();
          if (item.variationLabel?.isNotEmpty ?? false) {
            productName = '$productName\n${item.variationLabel!}';
          }

          return <String>[
            _money(item.lineTotal, currency: currency),
            _money(item.price, currency: currency),
            item.qty.toString(),
            productName,
          ];
        })
        .toList(growable: false);

    if (rows.isEmpty) {
      return pw.Container(
        padding: const pw.EdgeInsets.all(12),
        decoration: pw.BoxDecoration(
          borderRadius: pw.BorderRadius.circular(8),
          border: pw.Border.all(color: _borderLight, width: 0.6),
        ),
        child: pw.Text(
          'لا توجد منتجات ضمن هذه الفاتورة.',
          style: const pw.TextStyle(fontSize: 10, color: _textSecondary),
        ),
      );
    }

    return pw.Container(
      decoration: pw.BoxDecoration(
        borderRadius: pw.BorderRadius.circular(8),
        border: pw.Border.all(color: _borderLight, width: 0.6),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: [
          // Section title bar
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            color: PdfColors.white,
            child: pw.Row(
              children: [
                pw.Container(width: 3, height: 14, color: _brandGold),
                pw.SizedBox(width: 6),
                pw.Text(
                  'المنتجات المطلوبة',
                  style: pw.TextStyle(
                    fontSize: 10.5,
                    fontWeight: pw.FontWeight.bold,
                    color: _brandBlack,
                  ),
                ),
              ],
            ),
          ),
          // Table
          pw.TableHelper.fromTextArray(
            headers: const ['الإجمالي', 'سعر الوحدة', 'الكمية', 'المنتج'],
            data: rows,
            headerDecoration: pw.BoxDecoration(color: _brandBlack),
            headerStyle: pw.TextStyle(
              color: PdfColors.white,
              fontWeight: pw.FontWeight.bold,
              fontSize: 9.5,
            ),
            headerAlignment: pw.Alignment.centerRight,
            cellAlignment: pw.Alignment.centerRight,
            border: pw.TableBorder(
              horizontalInside: pw.BorderSide(color: _borderLight, width: 0.4),
            ),
            cellStyle: const pw.TextStyle(fontSize: 9.2),
            cellPadding: const pw.EdgeInsets.symmetric(
              horizontal: 6,
              vertical: 5,
            ),
            oddRowDecoration: pw.BoxDecoration(color: PdfColors.white),
            columnWidths: {
              0: const pw.FlexColumnWidth(1.3),
              1: const pw.FlexColumnWidth(1.3),
              2: const pw.FlexColumnWidth(0.6),
              3: const pw.FlexColumnWidth(2.8),
            },
          ),
        ],
      ),
    );
  }

  // ════════════════════════════════════════════════════════════
  //  TOTALS CARD
  // ════════════════════════════════════════════════════════════

  static pw.Widget _buildTotalsCard(Order order, {required String currency}) {
    final rows = <({String label, String value})>[
      (
        label: 'المجموع الفرعي',
        value: _money(order.subtotal, currency: currency),
      ),
      (label: 'الشحن', value: _money(order.shippingCost, currency: currency)),
    ];

    if ((order.discountTotal ?? 0) > 0) {
      rows.add((
        label: 'الخصم',
        value: _money(order.discountTotal ?? 0, currency: currency),
      ));
    }
    if ((order.tax ?? 0) > 0) {
      rows.add((
        label: 'الضريبة',
        value: _money(order.tax ?? 0, currency: currency),
      ));
    }

    return pw.Container(
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        color: PdfColors.white,
        borderRadius: pw.BorderRadius.circular(8),
        border: pw.Border.all(color: _borderLight, width: 0.6),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: [
          // Title
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 5),
            decoration: pw.BoxDecoration(
              color: PdfColors.white,
              borderRadius: pw.BorderRadius.circular(4),
              border: pw.Border(
                right: pw.BorderSide(color: _brandGold, width: 3),
              ),
            ),
            child: pw.Text(
              'الإجماليات',
              style: pw.TextStyle(
                fontSize: 10.5,
                fontWeight: pw.FontWeight.bold,
                color: _brandBlack,
              ),
            ),
          ),
          pw.SizedBox(height: 8),
          ...rows.map(
            (row) => pw.Padding(
              padding: const pw.EdgeInsets.symmetric(vertical: 3),
              child: pw.Row(
                children: [
                  pw.Text(
                    '${row.label}:',
                    style: const pw.TextStyle(
                      fontSize: 9.5,
                      color: _textSecondary,
                    ),
                  ),
                  pw.Spacer(),
                  pw.Text(
                    row.value,
                    style: const pw.TextStyle(
                      fontSize: 9.5,
                      color: PdfColors.black,
                    ),
                  ),
                ],
              ),
            ),
          ),
          pw.Container(height: 1.5, color: _brandGold),
          pw.SizedBox(height: 6),
          pw.Row(
            children: [
              pw.Text(
                'الإجمالي النهائي:',
                style: pw.TextStyle(
                  fontSize: 12,
                  fontWeight: pw.FontWeight.bold,
                  color: _brandBlack,
                ),
              ),
              pw.Spacer(),
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: pw.BoxDecoration(
                  color: _brandGold,
                  borderRadius: pw.BorderRadius.circular(6),
                ),
                child: pw.Text(
                  _money(order.total, currency: currency),
                  style: pw.TextStyle(
                    fontSize: 12.5,
                    fontWeight: pw.FontWeight.bold,
                    color: _brandBlack,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ════════════════════════════════════════════════════════════
  //  QR VERIFICATION CARD
  // ════════════════════════════════════════════════════════════

  static pw.Widget _buildQrCard(String verificationData) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        color: PdfColors.white,
        borderRadius: pw.BorderRadius.circular(8),
        border: pw.Border.all(color: _borderLight, width: 0.6),
      ),
      child: pw.Column(
        children: [
          pw.Text(
            'التحقق من الفاتورة',
            style: pw.TextStyle(
              fontSize: 9.5,
              fontWeight: pw.FontWeight.bold,
              color: _brandBlack,
            ),
          ),
          pw.SizedBox(height: 6),
          pw.Container(
            padding: const pw.EdgeInsets.all(6),
            decoration: pw.BoxDecoration(
              borderRadius: pw.BorderRadius.circular(6),
              border: pw.Border.all(color: _brandGold, width: 1),
            ),
            child: pw.BarcodeWidget(
              barcode: pw.Barcode.qrCode(),
              data: verificationData,
              width: 80,
              height: 80,
            ),
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            'امسح رمز QR للتحقق',
            style: const pw.TextStyle(fontSize: 7.5, color: _textSecondary),
          ),
        ],
      ),
    );
  }

  // ════════════════════════════════════════════════════════════
  //  FOOTER
  // ════════════════════════════════════════════════════════════

  static pw.Widget _footer() {
    return pw.Directionality(
      textDirection: pw.TextDirection.rtl,
      child: pw.Column(
        children: [
          pw.Container(height: 2, color: _brandGold),
          pw.SizedBox(height: 6),
          pw.Text(
            'هذه الفاتورة من متجر Lexi Mega Store وهي ليست بحاجة إلى توقيع لأنها موقعة إلكترونياً',
            textAlign: pw.TextAlign.center,
            style: const pw.TextStyle(fontSize: 8, color: _textSecondary),
          ),
        ],
      ),
    );
  }

  // ════════════════════════════════════════════════════════════
  //  LOGO LOADER
  // ════════════════════════════════════════════════════════════

  static Future<pw.MemoryImage?> _loadLogo() async {
    final candidates = <String>['assets/images/logo_long.jpg'];

    for (final path in candidates) {
      try {
        final bytes = await rootBundle.load(path);
        return pw.MemoryImage(bytes.buffer.asUint8List());
      } catch (_) {
        // Try next available logo asset.
      }
    }
    return null;
  }

  // ════════════════════════════════════════════════════════════
  //  HELPERS
  // ════════════════════════════════════════════════════════════

  static String _invoiceTitle(Order order, {String? invoiceType}) {
    final normalizedType = (invoiceType ?? '').trim().toLowerCase();
    switch (normalizedType) {
      case 'provisional':
      case 'proforma':
        return 'فاتورة مبدئية';
      case 'final':
        return 'فاتورة نهائية';
      default:
        return _canExportFinalInvoice(order.status)
            ? 'فاتورة نهائية'
            : 'فاتورة مبدئية';
    }
  }

  static String _statusLabel(String status) {
    switch (status.trim().toLowerCase()) {
      case 'completed':
      case 'delivered':
        return 'مكتمل';
      case 'processing':
        return 'قيد المعالجة';
      case 'pending-verification':
      case 'on-hold':
        return 'بانتظار التحقق';
      case 'pending':
        return 'قيد الانتظار';
      case 'out-for-delivery':
        return 'خرج للتسليم';
      case 'cancelled':
        return 'ملغي';
      case 'failed':
        return 'فشل';
      case 'refunded':
        return 'مسترجع';
      default:
        return status.trim().isEmpty ? 'غير معروف' : status.trim();
    }
  }

  static String _paymentLabel(PaymentMethod? method) {
    switch (method) {
      case PaymentMethod.cod:
        return 'عند الاستلام';
      case PaymentMethod.shamCash:
        return 'شام كاش';
      case null:
        return 'غير محدد';
    }
  }

  static String _currencyCode(Order order) {
    final raw = order.currency?.trim();
    if (raw == null || raw.isEmpty) {
      return 'SYP';
    }
    return raw.toUpperCase();
  }

  static String _money(num value, {required String currency}) {
    final formatted = NumberFormat.currency(
      locale: 'en_US',
      symbol: '',
      decimalDigits: 2,
    ).format(value);
    return '${formatted.trim()} $currency';
  }

  static _InvoiceCustomerInfo _customerInfo(Order order) {
    final billing = order.billing;
    final shipping = order.shipping;

    final name = billing?.fullName.trim().isNotEmpty == true
        ? billing!.fullName.trim()
        : (shipping?.fullName.trim().isNotEmpty == true
              ? shipping!.fullName.trim()
              : 'غير متوفر');

    final phone = billing?.phone.trim().isNotEmpty == true
        ? billing!.phone.trim()
        : (shipping?.phone.trim().isNotEmpty == true
              ? shipping!.phone.trim()
              : 'غير متوفر');

    final email = billing?.email.trim() ?? '';
    final address = billing?.fullAddress.trim().isNotEmpty == true
        ? billing!.fullAddress.trim()
        : (shipping?.fullAddress.trim().isNotEmpty == true
              ? shipping!.fullAddress.trim()
              : 'غير متوفر');

    return _InvoiceCustomerInfo(
      name: name,
      phone: phone,
      email: email,
      address: address,
    );
  }

  static String _displayOrderNumber(Order order) {
    final number = order.orderNumber.trim();
    if (number.isNotEmpty) {
      return number;
    }

    final id = order.id.trim();
    return id.isNotEmpty ? id : 'unknown';
  }

  static String _displayOrFallback(String value) {
    final normalized = value.trim();
    return normalized.isEmpty ? 'غير متوفر' : normalized;
  }

  static String _verificationData(Order order) {
    final url = _normalizeVerificationUrl(order.invoiceVerificationUrl);
    if (url.isNotEmpty) {
      return url;
    }

    return jsonEncode({
      'source': 'lexi',
      'order_id': order.id,
      'order_number': order.orderNumber,
      'total': order.total.toStringAsFixed(2),
      'date': order.date.toIso8601String(),
    });
  }

  static String _normalizeVerificationUrl(String raw) {
    final cleaned = raw
        .trim()
        .replaceAll('&amp;', '&')
        .replaceAll('&#38;', '&')
        .replaceAll(RegExp(r'\s+'), '');
    if (cleaned.isEmpty) {
      return '';
    }

    final uri = Uri.tryParse(cleaned);
    if (uri == null || !uri.hasScheme || !uri.hasAuthority) {
      return cleaned;
    }

    return uri.toString();
  }

  static bool _canExportFinalInvoice(String status) {
    final normalized = status.trim().toLowerCase();
    return normalized == 'completed' || normalized == 'processing';
  }
}

class _InvoiceCustomerInfo {
  final String name;
  final String phone;
  final String email;
  final String address;

  const _InvoiceCustomerInfo({
    required this.name,
    required this.phone,
    required this.email,
    required this.address,
  });
}
