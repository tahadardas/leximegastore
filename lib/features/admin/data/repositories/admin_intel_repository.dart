import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/admin_intel_stats.dart';
import '../datasources/admin_intel_remote_datasource.dart';

final adminIntelRepositoryProvider = Provider<AdminIntelRepository>((ref) {
  return AdminIntelRepository(ref.watch(adminIntelRemoteDatasourceProvider));
});

class AdminIntelRepository {
  final AdminIntelRemoteDatasource _remote;

  AdminIntelRepository(this._remote);

  Future<AdminIntelStats> getOverview({String range = 'today'}) {
    return _remote.getOverview(range: range);
  }
}
