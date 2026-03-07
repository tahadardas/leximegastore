import 'dart:async';

import 'package:flutter/material.dart';
import 'package:quickalert/quickalert.dart';

import '../../design_system/lexi_tokens.dart';

typedef LexiAlertCallback = FutureOr<void> Function();

/// A helper class for displaying consistent alerts throughout the app.
///
/// Uses QuickAlert under the hood with Lexi design system styling.
/// All alerts are in Arabic to match the app's primary language.
class LexiAlert {
  static int _activeDialogs = 0;
  static bool _isLoadingDialogVisible = false;
  static Completer<void>? _loadingDialogReady;

  static Future<void> _showAlert(Future<dynamic> Function() showCall) async {
    _activeDialogs++;
    try {
      await showCall();
    } finally {
      if (_activeDialogs > 0) {
        _activeDialogs--;
      }
    }
  }

  static Future<void> _dismissAlert(BuildContext context) async {
    await dismiss(context);
  }

  /// Shows a success alert with a checkmark icon.
  ///
  /// [context] - The build context
  /// [title] - The title of the alert (optional)
  /// [text] - The main message of the alert
  /// [onConfirm] - Callback when confirm button is pressed (optional)
  static Future<void> success(
    BuildContext context, {
    String? title,
    required String text,
    LexiAlertCallback? onConfirm,
  }) async {
    await _showAlert(
      () => QuickAlert.show(
        context: context,
        type: QuickAlertType.success,
        title: title ?? 'تم بنجاح',
        text: text,
        confirmBtnText: 'حسنًا',
        confirmBtnColor: LexiColors.success,
        onConfirmBtnTap: () async {
          await _dismissAlert(context);
          await onConfirm?.call();
        },
      ),
    );
  }

  /// Shows an error alert with an error icon.
  ///
  /// [context] - The build context
  /// [title] - The title of the alert (optional)
  /// [text] - The main message of the alert
  /// [onConfirm] - Callback when confirm button is pressed (optional)
  static Future<void> error(
    BuildContext context, {
    String? title,
    required String text,
    LexiAlertCallback? onConfirm,
  }) async {
    await _showAlert(
      () => QuickAlert.show(
        context: context,
        type: QuickAlertType.error,
        title: title ?? 'حدث خطأ',
        text: text,
        confirmBtnText: 'حسنًا',
        confirmBtnColor: LexiColors.error,
        onConfirmBtnTap: () async {
          await _dismissAlert(context);
          await onConfirm?.call();
        },
      ),
    );
  }

  /// Shows a warning alert with a warning icon.
  ///
  /// [context] - The build context
  /// [title] - The title of the alert (optional)
  /// [text] - The main message of the alert
  /// [onConfirm] - Callback when confirm button is pressed (optional)
  static Future<void> warning(
    BuildContext context, {
    String? title,
    required String text,
    LexiAlertCallback? onConfirm,
  }) async {
    await _showAlert(
      () => QuickAlert.show(
        context: context,
        type: QuickAlertType.warning,
        title: title ?? 'تحذير',
        text: text,
        confirmBtnText: 'حسنًا',
        confirmBtnColor: LexiColors.warning,
        onConfirmBtnTap: () async {
          await _dismissAlert(context);
          await onConfirm?.call();
        },
      ),
    );
  }

  /// Shows an info alert with an info icon.
  ///
  /// [context] - The build context
  /// [title] - The title of the alert (optional)
  /// [text] - The main message of the alert
  /// [onConfirm] - Callback when confirm button is pressed (optional)
  static Future<void> info(
    BuildContext context, {
    String? title,
    required String text,
    LexiAlertCallback? onConfirm,
  }) async {
    await _showAlert(
      () => QuickAlert.show(
        context: context,
        type: QuickAlertType.info,
        title: title ?? 'معلومة',
        text: text,
        confirmBtnText: 'حسنًا',
        confirmBtnColor: LexiColors.info,
        onConfirmBtnTap: () async {
          await _dismissAlert(context);
          await onConfirm?.call();
        },
      ),
    );
  }

