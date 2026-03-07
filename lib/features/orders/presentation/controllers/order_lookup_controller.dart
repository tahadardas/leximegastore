import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/order_repository_impl.dart';
import '../../domain/entities/order_track.dart';

final trackOrderControllerProvider =
    AutoDisposeAsyncNotifierProvider<TrackOrderNotifier, OrderTrackInfo?>(
      TrackOrderNotifier.new,
    );

class TrackOrderNotifier extends AutoDisposeAsyncNotifier<OrderTrackInfo?> {
  @override
  Future<OrderTrackInfo?> build() async {
    return null;
  }

  Future<void> track({required String orderNumber, String? verifier}) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final repo = ref.read(orderRepositoryProvider);
      return repo.trackOrderByNumber(orderNumber: orderNumber, verifier: verifier);
    });
  }
}
