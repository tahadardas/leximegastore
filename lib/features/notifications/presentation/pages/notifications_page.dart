import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/session/app_session.dart';
import '../../../../design_system/lexi_tokens.dart';
import '../../data/notification_repository.dart';
import '../../data/notifications_realtime_service.dart';
import '../../domain/entities/notification_entity.dart';
import '../widgets/admin_notification_tile.dart';
import '../widgets/notification_tile.dart';

class NotificationsPage extends ConsumerStatefulWidget {
  const NotificationsPage({super.key});

  @override
  ConsumerState<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends ConsumerState<NotificationsPage>
    with SingleTickerProviderStateMixin {
  TabController? _tabController;
  bool _isAdmin = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final session = ref.read(appSessionProvider);
    if (_isAdmin != session.isAdmin) {
      _isAdmin = session.isAdmin;
      _tabController?.dispose();
      _tabController = TabController(length: _isAdmin ? 2 : 1, vsync: this);
      setState(() {});
    }
  }

  @override
  void dispose() {
    _tabController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: LexiColors.neutral100,
      appBar: _buildAppBar(),
      body: _buildBody(),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      toolbarHeight: 64,
      backgroundColor: LexiColors.brandWhite,
      foregroundColor: LexiColors.brandBlack,
      elevation: 0,
      title: Text(
        'الإشعارات',
        style: Theme.of(
          context,
        ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
      ),
      actions: [
        TextButton(
          onPressed: _markAllAsRead,
          child: Text(
            'تعليم الكل كمقروء',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: LexiColors.brandPrimary),
          ),
        ),
      ],
      bottom: _isAdmin && _tabController != null
          ? TabBar(
              controller: _tabController,
              tabs: const [
                Tab(text: 'إشعاراتي'),
                Tab(text: 'إشعارات الإدارة'),
              ],
              labelColor: LexiColors.brandBlack,
              unselectedLabelColor: LexiColors.neutral400,
              indicatorColor: LexiColors.brandPrimary,
              indicatorWeight: 2,
            )
          : PreferredSize(
              preferredSize: const Size.fromHeight(1),
              child: Container(height: 1, color: LexiColors.neutral200),
            ),
    );
  }

  Widget _buildBody() {
    if (_isAdmin && _tabController != null) {
      return TabBarView(
        controller: _tabController,
        children: const [_CustomerNotificationsTab(), _AdminNotificationsTab()],
      );
    }
    return const _CustomerNotificationsTab();
  }

  void _markAllAsRead() {
    final service = ref.read(notificationsRealtimeServiceProvider);
    if (_isAdmin && _tabController?.index == 1) {
      unawaited(service.markAllAdminRead());
    } else {
      unawaited(service.markAllCustomerRead());
    }
  }
}

class _CustomerNotificationsTab extends ConsumerWidget {
  const _CustomerNotificationsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncSnapshot = ref.watch(notificationsStreamProvider);

    return RefreshIndicator(
      onRefresh: () => ref
          .read(notificationsRealtimeServiceProvider)
          .refreshNow(soft: false),
      child: asyncSnapshot.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => _ErrorBody(
          message: 'تعذر تحميل الإشعارات.',
          onRetry: () => ref
              .read(notificationsRealtimeServiceProvider)
              .refreshNow(soft: false),
        ),
        data: (snapshot) => _NotificationsList(
          items: snapshot.customerItems,
          isStale: snapshot.isStale,
          onTap: (item) {
            unawaited(
              ref
                  .read(notificationsRealtimeServiceProvider)
                  .markCustomerRead(item.id),
            );
            _openNotificationAction(context, item, isAdmin: false);
          },
        ),
      ),
    );
  }
}

class _AdminNotificationsTab extends ConsumerWidget {
  const _AdminNotificationsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncSnapshot = ref.watch(notificationsStreamProvider);

    return RefreshIndicator(
      onRefresh: () => ref
          .read(notificationsRealtimeServiceProvider)
          .refreshNow(soft: false),
      child: asyncSnapshot.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => _ErrorBody(
          message: 'تعذر تحميل الإشعارات.',
          onRetry: () => ref
              .read(notificationsRealtimeServiceProvider)
              .refreshNow(soft: false),
        ),
        data: (snapshot) {
          return _AdminNotificationsList(
            items: snapshot.adminItems,
            isStale: snapshot.isStale,
            onTap: (item) {
              unawaited(
                ref
                    .read(notificationsRealtimeServiceProvider)
                    .markAdminRead(item.id),
              );
              _openNotificationAction(context, item, isAdmin: true);
            },
            onDecision: (item, decision, note) async {
              if (item.orderId == null) {
                return;
              }

              final result = await ref
                  .read(notificationRepositoryProvider)
                  .adminOrderDecision(
                    orderId: item.orderId!,
                    decision: decision,
                    note: note,
                  );

              if (!context.mounted) {
                return;
              }

              if (result['success'] == true) {
                unawaited(
                  ref
                      .read(notificationsRealtimeServiceProvider)
                      .refreshNow(soft: false),
                );
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      decision == 'approve'
                          ? 'تمت الموافقة على الطلب بنجاح.'
                          : 'تم رفض الطلب.',
                    ),
                    backgroundColor: LexiColors.success,
                  ),
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      result['message']?.toString() ?? 'خطأ غير متوقع.',
                    ),
                    backgroundColor: LexiColors.error,
                  ),
                );
              }
            },
          );
        },
      ),
    );
  }
}

