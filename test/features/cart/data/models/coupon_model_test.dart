import 'package:flutter_test/flutter_test.dart';
import 'package:lexi_mega_store/features/cart/data/models/coupon_model.dart';

void main() {
  group('CouponModel.fromJson', () {
    test('parses flat payload', () {
      final coupon = CouponModel.fromJson({
        'code': 'SAVE10',
        'valid': true,
        'discount_amount': 1500,
        'discount_type': 'fixed_cart',
        'message': 'تم التطبيق',
        'description': 'خصم تجريبي',
      });

      expect(coupon.code, 'SAVE10');
      expect(coupon.isValid, isTrue);
      expect(coupon.discountAmount, 1500);
      expect(coupon.discountType, 'fixed_cart');
      expect(coupon.message, 'تم التطبيق');
      expect(coupon.description, 'خصم تجريبي');
    });

    test('parses success envelope payload', () {
      final coupon = CouponModel.fromJson({
        'success': true,
        'data': {
          'code': 'PERCENT20',
          'valid': 'true',
          'discount_amount': '2000',
          'discount_type': 'percent',
        },
      });

      expect(coupon.code, 'PERCENT20');
      expect(coupon.isValid, isTrue);
      expect(coupon.discountAmount, 2000);
      expect(coupon.discountType, 'percent');
      expect(coupon.message, isNotEmpty);
    });

    test('defaults validity from discount when valid flag is missing', () {
      final validCoupon = CouponModel.fromJson({
        'code': 'AUTO1',
        'discount_amount': '500',
      });
      final invalidCoupon = CouponModel.fromJson({
        'code': 'AUTO0',
        'discount_amount': '0',
      });

      expect(validCoupon.isValid, isTrue);
      expect(invalidCoupon.isValid, isFalse);
    });
  });
}
