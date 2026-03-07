import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../config/constants/endpoints.dart';
import '../../../../core/network/dio_client.dart';
import '../../domain/entities/admin_coupon.dart';

final adminCouponsRemoteDatasourceProvider =
    Provider<AdminCouponsRemoteDatasource>((ref) {
      return AdminCouponsRemoteDatasource(ref.read(dioClientProvider));
    });

class AdminCouponsRemoteDatasource {
  final DioClient _client;

  AdminCouponsRemoteDatasource(this._client);

  Future<List<AdminCoupon>> getCoupons() async {
    final response = await _client.get(Endpoints.adminCoupons());
    final list = extractList(response.data);
    return list
        .whereType<Map>()
        .map((e) => AdminCoupon.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<AdminCoupon> createCoupon(Map<String, dynamic> data) async {
    final response = await _client.post(Endpoints.adminCoupons(), data: data);
    return AdminCoupon.fromJson(extractMap(response.data));
  }

  Future<AdminCoupon> updateCoupon(int id, Map<String, dynamic> data) async {
    final response = await _client.put(Endpoints.adminCoupon(id), data: data);
    return AdminCoupon.fromJson(extractMap(response.data));
  }

  Future<void> deleteCoupon(int id) async {
    await _client.delete(Endpoints.adminCoupon(id));
  }
}
