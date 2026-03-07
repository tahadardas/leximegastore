import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/admin_orders_repository.dart';
import '../../domain/entities/admin_courier_report.dart';
import '../../domain/entities/admin_courier_assignment.dart';

final adminCourierReportsControllerProvider =
    AsyncNotifierProvider.autoDispose<
      AdminCourierReportsController,
      AdminCouriersReportResponse
    >(AdminCourierReportsController.new);

class AdminCourierReportsController
    extends AutoDisposeAsyncNotifier<AdminCouriersReportResponse> {
  DateTime _selectedDate = DateTime.now();
  int? _selectedCourierId;

  DateTime get selectedDate => _selectedDate;
  int? get selectedCourierId => _selectedCourierId;

  @override
  FutureOr<AdminCouriersReportResponse> build() {
    return _load();
  }

  Future<AdminCouriersReportResponse> _load() {
    return ref
        .read(adminOrdersRepositoryProvider)
        .getCouriersReport(date: _selectedDate, courierId: _selectedCourierId);
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(_load);
  }

  Future<void> setDate(DateTime date) async {
    final normalized = DateTime(date.year, date.month, date.day);
    if (normalized ==
        DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day)) {
      return;
    }
    _selectedDate = normalized;
    await refresh();
  }

  Future<void> setCourierId(int? courierId) async {
    final normalized = (courierId ?? 0) > 0 ? courierId : null;
    if (_selectedCourierId == normalized) {
      return;
    }
    _selectedCourierId = normalized;
    await refresh();
  }

  Future<double> settleAccount(int courierId) async {
    state = const AsyncLoading();
    try {
      final response = await ref
          .read(adminOrdersRepositoryProvider)
          .settleCourierAccount(courierId);
      await refresh();
      return (response['total_settled'] as num?)?.toDouble() ?? 0.0;
    } catch (e) {
      await refresh();
      rethrow;
    }
  }
}

final adminCouriersListForReportProvider =
    FutureProvider.autoDispose<List<AdminCourier>>((ref) async {
      return ref.read(adminOrdersRepositoryProvider).getCouriers();
    });
