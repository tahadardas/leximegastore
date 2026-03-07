import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../shared/widgets/error_state.dart';
import '../controllers/products_controller.dart';

class ProductDeepLinkResolverPage extends ConsumerStatefulWidget {
  const ProductDeepLinkResolverPage({
    super.key,
    required this.productRef,
    this.queryParameters = const <String, String>{},
  });

  final String productRef;
  final Map<String, String> queryParameters;

  @override
  ConsumerState<ProductDeepLinkResolverPage> createState() =>
      _ProductDeepLinkResolverPageState();
}

class _ProductDeepLinkResolverPageState
    extends ConsumerState<ProductDeepLinkResolverPage> {
  bool _resolving = true;
  Object? _error;
  StackTrace? _stackTrace;
  String _message = '';
  bool _didResolve = false;

  @override
  void initState() {
    super.initState();
    unawaited(_resolveAndNavigate());
  }

  @override
  Widget build(BuildContext context) {
    if (_resolving) {
      return const Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 14),
              Text('جاري فتح صفحة المنتج...'),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      body: SafeArea(
        child: ErrorState(
          message: _message.isEmpty ? 'تعذر فتح المنتج من الرابط.' : _message,
          error: _error,
          stackTrace: _stackTrace,
          onRetry: () => unawaited(_resolveAndNavigate(force: true)),
        ),
      ),
    );
  }

  Future<void> _resolveAndNavigate({bool force = false}) async {
    if (_didResolve && !force) {
      return;
    }
    _didResolve = true;
    _setResolving();

    final rawRef = Uri.decodeComponent(widget.productRef).trim();
    if (rawRef.isEmpty) {
      _setError('رابط المنتج غير صالح.');
      return;
    }

    final numericId = int.tryParse(rawRef);
    if (numericId != null && numericId > 0) {
      _goToProduct(numericId);
      return;
    }

    try {
      final repository = ref.read(productRepositoryProvider);
      final resolvedProductId = await repository.resolveProductIdBySlug(rawRef);
      if (!mounted) {
        return;
      }

      if (resolvedProductId == null || resolvedProductId <= 0) {
        _setError('لم نتمكن من العثور على هذا المنتج.');
        return;
      }

      _goToProduct(resolvedProductId);
    } catch (error, stackTrace) {
      if (!mounted) {
        return;
      }
      _setError(
        'تعذر فتح المنتج من الرابط حالياً.',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  void _goToProduct(int productId) {
    if (!mounted) {
      return;
    }

    final queryParameters = widget.queryParameters.isEmpty
        ? null
        : widget.queryParameters;
    final targetLocation = Uri(
      path: AppRoutePaths.product(productId),
      queryParameters: queryParameters,
    ).toString();

    final router = GoRouter.of(context);
    final currentUri = router.routeInformationProvider.value.uri;
    final targetUri = Uri.parse(targetLocation);
    if (currentUri.path == targetUri.path &&
        mapEquals(currentUri.queryParameters, targetUri.queryParameters)) {
      return;
    }

    router.go(targetLocation);
  }

  void _setResolving() {
    if (!mounted) {
      return;
    }
    setState(() {
      _resolving = true;
      _error = null;
      _stackTrace = null;
      _message = '';
    });
  }

  void _setError(String message, {Object? error, StackTrace? stackTrace}) {
    if (!mounted) {
      return;
    }
    setState(() {
      _resolving = false;
      _error = error;
      _stackTrace = stackTrace;
      _message = message;
    });
  }
}
