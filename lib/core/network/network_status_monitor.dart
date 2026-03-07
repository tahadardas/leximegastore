import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../config/constants/endpoints.dart';
import '../../design_system/lexi_tokens.dart';

enum NetworkConnectionStatus { unknown, online, offline }

final networkStatusProvider =
    StateNotifierProvider<NetworkStatusController, NetworkConnectionStatus>((
      ref,
    ) {
      final controller = NetworkStatusController();
      ref.onDispose(controller.dispose);
      return controller;
    });

class NetworkStatusController extends StateNotifier<NetworkConnectionStatus> {
  final Connectivity _connectivity;
  final Dio _probeDio;
  StreamSubscription<dynamic>? _subscription;
  Timer? _debounce;
  dynamic _lastEvent;

  NetworkStatusController({Connectivity? connectivity, Dio? probeDio})
    : _connectivity = connectivity ?? Connectivity(),
      _probeDio =
          probeDio ??
          Dio(
            BaseOptions(
              connectTimeout: const Duration(seconds: 5),
              receiveTimeout: const Duration(seconds: 5),
              sendTimeout: const Duration(seconds: 5),
              validateStatus: (status) =>
                  status != null && status >= 200 && status < 500,
              headers: const {'Accept': 'application/json'},
            ),
          ),
      super(NetworkConnectionStatus.unknown) {
    unawaited(_initialize());
  }

  Future<void> _initialize() async {
    _lastEvent = await _connectivity.checkConnectivity();
    await _evaluate();
    _subscription = _connectivity.onConnectivityChanged.listen((event) {
      _lastEvent = event;
      _scheduleEvaluation();
    });
  }

  void _scheduleEvaluation() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      unawaited(_evaluate());
    });
  }

  Future<void> _evaluate() async {
    final hasTransport = _hasTransport(_lastEvent);
    if (!hasTransport) {
      if (state != NetworkConnectionStatus.offline) {
        state = NetworkConnectionStatus.offline;
      }
      return;
    }

    final reachable = await _probeReachability();
    final next = reachable
        ? NetworkConnectionStatus.online
        : NetworkConnectionStatus.offline;
    if (next != state) {
      state = next;
    }
  }

  bool _hasTransport(dynamic result) {
    if (result is ConnectivityResult) {
      return result != ConnectivityResult.none;
    }
    if (result is List<ConnectivityResult>) {
      if (result.isEmpty) {
        return false;
      }
      return result.any((item) => item != ConnectivityResult.none);
    }
    if (result is Iterable<ConnectivityResult>) {
      final values = result.toList(growable: false);
      if (values.isEmpty) {
        return false;
      }
      return values.any((item) => item != ConnectivityResult.none);
    }
    // Fail-open: unknown result type should not block requests.
    return true;
  }

  Future<bool> _probeReachability() async {
    if (kIsWeb) {
      // Browser CORS rules block cross-origin reachability probes.
      // On web we trust connectivity transport state to avoid false offline.
      return true;
    }

    try {
      // Primary probe: API root
      final response = await _probeDio.get(Endpoints.baseUrl);
      // Any response (even 404/403) from our domain means we are "online"
      if ((response.statusCode ?? 0) >= 200) {
        return true;
      }
    } catch (_) {
      // Fallback: try a highly reliable host to distinguish between
      // "server down" and "no internet"
      try {
        final fallback = await _probeDio
            .get('https://8.8.8.8')
            .timeout(const Duration(seconds: 3));
        return (fallback.statusCode ?? 0) >= 200;
      } catch (_) {
        return false;
      }
    }
    return false;
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _subscription?.cancel();
    super.dispose();
  }
}

class NetworkStatusSnackbarListener extends ConsumerStatefulWidget {
  final Widget child;

  const NetworkStatusSnackbarListener({super.key, required this.child});

  @override
  ConsumerState<NetworkStatusSnackbarListener> createState() =>
      _NetworkStatusSnackbarListenerState();
}

class _NetworkStatusSnackbarListenerState
    extends ConsumerState<NetworkStatusSnackbarListener> {
  @override
  Widget build(BuildContext context) {
    // Ensure monitoring starts as soon as app starts.
    ref.watch(networkStatusProvider);

    ref.listen<NetworkConnectionStatus>(networkStatusProvider, (
      previous,
      next,
    ) {
      if (!mounted) {
        return;
      }

      final messenger = ScaffoldMessenger.maybeOf(context);
      if (messenger == null) {
        return;
      }

      if (next == NetworkConnectionStatus.offline &&
          previous != NetworkConnectionStatus.offline) {
        messenger.hideCurrentSnackBar();
        messenger.showSnackBar(
          _buildSnackBar(
            context,
            backgroundColor: LexiColors.error,
            icon: Icons.wifi_off_rounded,
            message: 'لا يوجد اتصال بالإنترنت',
            duration: const Duration(seconds: 3),
          ),
        );
      } else if (next == NetworkConnectionStatus.online &&
          previous == NetworkConnectionStatus.offline) {
        messenger.hideCurrentSnackBar();
        messenger.showSnackBar(
          _buildSnackBar(
            context,
            backgroundColor: LexiColors.success,
            icon: Icons.wifi_rounded,
            message: 'تم استعادة الاتصال بالإنترنت',
            duration: const Duration(seconds: 3),
          ),
        );
      }
    });

    return widget.child;
  }

  SnackBar _buildSnackBar(
    BuildContext context, {
    required Color backgroundColor,
    required IconData icon,
    required String message,
    required Duration duration,
  }) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final keyboardInset = MediaQuery.viewInsetsOf(context).bottom;
    final bottomMargin = bottomInset + (keyboardInset > 0 ? 8 : 16);
    return SnackBar(
      behavior: SnackBarBehavior.floating,
      margin: EdgeInsetsDirectional.fromSTEB(
        LexiSpacing.s16,
        0,
        LexiSpacing.s16,
        bottomMargin,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(LexiRadius.button),
      ),
      backgroundColor: backgroundColor,
      duration: duration,
      content: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(icon, color: LexiColors.brandWhite, size: 20),
          const SizedBox(width: LexiSpacing.s8),
          Expanded(
            child: Text(
              message,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              softWrap: true,
              style: const TextStyle(
                color: LexiColors.brandWhite,
                fontFamily: 'Cairo',
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
