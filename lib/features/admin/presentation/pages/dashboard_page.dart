import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/utils/currency_formatter.dart';
import '../../../../design_system/lexi_tokens.dart';
import '../../../../design_system/lexi_typography.dart';
import '../../../../shared/widgets/lexi_ui/lexi_button.dart';
import '../../../../shared/widgets/lexi_ui/lexi_card.dart';
import '../../domain/entities/admin_dashboard_stats.dart';
import '../../domain/entities/admin_intel_stats.dart';
import '../controllers/admin_auth_controller.dart';
import '../controllers/admin_dashboard_controller.dart';
import '../controllers/admin_intel_controller.dart';

class DashboardPage extends ConsumerWidget {
  const DashboardPage({super.key});

  String _friendlyDashboardError(Object err) {
    final raw = err.toString().toLowerCase();

    if (raw.contains('401') ||
        raw.contains('forbidden') ||
        raw.contains('unauthorized') ||
        raw.contains('rest_forbidden')) {
      return '\u0627\u0646\u062a\u0647\u062a\u0020\u062c\u0644\u0633\u0629\u0020\u0627\u0644\u0625\u062f\u0627\u0631\u0629\u002e\u0020\u064a\u0631\u062c\u0649\u0020\u062a\u0633\u062c\u064a\u0644\u0020\u0627\u0644\u062f\u062e\u0648\u0644\u0020\u0645\u0631\u0629\u0020\u0623\u062e\u0631\u0649\u002e';
    }

    if (raw.contains('connection') ||
        raw.contains('socketexception') ||
        raw.contains('xmlhttprequest') ||
        raw.contains('timeout')) {
      return '\u062a\u0639\u0630\u0631\u0020\u0627\u0644\u0627\u062a\u0635\u0627\u0644\u0020\u0628\u0627\u0644\u062e\u0627\u062f\u0645\u0020\u062d\u0627\u0644\u064a\u0627\u064b\u002e\u0020\u062a\u062d\u0642\u0642\u0020\u0645\u0646\u0020\u0627\u0644\u0634\u0628\u0643\u0629\u0020\u062b\u0645\u0020\u0623\u0639\u062f\u0020\u0627\u0644\u0645\u062d\u0627\u0648\u0644\u0629\u002e';
    }

    return '\u062a\u0639\u0630\u0631\u0020\u062a\u062d\u0645\u064a\u0644\u0020\u0628\u064a\u0627\u0646\u0627\u062a\u0020\u0644\u0648\u062d\u0629\u0020\u0627\u0644\u062a\u062d\u0643\u0645\u0020\u062d\u0627\u0644\u064a\u0627\u064b\u002e\u0020\u064a\u0631\u062c\u0649\u0020\u0625\u0639\u0627\u062f\u0629\u0020\u0627\u0644\u0645\u062d\u0627\u0648\u0644\u0629\u002e';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(adminAuthControllerProvider);
    final user = authState.asData?.value;
    final dashboardState = ref.watch(adminDashboardControllerProvider);
    final intelState = ref.watch(adminIntelControllerProvider);

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () => Future.wait([
          ref.read(adminDashboardControllerProvider.notifier).refresh(),
          ref.read(adminIntelControllerProvider.notifier).refresh(),
        ]),
        color: LexiColors.brandPrimary,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(LexiSpacing.lg),
          child: Column(
            children: [
              dashboardState.when(
                data: (stats) => intelState.when(
                  data: (intelStats) => _DashboardContent(
                    stats: stats,
                    intelStats: intelStats,
                    userName: user?.displayName,
                    onRefresh: () {
                      ref
                          .read(adminDashboardControllerProvider.notifier)
                          .refresh();
                      ref.read(adminIntelControllerProvider.notifier).refresh();
                    },
                    onExitPanel: () => context.go('/'),
                  ),
                  loading: () => const _DashboardLoading(),
                  error: (err, stack) => _DashboardError(
                    message: _friendlyDashboardError(err),
                    onRetry: () => ref
                        .read(adminIntelControllerProvider.notifier)
                        .refresh(),
                  ),
                ),
                loading: () => const _DashboardLoading(),
                error: (err, stack) => _DashboardError(
                  message: _friendlyDashboardError(err),
                  onRetry: () => ref
                      .read(adminDashboardControllerProvider.notifier)
                      .refresh(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DashboardContent extends StatelessWidget {
  final AdminDashboardStats stats;
  final AdminIntelStats intelStats;
  final String? userName;
  final VoidCallback onRefresh;
  final VoidCallback onExitPanel;

  const _DashboardContent({
    required this.stats,
    required this.intelStats,
    required this.userName,
    required this.onRefresh,
    required this.onExitPanel,
  });

  @override
  Widget build(BuildContext context) {
    final completedCount =
        (stats.totalOrdersCount -
                stats.pendingVerificationCount -
                stats.processingCount)
            .clamp(0, stats.totalOrdersCount);

    final total = stats.totalOrdersCount;
    final pendingRatio = total == 0
        ? 0.0
        : stats.pendingVerificationCount / total;
    final processingRatio = total == 0 ? 0.0 : stats.processingCount / total;
    final completedRatio = total == 0 ? 0.0 : completedCount / total;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'مرحبًا${userName == null ? '' : '، $userName'}',
          style: LexiTypography.h2,
        ),
        const SizedBox(height: LexiSpacing.xs),
        Text(
          'هذه نظرة فورية على أداء المتجر والطلبات.',
          style: LexiTypography.bodyMd.copyWith(color: LexiColors.neutral500),
        ),
        const SizedBox(height: LexiSpacing.lg),

        _HeroSummaryCard(
          todaySales: stats.todaySales,
          todayOrdersCount: stats.todayOrdersCount,
        ),
        const SizedBox(height: LexiSpacing.md),

        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          crossAxisSpacing: LexiSpacing.md,
          mainAxisSpacing: LexiSpacing.md,
          childAspectRatio: 1.28,
          children: [
            _KPICard(
              title: 'مبيعات اليوم',
              value: CurrencyFormatter.formatAmount(stats.todaySales),
              icon: Icons.payments_rounded,
              color: LexiColors.brandBlack,
            ),
            _KPICard(
              title: 'طلبات اليوم',
              value: stats.todayOrdersCount.toString(),
              icon: Icons.today_rounded,
              color: LexiColors.info,
            ),
            _KPICard(
              title: 'كل الطلبات',
              value: stats.totalOrdersCount.toString(),
              icon: Icons.inventory_2_outlined,
              color: LexiColors.brandBlack,
            ),
            _KPICard(
              title: 'بانتظار التحقق',
              value: stats.pendingVerificationCount.toString(),
              icon: Icons.rule_folder_outlined,
              color: LexiColors.warning,
            ),
            _KPICard(
              title: 'قيد المعالجة',
              value: stats.processingCount.toString(),
              icon: Icons.autorenew_rounded,
              color: LexiColors.info,
            ),
            _KPICard(
              title: 'مكتمل',
              value: completedCount.toString(),
              icon: Icons.task_alt_rounded,
              color: LexiColors.success,
            ),
          ],
        ),

        const SizedBox(height: LexiSpacing.xl),
        Text('أداء المتجر (الذكاء)', style: LexiTypography.h3),
        const SizedBox(height: LexiSpacing.md),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          crossAxisSpacing: LexiSpacing.md,
          mainAxisSpacing: LexiSpacing.md,
          childAspectRatio: 1.28,
          children: [
            _KPICard(
              title: 'معدل التحويل',
              value: '${intelStats.conversionRate.toStringAsFixed(2)}%',
              icon: Icons.trending_up_rounded,
              color: LexiColors.success,
            ),
            _KPICard(
              title: 'متوسط قيمة الطلب',
              value: CurrencyFormatter.formatAmount(intelStats.avgOrderValue),
              icon: Icons.shopping_bag_outlined,
              color: LexiColors.brandBlack,
            ),
            _KPICard(
              title: 'الإضافة للسلة',
              value: '${intelStats.addToCartRate.toStringAsFixed(2)}%',
              icon: Icons.add_shopping_cart_rounded,
              color: LexiColors.info,
            ),
            _KPICard(
              title: 'إجمالي الجلسات',
              value: intelStats.sessions.toString(),
              icon: Icons.people_outline_rounded,
              color: LexiColors.brandBlack,
            ),
          ],
        ),

        const SizedBox(height: LexiSpacing.xl),
        Text('مؤشرات الحالة', style: LexiTypography.h3),
        const SizedBox(height: LexiSpacing.md),
        LexiCard(
          child: Column(
            children: [
              _StatusProgressTile(
                label: 'بانتظار التحقق',
                count: stats.pendingVerificationCount,
                total: total,
                progress: pendingRatio,
                color: LexiColors.warning,
              ),
              const SizedBox(height: LexiSpacing.md),
              _StatusProgressTile(
                label: 'قيد المعالجة',
                count: stats.processingCount,
                total: total,
                progress: processingRatio,
                color: LexiColors.info,
              ),
              const SizedBox(height: LexiSpacing.md),
              _StatusProgressTile(
                label: 'مكتمل',
                count: completedCount,
                total: total,
                progress: completedRatio,
                color: LexiColors.success,
              ),
            ],
          ),
        ),

        const SizedBox(height: LexiSpacing.xl),
        Text('إجراءات سريعة', style: LexiTypography.h3),
        const SizedBox(height: LexiSpacing.md),

        _DashboardActionCard(
          title: 'إدارة الطلبات',
          subtitle: 'مراجعة الحالات وتأكيد المدفوعات.',
          icon: Icons.list_alt_rounded,
          onTap: () => context.push('/admin/orders'),
        ),
        const SizedBox(height: LexiSpacing.sm),
        _DashboardActionCard(
          title: 'تقارير المندوبين',
          subtitle:
              'متابعة عدد الطلبات المسندة، التسليمات اليومية، ومتوسط زمن التسليم.',
          icon: Icons.analytics_rounded,
          onTap: () => context.push('/admin/couriers/reports'),
        ),
        const SizedBox(height: LexiSpacing.sm),
        _DashboardActionCard(
          title: 'عروض الفلاش',
          subtitle: 'جدولة الخصومات المؤقتة والعد التنازلي.',
          icon: Icons.flash_on_rounded,
          onTap: () => context.push('/admin/merch/deals'),
        ),
        const SizedBox(height: LexiSpacing.sm),
        _DashboardActionCard(
          title: 'ترتيب الأقسام',
          subtitle: 'التحكم في ظهور وترتيب أقسام الصفحة الرئيسية.',
          icon: Icons.dashboard_customize_rounded,
          onTap: () => context.push('/admin/merch/home-sections'),
        ),
        const SizedBox(height: LexiSpacing.sm),
        _DashboardActionCard(
          title: 'بانرات إعلانية',
          subtitle: 'إدارة بانرات الصور الإعلانية في الصفحة الرئيسية.',
          icon: Icons.photo_library_outlined,
          onTap: () => context.push('/admin/merch/ad-banners'),
        ),
        const SizedBox(height: LexiSpacing.sm),
        _DashboardActionCard(
          title: 'تصنيفات المنتجات',
          subtitle: 'إدارة التصنيفات وترتيب المنتجات داخلها.',
          icon: Icons.category_rounded,
          onTap: () => context.push('/admin/merch/categories'),
        ),
        const SizedBox(height: LexiSpacing.sm),
        _DashboardActionCard(
          title: 'مراجعة التقييمات',
          subtitle: 'الموافقة على تقييمات العملاء أو حذفها.',
          icon: Icons.rate_review_rounded,
          onTap: () => context.push('/admin/merch/reviews'),
        ),
        const SizedBox(height: LexiSpacing.sm),
        _DashboardActionCard(
          title: 'إرسال إشعار يدوي',
          subtitle: 'إرسال تنبيهات مخصصة أو عامة للمستخدمين.',
          icon: Icons.notification_add_rounded,
          onTap: () => context.push('/admin/notifications/send'),
        ),
        const SizedBox(height: LexiSpacing.sm),
        _DashboardActionCard(
          title: 'إدارة المدن والشحن',
          subtitle: 'تعديل أسعار الشحن وتفعيل المناطق.',
          icon: Icons.local_shipping_outlined,
          onTap: () => context.push('/admin/shipping/cities'),
        ),
        const SizedBox(height: LexiSpacing.sm),
        _DashboardActionCard(
          title: 'إشعارات الإدارة',
          subtitle: 'ضبط بريد استقبال الطلبات الجديدة تلقائياً.',
          icon: Icons.mark_email_read_outlined,
          onTap: () => context.push('/admin/notification-settings'),
        ),

        const SizedBox(height: LexiSpacing.sm),
        _DashboardActionCard(
          title: 'فحص اتصال API',
          subtitle: 'تشخيص سريع لاتصال المنتجات والتصنيفات.',
          icon: Icons.network_check_rounded,
          onTap: () => context.push('/debug-api'),
        ),

        const SizedBox(height: LexiSpacing.lg),
        LexiButton(
          label: 'تحديث البيانات الآن',
          icon: Icons.refresh_rounded,
          onPressed: onRefresh,
          isFullWidth: true,
          type: LexiButtonType.secondary,
        ),
        const SizedBox(height: LexiSpacing.sm),
        Center(
          child: TextButton.icon(
            onPressed: onExitPanel,
            icon: const Icon(Icons.exit_to_app, color: LexiColors.error),
            label: Text(
              'الخروج من لوحة التحكم',
              style: LexiTypography.bodyMd.copyWith(color: LexiColors.error),
            ),
          ),
        ),
      ],
    );
  }
}

class _HeroSummaryCard extends StatelessWidget {
  final double todaySales;
  final int todayOrdersCount;

  const _HeroSummaryCard({
    required this.todaySales,
    required this.todayOrdersCount,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(LexiSpacing.md),
      decoration: BoxDecoration(
        color: LexiColors.brandBlack,
        borderRadius: BorderRadius.circular(LexiRadius.lg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'ملخص اليوم',
            style: LexiTypography.labelLg.copyWith(
              color: LexiColors.brandWhite,
            ),
          ),
          const SizedBox(height: LexiSpacing.sm),
          Text(
            CurrencyFormatter.formatAmount(todaySales),
            style: LexiTypography.h1.copyWith(color: LexiColors.brandPrimary),
          ),
          const SizedBox(height: LexiSpacing.xs),
          Text(
            'عدد طلبات اليوم: $todayOrdersCount',
            style: LexiTypography.bodyMd.copyWith(color: LexiColors.neutral300),
          ),
        ],
      ),
    );
  }
}

class _KPICard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _KPICard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return LexiCard(
      padding: const EdgeInsets.all(LexiSpacing.md),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 28, color: color),
          const SizedBox(height: LexiSpacing.sm),
          Text(
            value,
            style: LexiTypography.h3.copyWith(color: color),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: LexiSpacing.xs),
          Text(
            title,
            textAlign: TextAlign.center,
            style: LexiTypography.bodySm.copyWith(color: LexiColors.neutral500),
          ),
        ],
      ),
    );
  }
}

