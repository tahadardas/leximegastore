import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/repositories/admin_shipping_repository.dart';
import '../../domain/entities/admin_shipping_city.dart';

final adminShippingControllerProvider =
    AsyncNotifierProvider<AdminShippingController, List<AdminShippingCity>>(() {
      return AdminShippingController();
    });

class AdminShippingController extends AsyncNotifier<List<AdminShippingCity>> {
  @override
  FutureOr<List<AdminShippingCity>> build() {
    return _fetchCities();
  }

  Future<List<AdminShippingCity>> _fetchCities() async {
    final repository = ref.read(adminShippingRepositoryProvider);
    return repository.getCities();
  }

  Future<void> createCity({
    required String name,
    required double price,
    bool isActive = true,
    int sortOrder = 0,
  }) async {
    final repository = ref.read(adminShippingRepositoryProvider);
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      await repository.createCity(
        name: name,
        price: price,
        isActive: isActive,
        sortOrder: sortOrder,
      );
      return _fetchCities();
    });
  }

  Future<void> updateCity(
    int id, {
    String? name,
    double? price,
    bool? isActive,
    int? sortOrder,
  }) async {
    final repository = ref.read(adminShippingRepositoryProvider);
    // Optimistic update could be done here, but simpler to reload for now
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      await repository.updateCity(
        id,
        name: name,
        price: price,
        isActive: isActive,
        sortOrder: sortOrder,
      );
      return _fetchCities();
    });
  }

  Future<void> deleteCity(int id) async {
    final repository = ref.read(adminShippingRepositoryProvider);
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      await repository.deleteCity(id);
      return _fetchCities();
    });
  }
}
