import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:intl/intl.dart';

import '../../../../core/utils/order_number_utils.dart';
import '../../../../design_system/lexi_icons.dart';
import '../../../../design_system/lexi_typography.dart';
import '../../../../design_system/lexi_tokens.dart';
import '../../../../shared/widgets/lexi_ui/lexi_app_bar.dart';
import '../../data/repositories/order_repository_impl.dart';
import '../../domain/entities/order_track.dart';

const List<_OrderStepDefinition> _kOrderSteps = <_OrderStepDefinition>[
  _OrderStepDefinition(
    key: 'received',
    title: 'تم الاستلام',
    icon: LexiIcons.package,
  ),
  _OrderStepDefinition(
    key: 'confirmed',
    title: 'تم التأكيد',
    icon: LexiIcons.success,
  ),
  _OrderStepDefinition(
    key: 'preparing',
    title: 'قيد التجهيز',
    icon: FontAwesomeIcons.boxOpen,
  ),
  _OrderStepDefinition(
    key: 'ready_to_ship',
    title: 'جاهز للشحن',
    icon: FontAwesomeIcons.box,
  ),
  _OrderStepDefinition(
    key: 'out_for_delivery',
    title: 'قيد التوصيل',
    icon: LexiIcons.delivery,
  ),
  _OrderStepDefinition(
    key: 'delivered',
    title: 'تم التسليم',
    icon: FontAwesomeIcons.handHoldingHeart,
  ),
];

class OrderStatusPage extends ConsumerStatefulWidget {
  final String? orderNumber;

  const OrderStatusPage({super.key, this.orderNumber});

  @override
  ConsumerState<OrderStatusPage> createState() => _OrderStatusPageState();
}

class _OrderStatusPageState extends ConsumerState<OrderStatusPage> {
  Timer? _pollTimer;
  bool _isLoading = true;
  bool _isRefreshing = false;
  String? _error;
  String? _orderNumber;
  OrderTrackInfo? _trackInfo;

  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> _init() async {
    _orderNumber = normalizeOrderLookupInput(widget.orderNumber ?? '');

    if (_orderNumber == null || _orderNumber!.isEmpty) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isLoading = false;
        _error = 'يرجى إدخال رقم الطلب.';
      });
      return;
    }

    await _refresh(initial: true);
    _pollTimer = Timer.periodic(const Duration(seconds: 20), (_) {
      _refresh(silent: true);
    });
  }

  Future<void> _refresh({bool initial = false, bool silent = false}) async {
    if (!mounted || _orderNumber == null) {
      return;
    }

    if (initial) {
      setState(() {
        _isLoading = true;
        _error = null;
      });
    } else if (!silent) {
      setState(() {
        _isRefreshing = true;
        _error = null;
      });
    }

    try {
      final previousDecision = _trackInfo?.lastDecision;
      final repo = ref.read(orderRepositoryProvider);
      final info = await repo.trackOrderByNumber(orderNumber: _orderNumber!);

      if (!mounted) {
        return;
      }

      setState(() {
        _trackInfo = info;
        _error = null;
        _isLoading = false;
        _isRefreshing = false;
      });

      final decision = info.lastDecision.trim().toLowerCase();
      if (previousDecision != null &&
          previousDecision != decision &&
          (decision == 'approved' || decision == 'rejected')) {
        _showDecisionSnack(decision);
      }
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isLoading = false;
        _isRefreshing = false;
        _error = _friendlyError(error);
      });
    }
  }

  void _showDecisionSnack(String decision) {
    final messenger = ScaffoldMessenger.of(context);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text(
            decision == 'approved'
                ? 'تم قبول طلبك وسيتم تجهيزه.'
                : 'تم رفض الطلب. راجع تفاصيل الطلب أو تواصل مع الدعم.',
          ),
        ),
      );
  }

  String _friendlyError(Object error) {
    final text = error.toString();
    if (text.contains('order_not_found')) {
      return 'الطلب غير موجود.';
    }
    if (text.contains('rate_limited') || text.contains('429')) {
      return 'تم تجاوز عدد المحاولات. حاول لاحقاً.';
    }
    return 'تعذر تحديث حالة الطلب حالياً.';
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: LexiColors.background,
        appBar: const LexiAppBar(title: 'حالة الطلب'),
        body: const _OrderStatusSkeleton(),
      );
    }

    if (_error != null) {
      return Scaffold(
        backgroundColor: LexiColors.background,
        appBar: const LexiAppBar(title: 'حالة الطلب'),
        body: _OrderStatusError(message: _error!, onRetry: () => _refresh()),
      );
    }

    final info = _trackInfo;
    if (info == null) {
      return Scaffold(
        backgroundColor: LexiColors.background,
        appBar: const LexiAppBar(title: 'حالة الطلب'),
        body: const Center(child: Text('لا توجد بيانات للعرض.')),
      );
    }

    final flow = _OrderFlowResolver.resolve(info);

    return Scaffold(
      backgroundColor: LexiColors.background,
      appBar: LexiAppBar(
        title: 'حالة الطلب',
        actions: [
          IconButton(
            tooltip: 'تحديث',
            onPressed: _isRefreshing ? null : _refresh,
            icon: _isRefreshing
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const FaIcon(LexiIcons.refresh, size: 16),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => _refresh(),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(LexiSpacing.md),
          children: [
            _OrderHeaderCard(info: info),
            const SizedBox(height: LexiSpacing.md),
            _OrderProgressStepper(flow: flow),
            const SizedBox(height: LexiSpacing.md),
            _TimelineSection(events: info.timeline),
            if (info.inbox.isNotEmpty) ...[
              const SizedBox(height: LexiSpacing.md),
              _InboxSection(items: info.inbox),
            ],
          ],
        ),
      ),
    );
  }
}

