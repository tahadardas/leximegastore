import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../firebase_options.dart';

import '../../app/app_keys.dart';
import '../../app/router/app_router.dart';
import '../../app/router/app_routes.dart';
import '../../config/constants/endpoints.dart';
import '../../core/logging/app_logger.dart';
import '../../core/network/dio_client.dart';
import '../session/app_session.dart';
import '../storage/secure_store.dart';
import '../auth/auth_session_controller.dart';
import '../device/device_id_provider.dart';
import 'device_token_store.dart';
import 'notification_contract.dart';

const _kCourierSoundResource = 'courier_assignment_ringtone';
const _kPendingNotificationResponsesPrefsKey =
    'lexi_pending_notification_responses_v1';

final firebasePushServiceProvider = Provider<FirebasePushService>((ref) {
  final service = FirebasePushService(ref);
  ref.onDispose(service.dispose);
  return service;
});

final firebasePushBootstrapProvider = FutureProvider<void>((ref) async {
  await ref.read(firebasePushServiceProvider).bootstrap();
});

final FlutterLocalNotificationsPlugin _localNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

bool _localNotificationsInitialized = false;
bool _backgroundHandlersRegistered = false;

final StreamController<NotificationResponse> _notificationResponseController =
    StreamController<NotificationResponse>.broadcast();

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    WidgetsFlutterBinding.ensureInitialized();
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    await _ensureLocalNotificationsInitialized();
    await _showLocalNotificationFromRemoteMessage(message);
  } catch (error, stackTrace) {
    await AppLogger.error(
      'FCM background message handler failed',
      error,
      stackTrace,
    );
  }
}

@pragma('vm:entry-point')
void onDidReceiveBackgroundNotificationResponse(
  NotificationResponse notificationResponse,
) {
  unawaited(_persistPendingNotificationResponse(notificationResponse));
}

Future<void> _persistPendingNotificationResponse(
  NotificationResponse response,
) async {
  final prefs = await SharedPreferences.getInstance();
  final queue =
      prefs.getStringList(_kPendingNotificationResponsesPrefsKey) ?? <String>[];
  queue.add(
    jsonEncode(<String, dynamic>{
      'action_id': response.actionId ?? '',
      'payload': response.payload ?? '',
      'input': response.input ?? '',
    }),
  );

  final trimmed = queue.length > 20 ? queue.sublist(queue.length - 20) : queue;
  await prefs.setStringList(_kPendingNotificationResponsesPrefsKey, trimmed);
}

Future<void> _ensureLocalNotificationsInitialized() async {
  if (_localNotificationsInitialized) {
    return;
  }
  _localNotificationsInitialized = true;

  const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
  const initSettings = InitializationSettings(android: androidSettings);

  await _localNotificationsPlugin.initialize(
    initSettings,
    onDidReceiveNotificationResponse: (response) {
      _notificationResponseController.add(response);
    },
    onDidReceiveBackgroundNotificationResponse:
        onDidReceiveBackgroundNotificationResponse,
  );

  final androidImplementation = _localNotificationsPlugin
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >();

  if (androidImplementation == null) {
    return;
  }

  const customerChannel = AndroidNotificationChannel(
    NotificationChannels.customerDefaultId,
    'Customer Updates',
    description: 'General customer order updates.',
    importance: Importance.defaultImportance,
    playSound: true,
  );

  final courierChannel = AndroidNotificationChannel(
    NotificationChannels.courierAssignmentId,
    'Courier Assignment Alerts',
    description: 'Urgent courier assignment decisions.',
    importance: Importance.max,
    playSound: true,
    sound: const RawResourceAndroidNotificationSound(_kCourierSoundResource),
    enableVibration: true,
    vibrationPattern: Int64List.fromList(<int>[0, 700, 400, 900, 300, 1200]),
  );

  await androidImplementation.createNotificationChannel(customerChannel);
  await androidImplementation.createNotificationChannel(courierChannel);
}

