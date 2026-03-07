import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../design_system/lexi_theme.dart';
import 'app_keys.dart';
import 'router/app_router.dart';
import '../core/deeplink/share_deep_link_service.dart';
import '../core/network/polling_manager.dart';
import '../core/network/network_status_monitor.dart';
import '../core/notifications/firebase_push_service.dart';
import '../core/auth/auth_session_controller.dart';
import '../core/services/courier_location_tracker.dart';
import '../core/security/app_lifecycle_observer.dart';
import '../l10n/app_localizations.dart';

class LexiMegaStoreApp extends ConsumerWidget {
  const LexiMegaStoreApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);
    ref.watch(pollingManagerBootstrapProvider);
    ref.watch(firebasePushBootstrapProvider);
    ref.watch(appLifecycleObserverProvider); // registers lifecycle observer
    ref.watch(courierLocationTrackerProvider);
    ref.watch(shareDeepLinkBootstrapProvider);
    ref.listen<AuthSessionState>(
      authSessionControllerProvider.select((controller) => controller.state),
      (previous, next) {
        final becameAuthenticated =
            next.status == AuthSessionStatus.authenticated &&
            previous?.status != AuthSessionStatus.authenticated;
        if (!becameAuthenticated) {
          return;
        }

        unawaited(
          ref.read(firebasePushServiceProvider).syncTokenRegistration(),
        );
      },
    );

    return MaterialApp.router(
      title: 'ليكسي ميغا ستور',
      debugShowCheckedModeBanner: false,
      theme: LexiTheme.light,
      scaffoldMessengerKey: rootScaffoldMessengerKey,
      locale: const Locale('ar'),
      builder: (context, child) {
        if (child == null) {
          return const SizedBox.shrink();
        }

        return Directionality(
          textDirection: TextDirection.rtl,
          child: SafeArea(
            top: true,
            bottom: true,
            left: false,
            right: false,
            child: NetworkStatusSnackbarListener(child: child),
          ),
        );
      },
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      routerConfig: router,
    );
  }
}
