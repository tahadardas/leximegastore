import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/admin_notification_settings.dart';
import '../datasources/admin_notification_settings_datasource.dart';

final adminNotificationSettingsRepositoryProvider =
    Provider<AdminNotificationSettingsRepository>((ref) {
      return AdminNotificationSettingsRepository(
        ref.read(adminNotificationSettingsDatasourceProvider),
      );
    });

class AdminNotificationSettingsRepository {
  final AdminNotificationSettingsDatasource _datasource;

  AdminNotificationSettingsRepository(this._datasource);

  Future<AdminNotificationSettings> fetchSettings() {
    return _datasource.fetchSettings();
  }

  Future<AdminNotificationSettings> saveSettings({
    required List<String> managementEmails,
    required List<String> accountingEmails,
  }) {
    return _datasource.saveSettings(
      managementEmails: managementEmails,
      accountingEmails: accountingEmails,
    );
  }

  Future<void> sendTestEmail({String? note}) {
    return _datasource.sendTestEmail(note: note);
  }
}