Future<void> _showLocalNotificationFromRemoteMessage(
  RemoteMessage message,
) async {
  final data = message.data.map(
    (key, value) => MapEntry(key.toString(), '$value'),
  );
  final type = (data['type'] ?? '').trim();
  final title = message.notification?.title?.trim().isNotEmpty == true
      ? message.notification!.title!.trim()
      : (data['title'] ?? data['title_ar'] ?? '').trim();
  final body = message.notification?.body?.trim().isNotEmpty == true
      ? message.notification!.body!.trim()
      : (data['body'] ?? data['body_ar'] ?? '').trim();

  if (type == NotificationTypes.courierAssignment) {
    final assignment = CourierAssignmentPayload.fromMap(
      data,
      receivedAt: DateTime.now(),
    );
    await _showCourierAssignmentLocalNotification(
      payload: assignment,
      title: title,
      body: body,
    );
    return;
  }

  await _showCustomerLocalNotification(title: title, body: body, data: data);
}

Future<void> _showCustomerLocalNotification({
  required String title,
  required String body,
  required Map<String, dynamic> data,
}) async {
  final id = DateTime.now().millisecondsSinceEpoch ~/ 1000;
  final details = NotificationDetails(
    android: AndroidNotificationDetails(
      NotificationChannels.customerDefaultId,
      'Customer Updates',
      channelDescription: 'General customer order updates.',
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
      category: AndroidNotificationCategory.message,
      visibility: NotificationVisibility.private,
      playSound: true,
    ),
  );

  await _localNotificationsPlugin.show(
    id,
    title.isEmpty ? 'تحديث جديد' : title,
    body.isEmpty ? 'يوجد إشعار جديد' : body,
    details,
    payload: jsonEncode(data),
  );
}

Future<void> _showCourierAssignmentLocalNotification({
  required CourierAssignmentPayload payload,
  required String title,
  required String body,
}) async {
  final details = NotificationDetails(
    android: AndroidNotificationDetails(
      NotificationChannels.courierAssignmentId,
      'Courier Assignment Alerts',
      channelDescription: 'Urgent courier assignment decisions.',
      importance: Importance.max,
      priority: Priority.max,
      category: AndroidNotificationCategory.status,
      visibility: NotificationVisibility.public,
      playSound: true,
      sound: const RawResourceAndroidNotificationSound(_kCourierSoundResource),
      vibrationPattern: Int64List.fromList(<int>[0, 700, 400, 900, 300, 1200]),
      autoCancel: false,
      ongoing: true,
      timeoutAfter: payload.ttlSeconds * 1000,
      actions: <AndroidNotificationAction>[
        const AndroidNotificationAction(
          NotificationActions.accept,
          'ACCEPT',
          cancelNotification: true,
          showsUserInterface: true,
        ),
        const AndroidNotificationAction(
          NotificationActions.decline,
          'DECLINE',
          cancelNotification: true,
          showsUserInterface: true,
        ),
      ],
    ),
  );

  final safeOrderId = payload.orderId > 0
      ? payload.orderId
      : DateTime.now().millisecondsSinceEpoch ~/ 1000;
  await _localNotificationsPlugin.show(
    safeOrderId,
    title.isEmpty ? 'طلب توصيل جديد' : title,
    body.isEmpty ? 'يوجد طلب جديد بانتظار قرارك' : body,
    details,
    payload: payload.toJson(),
  );
}

class FirebasePushService {
  static const _kLastSenderIdPrefsKey = 'lexi_push_last_sender_id';

  final Ref _ref;

  bool _initialized = false;
  StreamSubscription<String>? _tokenRefreshSub;
  StreamSubscription<RemoteMessage>? _messageOpenSub;
  StreamSubscription<RemoteMessage>? _foregroundMessageSub;
  StreamSubscription<NotificationResponse>? _notificationResponseSub;

  FirebasePushService(this._ref);

  static void registerBackgroundHandlers() {
    if (_backgroundHandlersRegistered) {
      return;
    }
    _backgroundHandlersRegistered = true;
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  }