class _StatusProgressTile extends StatelessWidget {
  final String label;
  final int count;
  final int total;
  final double progress;
  final Color color;

  const _StatusProgressTile({
    required this.label,
    required this.count,
    required this.total,
    required this.progress,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final clampedProgress = progress.clamp(0.0, 1.0).toDouble();
    final percent = (clampedProgress * 100).toStringAsFixed(0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: LexiTypography.labelMd),
            Text('$count / $total ($percent%)', style: LexiTypography.bodySm),
          ],
        ),
        const SizedBox(height: LexiSpacing.xs),
        ClipRRect(
          borderRadius: BorderRadius.circular(LexiRadius.full),
          child: LinearProgressIndicator(
            value: clampedProgress,
            minHeight: 8,
            backgroundColor: LexiColors.neutral200,
            color: color,
          ),
        ),
      ],
    );
  }
}

class _DashboardActionCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;

  const _DashboardActionCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(LexiRadius.lg),
      onTap: onTap,
      child: Ink(
        padding: const EdgeInsets.all(LexiSpacing.md),
        decoration: BoxDecoration(
          color: LexiColors.brandWhite,
          borderRadius: BorderRadius.circular(LexiRadius.lg),
          border: Border.all(color: LexiColors.neutral200),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: LexiColors.brandPrimary,
                borderRadius: BorderRadius.circular(LexiRadius.md),
              ),
              child: Icon(icon, color: LexiColors.brandBlack),
            ),
            const SizedBox(width: LexiSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: LexiTypography.labelLg),
                  const SizedBox(height: LexiSpacing.xs),
                  Text(
                    subtitle,
                    style: LexiTypography.bodySm.copyWith(
                      color: LexiColors.neutral500,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios_rounded, size: 16),
          ],
        ),
      ),
    );
  }
}

