import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:dio/dio.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'app/app.dart';
import 'app/bootstrap/bootstrap.dart';
import 'core/cache/cache_store.dart';
import 'core/auth/auth_token_refresher.dart';
import 'core/auth/auth_session_controller.dart';
import 'core/auth/token_store.dart';
import 'core/logging/app_logger.dart';
import 'core/network/network_logging_interceptor.dart';
import 'core/network/network_guard.dart';
import 'core/network/app_boot_service.dart';
import 'core/security/app_lock_service.dart';
import 'core/services/auth_service.dart';
import 'core/session/app_session.dart';
import 'core/notifications/firebase_push_service.dart';
import 'core/utils/relative_time.dart';

const bool _allowInsecureCerts = bool.fromEnvironment(
  'ALLOW_INSECURE_CERTS',
  defaultValue: false,
);
const String _insecureCertHostsCsv = String.fromEnvironment(
  'INSECURE_CERT_HOSTS',
  defaultValue: 'localhost,127.0.0.1,10.0.2.2',
);

class DevOnlyHttpOverrides extends HttpOverrides {
  DevOnlyHttpOverrides(this.allowedHosts);

  final Set<String> allowedHosts;

  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return super.createHttpClient(context)
      ..badCertificateCallback = (X509Certificate cert, String host, int port) {
        return allowedHosts.contains(host);
      };
  }
}

Future<void> main() async {
  if (!kReleaseMode && _allowInsecureCerts) {
    final allowedHosts = _insecureCertHostsCsv
        .split(',')
        .map((host) => host.trim())
        .where((host) => host.isNotEmpty)
        .toSet();
    HttpOverrides.global = DevOnlyHttpOverrides(allowedHosts);
  }
  WidgetsFlutterBinding.ensureInitialized();
  FirebasePushService.registerBackgroundHandlers();
  await bootstrap();
  await Hive.initFlutter();
  await CacheStore.instance.init();
  await AppLogger.initialize();
  configureRelativeTimeLocales();

  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    unawaited(
      AppLogger.error(
        'Flutter framework error',
        details.exception,
        details.stack ?? StackTrace.current,
      ),
    );
  };

  PlatformDispatcher.instance.onError = (error, stackTrace) {
    unawaited(AppLogger.error('PlatformDispatcher error', error, stackTrace));
    return true;
  };

  // Dependency Injection Setup
  // A plain Dio is intentional here: AuthService only handles pre-auth
  // endpoints (login, register, token refresh) that don't need JWT injection
  // or retry logic. All post-auth API calls go through DioClient (Riverpod).
  final dio = Dio();
  dio.interceptors.add(NetworkLoggingInterceptor());
  const storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );
  final tokenStore = TokenStore(storage: storage);
  final authService = AuthService(dio);
  final appSession = AppSession(storage, authService, tokenStore: tokenStore);
  final authTokenRefresher = AuthTokenRefresher(appSession);
  final authSessionController = AuthSessionController(
    appSession: appSession,
    tokenStore: tokenStore,
    tokenRefresher: authTokenRefresher,
  );
  final appLockService = AppLockService(
    storage: storage,
    tokenStore: tokenStore,
  );
  await appLockService.bootstrap();

  final appBootService = AppBootService(
    networkGuard: NetworkGuard.instance,
    appSession: appSession,
    authSessionController: authSessionController,
  );
  await appBootService.boot();

  runApp(
    ProviderScope(
      overrides: [
        appSessionProvider.overrideWith((ref) => appSession),
        tokenStoreProvider.overrideWith((ref) => tokenStore),
        authTokenRefresherProvider.overrideWith((ref) => authTokenRefresher),
        authSessionControllerProvider.overrideWith(
          (ref) => authSessionController,
        ),
        appLockServiceProvider.overrideWith((ref) => appLockService),
      ],
      child: const LexiMegaStoreApp(),
    ),
  );
}
