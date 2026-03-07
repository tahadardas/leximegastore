import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../config/constants/endpoints.dart';
import '../../../../core/network/dio_client.dart';
import '../../domain/entities/admin_notification_settings.dart';

final adminNotificationSettingsDatasourceProvider =
    Provider<AdminNotificationSettingsDatasource>((ref) {
      return AdminNotificationSettingsDatasource(ref.read(dioClientProvider));
    });

class AdminNotificationSettingsDatasource {
  final DioClient _client;

  AdminNotificationSettingsDatasource(this._client);

  Future<AdminNotificationSettings> fetchSettings() async {
    final response = await _client.get(Endpoints.adminNotificationSettings());
    final map = extractMap(response.data);
    return AdminNotificationSettings.fromJson(map);
  }

  Future<AdminNotificationSettings> saveSettings({
    required List<String> managementEmails,
    required List<String> accountingEmails,
  }) async {
    final response = await _client.patch(
      Endpoints.adminNotificationSettings(),
      data: {
        'management_emails': managementEmails,
        'accounting_emails': accountingEmails,
      },
    );
    final map = extractMap(response.data);
    return AdminNotificationSettings.fromJson(map);
  }

  Future<void> sendTestEmail({String? note}) async {
    await _client.post(
      Endpoints.adminEmailDiagnostics(),
      data: {if ((note ?? '').trim().isNotEmpty) 'note': note!.trim()},
    );
  }
}
