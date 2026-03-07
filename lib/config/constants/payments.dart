/// ShamCash payment gateway configuration.
///
/// These values are fetched from the WordPress backend via the Lexi API
/// settings endpoint. The defaults below are fallbacks only.
class ShamCashConfig {
  static const String displayNameArabic = 'شام كاش';

  /// Merchant display name shown on payment screen.
  static const String accountName = 'متجر ليكسي ميجا';

  /// Static QR code value for ShamCash payment scanning.
  static const String qrValue = 'shamcash://pay?account=lexi-store';

  /// Barcode value for ShamCash payment scanning.
  static const String barcodeValue = 'LEXI-STORE-001';

  static const String notesHint = 'اكتب رقم الطلب هنا...';
}
