import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class NoInternetException implements Exception {
  final String message;

  const NoInternetException([this.message = 'No internet connection']);

  @override
  String toString() => message;
}

class NetworkGuard {
  NetworkGuard._internal();

  static final NetworkGuard instance = NetworkGuard._internal();

  final Connectivity _connectivity = Connectivity();
  final StreamController<bool> _statusController =
      StreamController<bool>.broadcast();

  StreamSubscription<dynamic>? _subscription;
  bool _started = false;
  bool _isConnected = true;

  bool get isConnected => _isConnected;
  Stream<bool> get connectivityChanges => _statusController.stream;

  Future<void> start() async {
    if (_started) {
      return;
    }
    _started = true;

    final initial = await _connectivity.checkConnectivity();
    _update(initial);
    _subscription = _connectivity.onConnectivityChanged.listen(_update);
  }

  Future<bool> hasConnectivity() async {
    await start();
    return _isConnected;
  }

  Future<void> assertConnected() async {
    final connected = await hasConnectivity();
    if (!connected) {
      throw const NoInternetException();
    }
  }

  void _update(dynamic event) {
    final next = _hasTransport(event);
    if (next == _isConnected) {
      return;
    }

    _isConnected = next;
    _statusController.add(next);
    if (kDebugMode) {
      debugPrint('[NetworkGuard] connected=$_isConnected');
    }
  }

  bool _hasTransport(dynamic value) {
    if (value is ConnectivityResult) {
      return value != ConnectivityResult.none;
    }

    if (value is List<ConnectivityResult>) {
      if (value.isEmpty) {
        return false;
      }
      return value.any((item) => item != ConnectivityResult.none);
    }

    if (value is Iterable<ConnectivityResult>) {
      final values = value.toList(growable: false);
      if (values.isEmpty) {
        return false;
      }
      return values.any((item) => item != ConnectivityResult.none);
    }

    // Unknown event shape: fail-open.
    return true;
  }

  void dispose() {
    _subscription?.cancel();
    _subscription = null;
    _started = false;
  }
}

class NetworkGuardInterceptor extends Interceptor {
  final NetworkGuard guard;

  NetworkGuardInterceptor(this.guard);

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    try {
      await guard.assertConnected();
      handler.next(options);
    } on NoInternetException catch (error) {
      handler.reject(
        DioException(
          requestOptions: options,
          type: DioExceptionType.connectionError,
          error: error,
          message: error.message,
        ),
      );
    } catch (_) {
      handler.next(options);
    }
  }
}

final networkGuardProvider = Provider<NetworkGuard>((ref) {
  final guard = NetworkGuard.instance;
  unawaited(guard.start());
  return guard;
});
