import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../app/app_keys.dart';
import '../../../../core/auth/auth_session_controller.dart';
import '../../../../core/services/courier_location_tracker.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/utils/safe_parsers.dart';
import '../../../../shared/ui/lexi_alert.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../design_system/lexi_tokens.dart';
import '../../domain/entities/delivery_entities.dart';
import '../controllers/delivery_dashboard_controller.dart';

class DeliveryDashboardPage extends ConsumerStatefulWidget {
  const DeliveryDashboardPage({super.key});

  @override
  ConsumerState<DeliveryDashboardPage> createState() =>
      _DeliveryDashboardPageState();
}

class _DeliveryDashboardPageState extends ConsumerState<DeliveryDashboardPage> {
  bool _availabilityBusy = false;
  bool _locationActionBusy = false;
  final Set<int> _busyOrders = <int>{};
  final Map<int, TextEditingController> _codControllers =
      <int, TextEditingController>{};

  @override
  void initState() {
    super.initState();
    Future.microtask(
      () => ref.read(courierLocationTrackerProvider.notifier).requestAccess(),
    );
  }

  @override
  void dispose() {
    for (final c in _codControllers.values) {
      c.dispose();
    }
    _codControllers.clear();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final locationState = ref.watch(courierLocationTrackerProvider);
    final locationStatus = locationState.status;
    final locationReady = locationState.isReady;

    return Scaffold(
      appBar: AppBar(
        title: const Text('لوحة مندوب التوصيل'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: locationReady
                ? () => ref
                      .read(deliveryDashboardControllerProvider.notifier)
                      .refresh()
                : () => ref
                      .read(courierLocationTrackerProvider.notifier)
                      .refreshAccess(),
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await ref.read(authSessionControllerProvider).logout();
              if (!context.mounted) {
                return;
              }
              context.go('/profile');
            },
          ),
        ],
      ),
      body: !locationReady
          ? _buildLocationRequiredBody(locationStatus)
          : ref
                .watch(deliveryDashboardControllerProvider)
                .when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (error, stackTrace) => Center(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.error_outline,
                            size: 44,
                            color: Colors.redAccent,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'تعذر تحميل لوحة المندوب حالياً.',
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 12),
                          AppButton(
                            label: 'إعادة المحاولة',
                            icon: Icons.refresh,
                            type: AppButtonType.outline,
                            isExpanded: false,
                            onPressed: () => ref
                                .read(
                                  deliveryDashboardControllerProvider.notifier,
                                )
                                .refresh(),
                          ),
                        ],
                      ),
                    ),
                  ),
                  data: (dashboard) {
                    return RefreshIndicator(
                      onRefresh: () => ref
                          .read(deliveryDashboardControllerProvider.notifier)
                          .refresh(),
                      child: ListView(
                        padding: const EdgeInsets.all(16),
                        children: [
                          _buildAvailabilityCard(context, dashboard),
                          const SizedBox(height: 16),
                          Text(
                            'الطلبات المسندة (${dashboard.orders.length})',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 8),
                          if (dashboard.orders.isEmpty)
                            _buildEmptyOrdersCard(context)
                          else
                            ...dashboard.orders.map(
                              (order) => Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: _buildOrderCard(context, order),
                              ),
                            ),
                        ],
                      ),
                    );
                  },
                ),
    );
  }

  Widget _buildLocationRequiredBody(CourierLocationAccessStatus status) {
    final title = switch (status) {
      CourierLocationAccessStatus.checking => 'جاري التحقق من الموقع...',
      CourierLocationAccessStatus.servicesDisabled => 'خدمة الموقع غير مفعلة',
      CourierLocationAccessStatus.permissionDenied => 'صلاحية الموقع مطلوبة',
      CourierLocationAccessStatus.permissionDeniedForever =>
        'تم رفض صلاحية الموقع دائماً',
      CourierLocationAccessStatus.unavailable => 'تعذر التحقق من الموقع',
      CourierLocationAccessStatus.ready => 'الموقع جاهز',
    };

    final message = switch (status) {
      CourierLocationAccessStatus.checking =>
        'يرجى الانتظار حتى ننهي التحقق من صلاحية الموقع.',
      CourierLocationAccessStatus.servicesDisabled =>
        'يجب تشغيل خدمات الموقع حتى يتم عرض طلبات التوصيل.',
      CourierLocationAccessStatus.permissionDenied =>
        'لا يمكن إظهار طلبات المندوب بدون إذن الموقع.',
      CourierLocationAccessStatus.permissionDeniedForever =>
        'تم رفض الإذن نهائياً. افتح إعدادات التطبيق ومنح إذن الموقع.',
      CourierLocationAccessStatus.unavailable =>
        'لا يمكن متابعة عمل المندوب قبل تفعيل وإتاحة الموقع.',
      CourierLocationAccessStatus.ready => '',
    };

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              status == CourierLocationAccessStatus.checking
                  ? Icons.location_searching_outlined
                  : Icons.location_off_outlined,
              size: 52,
              color: LexiColors.brandBlack,
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: Theme.of(context).textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: AppButton(
                label: 'تفعيل الموقع',
                icon: Icons.my_location_outlined,
                isLoading: _locationActionBusy,
                onPressed: _locationActionBusy
                    ? null
                    : () => _runLocationAction(
                        () => ref
                            .read(courierLocationTrackerProvider.notifier)
                            .requestAccess(),
                      ),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: AppButton(
                label: 'فتح الإعدادات',
                icon: Icons.settings_outlined,
                type: AppButtonType.outline,
                isLoading: _locationActionBusy,
                onPressed: _locationActionBusy
                    ? null
                    : () => _runLocationAction(() async {
                        await ref
                            .read(courierLocationTrackerProvider.notifier)
                            .openLocationSettings();
                        await ref
                            .read(courierLocationTrackerProvider.notifier)
                            .openAppSettings();
                        await ref
                            .read(courierLocationTrackerProvider.notifier)
                            .refreshAccess();
                      }),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _runLocationAction(Future<void> Function() action) async {
    if (_locationActionBusy) {
      return;
    }
    setState(() {
      _locationActionBusy = true;
    });
    try {
      await action();
      if (!mounted) {
        return;
      }
      await ref.read(courierLocationTrackerProvider.notifier).forcePing();
      if (!mounted) {
        return;
      }
      if (ref.read(courierLocationTrackerProvider).isReady) {
        await ref.read(deliveryDashboardControllerProvider.notifier).refresh();
      }
    } finally {
      if (mounted) {
        setState(() {
          _locationActionBusy = false;
        });
      }
    }
  }

  Widget _buildAvailabilityCard(
    BuildContext context,
    DeliveryDashboardData dashboard,
  ) {
    final isAvailable = dashboard.profile.isAvailable;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('حالة التوفر', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Theme.of(context).primaryColor.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(LexiRadius.sm),
                border: Border.all(
                  color: Theme.of(context).primaryColor.withValues(alpha: 0.2),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.payments_outlined,
                    color: Theme.of(context).primaryColor,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'إجمالي المبلغ المحصل: ${CurrencyFormatter.formatAmount(dashboard.totalCollectedToday)}',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Theme.of(context).primaryColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              isAvailable
                  ? 'أنت متوفر الآن لاستقبال الطلبات.'
                  : 'أنت غير متوفر الآن ولن يتم إسناد طلبات جديدة.',
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: AppButton(
                    label: isAvailable
                        ? 'تحويل إلى غير متوفر'
                        : 'تحويل إلى متوفر',
                    icon: isAvailable
                        ? Icons.toggle_off_outlined
                        : Icons.toggle_on_outlined,
                    type: isAvailable
                        ? AppButtonType.outline
                        : AppButtonType.primary,
                    isLoading: _availabilityBusy,
                    onPressed: _availabilityBusy
                        ? null
                        : () => _setAvailability(!isAvailable),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyOrdersCard(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const Icon(Icons.inventory_2_outlined, size: 34),
            const SizedBox(height: 8),
            Text(
              'لا توجد طلبات مسندة لك حالياً.',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOrderCard(BuildContext context, DeliveryOrderCard order) {
    final isBusy = _busyOrders.contains(order.id);
    final canMarkOutForDelivery =
        order.deliveryState.trim() != 'out_for_delivery';
    final cod = order.cod;
    final isCod = cod?.isCod == true;
    final isCodLocked = cod?.locked == true;
    final canMarkCompleted =
        order.status.trim() != 'completed' && (!isCod || isCodLocked);

    return Container(
      decoration: BoxDecoration(
        color: LexiColors.white,
        borderRadius: BorderRadius.circular(LexiRadius.md),
        border: Border.all(color: LexiColors.neutral200, width: 1.0),
        boxShadow: LexiShadows.cardLow,
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            context.push('/orders/details', extra: order.fullOrder);
          },
          child: Padding(
            padding: const EdgeInsets.all(LexiSpacing.s16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'طلب #${order.orderNumber}',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    Text(_statusLabel(order.status)),
                  ],
                ),
                const SizedBox(height: 8),
                Text('العميل: ${order.customerName}'),
                if (order.customerPhone.trim().isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4, bottom: 4),
                    child: Row(
                      children: [
                        Expanded(child: Text('الهاتف: ${order.customerPhone}')),
                        IconButton(
                          icon: const Icon(Icons.phone, color: Colors.blue),
                          onPressed: () => _launchPhone(order.customerPhone),
                          tooltip: 'اتصال هاتفي',
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                        const SizedBox(width: 16),
                        IconButton(
                          icon: const Icon(Icons.chat, color: Colors.green),
                          onPressed: () => _launchWhatsApp(order.customerPhone),
                          tooltip: 'مراسلة واتساب',
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      ],
                    ),
                  ),
                if (order.address.trim().isNotEmpty)
                  Text('العنوان: ${order.address}'),
                const SizedBox(height: 8),
                Text(
                  'الإجمالي: ${CurrencyFormatter.formatAmount(order.total)}',
                ),
                if (isCod) ...[
                  const SizedBox(height: 6),
                  Text(
                    'المطلوب تحصيله: ${cod?.expectedAmount ?? '--'} ${cod?.currency ?? ''}',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                      color: isCodLocked ? Colors.green : Colors.deepOrange,
                    ),
                  ),
                  if (isCodLocked)
                    const Text('تم تأكيد التحصيل (مقفل).')
                  else
                    const Text('لم يتم تأكيد التحصيل بعد.'),
                ] else if (order.fullOrder.paymentMethod
                        ?.toString()
                        .toLowerCase()
                        .replaceAll(' ', '') ==
                    'shamcash') ...[
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: Colors.green.shade200),
                    ),
                    child: Text(
                      'المبلغ مُحصَّل عبر شام كاش',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.green.shade800,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
                if (order.date.trim().isNotEmpty)
                  Text('التاريخ: ${_formatDate(order.date)}'),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: AppButton(
                        label: 'بدء التوصيل',
                        icon: Icons.local_shipping_outlined,
                        type: AppButtonType.outline,
                        isLoading: isBusy,
                        onPressed: (!canMarkOutForDelivery || isBusy)
                            ? null
                            : () => _updateOrderStatus(
                                order.id,
                                status: 'out_for_delivery',
                              ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: AppButton(
                        label: 'تم التسليم',
                        icon: Icons.check_circle_outline,
                        isLoading: isBusy,
                        onPressed: (!canMarkCompleted || isBusy)
                            ? null
                            : () => _handleDeliveryCompletion(context, order),
                      ),
                    ),
                  ],
                ),
                if (order.status.trim() != 'completed' &&
                    order.status.trim() != 'cancelled') ...[
                  const SizedBox(height: 8),
                  AppButton(
                    label: 'إلغاء الإسناد',
                    icon: Icons.cancel_outlined,
                    type: AppButtonType.outline,
                    isLoading: isBusy,
                    onPressed: isBusy
                        ? null
                        : () => _cancelAssignment(context, order),
                  ),
                ],
                if (isCod && !isCodLocked) ...[
                  const SizedBox(height: 8),
                  AppButton(
                    label: 'تأكيد تحصيل الدفع',
                    icon: Icons.payments_outlined,
                    type: AppButtonType.primary,
                    isLoading: isBusy,
                    onPressed: isBusy
                        ? null
                        : () => _collectCod(context, order),
                  ),
                ],
                if (order.mapsNavigateUrl.trim().isNotEmpty ||
                    order.mapsOpenUrl.trim().isNotEmpty ||
                    order.address.trim().isNotEmpty) ...[
                  const SizedBox(height: 8),
                  AppButton(
                    label: 'فتح الملاحة',
                    icon: Icons.navigation_outlined,
                    type: AppButtonType.secondary,
                    isLoading: isBusy,
                    onPressed: isBusy ? null : () => _openMaps(order),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _handleDeliveryCompletion(
    BuildContext context,
    DeliveryOrderCard order,
  ) async {
    final cod = order.cod;
    if (cod?.isCod == true && cod?.locked != true) {
      final success = await _collectCod(context, order);
      if (success != true) {
        return;
      }
    }
    if (!context.mounted) return;
    await _updateOrderStatus(order.id, status: 'completed');
  }

  Future<bool> _collectCod(
    BuildContext context,
    DeliveryOrderCard order,
  ) async {
    final cod = order.cod;
    if (cod == null || !cod.isCod) {
      await LexiAlert.error(context, text: 'هذا الطلب ليس دفع عند الاستلام.');
      return false;
    }

    final controller = _codControllers.putIfAbsent(
      order.id,
      () => TextEditingController(text: cod.expectedAmount),
    );

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('تأكيد تحصيل الدفع'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('المطلوب: ${cod.expectedAmount} ${cod.currency}'),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'المبلغ المحصّل',
                  hintText: '0.00',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('إلغاء'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('تأكيد'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      return false;
    }
    if (!context.mounted) {
      return false;
    }

    final value = controller.text.trim();
    if (value.isEmpty) {
      await LexiAlert.error(context, text: 'يرجى إدخال مبلغ التحصيل.');
      return false;
    }

    final collectedAmount = _parseAmount(value);
    if (collectedAmount == null || collectedAmount <= 0) {
      await LexiAlert.error(context, text: 'صيغة المبلغ غير صالحة.');
      return false;
    }

    final expectedAmount = _parseAmount(cod.expectedAmount);
    if (expectedAmount != null &&
        !_isAmountEqual(collectedAmount, expectedAmount)) {
      final expectedText = _formatAmountPlain(expectedAmount);
      final submittedText = _formatAmountPlain(collectedAmount);
      final currency = cod.currency.trim();
      await LexiAlert.error(
        context,
        text:
            'المبلغ المدخل لا يطابق المطلوب. المطلوب $expectedText $currency، المدخل $submittedText $currency.',
      );
      return false;
    }

    final submittedAmountForApi = collectedAmount.toStringAsFixed(2);

    setState(() => _busyOrders.add(order.id));
    try {
      await ref
          .read(deliveryDashboardControllerProvider.notifier)
          .collectCod(
            order.id,
            collectedAmount: submittedAmountForApi,
            currency: cod.currency,
          );
      return true;
    } catch (e) {
      if (!context.mounted) return false;
      final message = _collectCodErrorMessage(
        e,
        cod: cod,
        submittedAmount: submittedAmountForApi,
      );
      await LexiAlert.error(context, text: message);
      return false;
    } finally {
      if (mounted) {
        setState(() => _busyOrders.remove(order.id));
      }
    }
  }

  Future<void> _setAvailability(bool isAvailable) async {
    setState(() => _availabilityBusy = true);
    try {
      await ref
          .read(deliveryDashboardControllerProvider.notifier)
          .setAvailability(isAvailable);
      if (!mounted) {
        return;
      }
      final messenger = rootScaffoldMessengerKey.currentState;
      if (messenger != null) {
        messenger
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: Text(
                isAvailable
                    ? 'تم تفعيل حالة متوفر.'
                    : 'تم تفعيل حالة غير متوفر.',
              ),
            ),
          );
      }
    } catch (e) {
      if (!mounted) {
        return;
      }
      await LexiAlert.error(context, text: 'تعذر تحديث حالة التوفر: $e');
    } finally {
      if (mounted) {
        setState(() => _availabilityBusy = false);
      }
    }
  }

  Future<void> _updateOrderStatus(int orderId, {required String status}) async {
    setState(() => _busyOrders.add(orderId));
    try {
      await ref
          .read(deliveryDashboardControllerProvider.notifier)
          .updateOrderStatus(orderId, status: status);
    } catch (e) {
      if (!mounted) {
        return;
      }
      await LexiAlert.error(context, text: 'تعذر تحديث حالة الطلب: $e');
    } finally {
      if (mounted) {
        setState(() => _busyOrders.remove(orderId));
      }
    }
  }

  Future<void> _cancelAssignment(
    BuildContext context,
    DeliveryOrderCard order,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('إلغاء الإسناد'),
        content: const Text(
          'هل أنت متأكد من رغبتك في إلغاء إسناد هذا الطلب إليك؟ سيتم إشعار الإدارة بذلك.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('تراجع'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('نعم، إلغاء الإسناد'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) {
      return;
    }

    setState(() => _busyOrders.add(order.id));
    try {
      await ref
          .read(deliveryDashboardControllerProvider.notifier)
          .cancelAssignment(order.id);

      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('تم إلغاء الإسناد بنجاح.')));
    } catch (e) {
      if (!context.mounted) return;
      await LexiAlert.error(context, text: 'تعذر إلغاء الإسناد: $e');
    } finally {
      if (mounted) {
        setState(() => _busyOrders.remove(order.id));
      }
    }
  }

  Future<void> _openMaps(DeliveryOrderCard order) async {
    final primary = order.mapsNavigateUrl.trim();
    if (primary.isNotEmpty) {
      final launchedPrimary = await launchUrl(
        Uri.parse(primary),
        mode: LaunchMode.externalApplication,
      );
      if (launchedPrimary) {
        return;
      }
    }

    final fallback = order.mapsOpenUrl.trim();
    if (fallback.isNotEmpty) {
      final launchedFallback = await launchUrl(
        Uri.parse(fallback),
        mode: LaunchMode.platformDefault,
      );
      if (launchedFallback) {
        return;
      }
    }

    final address = order.address.trim();
    if (address.isNotEmpty) {
      final byAddress = Uri.https('www.google.com', '/maps/search/', {
        'api': '1',
        'query': address,
      }).toString();
      final launchedByAddress = await launchUrl(
        Uri.parse(byAddress),
        mode: LaunchMode.externalApplication,
      );
      if (launchedByAddress) {
        return;
      }
    }

    if (!mounted) {
      return;
    }
    await LexiAlert.error(context, text: 'تعذر فتح الملاحة على هذا الجهاز.');
  }

  Future<void> _launchPhone(String phone) async {
    final cleanPhone = phone.replaceAll(RegExp(r'[^\d+]'), '');
    final uri = Uri.parse('tel:$cleanPhone');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  Future<void> _launchWhatsApp(String phone) async {
    var cleanPhone = phone.replaceAll(RegExp(r'[^\d+]'), '');
    if (cleanPhone.startsWith('09') && cleanPhone.length == 10) {
      cleanPhone = '+963${cleanPhone.substring(1)}';
    }
    final msg = Uri.encodeComponent(
      'مرحباً، أنا مندوب Lexi Mega Store، أنا في طريقي إليك',
    );
    final uri = Uri.parse('https://wa.me/$cleanPhone?text=$msg');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  String _statusLabel(String rawStatus) {
    switch (rawStatus.trim().toLowerCase()) {
      case 'pending':
        return 'قيد الانتظار';
      case 'on-hold':
      case 'pending-verification':
        return 'بانتظار التحقق';
      case 'processing':
        return 'قيد المعالجة';
      case 'completed':
        return 'مكتمل';
      case 'cancelled':
        return 'ملغي';
      case 'failed':
        return 'فشل';
      default:
        return rawStatus;
    }
  }

  String _formatDate(String rawDate) {
    if (rawDate.trim().isEmpty) {
      return '--';
    }
    try {
      return DateFormat('yyyy-MM-dd HH:mm').format(DateTime.parse(rawDate));
    } catch (_) {
      return rawDate;
    }
  }

  double? _parseAmount(String raw) {
    return parseDoubleNullable(raw.trim());
  }

  bool _isAmountEqual(double a, double b) {
    return (a - b).abs() < 0.005;
  }

  String _formatAmountPlain(double value) {
    if ((value - value.roundToDouble()).abs() < 0.005) {
      return value.round().toString();
    }
    return value.toStringAsFixed(2);
  }

  String _collectCodErrorMessage(
    Object error, {
    required DeliveryCodInfo cod,
    required String submittedAmount,
  }) {
    const fallback = 'تعذر تأكيد التحصيل. حاول مرة أخرى.';

    if (error is DioException) {
      final body = _asMap(error.response?.data);
      final errorMap = _asMap(body?['error']);
      final code = ((errorMap?['code'] ?? body?['code'] ?? '')).toString();
      final message = ((errorMap?['message'] ?? body?['message'] ?? ''))
          .toString()
          .trim();

      if (code.toLowerCase() == 'amount_mismatch') {
        final details = _asMap(errorMap?['details']);
        final expected = (details?['expected'] ?? cod.expectedAmount)
            .toString()
            .trim();
        final received = (details?['received'] ?? submittedAmount)
            .toString()
            .trim();
        final currency = (details?['currency'] ?? cod.currency)
            .toString()
            .trim();
        if (expected.isNotEmpty && received.isNotEmpty) {
          return 'المبلغ غير مطابق. المطلوب $expected $currency، المدخل $received $currency.';
        }
        return message.isNotEmpty
            ? message
            : 'المبلغ لا يطابق القيمة المطلوبة. يرجى المراجعة.';
      }

      if (message.isNotEmpty) {
        return message;
      }
    }

    final text = error.toString().toLowerCase();
    if (text.contains('amount_mismatch')) {
      final expected = cod.expectedAmount.trim();
      final currency = cod.currency.trim();
      if (expected.isNotEmpty) {
        return 'المبلغ لا يطابق القيمة المطلوبة. المطلوب $expected $currency.';
      }
      return 'المبلغ لا يطابق القيمة المطلوبة.';
    }

    return fallback;
  }

  Map<String, dynamic>? _asMap(dynamic value) {
    if (value is Map<String, dynamic>) {
      return value;
    }
    if (value is Map) {
      return value.map((key, val) => MapEntry(key.toString(), val));
    }
    return null;
  }
}