  /// Shows a confirmation dialog with confirm and cancel buttons.
  ///
  /// [context] - The build context
  /// [title] - The title of the alert (optional)
  /// [text] - The main message of the alert
  /// [confirmText] - Text for the confirm button (default: 'تأكيد')
  /// [cancelText] - Text for the cancel button (default: 'إلغاء')
  /// [onConfirm] - Callback when confirm button is pressed
  /// [onCancel] - Callback when cancel button is pressed (optional)
  static Future<void> confirm(
    BuildContext context, {
    String? title,
    required String text,
    String confirmText = 'تأكيد',
    String cancelText = 'إلغاء',
    required LexiAlertCallback onConfirm,
    LexiAlertCallback? onCancel,
  }) async {
    await _showAlert(
      () => QuickAlert.show(
        context: context,
        type: QuickAlertType.confirm,
        title: title ?? 'تأكيد',
        text: text,
        confirmBtnText: confirmText,
        cancelBtnText: cancelText,
        confirmBtnColor: LexiColors.brandPrimary,
        onConfirmBtnTap: () async {
          await _dismissAlert(context);
          await onConfirm();
        },
        onCancelBtnTap: () async {
          await _dismissAlert(context);
          await onCancel?.call();
        },
      ),
    );
  }

  /// Shows a loading alert that doesn't dismiss automatically.
  ///
  /// [context] - The build context
  /// [text] - The loading message (default: 'جاري التحميل...')
  static Future<void> loading(
    BuildContext context, {
    String text = 'جاري التحميل...',
  }) async {
    if (!context.mounted || _isLoadingDialogVisible) return;

    _isLoadingDialogVisible = true;
    _activeDialogs++;
    final ready = Completer<void>();
    _loadingDialogReady = ready;

    unawaited(
      showDialog<void>(
        context: context,
        barrierDismissible: false,
        useRootNavigator: true,
        builder: (dialogContext) {
          if (!ready.isCompleted) {
            ready.complete();
          }
          return PopScope(
            canPop: false,
            child: AlertDialog(
              content: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2.4),
                  ),
                  const SizedBox(width: 12),
                  Flexible(
                    child: Text(
                      text,
                      textAlign: TextAlign.right,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ).whenComplete(() {
        if (!ready.isCompleted) {
          ready.complete();
        }
        if (_activeDialogs > 0) {
          _activeDialogs--;
        }
        _isLoadingDialogVisible = false;
        if (identical(_loadingDialogReady, ready)) {
          _loadingDialogReady = null;
        }
      }),
    );

    await ready.future;
    await WidgetsBinding.instance.endOfFrame;
  }

  /// Dismisses the current alert.
  ///
  /// [context] - The build context
  static Future<void> dismiss(BuildContext context) async {
    if (!context.mounted) return;
    final navigator = Navigator.of(context, rootNavigator: true);

    if (_isLoadingDialogVisible) {
      final ready = _loadingDialogReady;
      if (ready != null && !ready.isCompleted) {
        try {
          await ready.future.timeout(const Duration(milliseconds: 300));
        } catch (_) {
          // Ignore timeout and try to dismiss anyway.
        }
      }
      if (!context.mounted) return;

      try {
        if (navigator.canPop()) {
          navigator.pop();
          await WidgetsBinding.instance.endOfFrame;
          return;
        }
      } catch (_) {
        // Fallback to generic dismissal below.
      }
    }

    if (_activeDialogs <= 0) return;
    for (var attempt = 0; attempt < 10; attempt++) {
      if (!context.mounted || _activeDialogs <= 0) return;

      try {
        final popped = await navigator.maybePop();
        if (popped) return;
      } catch (_) {
        // Retry on the next frame when navigator lock is released.
      }

      if (attempt < 9) {
        await WidgetsBinding.instance.endOfFrame;
        await Future<void>.delayed(const Duration(milliseconds: 30));
      }
    }
  }

  /// Shows a custom alert with the specified type.
  ///
  /// [context] - The build context
  /// [type] - The QuickAlertType to display
  /// [title] - The title of the alert
  /// [text] - The main message of the alert
  /// [confirmBtnText] - Text for the confirm button (default: 'حسنًا')
  /// [confirmBtnColor] - Color for the confirm button (optional)
  /// [onConfirm] - Callback when confirm button is pressed (optional)
  static Future<void> custom({
    required BuildContext context,
    required QuickAlertType type,
    String? title,
    required String text,
    String confirmBtnText = 'حسنًا',
    Color? confirmBtnColor,
    LexiAlertCallback? onConfirm,
  }) async {
    await _showAlert(
      () => QuickAlert.show(
        context: context,
        type: type,
        title: title,
        text: text,
        confirmBtnText: confirmBtnText,
        confirmBtnColor: confirmBtnColor ?? LexiColors.brandPrimary,
        onConfirmBtnTap: () async {
          await _dismissAlert(context);
          await onConfirm?.call();
        },
      ),
    );
  }
}
