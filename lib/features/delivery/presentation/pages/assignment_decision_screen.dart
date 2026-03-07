import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../data/repositories/delivery_repository.dart';

class AssignmentDecisionScreen extends ConsumerStatefulWidget {
  final int orderId;
  final String amountDue;
  final String customerName;
  final String address;
  final String customerPhone;
  final int ttlSeconds;
  final String deepLink;
  final DateTime receivedAt;
  final String initialAction;

  const AssignmentDecisionScreen({
    super.key,
    required this.orderId,
    required this.amountDue,
    required this.customerName,
    required this.address,
    required this.customerPhone,
    required this.ttlSeconds,
    required this.deepLink,
    required this.receivedAt,
    this.initialAction = '',
  });

  @override
  ConsumerState<AssignmentDecisionScreen> createState() =>
      _AssignmentDecisionScreenState();
}

class _AssignmentDecisionScreenState
    extends ConsumerState<AssignmentDecisionScreen> {
  Timer? _ticker;
  bool _isSubmitting = false;
  String _errorText = '';
  Duration _remaining = Duration.zero;

  DateTime get _expiresAt =>
      widget.receivedAt.add(Duration(seconds: widget.ttlSeconds));

  bool get _expired => _remaining.inSeconds <= 0;

  @override
  void initState() {
    super.initState();
    _refreshRemaining();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      _refreshRemaining();
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final action = widget.initialAction.trim().toLowerCase();
      if (action == 'accept' || action == 'decline') {
        _submit(action, autoTriggered: true);
      }
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('قرار استلام الطلب')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            Text(
              'طلب #${widget.orderId}',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 12),
            _infoTile(
              'المبلغ للتحصيل',
              widget.amountDue.isEmpty ? '--' : widget.amountDue,
            ),
            _infoTile(
              'العميل',
              widget.customerName.isEmpty ? '--' : widget.customerName,
            ),
            _infoTile(
              'العنوان',
              widget.address.isEmpty ? '--' : widget.address,
            ),
            _infoTile(
              'الهاتف',
              widget.customerPhone.isEmpty ? '--' : widget.customerPhone,
            ),
            _infoTile(
              'ينتهي خلال',
              _expired ? 'انتهت المهلة' : _formatDuration(_remaining),
            ),
            if (widget.deepLink.trim().isNotEmpty)
              _infoTile('رابط داخلي', widget.deepLink.trim()),
            const SizedBox(height: 12),
            if (_errorText.trim().isNotEmpty)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
                ),
                child: Text(
                  _errorText,
                  style: const TextStyle(color: Colors.red),
                ),
              ),
            const SizedBox(height: 16),
            AppButton(
              label: 'قبول الطلب',
              icon: Icons.check_circle_outline,
              isLoading: _isSubmitting,
              onPressed: (_isSubmitting || _expired)
                  ? null
                  : () => _submit('accept'),
            ),
            const SizedBox(height: 8),
            AppButton(
              label: 'رفض الطلب',
              icon: Icons.cancel_outlined,
              type: AppButtonType.outline,
              isLoading: _isSubmitting,
              onPressed: (_isSubmitting || _expired)
                  ? null
                  : () => _submit('decline'),
            ),
            const SizedBox(height: 12),
            Text(
              'وقت الاستلام: ${DateFormat('yyyy-MM-dd HH:mm:ss').format(widget.receivedAt)}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoTile(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  void _refreshRemaining() {
    final duration = _expiresAt.difference(DateTime.now());
    if (!mounted) {
      return;
    }
    setState(() {
      _remaining = duration.isNegative ? Duration.zero : duration;
    });
  }

  Future<void> _submit(String action, {bool autoTriggered = false}) async {
    if (_expired) {
      setState(() {
        _errorText = 'انتهت مهلة الرد على هذا الإسناد.';
      });
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorText = '';
    });

    try {
      final repository = ref.read(deliveryRepositoryProvider);
      if (action == 'accept') {
        await repository.acceptAssignment(widget.orderId);
      } else {
        await repository.declineAssignment(widget.orderId);
      }

      if (!mounted) {
        return;
      }

      final message = action == 'accept'
          ? 'تم قبول الطلب بنجاح.'
          : 'تم رفض الطلب بنجاح.';
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
      if (context.canPop()) {
        context.pop(true);
      } else {
        context.go(AppRoutePaths.deliveryDashboard);
      }
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _errorText = autoTriggered
            ? 'تعذر تنفيذ $action تلقائيًا. يمكنك إعادة المحاولة يدويًا.'
            : 'تعذر تنفيذ الطلب: $error';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  String _formatDuration(Duration duration) {
    final totalSeconds = duration.inSeconds;
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }
}
