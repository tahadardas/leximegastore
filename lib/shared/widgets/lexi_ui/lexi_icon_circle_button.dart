import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../../design_system/lexi_motion.dart';
import '../../../design_system/lexi_tokens.dart';

enum LexiHapticType { none, light, medium }

class LexiIconCircleButton extends StatefulWidget {
  final IconData icon;
  final String? tooltip;
  final double size;
  final double iconSize;
  final Color backgroundColor;
  final Color iconColor;
  final List<BoxShadow>? boxShadow;
  final bool enabled;
  final LexiHapticType hapticType;
  final bool enableScaleFeedback;
  final FutureOr<void> Function()? onTap;

  const LexiIconCircleButton({
    super.key,
    required this.icon,
    this.tooltip,
    this.size = 34,
    this.iconSize = 14,
    this.backgroundColor = LexiColors.white,
    this.iconColor = LexiColors.darkBlack,
    this.boxShadow,
    this.enabled = true,
    this.hapticType = LexiHapticType.light,
    this.enableScaleFeedback = true,
    this.onTap,
  });

  @override
  State<LexiIconCircleButton> createState() => _LexiIconCircleButtonState();
}

class _LexiIconCircleButtonState extends State<LexiIconCircleButton> {
  bool _pressed = false;
  bool _busy = false;

  Future<void> _handleTap() async {
    if (!widget.enabled || widget.onTap == null || _busy) {
      return;
    }

    _busy = true;
    try {
      switch (widget.hapticType) {
        case LexiHapticType.none:
          break;
        case LexiHapticType.light:
          HapticFeedback.lightImpact();
          break;
        case LexiHapticType.medium:
          HapticFeedback.mediumImpact();
          break;
      }
      await widget.onTap!.call();
    } finally {
      _busy = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEnabled = widget.enabled && widget.onTap != null;
    final message = (widget.tooltip ?? '').trim();
    final button = AnimatedScale(
      scale: widget.enableScaleFeedback && _pressed ? LexiMotion.tapScale : 1,
      duration: LexiMotion.tap,
      curve: LexiMotion.standardCurve,
      child: DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: widget.backgroundColor,
          boxShadow: widget.boxShadow,
        ),
        child: Material(
          color: Colors.transparent,
          shape: const CircleBorder(),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: isEnabled ? _handleTap : null,
            onTapDown: (_) => setState(() => _pressed = true),
            onTapUp: (_) => setState(() => _pressed = false),
            onTapCancel: () => setState(() => _pressed = false),
            child: SizedBox(
              width: widget.size,
              height: widget.size,
              child: Center(
                child: FaIcon(
                  widget.icon,
                  size: widget.iconSize,
                  color: isEnabled ? widget.iconColor : LexiColors.gray500,
                ),
              ),
            ),
          ),
        ),
      ),
    );

    if (message.isEmpty) {
      return button;
    }

    return Tooltip(message: message, child: button);
  }
}