  Future<void> bootstrap() async {
    if (_initialized) {
      return;
    }
    _initialized = true;

    // Listen for auth state changes to re-register token
    _ref.listen(authSessionControllerProvider, (previous, next) {
      if (previous?.state.status != next.state.status) {
        unawaited(_syncTokenOnAuthChange());
      }
    });

    if (kIsWeb) {
      AppLogger.info(
        'Skipping Firebase bootstrap on web until web Firebase options are configured.',
      );
      return;
    }

    if (defaultTargetPlatform != TargetPlatform.android &&
        defaultTargetPlatform != TargetPlatform.iOS) {
      AppLogger.info('Skipping Firebase bootstrap on unsupported platform.');
      return;
    }

    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    } catch (error, stackTrace) {
      await AppLogger.error('Firebase.initializeApp failed', error, stackTrace);
      return;
    }

    await _ensureLocalNotificationsInitialized();
    await _requestNotificationPermissions();
    await _consumePendingNotificationResponses();

    final messaging = FirebaseMessaging.instance;
    try {
      await messaging.setAutoInitEnabled(true);
    } catch (error, stackTrace) {
      await AppLogger.error('FCM auto-init enabling failed', error, stackTrace);
    }

    // Detect project/sender-id change and force refresh
    try {
      final currentSenderId =
          DefaultFirebaseOptions.currentPlatform.messagingSenderId;
      final prefs = await SharedPreferences.getInstance();
      final lastSenderId = prefs.getString(_kLastSenderIdPrefsKey);

      if (lastSenderId != null && lastSenderId != currentSenderId) {
        AppLogger.info(
          'FCM Sender ID changed from $lastSenderId to $currentSenderId. Forcing token refresh.',
        );
        await messaging.deleteToken();
      }
      await prefs.setString(_kLastSenderIdPrefsKey, currentSenderId);
    } catch (e) {
      AppLogger.warn('Failed to check for Sender ID change: $e');
    }

    try {
      final token = await messaging.getToken();
      if ((token ?? '').trim().isNotEmpty) {
        AppLogger.info('--- FCM TOKEN START ---');
        AppLogger.info(token!.trim());
        AppLogger.info('--- FCM TOKEN END ---');
        await _registerToken(token.trim());
      }
    } catch (error, stackTrace) {
      await AppLogger.error('FCM getToken failed', error, stackTrace);
    }

    _tokenRefreshSub = messaging.onTokenRefresh.listen(
      (token) => unawaited(_registerToken(token)),
      onError: (Object error, StackTrace stackTrace) async {
        await AppLogger.error(
          'FCM token refresh listener failed',
          error,
          stackTrace,
        );
      },
    );

    _foregroundMessageSub = FirebaseMessaging.onMessage.listen(
      (message) => unawaited(_handleForegroundRemoteMessage(message)),
      onError: (Object error, StackTrace stackTrace) async {
        await AppLogger.error('FCM onMessage failed', error, stackTrace);
      },
    );

    _messageOpenSub = FirebaseMessaging.onMessageOpenedApp.listen(
      (message) => unawaited(_handleMessageTap(message.data)),
      onError: (Object error, StackTrace stackTrace) async {
        await AppLogger.error(
          'FCM onMessageOpenedApp failed',
          error,
          stackTrace,
        );
      },
    );

    _notificationResponseSub = _notificationResponseController.stream.listen(
      (response) => unawaited(_handleLocalNotificationResponse(response)),
      onError: (Object error, StackTrace stackTrace) async {
        await AppLogger.error(
          'Local notification response handler failed',
          error,
          stackTrace,
        );
      },
    );

    try {
      final notificationAppLaunchDetails = await _localNotificationsPlugin
          .getNotificationAppLaunchDetails();
      final launchedResponse =
          notificationAppLaunchDetails?.notificationResponse;
      if (launchedResponse != null) {
        await _handleLocalNotificationResponse(launchedResponse);
      }
    } catch (error, stackTrace) {
      await AppLogger.error(
        'Loading launch notification details failed',
        error,
        stackTrace,
      );
    }

