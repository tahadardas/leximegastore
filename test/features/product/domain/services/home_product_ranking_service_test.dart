import 'package:flutter_test/flutter_test.dart';
import 'package:lexi_mega_store/features/product/domain/entities/product_entity.dart';
import 'package:lexi_mega_store/features/product/domain/services/home_product_ranking_service.dart';

void main() {
  group('HomeProductRankingService', () {
    const service = HomeProductRankingService();

    test('pins the newest 6 products at the top', () {
      final base = DateTime.utc(2026, 1, 1);
      final products = <ProductEntity>[
        for (var id = 1; id <= 10; id++)
          _product(
            id: id,
            createdAt: base.add(Duration(days: id)),
            salesCount: id == 1 ? 100000 : 10,
            rating: 4.5,
            viewsCount: 200,
            brandId: id,
            brandName: 'Brand $id',
          ),
      ];

      final ranked = service.rankProductsForHome(products, randomSeed: 42);
      final topIds = ranked.take(6).map((item) => item.id).toList();

      expect(topIds, <int>[10, 9, 8, 7, 6, 5]);
    });

    test(
      'enforces brand diversity for ranked remainder when alternatives exist',
      () {
        final now = DateTime.utc(2026, 3, 10);
        final products = <ProductEntity>[
          // Newest pinned slice.
          for (var id = 100; id >= 95; id--)
            _product(
              id: id,
              createdAt: now.add(Duration(days: id)),
              salesCount: 10,
              rating: 4,
              viewsCount: 100,
              brandId: id,
              brandName: 'Pinned $id',
            ),
          // Ranked remainder.
          _product(
            id: 1,
            createdAt: now.subtract(const Duration(days: 10)),
            salesCount: 1000,
            rating: 4.8,
            viewsCount: 1200,
            brandId: 1,
            brandName: 'A',
          ),
          _product(
            id: 2,
            createdAt: now.subtract(const Duration(days: 11)),
            salesCount: 950,
            rating: 4.7,
            viewsCount: 1100,
            brandId: 1,
            brandName: 'A',
          ),
          _product(
            id: 3,
            createdAt: now.subtract(const Duration(days: 12)),
            salesCount: 900,
            rating: 4.6,
            viewsCount: 1000,
            brandId: 2,
            brandName: 'B',
          ),
          _product(
            id: 4,
            createdAt: now.subtract(const Duration(days: 13)),
            salesCount: 850,
            rating: 4.5,
            viewsCount: 900,
            brandId: 2,
            brandName: 'B',
          ),
          _product(
            id: 5,
            createdAt: now.subtract(const Duration(days: 14)),
            salesCount: 800,
            rating: 4.4,
            viewsCount: 800,
            brandId: 3,
            brandName: 'C',
          ),
          _product(
            id: 6,
            createdAt: now.subtract(const Duration(days: 15)),
            salesCount: 750,
            rating: 4.3,
            viewsCount: 700,
            brandId: 3,
            brandName: 'C',
          ),
        ];

        final ranked = service.rankProductsForHome(products, randomSeed: 99);
        final remainderBrands = ranked
            .skip(6)
            .map((item) => '${item.brandId}:${item.brandName}')
            .toList(growable: false);

        for (var i = 1; i < remainderBrands.length; i++) {
          final current = remainderBrands[i];
          final previous = remainderBrands[i - 1];
          if (current != previous) {
            continue;
          }
          final hasAlternativeLater = remainderBrands
              .skip(i)
              .any((brand) => brand != current);
          expect(hasAlternativeLater, isFalse);
        }
      },
    );

    test(
      'is deterministic with the same seed and can vary with another seed',
      () {
        final now = DateTime.utc(2026, 3, 1);
        final products = <ProductEntity>[
          for (var id = 1; id <= 14; id++)
            _product(
              id: id,
              createdAt: id > 8
                  ? now.add(Duration(days: id))
                  : now.subtract(const Duration(days: 30)),
              salesCount: id > 8 ? 200 : 100,
              rating: id > 8 ? 4.5 : 4.0,
              viewsCount: id > 8 ? 400 : 150,
              brandId: id,
              brandName: 'Brand $id',
            ),
        ];

        final rankedA1 = service.rankProductsForHome(
          products,
          randomSeed: 2026,
        );
        final rankedA2 = service.rankProductsForHome(
          products,
          randomSeed: 2026,
        );
        final rankedB = service.rankProductsForHome(products, randomSeed: 2027);

        final idsA1 = rankedA1.map((item) => item.id).toList(growable: false);
        final idsA2 = rankedA2.map((item) => item.id).toList(growable: false);
        final idsB = rankedB.map((item) => item.id).toList(growable: false);

        expect(idsA1, idsA2);
        expect(idsA1.skip(6).toList(), isNot(equals(idsB.skip(6).toList())));
      },
    );

    test('supports home mode without pinning newest products', () {
      final now = DateTime.utc(2026, 3, 1);
      final products = <ProductEntity>[
        _product(
          id: 1,
          createdAt: now.subtract(const Duration(days: 40)),
          salesCount: 5000,
          rating: 4.9,
          viewsCount: 4000,
          brandId: 1,
          brandName: 'Legacy',
        ),
        for (var id = 2; id <= 12; id++)
          _product(
            id: id,
            createdAt: now.add(Duration(days: id)),
            salesCount: 50,
            rating: 3.8,
            viewsCount: 120,
            brandId: id,
            brandName: 'Brand $id',
          ),
      ];

      final ranked = service.rankProductsForHome(
        products,
        options: const HomeProductRankingOptions(
          newestPinnedCount: 0,
          randomJitter: 0,
        ),
        randomSeed: 11,
      );

      expect(ranked.first.id, 1);
    });

    test('uses category diversity when brand data is missing', () {
      final now = DateTime.utc(2026, 3, 5);
      final products = <ProductEntity>[
        _product(
          id: 1,
          createdAt: now.subtract(const Duration(days: 1)),
          salesCount: 1000,
          rating: 4.8,
          viewsCount: 900,
          categoryIds: const [10],
        ),
        _product(
          id: 2,
          createdAt: now.subtract(const Duration(days: 2)),
          salesCount: 990,
          rating: 4.7,
          viewsCount: 850,
          categoryIds: const [10],
        ),
        _product(
          id: 3,
          createdAt: now.subtract(const Duration(days: 3)),
          salesCount: 980,
          rating: 4.6,
          viewsCount: 800,
          categoryIds: const [20],
        ),
        _product(
          id: 4,
          createdAt: now.subtract(const Duration(days: 4)),
          salesCount: 970,
          rating: 4.5,
          viewsCount: 750,
          categoryIds: const [20],
        ),
      ];

      final ranked = service.rankProductsForHome(
        products,
        options: const HomeProductRankingOptions(
          newestPinnedCount: 0,
          randomJitter: 0,
        ),
        randomSeed: 7,
      );
      final categories = ranked
          .map(
            (item) => item.categoryIds.isNotEmpty ? item.categoryIds.first : -1,
          )
          .toList(growable: false);

      for (var i = 1; i < categories.length; i++) {
        final sameAsPrevious = categories[i] == categories[i - 1];
        if (!sameAsPrevious) {
          continue;
        }
        final hasAlternativeLater = categories
            .skip(i)
            .any((category) => category != categories[i]);
        expect(hasAlternativeLater, isFalse);
      }
    });

    test('prefers category diversity when brand diversity is impossible', () {
      final now = DateTime.utc(2026, 3, 6);
      final products = <ProductEntity>[
        _product(
          id: 11,
          createdAt: now.subtract(const Duration(days: 1)),
          salesCount: 1000,
          rating: 4.8,
          viewsCount: 900,
          brandId: 547,
          brandName: 'Same Brand',
          categoryIds: const [61],
        ),
        _product(
          id: 12,
          createdAt: now.subtract(const Duration(days: 2)),
          salesCount: 990,
          rating: 4.7,
          viewsCount: 850,
          brandId: 547,
          brandName: 'Same Brand',
          categoryIds: const [61],
        ),
        _product(
          id: 13,
          createdAt: now.subtract(const Duration(days: 3)),
          salesCount: 980,
          rating: 4.6,
          viewsCount: 840,
          brandId: 547,
          brandName: 'Same Brand',
          categoryIds: const [62],
        ),
        _product(
          id: 14,
          createdAt: now.subtract(const Duration(days: 4)),
          salesCount: 970,
          rating: 4.5,
          viewsCount: 830,
          brandId: 547,
          brandName: 'Same Brand',
          categoryIds: const [62],
        ),
        _product(
          id: 15,
          createdAt: now.subtract(const Duration(days: 5)),
          salesCount: 960,
          rating: 4.4,
          viewsCount: 820,
          brandId: 547,
          brandName: 'Same Brand',
          categoryIds: const [63],
        ),
      ];

      final ranked = service.rankProductsForHome(
        products,
        options: const HomeProductRankingOptions(
          newestPinnedCount: 0,
          randomJitter: 0,
        ),
        randomSeed: 17,
      );

      final categories = ranked
          .map(
            (item) => item.categoryIds.isNotEmpty ? item.categoryIds.first : -1,
          )
          .toList(growable: false);

      for (var i = 1; i < categories.length; i++) {
        final sameAsPrevious = categories[i] == categories[i - 1];
        if (!sameAsPrevious) {
          continue;
        }
        final hasAlternativeLater = categories
            .skip(i)
            .any((category) => category != categories[i]);
        expect(hasAlternativeLater, isFalse);
      }
    });
  });
}

ProductEntity _product({
  required int id,
  required DateTime createdAt,
  required int salesCount,
  required double rating,
  required int viewsCount,
  int? brandId,
  String brandName = '',
  List<int> categoryIds = const <int>[],
}) {
  return ProductEntity(
    id: id,
    name: 'Product $id',
    price: 100,
    regularPrice: 100,
    rating: rating,
    reviewsCount: 10,
    inStock: true,
    createdAt: createdAt,
    salesCount: salesCount,
    viewsCount: viewsCount,
    brandId: brandId,
    brandName: brandName,
    categoryIds: categoryIds,
  );
}
