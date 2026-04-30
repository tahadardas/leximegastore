import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/product_entity.dart';
import '../../domain/usecases/get_product.dart';
import 'products_controller.dart'; // To access productRepositoryProvider

// Use Case Provider
final getProductUseCaseProvider = Provider<GetProduct>((ref) {
  return GetProduct(repository: ref.watch(productRepositoryProvider));
});

// Controller Family
final productDetailsControllerProvider = FutureProvider.family
    .autoDispose<ProductEntity, String>((ref, id) {
      final link = ref.keepAlive();
      final timer = Timer(const Duration(minutes: 3), link.close);
      ref.onDispose(timer.cancel);
      final getProduct = ref.watch(getProductUseCaseProvider);
      return getProduct(id);
    });
