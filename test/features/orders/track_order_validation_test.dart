import 'package:flutter_test/flutter_test.dart';

void main() {
  String digitsOnly(String raw) => raw.replaceAll(RegExp(r'[^0-9]'), '');

  test('Order number normalization accepts #12345 and returns digits', () {
    expect(digitsOnly('#12345'), '12345');
    expect(digitsOnly('  12345 '), '12345');
  });

  test('Order number validation rejects too short or too long', () {
    bool isValid(String raw) {
      final digits = digitsOnly(raw);
      return digits.length >= 3 && digits.length <= 12;
    }

    expect(isValid('12'), isFalse);
    expect(isValid('123'), isTrue);
    expect(isValid('123456789012'), isTrue);
    expect(isValid('1234567890123'), isFalse);
  });
}
