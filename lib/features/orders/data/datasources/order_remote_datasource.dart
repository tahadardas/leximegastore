import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../config/constants/endpoints.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../core/utils/order_number_utils.dart';
import '../../../../core/utils/safe_parsers.dart';
import '../../../../core/utils/text_normalizer.dart';
import '../parsers/order_parsing.dart';
import '../../domain/entities/order.dart';
import '../../domain/entities/order_track.dart';

final orderRemoteDatasourceProvider = Provider<OrderRemoteDatasource>((ref) {
  return OrderRemoteDatasourceImpl(ref.watch(dioClientProvider));
});

abstract class OrderRemoteDatasource {
  Future<dynamic> getInvoice(String orderId, String type, {String? phone});
  Future<({int page, int perPage, List<Order> items})> myOrders({
    int page,
    int perPage,
  });
  Future<Order> myOrderDetails(int orderId);
  Future<OrderTrackInfo> trackOrderByNumber({
    required String orderNumber,
    String? verifier,
  });
  Future<void> confirmReceived(int orderId);
  Future<void> refuseOrder(int orderId, String reason);
}

class OrderRemoteDatasourceImpl implements OrderRemoteDatasource {
  final DioClient _dioClient;

  OrderRemoteDatasourceImpl(this._dioClient);

  @override
  Future<dynamic> getInvoice(
    String orderId,
    String type, {
    String? phone,
  }) async {
    final normalizedPhone = (phone ?? '').trim();
    final typeAttempts = _invoiceTypeAttempts(type);
    DioException? lastError;

    for (var index = 0; index < typeAttempts.length; index++) {
      final candidateType = typeAttempts[index];
      final isLast = index == typeAttempts.length - 1;

      try {
        final response = await _dioClient.get(
          Endpoints.invoice(orderId),
          queryParameters: {
            'type': candidateType,
            if (normalizedPhone.isNotEmpty) 'phone': normalizedPhone,
          },
          options: Options(extra: const {'requiresAuth': false}),
        );
        return _resolveInvoiceResponse(response.data);
      } on DioException catch (e) {
        lastError = e;
        final canRetry = !isLast && _canTryInvoiceFallback(e);
        if (kDebugMode && canRetry) {
          debugPrint(
            '[Invoice][WARN] retry with alternate type after ${e.response?.statusCode}: $candidateType',
          );
        }
        if (!canRetry) {
          rethrow;
        }
      }
    }

    throw lastError ??
        DioException(
          requestOptions: RequestOptions(path: Endpoints.invoice(orderId)),
        );
  }

  List<String> _invoiceTypeAttempts(String rawType) {
    final normalized = rawType.trim().toLowerCase();
    if (normalized.isEmpty) {
      return const ['final'];
    }

    final attempts = <String>[normalized];
    if (normalized == 'provisional') {
      attempts.add('proforma');
      attempts.add('final');
    } else if (normalized == 'proforma') {
      attempts.add('provisional');
      attempts.add('final');
    } else if (normalized != 'final') {
      attempts.add('final');
    }

    return attempts.toSet().toList(growable: false);
  }

  bool _canTryInvoiceFallback(DioException error) {
    final status = error.response?.statusCode;
    if (status != null) {
      return status == 400 || status == 404 || status == 405 || status == 422;
    }

    return switch (error.type) {
      DioExceptionType.connectionError => true,
      DioExceptionType.connectionTimeout => true,
      DioExceptionType.sendTimeout => true,
      DioExceptionType.receiveTimeout => true,
      DioExceptionType.unknown => true,
      _ => false,
    };
  }

  Future<dynamic> _resolveInvoiceResponse(dynamic responseData) async {
    final invoicePayload = extractMap(responseData);
    final invoiceUrl =
        (invoicePayload['invoice_url'] ?? invoicePayload['url'] ?? '')
            .toString()
            .trim();

    if (invoiceUrl.isEmpty) {
      throw const FormatException('رابط الفاتورة غير متوفر.');
    }

    try {
      final invoiceResponse = await _dioClient.dio.getUri(
        Uri.parse(invoiceUrl),
        options: Options(
          responseType: ResponseType.bytes,
          extra: const {'requiresAuth': false},
        ),
      );

      final rawBytes = invoiceResponse.data;
      if (rawBytes is String) {
        if (rawBytes.trim().isNotEmpty) {
          return TextNormalizer.normalize(rawBytes);
        }
        return invoiceUrl;
      }

      final bytes = rawBytes is List<int>
          ? Uint8List.fromList(rawBytes)
          : Uint8List.fromList(
              (rawBytes as List).map((e) => parseInt(e)).toList(),
            );
      final contentType = (invoiceResponse.headers.value('content-type') ?? '')
          .toLowerCase();

      if (contentType.contains('application/pdf')) {
        return bytes;
      }

      try {
        final html = TextNormalizer.normalize(
          utf8.decode(bytes, allowMalformed: true),
        );
        if (html.trim().isNotEmpty) {
          return html;
        }
      } catch (_) {
        try {
          final html = TextNormalizer.normalize(latin1.decode(bytes));
          if (html.trim().isNotEmpty) {
            return html;
          }
        } catch (_) {
          // ignore and fallback
        }
      }

      return invoiceUrl;
    } on DioException catch (e) {
      if (kDebugMode) {
        debugPrint(
          '[Invoice][WARN] fallback to url: $invoiceUrl | ${e.message}',
        );
      }
      return invoiceUrl;
    }
  }

