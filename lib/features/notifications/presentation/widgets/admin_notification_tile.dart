import 'package:flutter/material.dart';

import '../../../../core/utils/relative_time.dart';
import '../../../../design_system/lexi_tokens.dart';
import '../../domain/entities/notification_entity.dart';
import 'notification_tile.dart';

/// Admin notification tile with approve/reject actions for new orders
class AdminNotificationTile extends StatefulWidget {
  final NotificationEntity notification;
  final VoidCallback? onTap;
  final Future<void> Function(String decision, String? note)? onDecision;

  const AdminNotificationTile({
    super.key,
    required this.notification,
    this.onTap,
    this.onDecision,
  });

  @override
  State<AdminNotificationTile> createState() => _AdminNotificationTileState();
}

class _AdminNotificationTileState extends State<AdminNotificationTile> {
  bool _isProcessing = false;
  bool? _decisionMade;

  @override
  Widget build(BuildContext context) {
    final timeAgo = formatRelativeTime(widget.notification.createdAt);

    // If decision already made, show regular tile
    if (_decisionMade != null ||
        widget.notification.type != NotificationType.orderCreated) {
      return NotificationTile(
        notification: widget.notification,
        onTap: widget.onTap,
      );
    }

    return InkWell(
      onTap: widget.onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: LexiSpacing.md,
          vertical: LexiSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: widget.notification.isRead
              ? null
              : LexiColors.brandPrimary.withValues(alpha: 0.05),
          border: Border(
            bottom: BorderSide(color: LexiColors.neutral200, width: 1),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Unread indicator
                Container(
                  width: 8,
                  height: 8,
                  margin: const EdgeInsets.only(top: 6, left: LexiSpacing.xs),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: widget.notification.isRead
                        ? Colors.transparent
                        : LexiColors.brandPrimary,
                  ),
                ),
                const SizedBox(width: LexiSpacing.sm),
                // Content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Title
                      Text(
                        widget.notification.titleAr,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: widget.notification.isRead
                              ? FontWeight.normal
                              : FontWeight.bold,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      // Body
                      Text(
                        widget.notification.bodyAr,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: LexiColors.neutral500,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        timeAgo,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: LexiColors.neutral400,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                // Order icon
                const Icon(
                  Icons.shopping_bag_outlined,
                  size: 20,
                  color: LexiColors.info,
                ),
              ],
            ),
            const SizedBox(height: LexiSpacing.sm),
            // Action buttons
            if (_isProcessing)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(LexiSpacing.sm),
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              )
            else
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _handleDecision('reject'),
                      icon: const Icon(Icons.close, size: 16),
                      label: const Text('رفض'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: LexiColors.error,
                        side: const BorderSide(color: LexiColors.error),
                        padding: const EdgeInsets.symmetric(
                          horizontal: LexiSpacing.sm,
                          vertical: LexiSpacing.xs,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: LexiSpacing.sm),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _handleDecision('approve'),
                      icon: const Icon(Icons.check, size: 16),
                      label: const Text('قبول'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: LexiColors.success,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: LexiSpacing.sm,
                          vertical: LexiSpacing.xs,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleDecision(String decision) async {
    if (widget.onDecision == null) return;

    setState(() {
      _isProcessing = true;
    });

    try {
      await widget.onDecision!(decision, null);
      if (mounted) {
        setState(() {
          _decisionMade = decision == 'approve';
          _isProcessing = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('حدث خطأ: $e'),
            backgroundColor: LexiColors.error,
          ),
        );
      }
    }
  }
}
