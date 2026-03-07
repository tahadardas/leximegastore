import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import '../auth/auth_session_controller.dart';
import '../network/polling_manager.dart';
import '../../features/delivery/data/repositories/delivery_repository.dart';

enum CourierLocationAccessStatus {
  checking,
  ready,
  servicesDisabled,
  permissionDenied,
  permissionDeniedForever,
  unavailable,
}

class CourierLocationAccessState {
  final CourierLocationAccessStatus status;
  final DateTime? lastPingAt;
  final String? lastError;
  final bool isTrackingActive;

  const CourierLocationAccessState({
    required this.status,
    required this.lastPingAt,
    required this.lastError,
    required this.isTrackingActive,
  });

  const CourierLocationAccessState.initial()
    : this(
        status: CourierLocationAccessStatus.checking,
        lastPingAt: null,
        lastError: null,
        isTrackingActive: false,
      );

  bool get isReady => status == CourierLocationAccessStatus.ready;

  CourierLocationAccessState copyWith({
    CourierLocationAccessStatus? status,
    DateTime? lastPingAt,
    String? lastError,
    bool? isTrackingActive,
  }) {
    return CourierLocationAccessState(
      status: status ?? this.status,
      lastPingAt: lastPingAt ?? this.lastPingAt,
      lastError: lastError,
      isTrackingActive: isTrackingActive ?? this.isTrackingActive,
    );
  }
}

class CourierLocationTracker extends Notifier<CourierLocationAccessState>
    with WidgetsBindingObserver {
  static const Duration _gpsTimeout = Duration(seconds: 12);

  bool _foreground = true;
  bool _sendingPing = false;
  bool _disposed = false;
  bool _trackingEnabled = false;
  bool _stateReady = false;

  @override
  CourierLocationAccessState build() {
    _disposed = false;
    _stateReady = true;
    WidgetsBinding.instance.addObserver(this);
    ref.onDispose(() {
      _disposed = true;
      _stateReady = false;
      WidgetsBinding.instance.removeObserver(this);
      _stopTracking();
    });

    ref.listen<AuthSessionState>(
      authSessionControllerProvider.select((controller) => controller.state),
      (_, _) {
        unawaited(_syncTrackingState());
      },
    );

    // Defer first sync until after initial state is returned.
    Future<void>.microtask(() => _syncTrackingState());
    return const CourierLocationAccessState.initial();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final isForeground = state == AppLifecycleState.resumed;
    if (_foreground == isForeground) {
      return;
    }
    _foreground = isForeground;
    unawaited(_syncTrackingState());
  }

  Future<void> requestAccess() async {
    await _refreshAccessState(requestPermission: true);
    await _syncTrackingState();
  }

  Future<void> refreshAccess() async {
    await _refreshAccessState(requestPermission: false);
    await _syncTrackingState();
  }

  Future<void> forcePing() async {
    await _sendPing();
  }

  Future<void> openLocationSettings() async {
    await Geolocator.openLocationSettings();
  }

  Future<void> openAppSettings() async {
    await Geolocator.openAppSettings();
  }

  Future<void> _syncTrackingState() async {
    if (_disposed || !_stateReady) {
      return;
    }

    if (!_isCourierAuthenticated()) {
      _stopTracking();
      _setState(
        _currentState().copyWith(
          status: CourierLocationAccessStatus.unavailable,
          isTrackingActive: false,
        ),
      );
      return;
    }

    await _refreshAccessState(requestPermission: false);
    if (_disposed) {
      return;
    }
    final current = _currentState();
    if (!_foreground || !current.isReady) {
      _stopTracking();
      _setState(current.copyWith(isTrackingActive: false));
      return;
    }

    _startTracking();
    _setState(current.copyWith(isTrackingActive: true));
  }

  Future<void> _refreshAccessState({required bool requestPermission}) async {
    if (_disposed || !_stateReady) {
      return;
    }

    if (!_isCourierAuthenticated()) {
      _setState(
        _currentState().copyWith(
          status: CourierLocationAccessStatus.unavailable,
        ),
      );
      return;
    }

    final current = _currentState();
    _setState(
      current.copyWith(
        status: CourierLocationAccessStatus.checking,
        isTrackingActive: _trackingEnabled,
      ),
    );

    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (_disposed) {
      return;
    }
    if (!serviceEnabled) {
      _setState(
        _currentState().copyWith(
          status: CourierLocationAccessStatus.servicesDisabled,
        ),
      );
      return;
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied && requestPermission) {
      permission = await Geolocator.requestPermission();
    }
    if (_disposed) {
      return;
    }

    if (permission == LocationPermission.deniedForever) {
      _setState(
        _currentState().copyWith(
          status: CourierLocationAccessStatus.permissionDeniedForever,
        ),
      );
      return;
    }

    if (permission == LocationPermission.denied) {
      _setState(
        _currentState().copyWith(
          status: CourierLocationAccessStatus.permissionDenied,
        ),
      );
      return;
    }

    _setState(
      _currentState().copyWith(status: CourierLocationAccessStatus.ready),
    );
  }

  bool _isCourierAuthenticated() {
    final auth = ref.read(authSessionControllerProvider).state;
    final role = (auth.role ?? '').trim().toLowerCase();
    return auth.status == AuthSessionStatus.authenticated &&
        role == 'delivery_agent';
  }

  void _startTracking() {
    if (_trackingEnabled) {
      return;
    }
    _trackingEnabled = true;
    ref
        .read(pollingManagerProvider)
        .setCourierLocationPolling(enabled: true, task: _sendPing);
    unawaited(_sendPing());
  }

  void _stopTracking() {
    if (!_trackingEnabled) {
      return;
    }
    _trackingEnabled = false;
    ref.read(pollingManagerProvider).setCourierLocationPolling(enabled: false);
  }

  Future<void> _sendPing() async {
    if (_sendingPing ||
        _disposed ||
        !_stateReady ||
        !_foreground ||
        !_isCourierAuthenticated() ||
        !_currentState().isReady) {
      return;
    }

    _sendingPing = true;
    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      ).timeout(_gpsTimeout);

      await ref
          .read(deliveryRepositoryProvider)
          .pingLocation(
            lat: position.latitude,
            lng: position.longitude,
            accuracy: position.accuracy > 0 ? position.accuracy : null,
            heading: position.heading.isNaN ? null : position.heading,
            speed: position.speed.isNaN ? null : position.speed,
          );

      if (_disposed) {
        return;
      }
      _setState(
        _currentState().copyWith(lastPingAt: DateTime.now(), lastError: null),
      );
    } catch (error) {
      if (_disposed) {
        return;
      }
      _setState(_currentState().copyWith(lastError: error.toString()));
    } finally {
      _sendingPing = false;
    }
  }

  CourierLocationAccessState _currentState() {
    try {
      return state;
    } catch (_) {
      return const CourierLocationAccessState.initial();
    }
  }

  void _setState(CourierLocationAccessState next) {
    if (_disposed || !_stateReady) {
      return;
    }
    state = next;
  }
}

final courierLocationTrackerProvider =
    NotifierProvider<CourierLocationTracker, CourierLocationAccessState>(
      CourierLocationTracker.new,
    );
