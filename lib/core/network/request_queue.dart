import 'dart:async';
import 'dart:collection';
import 'dart:math' as math;

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class RequestQueue {
  RequestQueue({this.maxConcurrent = 4});

  final int maxConcurrent;
  final Queue<Completer<void>> _waiters = Queue<Completer<void>>();

  int _activeRequests = 0;

  int get activeRequests => _activeRequests;
  int get queuedRequests => _waiters.length;

  Future<void> acquire() async {
    if (_activeRequests < maxConcurrent) {
      _activeRequests++;
      _debugLog('acquire-immediate');
      return;
    }

    final completer = Completer<void>();
    _waiters.addLast(completer);
    _debugLog('queued');
    await completer.future;
    _debugLog('dequeued');
  }

  void release() {
    if (_waiters.isNotEmpty) {
      final next = _waiters.removeFirst();
      if (!next.isCompleted) {
        // Slot handoff keeps active requests count unchanged.
        next.complete();
      }
      _debugLog('handoff');
      return;
    }

    _activeRequests = math.max(0, _activeRequests - 1);
    _debugLog('release');
  }

  void _debugLog(String action) {
    if (!kDebugMode) {
      return;
    }
    debugPrint(
      '[RequestQueue] $action active=$_activeRequests queued=${_waiters.length}',
    );
  }
}

class RequestQueueInterceptor extends Interceptor {
  static const _releaseKey = '__request_queue_release';

  final RequestQueue queue;

  RequestQueueInterceptor({required this.queue});

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    await queue.acquire();
    options.extra[_releaseKey] = true;
    handler.next(options);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    _releaseIfNeeded(response.requestOptions);
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    _releaseIfNeeded(err.requestOptions);
    handler.next(err);
  }

  void _releaseIfNeeded(RequestOptions options) {
    final hasRelease = options.extra.remove(_releaseKey) == true;
    if (hasRelease) {
      queue.release();
    }
  }
}

final requestQueueProvider = Provider<RequestQueue>((ref) {
  return RequestQueue(maxConcurrent: 4);
});
