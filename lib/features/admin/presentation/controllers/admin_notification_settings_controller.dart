import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/admin_notification_settings_repository.dart';
import '../../domain/entities/admin_notification_settings.dart';

final adminNotificationSettingsControllerProvider =
    AsyncNotifierProvider<
      AdminNotificationSettingsController,
      AdminNotificationSettings
    >(AdminNotificationSettingsController.new);

class AdminNotificationSettingsController
    extends AsyncNotifier<AdminNotificationSettings> {
  @override
  FutureOr<AdminNotificationSettings> build() {
    return _fetch();
  }

  Future<AdminNotificationSettings> _fetch() async {
    final repository = ref.read(adminNotificationSettingsRepositoryProvider);
    return repository.fetchSettings();
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(_fetch);
  }

  Future<void> save({
    required List<String> managementEmails,
    required List<String> accountingEmails,
  }) async {
    final repository = ref.read(adminNotificationSettingsRepositoryProvider);
    state = const AsyncLoading();
    state = await AsyncValue.guard(() {
      return repository.saveSettings(
        managementEmails: managementEmails,
        accountingEmails: accountingEmails,
      );
    });
  }
}
