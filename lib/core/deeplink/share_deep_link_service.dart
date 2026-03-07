import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/router/app_router.dart';
import '../../app/router/app_routes.dart';
import '../auth/auth_session_controller.dart';
import 'share_links.dart';

final deepLinkBootstrapProvider = Provider<void>((ref) {
  if (kIsWeb) {
    return;
  }

  final service = DeepLinkService(ref);
  ref.onDispose(service.dispose);
});

// Backward-compatible alias used by existing app bootstrap.
final shareDeepLinkBootstrapProvider = deepLinkBootstrapProvider;

class DeepLinkService {
  final Ref _ref;
  final AppLinks _appLinks = AppLinks();
  final AuthSessionController _authSessionController;

  StreamSubscription<Uri>? _subscription;
  bool _isInitialized = false;
  String? _pendingAuthLocation;
  String? _lastIncomingKey;
  DateTime? _lastIncomingAt;
  bool _didNavigatePendingAfterAuth = false;

  DeepLinkService(this._ref)
    : _authSessionController = _ref.read(authSessionControllerProvider) {
    unawaited(_init());
  }

  Future<void> _init() async {
    if (_isInitialized) {
      return;
    }
    _isInitialized = true;
    _authSessionController.addListener(_onAuthStateChanged);
    await _waitForRouterReady();

    try {
      final initialUri = await _appLinks.getInitialLink();
      _processIncomingUri(initialUri);
    } catch (_) {
      // Ignore malformed initial links.
    }

    _subscription = _appLinks.uriLinkStream.listen(
      _processIncomingUri,
      onError: (_) {
        // Ignore malformed runtime links.
      },
    );
  }

  Future<void> _waitForRouterReady() async {
    final completer = Completer<void>();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!completer.isCompleted) {
        completer.complete();
      }
    });
    await completer.future;
  }

  void _processIncomingUri(Uri? incomingUri) {
    if (incomingUri == null) {
      return;
    }

    final resolved = _resolveUri(incomingUri);
    if (resolved == null || resolved.location.trim().isEmpty) {
      return;
    }

    if (_isDuplicateIncoming(resolved.key)) {
      return;
    }

    if (!resolved.requiresAuth) {
      _navigateToLocation(resolved.location);
      return;
    }

    final authState = _authSessionController.state.status;
    if (authState == AuthSessionStatus.authenticated) {
      _pendingAuthLocation = null;
      _didNavigatePendingAfterAuth = false;
      _navigateToLocation(resolved.location);
      return;
    }

    _pendingAuthLocation = resolved.location;
    _didNavigatePendingAfterAuth = false;
    if (authState == AuthSessionStatus.unauthenticated) {
      _navigateToLocation(_loginLocationForNext(resolved.location));
    }
  }

  void _onAuthStateChanged() {
    final pending = _pendingAuthLocation;
    if (pending == null || pending.trim().isEmpty) {
      return;
    }

    final authState = _authSessionController.state.status;
    if (authState == AuthSessionStatus.authenticated) {
      if (_didNavigatePendingAfterAuth) {
        return;
      }
      _didNavigatePendingAfterAuth = true;
      _pendingAuthLocation = null;
      _navigateToLocation(pending);
      return;
    }

    if (authState == AuthSessionStatus.unauthenticated) {
      _navigateToLocation(_loginLocationForNext(pending));
    }
  }

  _ResolvedDeepLink? _resolveUri(Uri uri) {
    final shareTarget = ShareLinks.parseUri(uri);
    if (shareTarget != null) {
      final location = Uri(
        path: ShareLinks.entryPath(type: shareTarget.type, id: shareTarget.id),
        queryParameters: uri.queryParameters.isEmpty
            ? null
            : uri.queryParameters,
      ).toString();
      return _ResolvedDeepLink(
        location: location,
        key: 'share:${shareTarget.type}:${shareTarget.id}',
        requiresAuth: ShareLinks.requiresAuthType(shareTarget.type),
      );
    }

    final productSlug = ShareLinks.parseProductSlug(uri);
    if (productSlug != null) {
      final location = Uri(
        path:
            '/${ShareLinks.productSegment}/${Uri.encodeComponent(productSlug)}',
        queryParameters: uri.queryParameters.isEmpty
            ? null
            : uri.queryParameters,
      ).toString();
      return _ResolvedDeepLink(
        location: location,
        key: 'product:$productSlug',
        requiresAuth: false,
      );
    }

    final normalizedPath = _normalizePath(uri.path);
    if (normalizedPath == null) {
      return null;
    }

    final location = Uri(
      path: normalizedPath,
      queryParameters: uri.queryParameters.isEmpty ? null : uri.queryParameters,
    ).toString();
    if (location.trim().isEmpty) {
      return null;
    }

    return _ResolvedDeepLink(
      location: location,
      key: 'raw:$location',
      requiresAuth: false,
    );
  }

  String? _normalizePath(String rawPath) {
    final path = rawPath.trim();
    if (!path.startsWith('/')) {
      return null;
    }

    if (path.startsWith('/index.php/product/')) {
      return '/product/${path.substring('/index.php/product/'.length)}';
    }

    if (path.startsWith('/index.php/s/')) {
      return '/s/${path.substring('/index.php/s/'.length)}';
    }

    return path;
  }

  void _navigateToLocation(String targetLocation) {
    if (targetLocation.trim().isEmpty) {
      return;
    }

    final router = _ref.read(appRouterProvider);
    if (_isSameLocation(router, targetLocation)) {
      return;
    }

    router.go(targetLocation);
  }

  bool _isDuplicateIncoming(String key) {
    final now = DateTime.now();
    if (_lastIncomingKey == key &&
        _lastIncomingAt != null &&
        now.difference(_lastIncomingAt!) <= const Duration(milliseconds: 700)) {
      return true;
    }
    _lastIncomingKey = key;
    _lastIncomingAt = now;
    return false;
  }

  String _loginLocationForNext(String targetLocation) {
    final parsed = Uri.tryParse(targetLocation);
    if (parsed == null || !parsed.path.startsWith('/')) {
      return AppRoutePaths.login;
    }

    final next = Uri(
      path: parsed.path,
      queryParameters: parsed.queryParameters.isEmpty
          ? null
          : parsed.queryParameters,
    ).toString();

    return Uri(
      path: AppRoutePaths.login,
      queryParameters: {'next': next},
    ).toString();
  }

  bool _isSameLocation(GoRouter router, String targetLocation) {
    final currentUri = router.routeInformationProvider.value.uri;
    final targetUri = Uri.parse(targetLocation);
    return currentUri.path == targetUri.path &&
        mapEquals(currentUri.queryParameters, targetUri.queryParameters);
  }

  void dispose() {
    _subscription?.cancel();
    _authSessionController.removeListener(_onAuthStateChanged);
  }
}

class _ResolvedDeepLink {
  final String location;
  final String key;
  final bool requiresAuth;

  const _ResolvedDeepLink({
    required this.location,
    required this.key,
    required this.requiresAuth,
  });
}
