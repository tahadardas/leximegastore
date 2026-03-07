import 'package:flutter/material.dart';

class LexiSafeBottom extends StatelessWidget {
  final Widget child;
  final bool keyboardAware;

  const LexiSafeBottom({
    super.key,
    required this.child,
    this.keyboardAware = true,
  });

  @override
  Widget build(BuildContext context) {
    final insets = MediaQuery.of(context);
    final kb = keyboardAware ? insets.viewInsets.bottom : 0.0;
    final sys = insets.padding.bottom;
    final extraBottom = kb > sys ? (kb - sys) : 0.0;

    return SafeArea(
      top: false,
      child: Padding(
        // SafeArea already applies the system bottom inset; only add
        // the keyboard delta so we don't double-apply bottom padding.
        padding: EdgeInsets.only(bottom: extraBottom),
        child: child,
      ),
    );
  }
}

SnackBar lexiFloatingSnackBar(
  BuildContext context, {
  required Widget content,
  SnackBarAction? action,
  Color? backgroundColor,
  Duration? duration,
}) {
  final bottomPad = MediaQuery.of(context).padding.bottom;
  return SnackBar(
    content: content,
    action: action,
    backgroundColor: backgroundColor,
    duration: duration ?? const Duration(seconds: 4),
    behavior: SnackBarBehavior.floating,
    margin: EdgeInsetsDirectional.fromSTEB(12, 0, 12, 12 + bottomPad),
  );
}

