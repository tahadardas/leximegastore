import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';

import '../../design_system/lexi_tokens.dart';

class OfflineBanner extends StatefulWidget {
  final VoidCallback? onRetry;

  const OfflineBanner({super.key, this.onRetry});

  @override
  State<OfflineBanner> createState() => _OfflineBannerState();
}

class _OfflineBannerState extends State<OfflineBanner> {
  final Connectivity _connectivity = Connectivity();
  StreamSubscription<dynamic>? _subscription;
  bool _offline = false;

  @override
  void initState() {
    super.initState();
    _checkNow();
    _subscription = _connectivity.onConnectivityChanged.listen((event) {
      _updateOffline(event);
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  Future<void> _checkNow() async {
    final result = await _connectivity.checkConnectivity();
    if (!mounted) {
      return;
    }
    _updateOffline(result);
  }

  void _updateOffline(dynamic result) {
    final offline = _isOffline(result);
    if (offline == _offline) {
      return;
    }
    setState(() => _offline = offline);
  }

  bool _isOffline(dynamic result) {
    if (result is ConnectivityResult) {
      return result == ConnectivityResult.none;
    }

    if (result is List<ConnectivityResult>) {
      if (result.isEmpty) {
        return true;
      }
      return result.every((item) => item == ConnectivityResult.none);
    }

    if (result is Iterable<ConnectivityResult>) {
      final values = result.toList(growable: false);
      if (values.isEmpty) {
        return true;
      }
      return values.every((item) => item == ConnectivityResult.none);
    }

    return false;
  }

  @override
  Widget build(BuildContext context) {
    if (!_offline) {
      return const SizedBox.shrink();
    }

    return Container(
      width: double.infinity,
      color: LexiColors.brandBlack,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          const Expanded(
            child: Text(
              'أنت غير متصل بالإنترنت - يتم عرض بيانات محفوظة',
              style: TextStyle(
                color: LexiColors.brandWhite,
                fontFamily: 'Cairo',
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          if (widget.onRetry != null)
            TextButton(
              onPressed: widget.onRetry,
              style: TextButton.styleFrom(
                foregroundColor: LexiColors.brandPrimary,
                textStyle: const TextStyle(
                  fontFamily: 'Cairo',
                  fontWeight: FontWeight.w700,
                ),
              ),
              child: const Text('إعادة المحاولة'),
            ),
        ],
      ),
    );
  }
}
