import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../config/constants/endpoints.dart';
import '../../../../core/network/dio_client.dart';
import '../../domain/entities/admin_intel_stats.dart';

final adminIntelRemoteDatasourceProvider = Provider<AdminIntelRemoteDatasource>((ref) {
  return AdminIntelRemoteDatasourceImpl(ref.watch(dioClientProvider));
});

abstract class AdminIntelRemoteDatasource {
  Future<AdminIntelStats> getOverview({String range = 'today'});
}

class AdminIntelRemoteDatasourceImpl implements AdminIntelRemoteDatasource {
  final DioClient _dioClient;

  AdminIntelRemoteDatasourceImpl(this._dioClient);

  @override
  Future<AdminIntelStats> getOverview({String range = 'today'}) async {
    final response = await _dioClient.get(
      Endpoints.adminIntelOverview(),
      queryParameters: {'range': range},
      options: Options(responseType: ResponseType.plain),
    );

    final decoded = _decodeResponse(response.data);
    return AdminIntelStats.fromJson(extractMap(decoded));
  }

  dynamic _decodeResponse(dynamic raw) {
    if (raw is Map || raw is List) {
      return raw;
    }

    final text = (raw ?? '').toString().trim();
    if (text.isEmpty) {
      return const <String, dynamic>{};
    }

    final sanitized = text
        .replaceAll('\uFEFF', '')
        .replaceFirst(RegExp(r'^[\s,]+'), '');

    return jsonDecode(sanitized);
  }
}