    try {
      final initialMessage = await messaging.getInitialMessage();
      if (initialMessage != null) {
        await _handleMessageTap(initialMessage.data);
      }
    } catch (error, stackTrace) {
      await AppLogger.error('FCM getInitialMessage failed', error, stackTrace);
    }
  }

  Future<bool> areNotificationsAuthorized() async {
    try {
      final settings = await FirebaseMessaging.instance
          .getNotificationSettings();
      return settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional;
    } catch (_) {
      return false;
    }
  }

  /// Request notification permission contextually from user-triggered flows.
  Future<void> requestNotificationsPermissionFromUser() async {
    await _requestNotificationPermissions();
    await syncTokenRegistration();
  }

  Future<void> syncTokenRegistration() async {
    if (kIsWeb) {
      return;
    }

    try {
      final token = await FirebaseMessaging.instance.getToken();
      if ((token ?? '').trim().isNotEmpty) {
        await _registerToken(token!.trim());
      }
    } catch (error, stackTrace) {
      await AppLogger.error(
        'Syncing push token registration failed',
        error,
        stackTrace,
      );
    }
  }

  Future<void> _requestNotificationPermissions() async {
    final messaging = FirebaseMessaging.instance;
    try {
      await messaging.requestPermission(alert: true, badge: true, sound: true);
    } catch (error, stackTrace) {
      await AppLogger.error('FCM permission request failed', error, stackTrace);
    }

    if (defaultTargetPlatform != TargetPlatform.android) {
      return;
    }

    final androidImplementation = _localNotificationsPlugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    if (androidImplementation == null) {
      return;
    }

    try {
      await androidImplementation.requestNotificationsPermission();
    } catch (error, stackTrace) {
      await AppLogger.error(
        'Local notifications permission request failed',
        error,
        stackTrace,
      );
    }
  }

  Future<void> _handleForegroundRemoteMessage(RemoteMessage message) async {
    await _showLocalNotificationFromRemoteMessage(message);

    final data = message.data.map(
      (key, value) => MapEntry(key.toString(), '$value'),
    );
    final type = (data['type'] ?? '').trim();

    final title = message.notification?.title?.trim().isNotEmpty == true
        ? message.notification!.title!.trim()
        : (data['title'] ?? data['title_ar'] ?? '').trim();
    final body = message.notification?.body?.trim().isNotEmpty == true
        ? message.notification!.body!.trim()
        : (data['body'] ?? data['body_ar'] ?? '').trim();

    _showInAppBanner(
      title: title.isEmpty
          ? (type == NotificationTypes.courierAssignment
                ? 'طلب توصيل جديد'
                : 'تحديث جديد')
          : title,
      body: body.isEmpty
          ? (type == NotificationTypes.courierAssignment
                ? 'يوجد طلب جديد بانتظار قرارك'
                : 'يوجد إشعار جديد')
          : body,
      highPriority: type == NotificationTypes.courierAssignment,
    );
  }

  void _showInAppBanner({
    required String title,
    required String body,
    required bool highPriority,
  }) {
    final messenger = rootScaffoldMessengerKey.currentState;
    if (messenger == null) {
      return;
    }

    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Text('$title\n$body'),
        behavior: SnackBarBehavior.floating,
        duration: highPriority
            ? const Duration(seconds: 6)
            : const Duration(seconds: 3),
      ),
    );
  }

  Future<void> _syncTokenOnAuthChange() async {
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token != null) {
        await _registerToken(token);
      }
    } catch (_) {}
  }

  Future<void> _registerToken(String token) async {
    final safeToken = token.trim();
    if (safeToken.isEmpty) {
      return;
    }

    try {
      await _ref.read(deviceTokenStoreProvider).setToken(safeToken);

      final deviceId = (await _ref.read(deviceIdProvider.future)).trim();
      final platform = switch (defaultTargetPlatform) {
        TargetPlatform.android => 'android',
        TargetPlatform.iOS => 'ios',
        TargetPlatform.fuchsia => 'unknown',
        TargetPlatform.linux => 'unknown',
        TargetPlatform.macOS => 'unknown',
        TargetPlatform.windows => 'unknown',
      };
      final session = _ref.read(appSessionProvider);
      final rawRole = (session.role ?? '').trim().toLowerCase();
      final role = rawRole.isNotEmpty
          ? rawRole
          : (session.isLoggedIn ? 'customer' : 'guest');

      int? userId;
      if (session.isLoggedIn) {
        final rawUserId = (await _ref.read(secureStoreProvider).getUserId())
            ?.trim();
        final parsed = int.tryParse(rawUserId ?? '');
        if (parsed != null && parsed > 0) {
          userId = parsed;
        }
      }

      final registrationPayload = <String, dynamic>{
        'token': safeToken,
        'fcm_token': safeToken,
        'device_id': deviceId,
        'platform': platform,
        'sender_id': DefaultFirebaseOptions.currentPlatform.messagingSenderId,
        'firebase_project_id': DefaultFirebaseOptions.currentPlatform.projectId,
        'role': role,
        ...?userId == null ? null : <String, dynamic>{'user_id': userId},
        ...?userId == null ? <String, dynamic>{'guest_id': deviceId} : null,
      };

      final registrationEndpoints = <String>{
        Endpoints.devicesRegister(),
        Endpoints.notificationsRegisterToken(),
      };
      final shouldTryAuthenticated =
          session.isLoggedIn && session.hasStoredToken;
      final registrationAuthModes = <bool>[
        if (shouldTryAuthenticated) true,
        false,
      ];

      Object? lastError;
      StackTrace? lastStackTrace;

      for (final endpoint in registrationEndpoints) {
        for (final requiresAuth in registrationAuthModes) {
          try {
            await _registerTokenAtEndpoint(
              endpoint: endpoint,
              deviceId: deviceId,
              payload: registrationPayload,
              requiresAuth: requiresAuth,
            );
            if (endpoint != Endpoints.devicesRegister()) {
              AppLogger.info(
                'FCM token registration used fallback endpoint: $endpoint',
              );
            }
            if (requiresAuth == false && shouldTryAuthenticated) {
              AppLogger.warn(
                'FCM token registration fell back to guest mode after authenticated attempt.',
              );
            }
            return;
          } catch (error, stackTrace) {
            lastError = error;
            lastStackTrace = stackTrace;
            AppLogger.warn(
              'FCM token registration failed at endpoint $endpoint (requiresAuth=$requiresAuth): $error',
            );
          }
        }
      }

      if (lastError != null && lastStackTrace != null) {
        await AppLogger.error(
          'Registering FCM token failed on all endpoints',
          lastError,
          lastStackTrace,
        );
      }
    } catch (error, stackTrace) {
      await AppLogger.error('Registering FCM token failed', error, stackTrace);
    }
  }

  Future<void> _registerTokenAtEndpoint({
    required String endpoint,
    required String deviceId,
    required Map<String, dynamic> payload,
    required bool requiresAuth,
  }) async {
    final response = await _ref
        .read(dioClientProvider)
        .post(
          endpoint,
          data: payload,
          options: Options(
            extra: <String, dynamic>{'requiresAuth': requiresAuth},
            headers: <String, dynamic>{'Device-Id': deviceId},
          ),
        );

    final responseMap = extractMap(response.data);
    final successValue = responseMap['success'];
    final isMarkedSuccess =
        successValue == null ||
        successValue == true ||
        successValue == 1 ||
        successValue == '1';

    if (!isMarkedSuccess) {
      final message = _extractApiErrorMessage(responseMap);
      if (message.isNotEmpty) {
        throw StateError(
          'FCM token registration rejected at $endpoint: $message',
        );
      }
      throw StateError('FCM token registration rejected at $endpoint.');
    }
  }

  String _extractApiErrorMessage(Map<String, dynamic> payload) {
    final nested = extractMap(payload['error']);
    return (nested['message'] ?? payload['message'] ?? '').toString().trim();
  }

  Future<void> _handleLocalNotificationResponse(
    NotificationResponse response,
  ) async {
    final payloadRaw = (response.payload ?? '').trim();
    if (payloadRaw.isEmpty) {
      return;
    }

    Map<String, dynamic> payloadMap;
    try {
      final decoded = jsonDecode(payloadRaw);
      if (decoded is! Map) {
        return;
      }
      payloadMap = decoded.map((key, value) => MapEntry(key.toString(), value));
    } catch (_) {
      return;
    }

    final actionId = (response.actionId ?? '').trim();
    await _handleNotificationPayload(payloadMap, actionId: actionId);
  }

  Future<void> _consumePendingNotificationResponses() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final queue =
          prefs.getStringList(_kPendingNotificationResponsesPrefsKey) ??
          <String>[];
      if (queue.isEmpty) {
        return;
      }
      await prefs.remove(_kPendingNotificationResponsesPrefsKey);

      for (final raw in queue) {
        final decoded = jsonDecode(raw);
        if (decoded is! Map) {
          continue;
        }
        final map = decoded.map(
          (key, value) => MapEntry(key.toString(), value),
        );
        final payloadRaw = '${map['payload'] ?? ''}'.trim();
        if (payloadRaw.isEmpty) {
          continue;
        }
        final payloadDecoded = jsonDecode(payloadRaw);
        if (payloadDecoded is! Map) {
          continue;
        }
        final payloadMap = payloadDecoded.map(
          (key, value) => MapEntry(key.toString(), value),
        );
        await _handleNotificationPayload(
          payloadMap,
          actionId: '${map['action_id'] ?? ''}'.trim(),
        );
      }
    } catch (error, stackTrace) {
      await AppLogger.error(
        'Consuming pending notification responses failed',
        error,
        stackTrace,
      );
    }
  }

  Future<void> _handleNotificationPayload(
    Map<String, dynamic> payloadMap, {
    String actionId = '',
  }) async {
    final type = '${payloadMap['type'] ?? ''}'.trim();

    if (type == NotificationTypes.courierAssignment) {
      final assignment = CourierAssignmentPayload.fromMap(payloadMap);
      final action = switch (actionId) {
        NotificationActions.accept => 'accept',
        NotificationActions.decline => 'decline',
        _ => '',
      };

      final route = AppRoutePaths.courierAssignmentDecisionPath(
        orderId: assignment.orderId,
        amountDue: assignment.amountDue,
        customerName: assignment.customerName,
        address: assignment.address,
        customerPhone: assignment.customerPhone,
        ttlSeconds: assignment.ttlSeconds,
        deepLink: assignment.deepLink,
        action: action,
        receivedAt: assignment.receivedAt.toIso8601String(),
      );
      _ref.read(appRouterProvider).go(route);
      return;
    }

    await _handleMessageTap(payloadMap);
  }

  Future<void> _handleMessageTap(Map<String, dynamic> data) async {
    final openMode = (data['open_mode'] ?? 'in_app').toString().trim();
    final deepLink = (data['deep_link'] ?? '').toString().trim();

    if (deepLink.isEmpty && openMode != 'deals') {
      return;
    }

    if (openMode == 'external') {
      await _openExternalUrl(deepLink);
      return;
    }

    final path = _resolveInAppPath(openMode: openMode, deepLink: deepLink);
    if (path == null || path.isEmpty) {
      return;
    }

    try {
      final router = _ref.read(appRouterProvider);
      router.go(path);
    } catch (error, stackTrace) {
      await AppLogger.error(
        'Handling push deep-link failed',
        error,
        stackTrace,
      );
    }
  }

  Future<void> _openExternalUrl(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) {
      return;
    }
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  String? _resolveInAppPath({
    required String openMode,
    required String deepLink,
  }) {
    final mode = openMode.trim();
    final value = deepLink.trim();

    if (mode == 'deals') {
      return '/deals';
    }

    if (mode == 'product') {
      final id = int.tryParse(value);
      if (id != null && id > 0) {
        return '/product/$id';
      }
    }

    if (mode == 'category') {
      final id = int.tryParse(value);
      if (id != null && id > 0) {
        return '/categories/$id/products';
      }
    }

    if (value.startsWith('/')) {
      return value;
    }

    final uri = Uri.tryParse(value);
    if (uri != null && (uri.scheme == 'http' || uri.scheme == 'https')) {
      unawaited(_openExternalUrl(value));
      return null;
    }

    return null;
  }

  void dispose() {
    _tokenRefreshSub?.cancel();
    _messageOpenSub?.cancel();
    _foregroundMessageSub?.cancel();
    _notificationResponseSub?.cancel();
  }
}
