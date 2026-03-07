import '../../../../core/utils/safe_parsers.dart';
import '../../../../core/utils/text_normalizer.dart';

class AdminCourierDeliveryEntry {
  final int orderId;
  final String orderNumber;
  final String startedAt;
  final String deliveredAt;
  final double? durationMinutes;

  const AdminCourierDeliveryEntry({
    required this.orderId,
    required this.orderNumber,
    required this.startedAt,
    required this.deliveredAt,
    required this.durationMinutes,
  });

  factory AdminCourierDeliveryEntry.fromJson(Map<String, dynamic> json) {
    return AdminCourierDeliveryEntry(
      orderId: parseInt(json['order_id']),
      orderNumber: TextNormalizer.normalize(json['order_number']),
      startedAt: TextNormalizer.normalize(json['started_at']),
      deliveredAt: TextNormalizer.normalize(json['delivered_at']),
      durationMinutes: parseDoubleNullable(json['duration_minutes']),
    );
  }
}

class AdminCourierReport {
  final int id;
  final String displayName;
  final String email;
  final String phone;
  final bool isAvailable;
  final int activeOrdersCount;
  final int assignedOrdersCount;
  final int assignedCount;
  final int acceptedCount;
  final int rejectedCount;
  final int deliveredCount;
  final int failedCount;
  final double codCollectedSum;
  final double avgDeliveryMinutes;
  final int deliveredTodayCount;
  final double deliveredTodayAvgMinutes;
  final double deliveredTodayTotalMinutes;
  final List<AdminCourierDeliveryEntry> deliveriesToday;

  const AdminCourierReport({
    required this.id,
    required this.displayName,
    required this.email,
    required this.phone,
    required this.isAvailable,
    required this.activeOrdersCount,
    required this.assignedOrdersCount,
    required this.assignedCount,
    required this.acceptedCount,
    required this.rejectedCount,
    required this.deliveredCount,
    required this.failedCount,
    required this.codCollectedSum,
    required this.avgDeliveryMinutes,
    required this.deliveredTodayCount,
    required this.deliveredTodayAvgMinutes,
    required this.deliveredTodayTotalMinutes,
    required this.deliveriesToday,
  });

  factory AdminCourierReport.fromJson(Map<String, dynamic> json) {
    final detailsRaw = json['deliveries_today'];
    final details = <AdminCourierDeliveryEntry>[];
    if (detailsRaw is List) {
      for (final item in detailsRaw) {
        if (item is Map<String, dynamic>) {
          details.add(AdminCourierDeliveryEntry.fromJson(item));
        } else if (item is Map) {
          details.add(
            AdminCourierDeliveryEntry.fromJson(
              item.map((key, value) => MapEntry(key.toString(), value)),
            ),
          );
        }
      }
    }

    return AdminCourierReport(
      id: parseInt(json['id']),
      displayName: TextNormalizer.normalize(json['display_name']),
      email: TextNormalizer.normalize(json['email']),
      phone: TextNormalizer.normalize(json['phone']),
      isAvailable: parseBool(json['is_available']),
      activeOrdersCount: parseInt(json['active_orders_count']),
      assignedOrdersCount: parseInt(
        json['assigned_orders_count'] ?? json['active_orders_count'],
      ),
      assignedCount: parseInt(
        json['assigned_count'] ?? json['assigned_orders_count'],
      ),
      acceptedCount: parseInt(json['accepted_count']),
      rejectedCount: parseInt(json['rejected_count']),
      deliveredCount: parseInt(
        json['delivered_count'] ?? json['delivered_today_count'],
      ),
      failedCount: parseInt(json['failed_count']),
      codCollectedSum: parseDouble(json['cod_collected_sum']),
      avgDeliveryMinutes: parseDouble(
        json['avg_delivery_minutes'] ?? json['delivered_today_avg_minutes'],
      ),
      deliveredTodayCount: parseInt(
        json['delivered_today_count'] ?? json['delivered_count'],
      ),
      deliveredTodayAvgMinutes: parseDouble(
        json['delivered_today_avg_minutes'],
      ),
      deliveredTodayTotalMinutes: parseDouble(
        json['delivered_today_total_minutes'],
      ),
      deliveriesToday: details,
    );
  }
}

class AdminCouriersReportSummary {
  final int couriersCount;
  final int activeAssignedOrdersTotal;
  final int assignedTotal;
  final int acceptedTotal;
  final int rejectedTotal;
  final int deliveredTotal;
  final int failedTotal;
  final double codCollectedTotal;
  final int deliveredTodayTotal;
  final double averageDeliveryMinutes;

  const AdminCouriersReportSummary({
    required this.couriersCount,
    required this.activeAssignedOrdersTotal,
    required this.assignedTotal,
    required this.acceptedTotal,
    required this.rejectedTotal,
    required this.deliveredTotal,
    required this.failedTotal,
    required this.codCollectedTotal,
    required this.deliveredTodayTotal,
    required this.averageDeliveryMinutes,
  });

  factory AdminCouriersReportSummary.fromJson(Map<String, dynamic> json) {
    return AdminCouriersReportSummary(
      couriersCount: parseInt(json['couriers_count']),
      activeAssignedOrdersTotal: parseInt(json['active_assigned_orders_total']),
      assignedTotal: parseInt(
        json['assigned_total'] ?? json['active_assigned_orders_total'],
      ),
      acceptedTotal: parseInt(json['accepted_total']),
      rejectedTotal: parseInt(json['rejected_total']),
      deliveredTotal: parseInt(
        json['delivered_total'] ?? json['delivered_today_total'],
      ),
      failedTotal: parseInt(json['failed_total']),
      codCollectedTotal: parseDouble(json['cod_collected_total']),
      deliveredTodayTotal: parseInt(
        json['delivered_today_total'] ?? json['delivered_total'],
      ),
      averageDeliveryMinutes: parseDouble(json['average_delivery_minutes']),
    );
  }
}

class AdminCouriersReportResponse {
  final String date;
  final String startLocal;
  final String endLocal;
  final AdminCouriersReportSummary summary;
  final List<AdminCourierReport> items;

  const AdminCouriersReportResponse({
    required this.date,
    required this.startLocal,
    required this.endLocal,
    required this.summary,
    required this.items,
  });

  factory AdminCouriersReportResponse.fromJson(Map<String, dynamic> json) {
    final summaryRaw = json['summary'];
    final summaryMap = summaryRaw is Map<String, dynamic>
        ? summaryRaw
        : summaryRaw is Map
        ? summaryRaw.map((key, value) => MapEntry(key.toString(), value))
        : <String, dynamic>{};

    final windowRaw = json['window'];
    final windowMap = windowRaw is Map<String, dynamic>
        ? windowRaw
        : windowRaw is Map
        ? windowRaw.map((key, value) => MapEntry(key.toString(), value))
        : <String, dynamic>{};

    final itemsRaw = json['items'];
    final items = <AdminCourierReport>[];
    if (itemsRaw is List) {
      for (final item in itemsRaw) {
        if (item is Map<String, dynamic>) {
          items.add(AdminCourierReport.fromJson(item));
        } else if (item is Map) {
          items.add(
            AdminCourierReport.fromJson(
              item.map((key, value) => MapEntry(key.toString(), value)),
            ),
          );
        }
      }
    }

    return AdminCouriersReportResponse(
      date: TextNormalizer.normalize(json['date']),
      startLocal: TextNormalizer.normalize(windowMap['start_local']),
      endLocal: TextNormalizer.normalize(windowMap['end_local']),
      summary: AdminCouriersReportSummary.fromJson(summaryMap),
      items: items,
    );
  }
}