  @override
  Future<({int page, int perPage, List<Order> items})> myOrders({
    int page = 1,
    int perPage = 20,
  }) async {
    final response = await _dioClient.get(
      Endpoints.myOrders(page: page, perPage: perPage),
    );

    final data = _extractPayloadDataMap(response.data);

    final resolvedPage = parseInt(data['page']) > 0
        ? parseInt(data['page'])
        : page;
    final resolvedPerPage = parseInt(data['per_page']) > 0
        ? parseInt(data['per_page'])
        : perPage;

    final items = _extractOrdersList(data);
    final parsedOrders = await parseOrdersInBackground(items);
    return (page: resolvedPage, perPage: resolvedPerPage, items: parsedOrders);
  }

  @override
  Future<Order> myOrderDetails(int orderId) async {
    final response = await _dioClient.get(Endpoints.myOrderDetails(orderId));
    final data = _extractPayloadDataMap(response.data);
    return Order.fromJson(data);
  }

  @override
  Future<OrderTrackInfo> trackOrderByNumber({
    required String orderNumber,
    String? verifier,
  }) async {
    final primaryOrderNumber = normalizeOrderLookupInput(orderNumber);
    final digitsOnlyOrderNumber = normalizeOrderNumber(primaryOrderNumber);

    try {
      final response = await _trackOrderRequest(
        orderNumber: primaryOrderNumber,
        verifier: verifier,
      );
      final data = _extractPayloadDataMap(response.data);
      return OrderTrackInfo.fromJson(data);
    } on DioException catch (e) {
      final canRetryWithDigits =
          digitsOnlyOrderNumber.isNotEmpty &&
          digitsOnlyOrderNumber != primaryOrderNumber &&
          _isOrderNotFound(e);
      if (!canRetryWithDigits) {
        rethrow;
      }

      final retry = await _trackOrderRequest(
        orderNumber: digitsOnlyOrderNumber,
        verifier: verifier,
      );
      final data = _extractPayloadDataMap(retry.data);
      return OrderTrackInfo.fromJson(data);
    }
  }

  @override
  Future<void> confirmReceived(int orderId) async {
    await _dioClient.post(
      Endpoints.confirmOrderReceived(orderId),
      options: Options(headers: const {'Accept': 'application/json'}),
    );
  }

  @override
  Future<void> refuseOrder(int orderId, String reason) async {
    await _dioClient.post(
      Endpoints.refuseOrder(orderId),
      data: {'reason': reason},
      options: Options(headers: const {'Accept': 'application/json'}),
    );
  }

  Future<Response<dynamic>> _trackOrderRequest({
    required String orderNumber,
    String? verifier,
  }) {
    return _dioClient.post(
      Endpoints.trackOrder(),
      data: {
        'order_number': orderNumber,
        if ((verifier ?? '').trim().isNotEmpty) 'verifier': verifier!.trim(),
      },
      options: Options(
        headers: const {'Accept': 'application/json'},
        extra: const {'requiresAuth': false},
      ),
    );
  }

  bool _isOrderNotFound(DioException error) {
    if (error.response?.statusCode != 404) {
      return false;
    }
    final payload = extractMap(error.response?.data);
    final errorBody = payload['error'];
    if (errorBody is Map) {
      final code = (errorBody['code'] ?? '').toString().trim().toLowerCase();
      return code == 'order_not_found';
    }
    final code = (payload['code'] ?? '').toString().trim().toLowerCase();
    return code == 'order_not_found';
  }

  Map<String, dynamic> _extractPayloadDataMap(dynamic raw) {
    final payload = extractMap(raw);
    final nested = payload['data'];
    if (nested is Map<String, dynamic>) {
      return nested;
    }
    if (nested is Map) {
      return nested.map((key, value) => MapEntry(key.toString(), value));
    }
    return payload;
  }

  List<Map<String, dynamic>> _extractOrdersList(Map<String, dynamic> payload) {
    final candidates = <dynamic>[
      payload['items'],
      payload['orders'],
      payload['results'],
      payload['data'],
    ];

    for (final candidate in candidates) {
      if (candidate is List) {
        return candidate
            .whereType<Map>()
            .map((e) => e.map((key, value) => MapEntry(key.toString(), value)))
            .toList();
      }
    }

    return const [];
  }
}
