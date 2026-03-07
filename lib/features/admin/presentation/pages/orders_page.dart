import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../app/theme/lexi_theme.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../domain/entities/admin_order.dart';
import '../controllers/admin_orders_controller.dart';

class AdminOrdersPage extends ConsumerStatefulWidget {
  const AdminOrdersPage({super.key});

  @override
  ConsumerState<AdminOrdersPage> createState() => _AdminOrdersPageState();
}

class _AdminOrdersPageState extends ConsumerState<AdminOrdersPage> {
  final ScrollController _scrollController = ScrollController();

  String _friendlyError(Object? error) {
    final raw = (error ?? '').toString().toLowerCase();
    if (raw.contains('401') ||
        raw.contains('forbidden') ||
        raw.contains('unauthorized') ||
        raw.contains('rest_forbidden')) {
      return '\u0627\u0646\u062a\u0647\u062a\u0020\u062c\u0644\u0633\u0629\u0020\u0627\u0644\u0625\u062f\u0627\u0631\u0629\u002e\u0020\u064a\u0631\u062c\u0649\u0020\u062a\u0633\u062c\u064a\u0644\u0020\u0627\u0644\u062f\u062e\u0648\u0644\u0020\u0645\u0646\u0020\u062c\u062f\u064a\u062f\u002e';
    }
    if (raw.contains('connection') ||
        raw.contains('socketexception') ||
        raw.contains('xmlhttprequest') ||
        raw.contains('timeout')) {
      return '\u062a\u0639\u0630\u0631\u0020\u0627\u0644\u0627\u062a\u0635\u0627\u0644\u0020\u0628\u0627\u0644\u062e\u0627\u062f\u0645\u0020\u062d\u0627\u0644\u064a\u0627\u064b\u002e\u0020\u062d\u0627\u0648\u0644\u0020\u0645\u0631\u0629\u0020\u0623\u062e\u0631\u0649\u002e';
    }
    return '\u062a\u0639\u0630\u0631\u0020\u062a\u062d\u0645\u064a\u0644\u0020\u0627\u0644\u0637\u0644\u0628\u0627\u062a\u0020\u062d\u0627\u0644\u064a\u0627\u064b\u002e';
  }

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent * 0.9) {
      ref.read(adminOrdersControllerProvider.notifier).loadMore();
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(adminOrdersControllerProvider);

    // Check if we are loading initial data or filtering
    final isLoading = state.isLoading && !state.hasValue;

    // Data might be present even if loading (e.g. loadMore)
    final orders = state.valueOrNull?.items ?? [];

    return Scaffold(
      floatingActionButton: FloatingActionButton.small(
        heroTag: 'orders_refresh',
        onPressed: () =>
            ref.read(adminOrdersControllerProvider.notifier).refresh(),
        child: const Icon(Icons.refresh),
      ),
      body: Column(
        children: [
          // Filter Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(
              horizontal: LexiSpacing.md,
              vertical: LexiSpacing.sm,
            ),
            child: Row(
              children: [
                _FilterChip(label: 'الكل', status: null),
                const SizedBox(width: 8),
                _FilterChip(
                  label: 'بانتظار التحقق',
                  status: 'pending-verification',
                ), // Matches dashboard/plugin
                const SizedBox(width: 8),
                _FilterChip(label: 'قيد المعالجة', status: 'processing'),
                const SizedBox(width: 8),
                _FilterChip(label: 'مكتمل', status: 'completed'),
                const SizedBox(width: 8),
                _FilterChip(label: 'ملغي', status: 'cancelled'),
              ],
            ),
          ),
          const Divider(height: 1),

          // Orders List
          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : state.hasError && orders.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(LexiSpacing.lg),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.error_outline,
                            color: Colors.redAccent,
                            size: 44,
                          ),
                          const SizedBox(height: LexiSpacing.sm),
                          Text(
                            _friendlyError(state.error),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: LexiSpacing.md),
                          OutlinedButton.icon(
                            onPressed: () => ref
                                .read(adminOrdersControllerProvider.notifier)
                                .refresh(),
                            icon: const Icon(Icons.refresh),
                            label: const Text(
                              '\u0625\u0639\u0627\u062f\u0629\u0020\u0627\u0644\u0645\u062d\u0627\u0648\u0644\u0629',
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : orders.isEmpty
                ? const Center(child: Text('لا توجد طلبات'))
                : ListView.separated(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(LexiSpacing.md),
                    itemCount: orders.length + (state.isLoading ? 1 : 0),
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: LexiSpacing.md),
                    itemBuilder: (context, index) {
                      if (index == orders.length) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      return _AdminOrderCard(order: orders[index]);
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _FilterChip extends ConsumerWidget {
  final String label;
  final String? status;

  const _FilterChip({required this.label, required this.status});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // We need to access the controller to start listening, but the state holds the _currentStatus?
    // Actually the controller holds _currentStatus internally.
    // We can check if calling filter triggers equality check on repo call effectively.
    // Or we can expose currentStatus in the state.
    // For simplicity, let's keep track locally or just select based on UI?
    // Better: let the controller expose selected filter or use a provider for filter state.

    // For now, let's assume we want to set it.
    // Ideally we should know which one is selected to highlight it.
    // We can add `currentStatus` to `AdminOrdersResponse` or use a separate provider.
    // Let's use a separate provider for the filter to make it clean UI-wise?
    // Or just simple state in the widget?
    // The controller resets page on filter change.

    // Let's implement a visual selection check by comparing with what we *think* is selected?
    // No, let's just use the button press to trigger.
    // Refactoring controller to expose filter would be best, but let's stick to simple "click to filter" for now.
    // Actually visual feedback is important.

    return ActionChip(
      label: Text(label),
      onPressed: () {
        ref.read(adminOrdersControllerProvider.notifier).filterByStatus(status);
      },
    );
  }
}

class _AdminOrderCard extends StatelessWidget {
  final AdminOrder order;

  const _AdminOrderCard({required this.order});

  @override
  Widget build(BuildContext context) {
    Color statusColor;
    String statusText;
    switch (order.status) {
      case 'on-hold':
      case 'pending-verification':
        statusColor = Colors.orange;
        statusText = 'بانتظار التحقق';
        break;
      case 'processing':
        statusColor = Colors.blue;
        statusText = 'قيد المعالجة';
        break;
      case 'completed':
        statusColor = Colors.green;
        statusText = 'مكتمل';
        break;
      case 'cancelled':
      case 'failed':
        statusColor = Colors.red;
        statusText = 'ملغي/فشل';
        break;
      default:
        statusColor = Colors.grey;
        statusText = order.status;
    }

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () => context.push('/admin/orders/${order.id}', extra: order),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(LexiSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'طلب #${order.orderNumber}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: statusColor),
                    ),
                    child: Text(
                      statusText,
                      style: TextStyle(
                        color: statusColor,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.person, size: 16, color: Colors.grey),
                  const SizedBox(width: 4),
                  Text(
                    '${order.billing.firstName} ${order.billing.lastName}',
                    style: const TextStyle(fontSize: 14),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(Icons.phone, size: 16, color: Colors.grey),
                  const SizedBox(width: 4),
                  Text(
                    order.billing.phone,
                    style: const TextStyle(fontSize: 14, color: Colors.grey),
                  ),
                ],
              ),
              const Divider(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    CurrencyFormatter.formatAmount(order.total),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: LexiColors.primary,
                    ),
                  ),
                  Text(
                    _formatDate(order.date),
                    style: const TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(Icons.payment, size: 14, color: Colors.grey),
                  const SizedBox(width: 4),
                  Text(
                    order.paymentMethod == 'cod'
                        ? 'الدفع عند الاستلام'
                        : 'شام كاش',
                    style: const TextStyle(fontSize: 12),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null) return '';
    try {
      final date = DateTime.parse(dateStr);
      return DateFormat('yyyy-MM-dd HH:mm').format(date);
    } catch (e) {
      return dateStr;
    }
  }
}
