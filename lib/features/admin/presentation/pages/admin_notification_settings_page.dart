import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/lexi_theme.dart';
import '../../../../core/errors/arabic_error_mapper.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../shared/ui/lexi_alert.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../data/repositories/admin_notification_settings_repository.dart';
import '../../domain/entities/admin_notification_settings.dart';
import '../controllers/admin_notification_settings_controller.dart';

class AdminNotificationSettingsPage extends ConsumerStatefulWidget {
  const AdminNotificationSettingsPage({super.key});

  @override
  ConsumerState<AdminNotificationSettingsPage> createState() =>
      _AdminNotificationSettingsPageState();
}

class _AdminNotificationSettingsPageState
    extends ConsumerState<AdminNotificationSettingsPage> {
  final _managementController = TextEditingController();
  final _accountingController = TextEditingController();
  bool _initialized = false;
  bool _isSendingTestEmail = false;

  @override
  void dispose() {
    _managementController.dispose();
    _accountingController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(adminNotificationSettingsControllerProvider);

    ref.listen(adminNotificationSettingsControllerProvider, (prev, next) {
      if (next.hasError) {
        final message = _friendlyError(
          next.error!,
          fallback: 'تعذر حفظ إعدادات الإشعارات حالياً.',
        );
        LexiAlert.error(context, text: message);
      } else if (prev != null &&
          prev.isLoading &&
          next.hasValue &&
          !next.isLoading) {
        LexiAlert.success(context, text: 'تم حفظ إعدادات الإشعارات بنجاح.');
      }
    });

    final settings = state.valueOrNull;
    if (!_initialized && settings != null) {
      _fillForm(settings);
    }

    return Scaffold(
      body: state.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => Center(
          child: Padding(
            padding: const EdgeInsets.all(LexiSpacing.md),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.error_outline,
                  size: 42,
                  color: LexiColors.error,
                ),
                const SizedBox(height: LexiSpacing.sm),
                Text(
                  'تعذر تحميل إعدادات الإشعارات',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: LexiSpacing.xs),
                Text(
                  _friendlyError(
                    e,
                    fallback: 'حدث خطأ غير متوقع أثناء تحميل الإعدادات.',
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: LexiSpacing.md),
                AppButton(
                  label: 'إعادة المحاولة',
                  icon: Icons.refresh,
                  onPressed: () {
                    ref
                        .read(
                          adminNotificationSettingsControllerProvider.notifier,
                        )
                        .refresh();
                  },
                ),
              ],
            ),
          ),
        ),
        data: (_) => SingleChildScrollView(
          padding: const EdgeInsets.all(LexiSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(LexiSpacing.md),
                decoration: BoxDecoration(
                  color: LexiColors.white,
                  border: Border.all(color: LexiColors.outline),
                  borderRadius: BorderRadius.circular(LexiRadius.md),
                ),
                child: const Text(
                  'عند ورود أي طلب جديد، سيتم إرسال تفاصيل الطلب كاملة تلقائياً إلى هذه الإيميلات.',
                ),
              ),
              const SizedBox(height: LexiSpacing.md),
              TextFormField(
                controller: _managementController,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'إيميلات الإدارة',
                  hintText: 'admin1@example.com\nadmin2@example.com',
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: LexiSpacing.md),
              TextFormField(
                controller: _accountingController,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'إيميلات المحاسبة',
                  hintText: 'accounting@example.com',
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: LexiSpacing.sm),
              Text(
                'يمكن إدخال أكثر من بريد (كل سطر بريد، أو مفصولة بفاصلة).',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: LexiColors.secondaryText,
                ),
              ),
              const SizedBox(height: LexiSpacing.lg),
              AppButton(
                label: 'حفظ الإعدادات',
                icon: Icons.save_outlined,
                isLoading: state.isLoading,
                onPressed: _saveSettings,
              ),
              const SizedBox(height: LexiSpacing.sm),
              AppButton(
                label: 'إرسال بريد تجريبي',
                icon: Icons.mark_email_read_outlined,
                type: AppButtonType.outline,
                isLoading: _isSendingTestEmail,
                onPressed: _isSendingTestEmail ? null : _sendTestEmail,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _fillForm(AdminNotificationSettings settings) {
    _initialized = true;
    _managementController.text = settings.managementEmails.join('\n');
    _accountingController.text = settings.accountingEmails.join('\n');
  }

  List<String> _parseEmails(String raw) {
    return raw
        .split(RegExp(r'[\n,;]+'))
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toSet()
        .toList();
  }

  Future<void> _saveSettings() async {
    final management = _parseEmails(_managementController.text);
    final accounting = _parseEmails(_accountingController.text);

    await ref
        .read(adminNotificationSettingsControllerProvider.notifier)
        .save(managementEmails: management, accountingEmails: accounting);
  }

  Future<void> _sendTestEmail() async {
    setState(() => _isSendingTestEmail = true);
    try {
      await ref
          .read(adminNotificationSettingsRepositoryProvider)
          .sendTestEmail(note: 'from_admin_notification_settings_page');

      if (!mounted) return;
      await LexiAlert.success(
        context,
        text: 'تم إرسال بريد الاختبار إلى العناوين المحددة.',
      );
    } catch (e) {
      if (!mounted) return;
      await LexiAlert.error(context, text: _friendlySendTestError(e));
    } finally {
      if (mounted) {
        setState(() => _isSendingTestEmail = false);
      }
    }
  }

  String _friendlyError(Object error, {required String fallback}) {
    return ArabicErrorMapper.map(error, fallback: fallback);
  }

  String _friendlySendTestError(Object error) {
    if (error is DioException) {
      final payload = extractMap(error.response?.data);
      final errorMap = extractMap(payload['error']);
      final serverMessageRaw = (errorMap['message'] ?? payload['message'] ?? '')
          .toString()
          .trim();
      final serverMessage = _normalizeMailErrorMessage(serverMessageRaw);

      if (serverMessage.isNotEmpty) {
        final details = extractMap(errorMap['details']);
        final recipients = (details['recipients'] is List)
            ? (details['recipients'] as List)
                  .map((e) => e.toString().trim())
                  .where((e) => e.isNotEmpty)
                  .toList()
            : const <String>[];

        if (recipients.isNotEmpty) {
          return '$serverMessage\nالمستلمون: ${recipients.join('، ')}';
        }
        return serverMessage;
      }
    }

    return _friendlyError(error, fallback: 'تعذر إرسال بريد الاختبار حالياً.');
  }

  String _normalizeMailErrorMessage(String raw) {
    var message = raw.trim();
    if (message.isEmpty) {
      return message;
    }

    if (message.startsWith('{') || message.startsWith('[')) {
      try {
        final decoded = jsonDecode(message);
        if (decoded is Map<String, dynamic>) {
          final nestedError = extractMap(decoded['error']);
          final nestedMessage =
              (nestedError['message'] ?? decoded['message'] ?? '')
                  .toString()
                  .trim();
          if (nestedMessage.isNotEmpty) {
            message = nestedMessage;
          }
        }
      } catch (_) {}
    }

    final lower = message.toLowerCase();
    if (lower.contains('missing required authentication credential') ||
        lower.contains('invalid_grant') ||
        lower.contains('unauthorized_client') ||
        lower.contains('oauth') ||
        lower.contains('unauthenticated') ||
        lower.contains('invalid credentials')) {
      return 'فشل التحقق من مزود البريد (SMTP/OAuth). أعد ربط البريد من إعدادات WP Mail SMTP ثم أعد المحاولة.';
    }

    return message;
  }
}
