import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/admin_dashboard_stats.dart';
import '../datasources/admin_dashboard_datasource.dart';

final adminDashboardRepositoryProvider = Provider<AdminDashboardRepository>((
  ref,
) {
  return AdminDashboardRepositoryImpl(
    ref.watch(adminDashboardRemoteDatasourceProvider),
  );
});

abstract class AdminDashboardRepository {
  Future<AdminDashboardStats> getStats();
}

class AdminDashboardRepositoryImpl implements AdminDashboardRepository {
  final AdminDashboardRemoteDatasource _datasource;

  AdminDashboardRepositoryImpl(this._datasource);

  @override
  Future<AdminDashboardStats> getStats() {
    return _datasource.getStats();
  }
}
