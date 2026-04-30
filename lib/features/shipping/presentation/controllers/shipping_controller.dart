import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/shipping_repository_impl.dart';
import '../../domain/entities/city.dart';
import '../../domain/usecases/shipping_usecases.dart';

// ?"??"? UseCases ?"??"?
final getCitiesUseCaseProvider = Provider<GetCities>((ref) {
  return GetCities(ref.watch(shippingRepositoryProvider));
});

final getShippingRateUseCaseProvider = Provider<GetShippingRate>((ref) {
  return GetShippingRate(ref.watch(shippingRepositoryProvider));
});

// ?"??"? State ?"??"?

/// Fetches list of available cities
final citiesProvider = FutureProvider<List<City>>((ref) {
  return ref.watch(getCitiesUseCaseProvider).call();
});

/// Holds the currently selected city (null if none selected)
final selectedCityProvider = StateProvider<City?>((ref) => null);

/// Calculates shipping cost based on selected city (async)
final shippingCostProvider = FutureProvider.autoDispose<double>((ref) async {
  final city = ref.watch(selectedCityProvider);
  if (city == null) return 0.0;

  try {
    // Fetch rate from API
    return await ref.watch(getShippingRateUseCaseProvider).call(city.id);
  } catch (e) {
    // Fallback to local price if available
    if (city.price > 0) return city.price;
    // Otherwise propagate error
    rethrow;
  }
});
