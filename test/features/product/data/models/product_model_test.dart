import 'package:flutter_test/flutter_test.dart';
import 'package:lexi_mega_store/features/product/data/models/product_model.dart';

void main() {
  group('ProductModel.fromJson', () {
    test('parses standard contract fields with localized numeric strings', () {
      final model = ProductModel.fromJson({
        'id': 101,
        'name': 'Test Product',
        'price': '15,500',
        'regular_price': '17,500',
        'sale_price': '15,500',
        'rating_avg': 4.6,
        'rating_count': 12,
        'stock_status': 'instock',
        'in_stock': true,
        'images': [
          {
            'thumb': 'https://example.com/image-300x300.jpg',
            'medium': 'https://example.com/image-600x600.jpg',
            'large': 'https://example.com/image.jpg',
          },
        ],
      });

      expect(model.id, 101);
      expect(model.name, 'Test Product');
      expect(model.price, 15500);
      expect(model.regularPrice, 17500);
      expect(model.salePrice, 15500);
      expect(model.rating, 4.6);
      expect(model.reviewsCount, 12);
      expect(model.inStock, isTrue);
      expect(model.images, isNotEmpty);
      expect(model.cardImages, isNotEmpty);
      expect(model.image.thumb, contains('300x300'));
      expect(model.image.medium, contains('600x600'));
      expect(model.image.large, contains('image.jpg'));
    });

    test('falls back to range fields for variable products', () {
      final model = ProductModel.fromJson({
        'id': 202,
        'name': 'Variable Product',
        'price': null,
        'price_min': '11,000',
        'regular_min': '12,500',
        'sale_min': '11,000',
        'in_stock': 1,
      });

      expect(model.id, 202);
      expect(model.price, 11000);
      expect(model.regularPrice, 12500);
      expect(model.salePrice, 11000);
      expect(model.inStock, isTrue);
    });

    test('keeps model valid when price is missing', () {
      final model = ProductModel.fromJson({
        'id': 303,
        'name': 'No Price Product',
        'price': null,
        'regular_price': null,
        'sale_price': null,
        'stock_status': 'outofstock',
      });

      expect(model.id, 303);
      expect(model.price, 0);
      expect(model.regularPrice, 0);
      expect(model.salePrice, isNull);
      expect(model.inStock, isFalse);
    });

    test('falls back to a single image url when size map is missing', () {
      final model = ProductModel.fromJson({
        'id': 404,
        'name': 'Single Image Product',
        'price': 12000,
        'regular_price': 12000,
        'images': [
          {'src': 'https://example.com/original.jpg'},
        ],
      });

      expect(model.image.thumb, isNotNull);
      expect(model.image.medium, isNotNull);
      expect(model.image.large, isNotNull);
      expect(model.cardImages.first, contains('original.jpg'));
      expect(model.images.first, contains('original.jpg'));
    });
  });
}
