import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../../../design_system/lexi_tokens.dart';
import '../../data/notifications_realtime_service.dart';

class NotificationBadge extends ConsumerWidget {
  final Color? color;
  final double size;

  const NotificationBadge({super.key, this.color, this.size = 24});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unreadAsync = ref.watch(notificationsUnreadCountStreamProvider);
    final unreadCount = unreadAsync.valueOrNull ?? 0;
    final badgeText = unreadCount > 999 ? '999+' : '$unreadCount';

    return Stack(
      clipBehavior: Clip.none,
      children: [
        IconButton(
          onPressed: () {
            unawaited(ref.read(notificationsRealtimeServiceProvider).prime());
            context.push('/notifications');
          },
          icon: FaIcon(
            FontAwesomeIcons.bell,
            size: size,
            color: color ?? LexiColors.brandBlack,
          ),
        ),
        if (unreadCount > 0)
          Positioned(
            top: 5,
            right: 5,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 3),
              decoration: const BoxDecoration(
                color: LexiColors.error,
                borderRadius: BorderRadius.all(Radius.circular(999)),
              ),
              constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
              child: Center(
                child: Text(
                  badgeText,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    height: 1,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
