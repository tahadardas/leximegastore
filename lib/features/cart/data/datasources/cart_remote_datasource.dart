import 'package:dio/dio.dart';

import '../../../../core/errors/app_exception.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../core/network/dio_exception_mapper.dart';
import '../../domain/entities/cart_item.dart';
import '../models/coupon_model.dart';
import '../../../../config/constants/endpoints.dart';

class CartRemoteDatasource {
  final DioClient _client;

  CartRemoteDatasource(this._client);

  Future<CouponModel> validateCoupon(
    String code,
    double total,
    List<CartItem> items,
  ) async {
    try {
      final response = await _client.post(
        Endpoints.couponsValidate(),
        data: {
          'code': code,
          'cart_total': total,
          'items': items
              .map(
                (e) => {
                  'product_id': e.productId,
                  'quantity': e.qty,
                  'variation_id': e.variationId,
                },
              )
              .toList(),
        },
      );

      final raw = response.data;
      final envelope = raw is Map
          ? Map<String, dynamic>.from(
              raw.map((key, value) => MapEntry(key.toString(), value)),
            )
          : const <String, dynamic>{};

      if (envelope['success'] == false) {
        final error = envelope['error'] is Map
            ? Map<String, dynamic>.from(envelope['error'] as Map)
            : const <String, dynamic>{};
        throw ServerException(
          message: _extractErrorMessage(error),
          statusCode: _extractErrorStatus(error),
          data: _extractErrorCode(error),
        );
      }

      final payload = extractMap(raw);
      if (payload.isEmpty) {
        throw const ServerException(
          message: 'تعذر قراءة بيانات القسيمة من الخادم.',
          statusCode: 500,
        );
      }

      return CouponModel.fromJson(payload);
    } on DioException catch (e) {
      throw DioExceptionMapper.fromDioException(e);
    } on AppException {
      rethrow;
    } catch (e) {
      throw UnknownException(
        message: 'تعذر تطبيق القسيمة حالياً. حاول مرة أخرى.',
        data: e.toString(),
      );
    }
  }

  String _extractErrorMessage(Map<String, dynamic> error) {
    final message = (error['message'] ?? '').toString().trim();
    if (message.isNotEmpty) {
      return message;
    }
    return 'تعذر تطبيق القسيمة حالياً.';
  }

  int? _extractErrorStatus(Map<String, dynamic> error) {
    final status = error['status'];
    if (status is num) {
      return status.toInt();
    }
    final details = error['details'];
    if (details is Map) {
      final nested = details['status'];
      if (nested is num) {
        return nested.toInt();
      }
    }
    return null;
  }

  String _extractErrorCode(Map<String, dynamic> error) {
    final code = (error['code'] ?? '').toString().trim();
    return code.isEmpty ? 'coupon_error' : code;
  }
}
