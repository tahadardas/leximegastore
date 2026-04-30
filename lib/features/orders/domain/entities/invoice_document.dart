import 'order.dart';

class InvoiceDocument {
  final dynamic content;
  final Order? order;
  final String invoiceType;
  final String invoiceUrl;
  final String verificationUrl;

  const InvoiceDocument({
    required this.content,
    this.order,
    this.invoiceType = '',
    this.invoiceUrl = '',
    this.verificationUrl = '',
  });
}
