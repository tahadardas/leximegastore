import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../design_system/lexi_tokens.dart';
import '../../../../design_system/lexi_typography.dart';
import '../../data/realtime/courier_location_realtime_service.dart';
import '../../domain/entities/admin_courier_assignment.dart';
import '../../domain/entities/admin_courier_report.dart';
import '../controllers/admin_courier_reports_controller.dart';

class AdminCourierReportsPage extends ConsumerStatefulWidget {
  const AdminCourierReportsPage({super.key});

  @override
  ConsumerState<AdminCourierReportsPage> createState() =>
      _AdminCourierReportsPageState();
}

class _AdminCourierReportsPageState
    extends ConsumerState<AdminCourierReportsPage> {
  DateTime _selectedDate = DateTime.now();
  int? _selectedCourierId;

  String _friendlyError(Object? error) {
    final raw = (error ?? '').toString().toLowerCase();
    if (raw.contains('401') ||
        raw.contains('forbidden') ||
        raw.contains('unauthorized') ||
        raw.contains('rest_forbidden')) {
      return 'انتهت جلسة الإدارة. يرجى تسجيل الدخول مرة أخرى.';
    }
    if (raw.contains('connection') ||
        raw.contains('socketexception') ||
        raw.contains('xmlhttprequest') ||
        raw.contains('timeout')) {
      return 'تعذر الاتصال بالخادم حالياً. تحقق من الشبكة ثم أعد المحاولة.';
    }
    return 'تعذر تحميل تقارير المندوبين حالياً.';
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2024, 1, 1),
      lastDate: DateTime.now().add(const Duration(days: 1)),
      helpText: 'اختر اليوم',
    );
    if (picked == null) {
      return;
    }

    final normalized = DateTime(picked.year, picked.month, picked.day);
    if (!mounted) {
      return;
    }

    setState(() {
      _selectedDate = normalized;
    });
    await ref
        .read(adminCourierReportsControllerProvider.notifier)
        .setDate(normalized);
  }

  Future<void> _setCourier(int? courierId) async {
    setState(() {
      _selectedCourierId = courierId;
    });
    await ref
        .read(adminCourierReportsControllerProvider.notifier)
        .setCourierId(courierId);
  }

  Future<void> _findCourier(AdminCourierReport courier) async {
    if (!mounted) {
      return;
    }

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return Consumer(
          builder: (context, ref, _) {
            final asyncSnapshot = ref.watch(
              courierLocationStreamProvider(courier.id),
            );

            return SafeArea(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final maxHeight = constraints.maxHeight * 0.9;
                  final insets = MediaQuery.viewInsetsOf(context).bottom;
                  return ConstrainedBox(
                    constraints: BoxConstraints(maxHeight: maxHeight),
                    child: SingleChildScrollView(
                      padding: EdgeInsets.fromLTRB(
                        LexiSpacing.lg,
                        LexiSpacing.lg,
                        LexiSpacing.lg,
                        LexiSpacing.lg + insets,
                      ),
                      child: asyncSnapshot.when(
                        loading: () => Column(
                          mainAxisSize: MainAxisSize.min,
                          children: const [
                            SizedBox(height: 12),
                            CircularProgressIndicator(),
                            SizedBox(height: 12),
                            Text('جاري تحميل موقع المندوب...'),
                          ],
                        ),
                        error: (error, _) => Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'موقع المندوب',
                              style: LexiTypography.h3.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: LexiSpacing.sm),
                            Text(
                              _friendlyError(error),
                              style: LexiTypography.bodyMd,
                            ),
                            const SizedBox(height: LexiSpacing.md),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                onPressed: () => ref
                                    .read(
                                      courierLocationRealtimeServiceProvider,
                                    )
                                    .refreshNow(courier.id, soft: false),
                                icon: const Icon(Icons.refresh),
                                label: const Text('إعادة المحاولة'),
                              ),
                            ),
                          ],
                        ),
                        data: (snapshot) {
                          final location = snapshot.location;
                          if (location == null) {
                            return Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'موقع المندوب',
                                  style: LexiTypography.h3.copyWith(
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(height: LexiSpacing.sm),
                                const Text('لا يوجد موقع مسجل للمندوب بعد.'),
                                const SizedBox(height: LexiSpacing.md),
                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton.icon(
                                    onPressed: () => ref
                                        .read(
                                          courierLocationRealtimeServiceProvider,
                                        )
                                        .refreshNow(courier.id, soft: false),
                                    icon: const Icon(Icons.refresh),
                                    label: const Text('إعادة المحاولة'),
                                  ),
                                ),
                              ],
                            );
                          }

                          return Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      'موقع المندوب: ${courier.displayName.isEmpty ? 'مندوب #${courier.id}' : courier.displayName}',
                                      style: LexiTypography.h3.copyWith(
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                  if (location.isOutdated || snapshot.isStale)
                                    const _TinyBadge(
                                      text: 'الموقع قديم',
                                      color: Colors.redAccent,
                                    ),
                                ],
                              ),
                              const SizedBox(height: LexiSpacing.sm),
                              Text(
                                'آخر تحديث: ${location.updatedAtLocal.isEmpty ? location.updatedAt : location.updatedAtLocal}',
                                style: LexiTypography.bodyMd,
                              ),
                              if (location.ageMinutes != null)
                                Text(
                                  'منذ ${location.ageMinutes} دقيقة',
                                  style: LexiTypography.bodySm,
                                ),
                              const SizedBox(height: LexiSpacing.sm),
                              Text(
                                'الإحداثيات: ${location.lat.toStringAsFixed(6)}, ${location.lng.toStringAsFixed(6)}',
                                style: LexiTypography.bodyMd.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              if (location.accuracyM != null)
                                Text(
                                  'الدقة: ±${location.accuracyM!.toStringAsFixed(0)} م',
                                  style: LexiTypography.bodySm,
                                ),
                              const SizedBox(height: LexiSpacing.md),
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton.icon(
                                  onPressed:
                                      location.mapsNavigateUrl.trim().isEmpty
                                      ? null
                                      : () => _openExternal(
                                          location.mapsNavigateUrl,
                                        ),
                                  icon: const Icon(Icons.navigation_rounded),
                                  label: const Text('بدء الملاحة'),
                                ),
                              ),
                              const SizedBox(height: LexiSpacing.xs),
                              SizedBox(
                                width: double.infinity,
                                child: OutlinedButton.icon(
                                  onPressed: location.mapsOpenUrl.trim().isEmpty
                                      ? null
                                      : () =>
                                            _openExternal(location.mapsOpenUrl),
                                  icon: const Icon(Icons.map_outlined),
                                  label: const Text('فتح الخريطة'),
                                ),
                              ),
                              const SizedBox(height: LexiSpacing.xs),
                              Align(
                                alignment: Alignment.centerRight,
                                child: TextButton.icon(
                                  onPressed: () => ref
                                      .read(
                                        courierLocationRealtimeServiceProvider,
                                      )
                                      .refreshNow(courier.id, soft: false),
                                  icon: const Icon(Icons.refresh),
                                  label: const Text('تحديث الآن'),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                  );
                },
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _openExternal(String rawUrl) async {
    final uri = Uri.tryParse(rawUrl.trim());
    if (uri == null) {
      return;
    }
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _settleAccount(AdminCourierReport courier) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('تسديد حساب المندوب'),
        content: Text(
          'هل أنت متأكد من تسديد كافّة المبالغ غير المحصلة (COD) للمندوب ${courier.displayName}؟\n'
          'إجمالي المبلغ غير المسدد: ${courier.codCollectedSum.toStringAsFixed(2)}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('تأكيد التسديد'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      final total = await ref
          .read(adminCourierReportsControllerProvider.notifier)
          .settleAccount(courier.id);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('تم تسديد مبلغ $total بنجاح.')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('حدث خطأ أثناء التسديد: ${_friendlyError(e)}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final reportAsync = ref.watch(adminCourierReportsControllerProvider);
    final couriersAsync = ref.watch(adminCouriersListForReportProvider);
    final report = reportAsync.valueOrNull;

    if (report == null && reportAsync.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (report == null && reportAsync.hasError) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(LexiSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 42, color: Colors.red),
              const SizedBox(height: LexiSpacing.sm),
              Text(
                _friendlyError(reportAsync.error),
                textAlign: TextAlign.center,
                style: LexiTypography.bodyMd,
              ),
              const SizedBox(height: LexiSpacing.md),
              OutlinedButton.icon(
                onPressed: () => ref
                    .read(adminCourierReportsControllerProvider.notifier)
                    .refresh(),
                icon: const Icon(Icons.refresh),
                label: const Text('إعادة المحاولة'),
              ),
            ],
          ),
        ),
      );
    }

    final data = report!;
    final dateText = DateFormat('yyyy-MM-dd').format(_selectedDate);

    return Scaffold(
      floatingActionButton: FloatingActionButton.small(
        heroTag: 'couriers_report_refresh',
        onPressed: () =>
            ref.read(adminCourierReportsControllerProvider.notifier).refresh(),
        child: const Icon(Icons.refresh),
      ),
      body: RefreshIndicator(
        onRefresh: () =>
            ref.read(adminCourierReportsControllerProvider.notifier).refresh(),
        child: ListView(
          padding: const EdgeInsets.all(LexiSpacing.lg),
          children: [
            _FiltersCard(
              dateText: dateText,
              selectedCourierId: _selectedCourierId,
              couriersAsync: couriersAsync,
              onPickDate: _pickDate,
              onCourierChanged: _setCourier,
            ),
            if (reportAsync.isLoading) ...[
              const SizedBox(height: LexiSpacing.sm),
              const LinearProgressIndicator(minHeight: 3),
            ],
            const SizedBox(height: LexiSpacing.md),
            _SummaryCards(summary: data.summary),
            const SizedBox(height: LexiSpacing.md),
            Text(
              'تفاصيل أداء المندوبين',
              style: LexiTypography.h3.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: LexiSpacing.sm),
            if (data.items.isEmpty)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(LexiSpacing.lg),
                  child: Center(
                    child: Text(
                      'لا توجد بيانات للمندوبين ضمن الفلاتر الحالية.',
                    ),
                  ),
                ),
              )
            else
              ...data.items.map(
                (courier) => _CourierReportCard(
                  courier,
                  onFindCourier: _findCourier,
                  onSettleAccount: _settleAccount,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _FiltersCard extends StatelessWidget {
  final String dateText;
  final int? selectedCourierId;
  final AsyncValue<List<AdminCourier>> couriersAsync;
  final Future<void> Function() onPickDate;
  final Future<void> Function(int?) onCourierChanged;

  const _FiltersCard({
    required this.dateText,
    required this.selectedCourierId,
    required this.couriersAsync,
    required this.onPickDate,
    required this.onCourierChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(LexiSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'فلاتر التقرير',
              style: LexiTypography.labelLg.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: LexiSpacing.sm),
            Wrap(
              spacing: LexiSpacing.sm,
              runSpacing: LexiSpacing.sm,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                OutlinedButton.icon(
                  onPressed: onPickDate,
                  icon: const Icon(Icons.calendar_today_rounded, size: 18),
                  label: Text('اليوم: $dateText'),
                ),
                SizedBox(
                  width: 280,
                  child: couriersAsync.when(
                    loading: () => const LinearProgressIndicator(minHeight: 2),
                    error: (error, stackTrace) =>
                        const Text('تعذر تحميل قائمة المندوبين'),
                    data: (couriers) {
                      return DropdownButtonFormField<int?>(
                        initialValue: selectedCourierId,
                        decoration: const InputDecoration(
                          labelText: 'المندوب',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                        items: [
                          const DropdownMenuItem<int?>(
                            value: null,
                            child: Text('كل المندوبين'),
                          ),
                          ...couriers.whereType<AdminCourier>().map((item) {
                            return DropdownMenuItem<int?>(
                              value: item.id,
                              child: Text(item.displayName),
                            );
                          }),
                        ],
                        onChanged: (value) => onCourierChanged(value),
                      );
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryCards extends StatelessWidget {
  final AdminCouriersReportSummary summary;

  const _SummaryCards({required this.summary});

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      crossAxisSpacing: LexiSpacing.sm,
      mainAxisSpacing: LexiSpacing.sm,
      childAspectRatio: 1.35,
      children: [
        _MetricCard(
          title: 'عدد المندوبين',
          value: summary.couriersCount.toString(),
          icon: Icons.group_rounded,
        ),
        _MetricCard(
          title: 'إسنادات',
          value: summary.assignedTotal.toString(),
          icon: Icons.assignment_ind_rounded,
        ),
        _MetricCard(
          title: 'قبول',
          value: summary.acceptedTotal.toString(),
          icon: Icons.check_circle_outline_rounded,
        ),
        _MetricCard(
          title: 'رفض',
          value: summary.rejectedTotal.toString(),
          icon: Icons.block_rounded,
        ),
        _MetricCard(
          title: 'تسليم',
          value: summary.deliveredTotal.toString(),
          icon: Icons.local_shipping_rounded,
        ),
        _MetricCard(
          title: 'فشل/مرتجع',
          value: summary.failedTotal.toString(),
          icon: Icons.assignment_late_rounded,
        ),
        _MetricCard(
          title: 'COD محصل',
          value: summary.codCollectedTotal.toStringAsFixed(2),
          icon: Icons.payments_rounded,
        ),
        _MetricCard(
          title: 'متوسط دقيقة التسليم',
          value: summary.averageDeliveryMinutes.toStringAsFixed(1),
          icon: Icons.timer_rounded,
        ),
      ],
    );
  }
}

class _MetricCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;

  const _MetricCard({
    required this.title,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(LexiSpacing.md),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: LexiColors.brandBlack),
            const SizedBox(height: LexiSpacing.xs),
            Text(
              value,
              style: LexiTypography.h3.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: LexiTypography.bodySm,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _CourierReportCard extends StatelessWidget {
  final AdminCourierReport courier;
  final Future<void> Function(AdminCourierReport courier) onFindCourier;
  final Future<void> Function(AdminCourierReport courier) onSettleAccount;

  const _CourierReportCard(
    this.courier, {
    required this.onFindCourier,
    required this.onSettleAccount,
  });

  @override
  Widget build(BuildContext context) {
    final statusColor = courier.isAvailable ? Colors.green : Colors.grey;

    return Card(
      margin: const EdgeInsets.only(bottom: LexiSpacing.sm),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(
          horizontal: LexiSpacing.md,
          vertical: LexiSpacing.xs,
        ),
        childrenPadding: const EdgeInsets.fromLTRB(
          LexiSpacing.md,
          0,
          LexiSpacing.md,
          LexiSpacing.md,
        ),
        title: Text(
          courier.displayName.isEmpty
              ? 'مندوب #${courier.id}'
              : courier.displayName,
          style: LexiTypography.labelLg.copyWith(fontWeight: FontWeight.w700),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Wrap(
            spacing: LexiSpacing.sm,
            runSpacing: 4,
            children: [
              _TinyBadge(
                text: courier.isAvailable ? 'متوفر' : 'غير متوفر',
                color: statusColor,
              ),
              _TinyBadge(
                text: 'نشط: ${courier.activeOrdersCount}',
                color: Colors.blueGrey,
              ),
              _TinyBadge(
                text: 'إسناد: ${courier.assignedCount}',
                color: Colors.indigo,
              ),
              _TinyBadge(
                text: 'قبول: ${courier.acceptedCount}',
                color: Colors.teal,
              ),
              _TinyBadge(
                text: 'تسليم: ${courier.deliveredCount}',
                color: Colors.blue,
              ),
              _TinyBadge(
                text: 'فشل/مرتجع: ${courier.failedCount}',
                color: Colors.redAccent,
              ),
              _TinyBadge(
                text: 'COD: ${courier.codCollectedSum.toStringAsFixed(2)}',
                color: Colors.green,
              ),
              _TinyBadge(
                text:
                    'متوسط: ${courier.avgDeliveryMinutes.toStringAsFixed(1)} دقيقة',
                color: Colors.orange,
              ),
            ],
          ),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: LexiSpacing.sm),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton.icon(
                  onPressed: courier.codCollectedSum <= 0
                      ? null
                      : () => onSettleAccount(courier),
                  icon: const Icon(Icons.payments_rounded, size: 18),
                  label: const Text('تسديد الحساب'),
                ),
                const SizedBox(width: LexiSpacing.sm),
                OutlinedButton.icon(
                  onPressed: () => onFindCourier(courier),
                  icon: const Icon(Icons.my_location_rounded, size: 18),
                  label: const Text('إيجاد المندوب'),
                ),
              ],
            ),
          ),
          if (courier.deliveriesToday.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: LexiSpacing.sm),
              child: Text('لا توجد عمليات تسليم مسجلة ضمن المدة المحددة.'),
            )
          else
            ...courier.deliveriesToday.map(
              (entry) => ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.receipt_long_rounded, size: 20),
                title: Text(
                  'طلب #${entry.orderNumber.isEmpty ? entry.orderId : entry.orderNumber}',
                  style: LexiTypography.bodyMd.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                subtitle: Text(
                  'بدء: ${entry.startedAt.isEmpty ? '--' : entry.startedAt}\n'
                  'تسليم: ${entry.deliveredAt.isEmpty ? '--' : entry.deliveredAt}',
                ),
                trailing: Text(
                  entry.durationMinutes == null
                      ? '--'
                      : '${entry.durationMinutes!.toStringAsFixed(1)} د',
                  style: LexiTypography.labelMd.copyWith(
                    color: LexiColors.brandBlack,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _TinyBadge extends StatelessWidget {
  final String text;
  final Color color;

  const _TinyBadge({required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Text(
        text,
        style: LexiTypography.caption.copyWith(
          color: color.withValues(alpha: 0.95),
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