class _NotificationsList extends StatelessWidget {
  final List<NotificationEntity> items;
  final bool isStale;
  final ValueChanged<NotificationEntity> onTap;

  const _NotificationsList({
    required this.items,
    required this.isStale,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const _EmptyBody(message: 'لا توجد إشعارات حتى الآن.');
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: LexiSpacing.sm),
      itemCount: items.length + (isStale ? 1 : 0),
      itemBuilder: (context, index) {
        if (isStale && index == 0) {
          return const _StaleBanner();
        }

        final item = items[isStale ? index - 1 : index];
        return NotificationTile(notification: item, onTap: () => onTap(item));
      },
    );
  }
}

class _AdminNotificationsList extends StatelessWidget {
  final List<NotificationEntity> items;
  final bool isStale;
  final ValueChanged<NotificationEntity> onTap;
  final Future<void> Function(
    NotificationEntity item,
    String decision,
    String? note,
  )
  onDecision;

  const _AdminNotificationsList({
    required this.items,
    required this.isStale,
    required this.onTap,
    required this.onDecision,
  });

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const _EmptyBody(message: 'لا توجد إشعارات إدارية حتى الآن.');
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: LexiSpacing.sm),
      itemCount: items.length + (isStale ? 1 : 0),
      itemBuilder: (context, index) {
        if (isStale && index == 0) {
          return const _StaleBanner();
        }

        final item = items[isStale ? index - 1 : index];
        return AdminNotificationTile(
          notification: item,
          onTap: () => onTap(item),
          onDecision: (decision, note) => onDecision(item, decision, note),
        );
      },
    );
  }
}

class _StaleBanner extends StatelessWidget {
  const _StaleBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(
        horizontal: LexiSpacing.md,
        vertical: LexiSpacing.sm,
      ),
      padding: const EdgeInsets.all(LexiSpacing.sm),
      decoration: BoxDecoration(
        color: Colors.amber.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.amber.shade700),
      ),
      child: Text(
        'تُعرض الإشعارات المخزنة. اسحب للأسفل للتحديث.',
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: Colors.amber.shade900,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _ErrorBody extends StatelessWidget {
  final String message;
  final Future<void> Function() onRetry;

  const _ErrorBody({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 48, color: LexiColors.error),
          const SizedBox(height: LexiSpacing.md),
          Text(message, style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: LexiSpacing.sm),
          TextButton(
            onPressed: () {
              unawaited(onRetry());
            },
            child: const Text('إعادة المحاولة'),
          ),
        ],
      ),
    );
  }
}

class _EmptyBody extends StatelessWidget {
  final String message;

  const _EmptyBody({required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.notifications_none,
            size: 64,
            color: LexiColors.neutral400.withValues(alpha: 0.5),
          ),
          const SizedBox(height: LexiSpacing.md),
          Text(
            message,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: LexiColors.neutral500),
          ),
        ],
      ),
    );
  }
}

Future<void> _openNotificationAction(
  BuildContext context,
  NotificationEntity notification, {
  required bool isAdmin,
}) async {
  final data = notification.data ?? const <String, dynamic>{};
  final openMode = (data['open_mode'] ?? 'in_app').toString().trim();
  final deepLink = (data['deep_link'] ?? '').toString().trim();

  if (openMode == 'deals') {
    context.push('/deals');
    return;
  }

  if (openMode == 'product') {
    final id = int.tryParse(deepLink);
    if (id != null && id > 0) {
      context.push('/product/$id');
      return;
    }
  }

  if (openMode == 'category') {
    final id = int.tryParse(deepLink);
    if (id != null && id > 0) {
      context.push('/categories/$id/products');
      return;
    }
  }

  if (openMode == 'external' && deepLink.isNotEmpty) {
    final uri = Uri.tryParse(deepLink);
    if (uri != null) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
      return;
    }
  }

  if (deepLink.startsWith('/')) {
    context.push(deepLink);
    return;
  }

  if (deepLink.startsWith('http://') || deepLink.startsWith('https://')) {
    final uri = Uri.tryParse(deepLink);
    if (uri != null) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
      return;
    }
  }

  if (notification.orderId != null) {
    if (isAdmin) {
      context.push('/admin/orders/${notification.orderId}');
      return;
    }
    context.push('/orders');
  }
}