class _DashboardLoading extends StatelessWidget {
  const _DashboardLoading();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(32.0),
        child: CircularProgressIndicator(color: LexiColors.brandPrimary),
      ),
    );
  }
}

class _DashboardError extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _DashboardError({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: LexiSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 46, color: LexiColors.error),
            const SizedBox(height: LexiSpacing.sm),
            Text(
              '\u062a\u0639\u0630\u0631\u0020\u062a\u062d\u0645\u064a\u0644\u0020\u0628\u064a\u0627\u0646\u0627\u062a\u0020\u0644\u0648\u062d\u0629\u0020\u0627\u0644\u062a\u062d\u0643\u0645',
              style: LexiTypography.h3,
            ),
            const SizedBox(height: LexiSpacing.xs),
            Text(
              message,
              textAlign: TextAlign.center,
              style: LexiTypography.bodySm.copyWith(
                color: LexiColors.neutral500,
              ),
            ),
            const SizedBox(height: LexiSpacing.md),
            LexiButton(
              label:
                  '\u0625\u0639\u0627\u062f\u0629\u0020\u0627\u0644\u0645\u062d\u0627\u0648\u0644\u0629',
              icon: Icons.refresh,
              onPressed: onRetry,
              type: LexiButtonType.secondary,
            ),
          ],
        ),
      ),
    );
  }
}
