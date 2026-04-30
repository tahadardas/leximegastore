import '../entities/product_entity.dart';

/// Ranking configuration for the home products feed.
class HomeProductRankingOptions {
  final int newestPinnedCount;
  final int maxSameBrandConsecutive;
  final int maxSameCategoryConsecutive;
  final double salesWeight;
  final double ratingWeight;
  final double viewsWeight;
  final double recencyBoostWeight;
  final double randomJitter;

  const HomeProductRankingOptions({
    this.newestPinnedCount = 6,
    this.maxSameBrandConsecutive = 1,
    this.maxSameCategoryConsecutive = 1,
    this.salesWeight = 0.45,
    this.ratingWeight = 0.30,
    this.viewsWeight = 0.20,
    this.recencyBoostWeight = 0.05,
    this.randomJitter = 0.03,
  });
}

/// Builds a ranked home list while preserving deterministic behavior when needed.
///
/// Flow:
/// 1) sort by `createdAt` descending and pin newest products,
/// 2) score the remaining products,
/// 3) add slight deterministic jitter,
/// 4) enforce brand/category diversity.
class HomeProductRankingService {
  const HomeProductRankingService();

  List<ProductEntity> rankProductsForHome(
    List<ProductEntity> products, {
    HomeProductRankingOptions options = const HomeProductRankingOptions(),
    int? randomSeed,
  }) {
    if (products.length <= 1) {
      return List<ProductEntity>.from(products, growable: false);
    }

    final deduped = _dedupeById(products);
    final newestFirst = [...deduped]..sort(_compareByCreatedAtDesc);
    final pinCount = options.newestPinnedCount.clamp(0, newestFirst.length);
    final pinnedNewest = newestFirst.take(pinCount).toList(growable: false);

    if (pinCount >= newestFirst.length) {
      return pinnedNewest;
    }

    final remainder = newestFirst.sublist(pinCount);
    final effectiveSeed = randomSeed ?? _defaultSeed();
    final scored = _scoreRemainder(
      remainder,
      options: options,
      randomSeed: effectiveSeed,
    )..sort((a, b) => _compareScoredDesc(a, b));

    final diversified = _enforceDiversity(
      scored,
      maxSameBrandConsecutive: options.maxSameBrandConsecutive,
      maxSameCategoryConsecutive: options.maxSameCategoryConsecutive,
    );

    return [
      ...pinnedNewest,
      ...diversified.map((item) => item.product),
    ].toList(growable: false);
  }

  List<ProductEntity> _dedupeById(List<ProductEntity> products) {
    final seen = <int>{};
    final output = <ProductEntity>[];
    for (final product in products) {
      if (seen.add(product.id)) {
        output.add(product);
      }
    }
    return output;
  }

  int _compareByCreatedAtDesc(ProductEntity a, ProductEntity b) {
    final createdCmp = _createdAtOrFallback(
      b,
    ).compareTo(_createdAtOrFallback(a));
    if (createdCmp != 0) {
      return createdCmp;
    }
    return b.id.compareTo(a.id);
  }

  List<_ScoredProduct> _scoreRemainder(
    List<ProductEntity> products, {
    required HomeProductRankingOptions options,
    required int randomSeed,
  }) {
    final salesStats = _NormalizationStats.from(
      products.map((item) => item.salesCount.toDouble()),
    );
    final ratingStats = _NormalizationStats.from(
      products.map((item) => item.rating),
    );
    final viewsStats = _NormalizationStats.from(
      products.map((item) => item.viewsCount.toDouble()),
    );
    final recencyStats = _NormalizationStats.from(
      products
          .map(_createdAtOrFallback)
          .map((date) => date.millisecondsSinceEpoch.toDouble()),
    );

    return products
        .map((product) {
          final normalizedSales = salesStats.normalize(
            _nonNegative(product.salesCount.toDouble()),
          );
          final normalizedRating = ratingStats.normalize(
            _nonNegative(product.rating),
          );
          final normalizedViews = viewsStats.normalize(
            _nonNegative(product.viewsCount.toDouble()),
          );
          final normalizedRecency = recencyStats.normalize(
            _createdAtOrFallback(product).millisecondsSinceEpoch.toDouble(),
          );

          final baseScore =
              (normalizedSales * options.salesWeight) +
              (normalizedRating * options.ratingWeight) +
              (normalizedViews * options.viewsWeight) +
              (normalizedRecency * options.recencyBoostWeight);

          final jitter =
              ((_stableUnitNoise(productId: product.id, seed: randomSeed) * 2) -
                  1) *
              options.randomJitter;

          return _ScoredProduct(
            product: product,
            brandKey: _brandKeyOf(product),
            categoryKey: _categoryKeyOf(product),
            createdAt: _createdAtOrFallback(product),
            score: baseScore + jitter,
          );
        })
        .toList(growable: false);
  }

