import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'lexi_tokens.dart';

abstract final class LexiMotion {
  static const Duration fast = Duration(milliseconds: 120);
  static const Duration base = Duration(milliseconds: 220);
  static const Duration slow = Duration(milliseconds: 320);

  static const Duration tap = Duration(milliseconds: 90);
  static const double tapScale = 0.98;

  static const Curve standardCurve = Curves.easeOutCubic;

  static Widget fadeSlideTransition({
    required Animation<double> animation,
    required Widget child,
    Offset begin = const Offset(0.04, 0),
  }) {
    final curved = CurvedAnimation(
      parent: animation,
      curve: standardCurve,
      reverseCurve: Curves.easeInCubic,
    );
    return FadeTransition(
      opacity: curved,
      child: SlideTransition(
        position: Tween<Offset>(begin: begin, end: Offset.zero).animate(curved),
        child: child,
      ),
    );
  }

  static Future<void> lightHaptic() => HapticFeedback.lightImpact();

  static Future<void> mediumHaptic() => HapticFeedback.mediumImpact();
}

class LexiScaleTap extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final BorderRadius? borderRadius;
  final bool enabled;

  const LexiScaleTap({
    super.key,
    required this.child,
    this.onTap,
    this.borderRadius,
    this.enabled = true,
  });

  @override
  State<LexiScaleTap> createState() => _LexiScaleTapState();
}

class _LexiScaleTapState extends State<LexiScaleTap> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return AnimatedScale(
      scale: _pressed ? LexiMotion.tapScale : 1,
      duration: LexiMotion.tap,
      curve: LexiMotion.standardCurve,
      child: Material(
        color: Colors.transparent,
        borderRadius: widget.borderRadius,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          borderRadius: widget.borderRadius,
          onTap: widget.enabled ? widget.onTap : null,
          onTapDown: (_) => setState(() => _pressed = true),
          onTapCancel: () => setState(() => _pressed = false),
          onTapUp: (_) => setState(() => _pressed = false),
          child: widget.child,
        ),
      ),
    );
  }
}

class LexiPulseOnChange extends StatefulWidget {
  final int value;
  final Widget child;

  const LexiPulseOnChange({
    super.key,
    required this.value,
    required this.child,
  });

  @override
  State<LexiPulseOnChange> createState() => _LexiPulseOnChangeState();
}

class _LexiPulseOnChangeState extends State<LexiPulseOnChange>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _animation;
  int _previousValue = 0;

  @override
  void initState() {
    super.initState();
    _previousValue = widget.value;
    _controller = AnimationController(
      duration: LexiDurations.medium,
      vsync: this,
    );
    _animation =
        TweenSequence<double>([
          TweenSequenceItem(
            tween: Tween<double>(begin: 1, end: 1.16),
            weight: 45,
          ),
          TweenSequenceItem(
            tween: Tween<double>(begin: 1.16, end: 1),
            weight: 55,
          ),
        ]).animate(
          CurvedAnimation(parent: _controller, curve: LexiMotion.standardCurve),
        );
  }

  @override
  void didUpdateWidget(covariant LexiPulseOnChange oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value > _previousValue) {
      _controller.forward(from: 0);
    }
    _previousValue = widget.value;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(scale: _animation, child: widget.child);
  }
}
