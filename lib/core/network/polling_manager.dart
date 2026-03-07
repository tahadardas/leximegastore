import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/auth_session_controller.dart';
import '../../features/notifications/data/notifications_realtime_service.dart';
import '../../features/orders/data/realtime/orders_realtime_service.dart';
import 'network_guard.dart';

class PollingManager with WidgetsBindingObserver {
  PollingManager({
    required this.refreshNotifications,
    required this.refreshOrders,
    required this.isAuthenticated,
    required this.networkGuard,
    this.notificationsInterval = const Duration(seconds: 30),
    this.ordersInterval = const Duration(seconds: 45),
    this.courierLocationInterval = const Duration(seconds: 15),
  });

  final Future<void> Function() refreshNotifications;
  final Future<void> Function() refreshOrders;
  final bool Function() isAuthenticated;
  final NetworkGuard networkGuard;

  final Duration notificationsInterval;
  final Duration ordersInterval;
  final Duration courierLocationInterval;

  Timer? _notificationsTimer;
  Timer? _ordersTimer;
  Timer? _courierTimer;
  StreamSubscription<bool>? _connectivitySub;
  final Map<String, _ScreenPoller> _screenPollers = <String, _ScreenPoller>{};

  bool _started = false;
  bool _foreground = true;
  bool _isConnected = true;
  bool _notificationsRunning = false;
  bool _ordersRunning = false;
  bool _courierRunning = false;

  bool _courierEnabled = false;
  Future<void> Function()? _courierTask;

  Future<void> start() async {
    if (_started) {
      return;
    }

    _started = true;
    WidgetsBinding.instance.addObserver(this);

    await networkGuard.start();
    _isConnected = networkGuard.isConnected;
    _connectivitySub = networkGuard.connectivityChanges.listen(
      _handleConnectivityChange,
    );

    _reconcileTimers(triggerImmediate: true);
  }

  void onAuthStateChanged(bool authenticated) {
    if (!authenticated) {
      _cancelCoreTimers();
      return;
    }
    _reconcileTimers(triggerImmediate: true);
  }

  void setCourierLocationPolling({
    required bool enabled,
    Future<void> Function()? task,
  }) {
    _courierEnabled = enabled;
    if (task != null) {
      _courierTask = task;
    }
    _reconcileTimers(triggerImmediate: enabled);
  }

  void registerScreenPoller({
    required String key,
    required Duration interval,
    required Future<void> Function() task,
    bool runImmediately = true,
  }) {
    final normalized = key.trim();
    if (normalized.isEmpty) {
      return;
    }

    final existing = _screenPollers[normalized];
    if (existing != null) {
      existing
        ..interval = interval
        ..task = task;
    } else {
      _screenPollers[normalized] = _ScreenPoller(
        key: normalized,
        interval: interval,
        task: task,
      );
    }

    _reconcileTimers(triggerImmediate: runImmediately);
  }

  void unregisterScreenPoller(String key) {
    final normalized = key.trim();
    final poller = _screenPollers.remove(normalized);
    poller?.timer?.cancel();
  }

  void _handleConnectivityChange(bool connected) {
    _isConnected = connected;
    _reconcileTimers(triggerImmediate: connected);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final isForeground = state == AppLifecycleState.resumed;
    if (_foreground == isForeground) {
      return;
    }
    _foreground = isForeground;
    _reconcileTimers(triggerImmediate: isForeground);
  }

  void _reconcileTimers({required bool triggerImmediate}) {
    final canRunCore =
        _started && _foreground && _isConnected && isAuthenticated();

    if (!canRunCore) {
      _cancelCoreTimers();
      _cancelCourierTimer();
      _reconcileScreenPollers(canRun: false, triggerImmediate: false);
      return;
    }

    _notificationsTimer ??= Timer.periodic(notificationsInterval, (_) {
      unawaited(_runNotificationsPoll());
    });
    _ordersTimer ??= Timer.periodic(ordersInterval, (_) {
      unawaited(_runOrdersPoll());
    });

    if (triggerImmediate) {
      unawaited(_runNotificationsPoll());
      unawaited(_runOrdersPoll());
    }

    final canRunCourier = canRunCore && _courierEnabled && _courierTask != null;
    if (!canRunCourier) {
      _cancelCourierTimer();
    } else {
      _courierTimer ??= Timer.periodic(courierLocationInterval, (_) {
        unawaited(_runCourierPoll());
      });
      if (triggerImmediate) {
        unawaited(_runCourierPoll());
      }
    }

    _reconcileScreenPollers(canRun: true, triggerImmediate: triggerImmediate);
  }