  List<_ScoredProduct> _enforceDiversity(
    List<_ScoredProduct> scored, {
    required int maxSameBrandConsecutive,
    required int maxSameCategoryConsecutive,
  }) {
    if (scored.length <= 1) {
      return scored;
    }

    final heap = _BinaryMaxHeap<_ScoredProduct>(_compareScoredPriority);
    for (final item in scored) {
      heap.add(item);
    }

    final output = <_ScoredProduct>[];
    String? previousBrand;
    String? previousCategory;
    var brandConsecutiveCount = 0;
    var categoryConsecutiveCount = 0;
    const diversityLookAhead = 24;

    while (heap.isNotEmpty) {
      final held = <_ScoredProduct>[];
      _ScoredProduct? chosen;
      _ScoredProduct? bestFallback;
      var bestFallbackIndex = -1;
      var bestFallbackPenalty = 1 << 30;
      var inspected = 0;

      while (heap.isNotEmpty && inspected < diversityLookAhead) {
        inspected++;
        final candidate = heap.removeFirst();
        final penalty = _diversityPenalty(
          candidate: candidate,
          previousBrand: previousBrand,
          previousCategory: previousCategory,
          brandConsecutiveCount: brandConsecutiveCount,
          categoryConsecutiveCount: categoryConsecutiveCount,
          maxSameBrandConsecutive: maxSameBrandConsecutive,
          maxSameCategoryConsecutive: maxSameCategoryConsecutive,
        );

        if (penalty == 0) {
          chosen = candidate;
          break;
        }

        held.add(candidate);
        if (bestFallback == null ||
            penalty < bestFallbackPenalty ||
            (penalty == bestFallbackPenalty &&
                _compareScoredPriority(candidate, bestFallback) > 0)) {
          bestFallback = candidate;
          bestFallbackPenalty = penalty;
          bestFallbackIndex = held.length - 1;
        }
      }

      if (chosen == null) {
        if (held.isEmpty) {
          chosen = heap.removeFirst();
        } else if (bestFallbackIndex >= 0) {
          chosen = held.removeAt(bestFallbackIndex);
        } else {
          chosen = held.removeAt(0);
        }
      }

      for (final item in held) {
        heap.add(item);
      }

      output.add(chosen);
      if (previousBrand == chosen.brandKey) {
        brandConsecutiveCount++;
      } else {
        previousBrand = chosen.brandKey;
        brandConsecutiveCount = 1;
      }

      if (previousCategory == chosen.categoryKey) {
        categoryConsecutiveCount++;
      } else {
        previousCategory = chosen.categoryKey;
        categoryConsecutiveCount = 1;
      }
    }

    return output;
  }

  int _diversityPenalty({
    required _ScoredProduct candidate,
    required String? previousBrand,
    required String? previousCategory,
    required int brandConsecutiveCount,
    required int categoryConsecutiveCount,
    required int maxSameBrandConsecutive,
    required int maxSameCategoryConsecutive,
  }) {
    var penalty = 0;

    final violatesBrand =
        maxSameBrandConsecutive > 0 &&
        previousBrand == candidate.brandKey &&
        brandConsecutiveCount >= maxSameBrandConsecutive;
    if (violatesBrand) {
      // Brand diversity is stricter than category diversity.
      penalty += 2;
    }

    final violatesCategory =
        maxSameCategoryConsecutive > 0 &&
        previousCategory == candidate.categoryKey &&
        categoryConsecutiveCount >= maxSameCategoryConsecutive;
    if (violatesCategory) {
      penalty++;
    }

    return penalty;
  }

  int _compareScoredDesc(_ScoredProduct a, _ScoredProduct b) {
    final scoreCmp = b.score.compareTo(a.score);
    if (scoreCmp != 0) {
      return scoreCmp;
    }
    final dateCmp = b.createdAt.compareTo(a.createdAt);
    if (dateCmp != 0) {
      return dateCmp;
    }
    return b.product.id.compareTo(a.product.id);
  }

  int _compareScoredPriority(_ScoredProduct a, _ScoredProduct b) {
    final scoreCmp = a.score.compareTo(b.score);
    if (scoreCmp != 0) {
      return scoreCmp;
    }
    final dateCmp = a.createdAt.compareTo(b.createdAt);
    if (dateCmp != 0) {
      return dateCmp;
    }
    return a.product.id.compareTo(b.product.id);
  }

