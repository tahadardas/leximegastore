import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/repositories/admin_dashboard_repository.dart';
import '../../domain/entities/admin_dashboard_stats.dart';

final adminDashboardControllerProvider =
    AsyncNotifierProvider.autoDispose<
      AdminDashboardController,
      AdminDashboardStats
    >(AdminDashboardController.new);

class AdminDashboardController
    extends AutoDisposeAsyncNotifier<AdminDashboardStats> {
  Timer? _pollingTimer;

  @override
  FutureOr<AdminDashboardStats> build() {
    ref.onDispose(() => _pollingTimer?.cancel());
    _startPolling();
    return _fetchStats();
  }

  void _startPolling() {
    _pollingTimer?.cancel();
    _pollingTimer = Timer.periodic(const Duration(seconds: 60), (_) {
      refresh(showLoading: false);
    });
  }

  Future<AdminDashboardStats> _fetchStats() async {
    final repository = ref.read(adminDashboardRepositoryProvider);
    return repository.getStats();
  }

  Future<void> refresh({bool showLoading = true}) async {
    if (showLoading) {
      state = const AsyncLoading();
    }
    state = await AsyncValue.guard(() => _fetchStats());
  }
}

