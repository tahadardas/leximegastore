class AdminNotificationSettings {
  final List<String> managementEmails;
  final List<String> accountingEmails;

  const AdminNotificationSettings({
    this.managementEmails = const [],
    this.accountingEmails = const [],
  });

  factory AdminNotificationSettings.fromJson(Map<String, dynamic> json) {
    List<String> parseList(dynamic value) {
      if (value is List) {
        return value
            .map((e) => e.toString().trim())
            .where((e) => e.isNotEmpty)
            .toList();
      }
      if (value is String) {
        return value
            .split(RegExp(r'[\n,;]'))
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty)
            .toList();
      }
      return const <String>[];
    }

    return AdminNotificationSettings(
      managementEmails: parseList(json['management_emails']),
      accountingEmails: parseList(json['accounting_emails']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'management_emails': managementEmails,
      'accounting_emails': accountingEmails,
    };
  }

  AdminNotificationSettings copyWith({
    List<String>? managementEmails,
    List<String>? accountingEmails,
  }) {
    return AdminNotificationSettings(
      managementEmails: managementEmails ?? this.managementEmails,
      accountingEmails: accountingEmails ?? this.accountingEmails,
    );
  }
}