  DateTime _createdAtOrFallback(ProductEntity product) {
    final created = product.createdAt?.toUtc();
    if (created != null) {
      return created;
    }
    // Fallback keeps ordering deterministic even when backend omits created_at.
    return DateTime.fromMillisecondsSinceEpoch(product.id * 1000, isUtc: true);
  }

  String _brandKeyOf(ProductEntity product) {
    final brandId = product.brandId;
    if (brandId != null && brandId > 0) {
      return 'id:$brandId';
    }

    final brandName = product.brandName.trim().toLowerCase();
    if (brandName.isNotEmpty) {
      return 'name:$brandName';
    }

    // Unknown brands are treated as unique buckets to avoid artificial caps.
    return 'unknown:${product.id}';
  }

  String _categoryKeyOf(ProductEntity product) {
    if (product.categoryIds.isNotEmpty) {
      // Prefer the most specific category when multiple ids are provided.
      for (var i = product.categoryIds.length - 1; i >= 0; i--) {
        final categoryId = product.categoryIds[i];
        if (categoryId > 0) {
          return 'cat:$categoryId';
        }
      }
    }
    return 'unknown-cat:${product.id}';
  }

  int _defaultSeed() {
    final now = DateTime.now().toUtc();
    return now.year * 10000 + now.month * 100 + now.day;
  }

  double _stableUnitNoise({required int productId, required int seed}) {
    var value = seed ^ (productId * 0x9E3779B9);
    value = (value ^ (value >> 16)) * 0x7feb352d;
    value = (value ^ (value >> 15)) * 0x846ca68b;
    value = value ^ (value >> 16);
    final positive = value & 0x7fffffff;
    return positive / 0x7fffffff;
  }

  double _nonNegative(double value) {
    if (!value.isFinite || value < 0) {
      return 0;
    }
    return value;
  }
}

class _ScoredProduct {
  final ProductEntity product;
  final String brandKey;
  final String categoryKey;
  final DateTime createdAt;
  final double score;

  const _ScoredProduct({
    required this.product,
    required this.brandKey,
    required this.categoryKey,
    required this.createdAt,
    required this.score,
  });
}

class _NormalizationStats {
  final double min;
  final double max;

  const _NormalizationStats({required this.min, required this.max});

  factory _NormalizationStats.from(Iterable<double> values) {
    var min = 0.0;
    var max = 0.0;
    var hasValue = false;

    for (final raw in values) {
      final value = raw.isFinite ? raw : 0.0;
      if (!hasValue) {
        min = value;
        max = value;
        hasValue = true;
        continue;
      }
      if (value < min) {
        min = value;
      }
      if (value > max) {
        max = value;
      }
    }

    if (!hasValue) {
      return const _NormalizationStats(min: 0.0, max: 0.0);
    }

    return _NormalizationStats(min: min, max: max);
  }

  double normalize(double value) {
    if (!value.isFinite) {
      return 0;
    }

    final range = max - min;
    if (range.abs() < 1e-9) {
      return 0.5;
    }

    final normalized = (value - min) / range;
    if (normalized < 0) {
      return 0;
    }
    if (normalized > 1) {
      return 1;
    }
    return normalized;
  }
}

class _BinaryMaxHeap<T> {
  final int Function(T a, T b) _compare;
  final List<T> _nodes = <T>[];

  _BinaryMaxHeap(this._compare);

  bool get isNotEmpty => _nodes.isNotEmpty;

  void add(T value) {
    _nodes.add(value);
    _siftUp(_nodes.length - 1);
  }

  T removeFirst() {
    final first = _nodes.first;
    final last = _nodes.removeLast();
    if (_nodes.isNotEmpty) {
      _nodes[0] = last;
      _siftDown(0);
    }
    return first;
  }

  void _siftUp(int index) {
    var child = index;
    while (child > 0) {
      final parent = (child - 1) ~/ 2;
      if (_compare(_nodes[child], _nodes[parent]) <= 0) {
        break;
      }
      final temp = _nodes[parent];
      _nodes[parent] = _nodes[child];
      _nodes[child] = temp;
      child = parent;
    }
  }

  void _siftDown(int index) {
    var parent = index;
    final length = _nodes.length;

    while (true) {
      final left = parent * 2 + 1;
      final right = left + 1;
      var largest = parent;

      if (left < length && _compare(_nodes[left], _nodes[largest]) > 0) {
        largest = left;
      }
      if (right < length && _compare(_nodes[right], _nodes[largest]) > 0) {
        largest = right;
      }
      if (largest == parent) {
        break;
      }

      final temp = _nodes[parent];
      _nodes[parent] = _nodes[largest];
      _nodes[largest] = temp;
      parent = largest;
    }
  }
}
