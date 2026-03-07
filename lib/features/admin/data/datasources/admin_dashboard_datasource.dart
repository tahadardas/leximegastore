import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../config/constants/endpoints.dart';
import '../../../../core/network/dio_client.dart';
import '../../domain/entities/admin_dashboard_stats.dart';

final adminDashboardRemoteDatasourceProvider =
    Provider<AdminDashboardRemoteDatasource>((ref) {
      return AdminDashboardRemoteDatasourceImpl(ref.watch(dioClientProvider));
    });

abstract class AdminDashboardRemoteDatasource {
  Future<AdminDashboardStats> getStats();
}

class AdminDashboardRemoteDatasourceImpl
    implements AdminDashboardRemoteDatasource {
  final DioClient _dioClient;

  AdminDashboardRemoteDatasourceImpl(this._dioClient);

  @override
  Future<AdminDashboardStats> getStats() async {
    final response = await _dioClient.get(
      Endpoints.adminDashboard(),
      options: Options(responseType: ResponseType.plain),
    );

    final decoded = _decodeDashboardResponse(response.data);
    return AdminDashboardStats.fromJson(extractMap(decoded));
  }

  dynamic _decodeDashboardResponse(dynamic raw) {
    if (raw is Map || raw is List) {
      return raw;
    }

    final text = (raw ?? '').toString().trim();
    if (text.isEmpty) {
      return const <String, dynamic>{};
    }

    // Handles UTF-8 BOM and accidental leading commas/spaces from server output.
    final sanitized = text
        .replaceAll('\uFEFF', '')
        .replaceFirst(RegExp(r'^[\s,]+'), '');

    return jsonDecode(sanitized);
  }
}
