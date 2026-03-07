import 'package:flutter/material.dart';

/// Controls the sidebar open/close state and animation.
///
/// Call [init] with a [TickerProvider] before using, and [dispose] when done.
class LexiSidebarController extends ChangeNotifier {
  static const Duration _animationDuration = Duration(milliseconds: 250);

  late final AnimationController _animationController;
  late final Animation<double> animation;

  bool _isOpen = false;
  bool get isOpen => _isOpen;

  /// Initializes the internal [AnimationController].
  /// Must be called in [State.initState] with the state as [vsync].
  void init(TickerProvider vsync) {
    _animationController = AnimationController(
      vsync: vsync,
      duration: _animationDuration,
    );

    animation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );

    _animationController.addStatusListener(_onAnimationStatus);
  }

  void _onAnimationStatus(AnimationStatus status) {
    if (status == AnimationStatus.dismissed) {
      _isOpen = false;
      notifyListeners();
    } else if (status == AnimationStatus.completed) {
      _isOpen = true;
      notifyListeners();
    }
  }

  /// Opens the sidebar.
  void open() {
    _animationController.forward();
  }

  /// Closes the sidebar.
  void close() {
    _animationController.reverse();
  }

  /// Toggles the sidebar open/closed.
  void toggle() {
    if (_animationController.isAnimating) return;
    if (_isOpen) {
      close();
    } else {
      open();
    }
  }

  /// Allows drag gestures to scrub the animation value directly.
  void dragUpdate(double fraction) {
    _animationController.value = fraction.clamp(0.0, 1.0);
  }

  /// Called at the end of a drag to decide whether to complete or reverse.
  void dragEnd(double velocity, double currentValue) {
    const double flingVelocityThreshold = 300.0;

    if (velocity.abs() > flingVelocityThreshold) {
      // Negative velocity = dragging left = closing (for RTL right-side sidebar)
      if (velocity < 0) {
        _animationController.forward();
      } else {
        _animationController.reverse();
      }
    } else {
      if (currentValue > 0.5) {
        _animationController.forward();
      } else {
        _animationController.reverse();
      }
    }
  }

  @override
  void dispose() {
    _animationController.removeStatusListener(_onAnimationStatus);
    _animationController.dispose();
    super.dispose();
  }
}
