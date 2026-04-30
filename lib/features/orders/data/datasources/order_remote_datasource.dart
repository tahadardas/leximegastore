import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../config/constants/endpoints.dart';
import '../../../../core/logging/app_logger.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../core/utils/order_number_utils.dart';
import '../../../../core/utils/safe_parsers.dart';
import '../../../../core/utils/text_normalizer.dart';
import '../parsers/order_parsing.dart';
import '../../domain/entities/invoice_document.dart';
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
      } on DioException catch (e, st) {
        lastError = e;
        final canRetry = !isLast && _canTryInvoiceFallback(e);
        if (kDebugMode && canRetry) {
          debugPrint(
            '[Invoice][WARN] retry with alternate type after ${e.response?.statusCode}: $candidateType',
          );
        }
        if (!canRetry) {
          _logCriticalInvoiceFailure(
            orderId: orderId,
            requestedType: type,
            attemptedType: candidateType,
            hasPhone: normalizedPhone.isNotEmpty,
            error: e,
            stackTrace: st,
          );
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
      return const ['provisional'];
    }

    final attempts = <String>[normalized];
    if (normalized == 'final') {
      attempts.add('provisional');
    } else if (normalized == 'provisional') {
      attempts.add('proforma');
    } else if (normalized == 'proforma') {
      attempts.add('provisional');
    } else {
      attempts.add('provisional');
    }

    return attempts.toSet().toList(growable: false);
  }

  bool _canTryInvoiceFallback(DioException error) {
    final status = error.response?.statusCode;
    if (status != null) {
      if (status == 403) {
        return _isInvoiceNotReady(error);
      }
      if (_isInvoiceAccessInputError(error)) {
        return false;
      }
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

  bool _isInvoiceAccessInputError(DioException error) {
    final payload = extractMap(error.response?.data);
    final errorBody = extractMap(payload['error']);
    final code = (errorBody['code'] ?? payload['code'] ?? '')
        .toString()
        .trim()
        .toLowerCase();
    return code == 'phone_required' || code == 'phone_mismatch';
  }

  bool _isInvoiceNotReady(DioException error) {
    final payload = extractMap(error.response?.data);
    final errorBody = extractMap(payload['error']);
    final code = (errorBody['code'] ?? payload['code'] ?? '')
        .toString()
        .trim()
        .toLowerCase();
    if (code == 'invoice_not_ready') {
      return true;
    }

    final message = (errorBody['message'] ?? payload['message'] ?? '')
        .toString()
        .trim()
        .toLowerCase();
    return message.contains('invoice_not_ready') ||
        message.contains('final invoice') ||
        message.contains('الفاتورة النهائية');
  }

  void _logCriticalInvoiceFailure({
    required String orderId,
    required String requestedType,
    required String attemptedType,
    required bool hasPhone,
    required DioException error,
    required StackTrace stackTrace,
  }) {
    if (!_isCriticalInvoiceFailure(error)) {
      return;
    }

    unawaited(
      AppLogger.error(
        'Invoice request failed',
        error,
        stackTrace,
        extra: {
          'order_id': orderId,
          'requested_type': requestedType,
          'attempted_type': attemptedType,
          'status_code': error.response?.statusCode,
          'error_type': error.type.name,
          'has_phone': hasPhone,
        },
      ),
    );
  }

  bool _isCriticalInvoiceFailure(DioException error) {
    final status = error.response?.statusCode;
    if (status == null) {
      return switch (error.type) {
        DioExceptionType.connectionError => true,
        DioExceptionType.connectionTimeout => true,
        DioExceptionType.sendTimeout => true,
        DioExceptionType.receiveTimeout => true,
        DioExceptionType.badCertificate => true,
        _ => false,
      };
    }
    return status >= 500;
  }

  Future<dynamic> _resolveInvoiceResponse(dynamic responseData) async {
    final invoicePayload = extractMap(responseData);
    final invoiceUrl =
        (invoicePayload['invoice_url'] ?? invoicePayload['url'] ?? '')
            .toString()
            .trim();
    final invoiceOrder = _extractInvoiceOrder(invoicePayload);
    final invoiceType = (invoicePayload['invoice_type'] ?? '')
        .toString()
        .trim();
    final verificationUrl =
        (invoicePayload['verification_url'] ??
                invoicePayload['invoice_verification_url'] ??
                '')
            .toString()
            .trim();

    if (invoiceUrl.isEmpty) {
      throw const FormatException('رابط الفاتورة غير متوفر.');
    }

    InvoiceDocument buildDocument(dynamic content) {
      return InvoiceDocument(
        content: content,
        order: invoiceOrder,
        invoiceType: invoiceType,
        invoiceUrl: invoiceUrl,
        verificationUrl: verificationUrl,
      );
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
          return buildDocument(TextNormalizer.normalize(rawBytes));
        }
        return buildDocument(invoiceUrl);
      }

      final bytes = rawBytes is List<int>
          ? Uint8List.fromList(rawBytes)
          : Uint8List.fromList(
              (rawBytes as List).map((e) => parseInt(e)).toList(),
            );
      final contentType = (invoiceResponse.headers.value('content-type') ?? '')
          .toLowerCase();

      if (contentType.contains('application/pdf')) {
        return buildDocument(bytes);
      }

      try {
        final html = TextNormalizer.normalize(
          utf8.decode(bytes, allowMalformed: true),
        );
        if (html.trim().isNotEmpty) {
          return buildDocument(html);
        }
      } catch (_) {
        try {
          final html = TextNormalizer.normalize(latin1.decode(bytes));
          if (html.trim().isNotEmpty) {
            return buildDocument(html);
          }
        } catch (_) {
          // ignore and fallback
        }
      }

      return buildDocument(invoiceUrl);
    } on DioException catch (e) {
      if (kDebugMode) {
        debugPrint(
          '[Invoice][WARN] fallback to url: $invoiceUrl | ${e.message}',
        );
      }
      return buildDocument(invoiceUrl);
    }
  }

  Order? _extractInvoiceOrder(Map<String, dynamic> invoicePayload) {
    final orderPayload = extractMap(invoicePayload['order']);
    if (orderPayload.isEmpty) {
      return null;
    }

    try {
      return Order.fromJson(orderPayload);
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('[Invoice][WARN] unable to parse embedded order: $e\n$st');
      }
      return null;
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
