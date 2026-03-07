import 'package:flutter/material.dart';

import '../../../../core/utils/relative_time.dart';
import '../../../../design_system/lexi_tokens.dart';
import '../../domain/entities/notification_entity.dart';

/// Notification tile widget for customer notifications
class NotificationTile extends StatelessWidget {
  final NotificationEntity notification;
  final VoidCallback? onTap;

  const NotificationTile({super.key, required this.notification, this.onTap});

  @override
  Widget build(BuildContext context) {
    final timeAgo = formatRelativeTime(notification.createdAt);

    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: LexiSpacing.md,
          vertical: LexiSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: notification.isRead
              ? null
              : LexiColors.brandPrimary.withValues(alpha: 0.05),
          border: Border(
            bottom: BorderSide(color: LexiColors.neutral200, width: 1),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Unread indicator
            Container(
              width: 8,
              height: 8,
              margin: const EdgeInsets.only(top: 6, left: LexiSpacing.xs),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: notification.isRead
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
                    notification.titleAr,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: notification.isRead
                          ? FontWeight.normal
                          : FontWeight.bold,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  // Body
                  Text(
                    notification.bodyAr,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: LexiColors.neutral500,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  // Time
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
            // Type icon
            _buildTypeIcon(),
          ],
        ),
      ),
    );
  }

  Widget _buildTypeIcon() {
    IconData iconData;
    Color iconColor;

    switch (notification.type) {
      case NotificationType.orderCreated:
        iconData = Icons.shopping_bag_outlined;
        iconColor = LexiColors.info;
        break;
      case NotificationType.orderApproved:
        iconData = Icons.check_circle_outline;
        iconColor = LexiColors.success;
        break;
      case NotificationType.orderRejected:
        iconData = Icons.cancel_outlined;
        iconColor = LexiColors.error;
        break;
      case NotificationType.orderStatusChanged:
        iconData = Icons.sync_alt;
        iconColor = LexiColors.warning;
        break;
      case NotificationType.unknown:
        iconData = Icons.notifications_outlined;
        iconColor = LexiColors.neutral400;
        break;
    }

    return Icon(iconData, size: 20, color: iconColor);
  }
}