class _OrderHeaderCard extends StatelessWidget {
  final OrderTrackInfo info;

  const _OrderHeaderCard({required this.info});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(LexiSpacing.md),
      decoration: BoxDecoration(
        color: LexiColors.surface,
        borderRadius: BorderRadius.circular(LexiRadius.card),
        border: Border.all(color: LexiColors.borderSubtle),
        boxShadow: LexiShadows.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('الطلب #${info.orderNumber}', style: LexiTypography.h3),
          const SizedBox(height: LexiSpacing.s8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _HeaderChip(
                icon: LexiIcons.orders,
                text: info.statusLabelAr,
                color: LexiColors.brandPrimary,
              ),
              _HeaderChip(
                icon: info.lastDecision.toLowerCase() == 'approved'
                    ? LexiIcons.success
                    : info.lastDecision.toLowerCase() == 'rejected'
                    ? LexiIcons.error
                    : LexiIcons.warning,
                text: _decisionLabel(info.lastDecision),
                color: info.lastDecision.toLowerCase() == 'approved'
                    ? LexiColors.success
                    : info.lastDecision.toLowerCase() == 'rejected'
                    ? LexiColors.error
                    : LexiColors.warning,
              ),
            ],
          ),
          if (info.adminNoteAr != null &&
              info.adminNoteAr!.trim().isNotEmpty) ...[
            const SizedBox(height: LexiSpacing.s8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(LexiSpacing.s8),
              decoration: BoxDecoration(
                color: LexiColors.surfaceAlt,
                borderRadius: BorderRadius.circular(LexiRadius.button),
                border: Border.all(color: LexiColors.borderSubtle),
              ),
              child: Text(
                info.adminNoteAr!,
                style: LexiTypography.bodyMd.copyWith(
                  color: LexiColors.textSecondary,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _HeaderChip extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color color;

  const _HeaderChip({
    required this.icon,
    required this.text,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: LexiSpacing.s8,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(LexiRadius.full),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          FaIcon(icon, size: 12, color: color),
          const SizedBox(width: 6),
          Text(
            text,
            style: LexiTypography.caption.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _OrderProgressStepper extends StatelessWidget {
  final _OrderFlowState flow;

  const _OrderProgressStepper({required this.flow});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(LexiSpacing.md),
      decoration: BoxDecoration(
        color: LexiColors.surface,
        borderRadius: BorderRadius.circular(LexiRadius.card),
        border: Border.all(color: LexiColors.borderSubtle),
        boxShadow: LexiShadows.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('مراحل الطلب', style: LexiTypography.h3),
          const SizedBox(height: LexiSpacing.md),
          ...List.generate(_kOrderSteps.length, (index) {
            final step = _kOrderSteps[index];
            final isLast = index == _kOrderSteps.length - 1;
            final isCompleted =
                index < flow.currentIndex ||
                (flow.isExceptional && index <= flow.currentIndex);
            final isCurrent = !flow.isExceptional && index == flow.currentIndex;
            final state = isCurrent
                ? _ProgressVisualState.current
                : isCompleted
                ? _ProgressVisualState.completed
                : _ProgressVisualState.future;

            return _OrderStepTile(
              title: step.title,
              icon: step.icon,
              state: state,
              showConnector: !isLast || flow.outcome != null,
            );
          }),
          if (flow.outcome != null)
            _OutcomeTile(outcome: flow.outcome!, showConnector: false),
        ],
      ),
    );
  }
}

class _OrderStepTile extends StatelessWidget {
  final String title;
  final IconData icon;
  final _ProgressVisualState state;
  final bool showConnector;

  const _OrderStepTile({
    required this.title,
    required this.icon,
    required this.state,
    required this.showConnector,
  });

  @override
  Widget build(BuildContext context) {
    final bool isCurrent = state == _ProgressVisualState.current;
    final bool isFuture = state == _ProgressVisualState.future;
    final Color iconBg = isCurrent
        ? LexiColors.brandPrimary
        : isFuture
        ? LexiColors.neutral200
        : LexiColors.success.withValues(alpha: 0.2);
    final Color iconColor = isCurrent
        ? LexiColors.brandBlack
        : isFuture
        ? LexiColors.neutral500
        : LexiColors.success;
    final Color textColor = isCurrent
        ? LexiColors.textPrimary
        : isFuture
        ? LexiColors.neutral500
        : LexiColors.textSecondary;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 24,
          child: Column(
            children: [
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: iconBg,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: FaIcon(
                    state == _ProgressVisualState.completed
                        ? LexiIcons.success
                        : icon,
                    size: 11,
                    color: iconColor,
                  ),
                ),
              ),
              if (showConnector)
                Container(
                  width: 2,
                  height: 32,
                  color: isFuture
                      ? LexiColors.neutral200
                      : LexiColors.success.withValues(alpha: 0.4),
                ),
            ],
          ),
        ),
        const SizedBox(width: LexiSpacing.s8),
        Expanded(
          child: Container(
            margin: const EdgeInsets.only(bottom: LexiSpacing.s8),
            padding: const EdgeInsets.symmetric(
              horizontal: LexiSpacing.s12,
              vertical: LexiSpacing.s8,
            ),
            decoration: BoxDecoration(
              color: isCurrent
                  ? LexiColors.brandPrimary.withValues(alpha: 0.14)
                  : LexiColors.surfaceAlt,
              borderRadius: BorderRadius.circular(LexiRadius.button),
              border: Border.all(
                color: isCurrent
                    ? LexiColors.brandPrimary
                    : LexiColors.borderSubtle,
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: LexiTypography.bodyMd.copyWith(
                      color: textColor,
                      fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w600,
                    ),
                  ),
                ),
                if (isCurrent)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: LexiSpacing.s8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: LexiColors.brandBlack,
                      borderRadius: BorderRadius.circular(LexiRadius.full),
                    ),
                    child: Text(
                      'جاري الآن',
                      style: LexiTypography.caption.copyWith(
                        color: LexiColors.brandWhite,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _OutcomeTile extends StatelessWidget {
  final _ExceptionalOutcome outcome;
  final bool showConnector;

  const _OutcomeTile({required this.outcome, required this.showConnector});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 24,
          child: Column(
            children: [
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: outcome.color.withValues(alpha: 0.18),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: FaIcon(outcome.icon, size: 11, color: outcome.color),
                ),
              ),
              if (showConnector)
                Container(width: 2, height: 28, color: outcome.color),
            ],
          ),
        ),
        const SizedBox(width: LexiSpacing.s8),
        Expanded(
          child: Container(
            margin: const EdgeInsets.only(bottom: LexiSpacing.s8),
            padding: const EdgeInsets.all(LexiSpacing.s12),
            decoration: BoxDecoration(
              color: outcome.color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(LexiRadius.button),
              border: Border.all(color: outcome.color.withValues(alpha: 0.5)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  outcome.title,
                  style: LexiTypography.labelMd.copyWith(color: outcome.color),
                ),
                if (outcome.reason.trim().isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    outcome.reason,
                    style: LexiTypography.bodyMd.copyWith(
                      color: LexiColors.textSecondary,
                    ),
                  ),
                ],
                if (outcome.dateLabel.trim().isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(outcome.dateLabel, style: LexiTypography.caption),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _TimelineSection extends StatelessWidget {
  final List<OrderTrackEvent> events;

  const _TimelineSection({required this.events});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(LexiSpacing.md),
      decoration: BoxDecoration(
        color: LexiColors.surface,
        borderRadius: BorderRadius.circular(LexiRadius.card),
        border: Border.all(color: LexiColors.borderSubtle),
        boxShadow: LexiShadows.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('تفاصيل التحديثات', style: LexiTypography.h3),
          const SizedBox(height: LexiSpacing.s8),
          if (events.isEmpty)
            Text(
              'لا توجد تحديثات بعد.',
              style: LexiTypography.bodyMd.copyWith(
                color: LexiColors.textSecondary,
              ),
            )
          else
            ...events.map(
              (event) => Container(
                margin: const EdgeInsets.only(bottom: LexiSpacing.s8),
                padding: const EdgeInsets.all(LexiSpacing.s8),
                decoration: BoxDecoration(
                  color: LexiColors.surfaceAlt,
                  borderRadius: BorderRadius.circular(LexiRadius.button),
                  border: Border.all(color: LexiColors.borderSubtle),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(top: 3),
                      child: FaIcon(
                        LexiIcons.notifications,
                        size: 12,
                        color: LexiColors.brandPrimary,
                      ),
                    ),
                    const SizedBox(width: LexiSpacing.s8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(event.messageAr, style: LexiTypography.bodyMd),
                          const SizedBox(height: 2),
                          Text(
                            _formatDate(event.createdAt),
                            style: LexiTypography.caption,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _InboxSection extends StatelessWidget {
  final List<OrderTrackInboxItem> items;

  const _InboxSection({required this.items});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(LexiSpacing.md),
      decoration: BoxDecoration(
        color: LexiColors.surface,
        borderRadius: BorderRadius.circular(LexiRadius.card),
        border: Border.all(color: LexiColors.borderSubtle),
        boxShadow: LexiShadows.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('رسائل الطلب', style: LexiTypography.h3),
          const SizedBox(height: LexiSpacing.s8),
          ...items.map(
            (item) => Container(
              margin: const EdgeInsets.only(bottom: LexiSpacing.s8),
              padding: const EdgeInsets.all(LexiSpacing.s8),
              decoration: BoxDecoration(
                color: LexiColors.surfaceAlt,
                borderRadius: BorderRadius.circular(LexiRadius.button),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.title, style: LexiTypography.labelMd),
                  const SizedBox(height: 2),
                  Text(item.message, style: LexiTypography.bodyMd),
                  const SizedBox(height: 2),
                  Text(
                    _formatDate(item.createdAt),
                    style: LexiTypography.caption,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _OrderStatusError extends StatelessWidget {
  final String message;
  final Future<void> Function() onRetry;

  const _OrderStatusError({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(LexiSpacing.md),
      children: [
        Container(
          padding: const EdgeInsets.all(LexiSpacing.md),
          decoration: BoxDecoration(
            color: LexiColors.error.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(LexiRadius.card),
            border: Border.all(color: LexiColors.error.withValues(alpha: 0.5)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.only(top: 2),
                child: FaIcon(
                  LexiIcons.error,
                  size: 16,
                  color: LexiColors.error,
                ),
              ),
              const SizedBox(width: LexiSpacing.s8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      message,
                      style: LexiTypography.bodyMd.copyWith(
                        color: LexiColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: LexiSpacing.s8),
                    OutlinedButton.icon(
                      onPressed: () => onRetry(),
                      icon: const FaIcon(LexiIcons.refresh, size: 14),
                      label: const Text('إعادة المحاولة'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _OrderStatusSkeleton extends StatelessWidget {
  const _OrderStatusSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(LexiSpacing.md),
      children: [
        ...List.generate(
          3,
          (_) => Container(
            margin: const EdgeInsets.only(bottom: LexiSpacing.s12),
            height: 110,
            decoration: BoxDecoration(
              color: LexiColors.neutral200,
              borderRadius: BorderRadius.circular(LexiRadius.card),
            ),
          ),
        ),
      ],
    );
  }
}

class _OrderStepDefinition {
  final String key;
  final String title;
  final IconData icon;

  const _OrderStepDefinition({
    required this.key,
    required this.title,
    required this.icon,
  });
}

enum _ProgressVisualState { completed, current, future }

class _OrderFlowState {
  final int currentIndex;
  final bool isExceptional;
  final _ExceptionalOutcome? outcome;

  const _OrderFlowState({
    required this.currentIndex,
    required this.isExceptional,
    this.outcome,
  });
}

class _ExceptionalOutcome {
  final String title;
  final String reason;
  final String dateLabel;
  final IconData icon;
  final Color color;

  const _ExceptionalOutcome({
    required this.title,
    required this.reason,
    required this.dateLabel,
    required this.icon,
    required this.color,
  });
}

abstract final class _OrderFlowResolver {
  static _OrderFlowState resolve(OrderTrackInfo info) {
    final status = _normalize(info.status);
    final timelineIndex = _timelineStepIndex(info.timeline);
    final statusIndex = _statusStepIndex(status);
    final decisionIndex = _decisionStepIndex(info.lastDecision);
    final reached = math.max(
      timelineIndex,
      math.max(statusIndex, decisionIndex),
    );

    final outcome = _exceptional(info, status);
    return _OrderFlowState(
      currentIndex: reached.clamp(0, _kOrderSteps.length - 1),
      isExceptional: outcome != null,
      outcome: outcome,
    );
  }

  static _ExceptionalOutcome? _exceptional(OrderTrackInfo info, String status) {
    if (_containsAny(status, const ['cancel', 'rejected'])) {
      return _ExceptionalOutcome(
        title: 'ملغي',
        reason: _resolveReason(info),
        dateLabel: _resolveOutcomeDate(info, const ['cancel', 'rejected']),
        icon: FontAwesomeIcons.ban,
        color: LexiColors.error,
      );
    }
    if (_containsAny(status, const ['failed', 'delivery-failed'])) {
      return _ExceptionalOutcome(
        title: 'فشل التوصيل',
        reason: _resolveReason(info),
        dateLabel: _resolveOutcomeDate(info, const ['failed', 'delivery']),
        icon: FontAwesomeIcons.triangleExclamation,
        color: LexiColors.warning,
      );
    }
    if (_containsAny(status, const ['returned', 'refund', 'refunded'])) {
      return _ExceptionalOutcome(
        title: 'مرتجع',
        reason: _resolveReason(info),
        dateLabel: _resolveOutcomeDate(info, const [
          'return',
          'refund',
          'refunded',
        ]),
        icon: FontAwesomeIcons.rotateLeft,
        color: LexiColors.brandAccent,
      );
    }
    if (info.lastDecision.toLowerCase() == 'rejected') {
      return _ExceptionalOutcome(
        title: 'ملغي',
        reason: _resolveReason(info),
        dateLabel: _resolveOutcomeDate(info, const ['reject']),
        icon: FontAwesomeIcons.ban,
        color: LexiColors.error,
      );
    }
    return null;
  }

  static String _resolveReason(OrderTrackInfo info) {
    if ((info.adminNoteAr ?? '').trim().isNotEmpty) {
      return info.adminNoteAr!.trim();
    }
    return info.statusLabelAr;
  }

  static String _resolveOutcomeDate(OrderTrackInfo info, List<String> keys) {
    for (final event in info.timeline.reversed) {
      final text = '${event.type} ${event.messageAr}'.toLowerCase();
      if (_containsAny(text, keys)) {
        return _formatDate(event.createdAt);
      }
    }
    return '';
  }

  static int _timelineStepIndex(List<OrderTrackEvent> events) {
    var maxIndex = 0;
    for (final event in events) {
      final text = '${event.type} ${event.messageAr}'.toLowerCase();
      maxIndex = math.max(maxIndex, _statusStepIndex(text));
    }
    return maxIndex;
  }

  static int _decisionStepIndex(String decision) {
    final normalized = decision.trim().toLowerCase();
    if (normalized == 'approved') {
      return 1;
    }
    return 0;
  }

  static int _statusStepIndex(String status) {
    final value = _normalize(status);
    if (_containsAny(value, const ['delivered', 'completed'])) {
      return 5;
    }
    if (_containsAny(value, const [
      'out-for-delivery',
      'in-transit',
      'shipped',
    ])) {
      return 4;
    }
    if (_containsAny(value, const [
      'ready-to-ship',
      'ready for shipping',
      'packed',
    ])) {
      return 3;
    }
    if (_containsAny(value, const ['processing', 'prepar'])) {
      return 2;
    }
    if (_containsAny(value, const ['confirmed', 'approved'])) {
      return 1;
    }
    return 0;
  }

  static String _normalize(String value) {
    return value.trim().toLowerCase().replaceAll('_', '-');
  }

  static bool _containsAny(String value, List<String> parts) {
    for (final part in parts) {
      if (value.contains(part)) {
        return true;
      }
    }
    return false;
  }
}

String _decisionLabel(String decision) {
  switch (decision.toLowerCase()) {
    case 'approved':
      return 'مقبول';
    case 'rejected':
      return 'مرفوض';
    default:
      return 'بانتظار القرار';
  }
}

String _formatDate(String raw) {
  final date = DateTime.tryParse(raw);
  if (date == null) {
    return raw;
  }
  return DateFormat('yyyy/MM/dd HH:mm').format(date);
}
