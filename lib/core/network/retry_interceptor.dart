import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart' as app_logger;

import 'retry_policy.dart';

/// Controlled retry interceptor with bounded attempts and endpoint exclusions.
class RetryInterceptor extends Interceptor {
  final Dio dio;
  final RetryPolicy retryPolicy;
  final app_logger.Logger? logger;

  RetryInterceptor({required this.dio, required this.retryPolicy, this.logger});

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final attempt = _getAttempt(err.requestOptions);
    final shouldRetry = retryPolicy.shouldRetry(
      error: err,
      request: err.requestOptions,
      attempt: attempt,
    );
    if (!shouldRetry) {
      handler.next(err);
      return;
    }

    final nextAttempt = attempt + 1;
    final delay = retryPolicy.backoffForAttempt(nextAttempt);

    if (kDebugMode) {
      debugPrint(
        '[RetryPolicy] retry=$nextAttempt '
        'method=${err.requestOptions.method} '
        'path=${err.requestOptions.path} '
        'delayMs=${delay.inMilliseconds}',
      );
    }

    logger?.w(
      'Retry $nextAttempt/${retryPolicy.maxAttempts} -> '
      '${err.requestOptions.method} ${err.requestOptions.path}',
    );

    await Future.delayed(delay);
    err.requestOptions.extra['retry_attempt'] = nextAttempt;

    try {
      final response = await dio.fetch(err.requestOptions);
      handler.resolve(response);
      return;
    } on DioException catch (retryErr) {
      handler.next(retryErr);
      return;
    }
  }

  int _getAttempt(RequestOptions options) {
    return (options.extra['retry_attempt'] as int?) ?? 0;
  }
}
