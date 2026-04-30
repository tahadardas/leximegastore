import 'package:flutter_test/flutter_test.dart';
import 'package:lexi_mega_store/features/categories/data/datasources/category_remote_datasource.dart';
import 'package:lexi_mega_store/features/categories/categories_screen.dart';
import 'package:lexi_mega_store/features/categories/domain/entities/category_entity.dart';

void main() {
  group('category display order', () {
    test('sorts child categories by the WordPress order index', () {
      final categories = <CategoryEntity>[
        const CategoryEntity(id: 10, name: 'الأب', parentId: 0),
        const CategoryEntity(
          id: 12,
          name: 'الثاني في ووردبريس',
          parentId: 10,
          sortOrder: 20,
        ),
        const CategoryEntity(
          id: 11,
          name: 'الأول في ووردبريس',
          parentId: 10,
          sortOrder: 10,
        ),
      ];

      final childrenMap = buildChildrenMap(categories);

      expect(childrenMap[10]!.map((category) => category.id), <int>[11, 12]);
    });

    test(
      'keeps categories missing from the WordPress page after page-ordered categories',
      () {
        final ordered = CategoryRemoteDatasource.orderCategoriesByPageSlugs(
          <Map<String, dynamic>>[
            {
              'id': 1,
              'name': 'أحبار وأختام',
              'slug': 'inks-and-seals',
              'parent': 0,
              'order_index': 0,
            },
            {
              'id': 2,
              'name': 'حقائب',
              'slug': 'bags',
              'parent': 0,
              'order_index': 1,
            },
            {
              'id': 3,
              'name': 'مدرسية',
              'slug': 'schools',
              'parent': 2,
              'order_index': 2,
            },
            {
              'id': 4,
              'name': 'قرطاسية',
              'slug': 'stationery',
              'parent': 0,
              'order_index': 3,
            },
            {
              'id': 5,
              'name': 'أدوات رياضة',
              'slug': 'sports-tools',
              'parent': 0,
              'order_index': 4,
            },
          ],
          <String>['bags', 'stationery'],
        );

        expect(
          ordered.whereType<Map<String, dynamic>>().map(
            (category) => category['id'],
          ),
          <int>[2, 3, 4, 1, 5],
        );
      },
    );
  });
}