  Future<void> _runNotificationsPoll() async {
    if (_notificationsRunning) {
      return;
    }
    _notificationsRunning = true;
    try {
      await refreshNotifications();
    } finally {
      _notificationsRunning = false;
    }
  }

  Future<void> _runOrdersPoll() async {
    if (_ordersRunning) {
      return;
    }
    _ordersRunning = true;
    try {
      await refreshOrders();
    } finally {
      _ordersRunning = false;
    }
  }

  Future<void> _runCourierPoll() async {
    if (_courierRunning) {
      return;
    }
    final task = _courierTask;
    if (task == null) {
      return;
    }
    _courierRunning = true;
    try {
      await task();
    } finally {
      _courierRunning = false;
    }
  }

  void _cancelCoreTimers() {
    _notificationsTimer?.cancel();
    _ordersTimer?.cancel();
    _notificationsTimer = null;
    _ordersTimer = null;
  }

  void _cancelCourierTimer() {
    _courierTimer?.cancel();
    _courierTimer = null;
  }

  void _reconcileScreenPollers({
    required bool canRun,
    required bool triggerImmediate,
  }) {
    for (final poller in _screenPollers.values) {
      if (!canRun) {
        poller.timer?.cancel();
        poller.timer = null;
        continue;
      }

      poller.timer ??= Timer.periodic(poller.interval, (_) {
        _runScreenPoller(poller);
      });
      if (triggerImmediate) {
        _runScreenPoller(poller);
      }
    }
  }

  void _runScreenPoller(_ScreenPoller poller) {
    if (poller.running) {
      return;
    }
    poller.running = true;
    Future<void>.sync(poller.task).whenComplete(() {
      poller.running = false;
    });
  }

  void dispose() {
    _cancelCoreTimers();
    _cancelCourierTimer();
    for (final poller in _screenPollers.values) {
      poller.timer?.cancel();
    }
    _screenPollers.clear();
    _connectivitySub?.cancel();
    _connectivitySub = null;
    if (_started) {
      WidgetsBinding.instance.removeObserver(this);
    }
    _started = false;
  }
}

final pollingManagerProvider = Provider<PollingManager>((ref) {
  final manager = PollingManager(
    refreshNotifications: () async {
      await ref.read(notificationsRealtimeServiceProvider).refreshNow();
    },
    refreshOrders: () async {
      await ref.read(ordersRealtimeServiceProvider).refreshNow();
    },
    isAuthenticated: () {
      final state = ref.read(authSessionControllerProvider).state;
      return state.status == AuthSessionStatus.authenticated;
    },
    networkGuard: ref.watch(networkGuardProvider),
  );

  ref.listen<AuthSessionState>(
    authSessionControllerProvider.select((controller) => controller.state),
    (previous, next) {
      final authenticated = next.status == AuthSessionStatus.authenticated;
      manager.onAuthStateChanged(authenticated);
      if (!authenticated) {
        ref.read(notificationsRealtimeServiceProvider).clear();
        ref.read(ordersRealtimeServiceProvider).clear();
      }
    },
  );

  unawaited(manager.start());
  ref.onDispose(manager.dispose);
  return manager;
});

final pollingManagerBootstrapProvider = Provider<void>((ref) {
  ref.watch(pollingManagerProvider);
  if (kDebugMode) {
    debugPrint('[PollingManager] bootstrap active');
  }
});

class _ScreenPoller {
  _ScreenPoller({
    required this.key,
    required this.interval,
    required this.task,
  });

  final String key;
  Duration interval;
  Future<void> Function() task;
  Timer? timer;
  bool running = false;
}
