import 'package:flutter_test/flutter_test.dart';
import 'package:lexi_mega_store/features/categories/data/models/category_model.dart';

void main() {
  group('CategoryModel.fromJson', () {
    test('uses categories page order before other order fields', () {
      final model = CategoryModel.fromJson({
        'id': 11,
        'name': 'Bags',
        'sort_order': 99,
        'admin_order_index': 12,
        'categories_page_order_index': 0,
      });

      expect(model.sortOrder, 0);
    });

    test('uses WordPress admin order index before legacy sort_order', () {
      final model = CategoryModel.fromJson({
        'id': 12,
        'name': 'Bags',
        'sort_order': 99,
        'admin_order_index': 3,
      });

      expect(model.sortOrder, 3);
    });

    test('uses generic order index when admin order index is missing', () {
      final model = CategoryModel.fromJson({
        'id': 14,
        'name': 'Bags',
        'sort_order': 99,
        'order_index': 4,
      });

      expect(model.sortOrder, 4);
    });

    test(
      'falls back to legacy sort_order when admin order index is missing',
      () {
        final model = CategoryModel.fromJson({
          'id': 13,
          'name': 'School',
          'sort_order': 7,
        });

        expect(model.sortOrder, 7);
      },
    );

    test('parses WooCommerce Store API category payloads', () {
      final model = CategoryModel.fromJson({
        'id': 795,
        'name': 'أقلام تأشير',
        'slug': 'highlighters',
        'parent': 791,
        'count': 27,
        'image': {'src': 'https://example.com/category.jpg'},
      });

      expect(model.id, 795);
      expect(model.name, 'أقلام تأشير');
      expect(model.parentId, 791);
      expect(model.count, 27);
      expect(model.image, 'https://example.com/category.jpg');
    });
  });
}
