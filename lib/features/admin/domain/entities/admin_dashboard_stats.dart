import '../../../../core/utils/safe_parsers.dart';

class AdminDashboardStats {
  final double todaySales;
  final int todayOrdersCount;
  final int totalOrdersCount;
  final int pendingVerificationCount;
  final int processingCount;

  AdminDashboardStats({
    required this.todaySales,
    required this.todayOrdersCount,
    required this.totalOrdersCount,
    required this.pendingVerificationCount,
    required this.processingCount,
  });

  factory AdminDashboardStats.fromJson(Map<String, dynamic> json) {
    return AdminDashboardStats(
      todaySales: parseDouble(json['today_sales']),
      todayOrdersCount: parseInt(json['today_orders_count']),
      totalOrdersCount: parseInt(json['total_orders_count']),
      pendingVerificationCount: parseInt(json['pending_verification_count']),
      processingCount: parseInt(json['processing_count']),
    );
  }
}
