import 'package:flutter_test/flutter_test.dart';
import 'package:lexi_mega_store/features/orders/presentation/pages/invoice_viewer_page.dart';

void main() {
  test('InvoiceViewerPage keeps provisional invoice as default type', () {
    const page = InvoiceViewerPage(orderId: '1001');

    expect(page.orderId, '1001');
    expect(page.type, 'provisional');
    expect(page.phone, isNull);
  });
}
