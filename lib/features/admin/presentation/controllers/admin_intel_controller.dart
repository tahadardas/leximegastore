import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/repositories/admin_intel_repository.dart';
import '../../domain/entities/admin_intel_stats.dart';

final adminIntelControllerProvider =
    AsyncNotifierProvider.autoDispose<AdminIntelController, AdminIntelStats>(
      AdminIntelController.new,
    );

class AdminIntelController extends AutoDisposeAsyncNotifier<AdminIntelStats> {
  Timer? _pollingTimer;

  @override
  FutureOr<AdminIntelStats> build() {
    ref.onDispose(() => _pollingTimer?.cancel());
    _startPolling();
    return _fetch();
  }

  void _startPolling() {
    _pollingTimer?.cancel();
    _pollingTimer = Timer.periodic(const Duration(seconds: 60), (_) {
      refresh(showLoading: false);
    });
  }

  Future<AdminIntelStats> _fetch({String range = 'today'}) {
    return ref.read(adminIntelRepositoryProvider).getOverview(range: range);
  }

  Future<void> refresh({String range = 'today', bool showLoading = true}) async {
    if (showLoading) {
      state = const AsyncLoading();
    }
    state = await AsyncValue.guard(() => _fetch(range: range));
  }
}
