class ShamCashInvoice {
  final String orderId;
  final double amount;
  final String currency;
  final String barcodeValue;
  final String qrValue;
  final DateTime expiresAt;

  const ShamCashInvoice({
    required this.orderId,
    required this.amount,
    required this.currency,
    required this.barcodeValue,
    required this.qrValue,
    required this.expiresAt,
  });

  factory ShamCashInvoice.fromJson(Map<String, dynamic> json) {
    return ShamCashInvoice(
      orderId: json['order_id'] as String,
      amount: (json['amount'] as num).toDouble(),
      currency: json['currency'] as String,
      barcodeValue: json['barcode_value'] as String,
      qrValue: json['qr_value'] as String,
      expiresAt: DateTime.parse(json['expires_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'order_id': orderId,
      'amount': amount,
      'currency': currency,
      'barcode_value': barcodeValue,
      'qr_value': qrValue,
      'expires_at': expiresAt.toIso8601String(),
    };
  }
}
