import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../core/auth/auth_session_controller.dart';
import '../../../../core/security/app_lock_service.dart';
import '../../../../core/session/app_session.dart';
import '../../../../core/images/image_url_optimizer.dart';
import '../../../../design_system/lexi_icons.dart';
import '../../../../design_system/lexi_tokens.dart';
import '../../../../design_system/lexi_typography.dart';
import '../../../../l10n/l10n.dart';
import '../../../../shared/widgets/lexi_ui/lexi_app_bar.dart';
import '../../../../shared/widgets/lexi_ui/lexi_card.dart';
import '../../../../shared/widgets/lexi_ui/lexi_drawer.dart';
import '../../../../shared/widgets/loading_body_stack.dart';
import '../../../../ui/widgets/lexi_safe_bottom.dart';
import '../../../auth/domain/entities/customer_user.dart';
import '../../../auth/presentation/controllers/customer_auth_controller.dart';

class ProfilePage extends ConsumerWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final authState = ref.watch(customerAuthControllerProvider);
    final customer = authState.asData?.value;
    final session = ref.watch(appSessionProvider);
    final isLoggedIn = session.isLoggedIn;

    final quickActions = <_QuickActionData>[
      _QuickActionData(
        icon: LexiIcons.wishlist,
        label: 'المفضلة',
        onTap: () => context.push('/wishlist'),
      ),
      _QuickActionData(
        icon: LexiIcons.notifications,
        label: 'الإشعارات',
        onTap: () => context.push('/notifications'),
      ),
      if (isLoggedIn)
        _QuickActionData(
          icon: LexiIcons.orders,
          label: 'طلباتي',
          onTap: () => context.push('/orders'),
        )
      else
        _QuickActionData(
          icon: LexiIcons.package,
          label: 'تتبع طلب',
          onTap: () => context.push('/track-order'),
        ),
      _QuickActionData(
        icon: LexiIcons.support,
        label: 'الدعم',
        onTap: () => context.push('/support/tickets'),
      ),
    ];

    final actions = <_ActionData>[
      if (isLoggedIn)
        _ActionData(
          icon: FontAwesomeIcons.userPen,
          title: 'تحديث البيانات',
          subtitle: 'تعديل العنوان ورقم الهاتف وبيانات الحساب',
          onTap: () => context.push('/profile/update'),
        ),
      if (!isLoggedIn)
        _ActionData(
          icon: FontAwesomeIcons.rightToBracket,
          title: 'تسجيل الدخول',
          subtitle: 'الدخول إلى حسابك لاستخدام بياناتك مباشرة عند الطلب',
          onTap: () => context.push('/login'),
        ),
      if (!isLoggedIn)
        _ActionData(
          icon: FontAwesomeIcons.userPlus,
          title: 'إنشاء حساب',
          subtitle: 'سجّل حساباً جديداً إذا لم يكن لديك حساب',
          onTap: () => context.push('/register'),
        ),
      if (isLoggedIn)
        _ActionData(
          icon: FontAwesomeIcons.rightFromBracket,
          title: 'تسجيل الخروج',
          subtitle: 'إنهاء الجلسة الحالية',
          onTap: () async {
            await ref.read(authSessionControllerProvider).logout();
            if (!context.mounted) {
              return;
            }
            ScaffoldMessenger.of(context).showSnackBar(
              lexiFloatingSnackBar(
                context,
                content: const Text('تم تسجيل الخروج.'),
              ),
            );
          },
        ),
    ];

    return Scaffold(
      drawer: const LexiDrawer(),
      appBar: LexiAppBar(title: l10n.appProfileTitle),
      body: LoadingBodyStack(
        isLoading: authState.isLoading,
        blockTouches: false,
        overlayColor: Colors.transparent,
        child: ListView(
          padding: const EdgeInsets.all(LexiSpacing.s16),
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            _ProfileHeader(
              isLoggedIn: isLoggedIn,
              displayName: customer?.fullName ?? session.displayName,
              subTitle: (customer?.email ?? session.email ?? '').trim().isEmpty
                  ? (customer?.phone ?? session.phone ?? '')
                  : (customer?.email ?? session.email),
              avatarUrl: customer?.avatarUrl ?? '',
              onOpenSupport: () => context.push('/support/tickets'),
            ),
            const SizedBox(height: LexiSpacing.s12),
            _QuickActions(items: quickActions),
            if (customer != null) ...[
              const SizedBox(height: LexiSpacing.s12),
              _AccountSummaryCard(customer: customer),
            ],
            if (actions.isNotEmpty) ...[
              const SizedBox(height: LexiSpacing.s24),
              Text(l10n.profileActionsTitle, style: LexiTypography.h3),
              const SizedBox(height: LexiSpacing.s8),
              for (final item in actions)
                _ProfileActionTile(
                  icon: item.icon,
                  title: item.title,
                  subtitle: item.subtitle,
                  onTap: item.onTap,
                ),
            ],
            const SizedBox(height: LexiSpacing.s24),
            Text(l10n.profileSettingsTitle, style: LexiTypography.h3),
            const SizedBox(height: LexiSpacing.s8),
            _SettingsCard(
              onLanguageTap: () {
                showDialog<void>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('اللغة العربية'),
                    content: const Text(
                      'واجهة التطبيق تعمل بالعربية بالكامل حالياً، ولا يوجد تبديل لغة داخل التطبيق.',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('حسناً'),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionData {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _ActionData({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });
}

class _QuickActionData {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _QuickActionData({
    required this.icon,
    required this.label,
    required this.onTap,
  });
}

class _QuickActions extends StatelessWidget {
  final List<_QuickActionData> items;

  const _QuickActions({required this.items});

  @override
  Widget build(BuildContext context) {
    return LexiCard(
      padding: const EdgeInsets.all(LexiSpacing.s8),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final crossAxisCount = constraints.maxWidth >= 520 ? 4 : 2;
          final ratio = crossAxisCount == 4 ? 1.1 : 2.1;
          return GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: items.length,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: crossAxisCount,
              crossAxisSpacing: LexiSpacing.s8,
              mainAxisSpacing: LexiSpacing.s8,
              childAspectRatio: ratio,
            ),
            itemBuilder: (context, index) {
              final item = items[index];
              return InkWell(
                onTap: item.onTap,
                borderRadius: BorderRadius.circular(LexiRadius.sm),
                child: Container(
                  decoration: BoxDecoration(
                    color: LexiColors.surfaceAlt,
                    borderRadius: BorderRadius.circular(LexiRadius.sm),
                    border: Border.all(color: LexiColors.borderSubtle),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: LexiSpacing.s8,
                    vertical: LexiSpacing.s8,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      FaIcon(
                        item.icon,
                        color: LexiColors.brandPrimary,
                        size: LexiIcons.secondarySize,
                      ),
                      const SizedBox(height: LexiSpacing.s4),
                      Text(
                        item.label,
                        style: LexiTypography.bodySm,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  final bool isLoggedIn;
  final String? displayName;
  final String? subTitle;
  final String avatarUrl;
  final VoidCallback onOpenSupport;

  const _ProfileHeader({
    required this.isLoggedIn,
    required this.displayName,
    required this.subTitle,
    required this.avatarUrl,
    required this.onOpenSupport,
  });

  @override
  Widget build(BuildContext context) {
    final normalizedAvatarUrl = avatarUrl.trim().isEmpty
        ? ''
        : ImageUrlOptimizer.optimize(avatarUrl.trim(), preferWebp: false);
    final ImageProvider avatarProvider = normalizedAvatarUrl.isEmpty
        ? const AssetImage('assets/images/logo_square.jpg')
        : NetworkImage(normalizedAvatarUrl);

    return LexiCard(
      padding: EdgeInsets.zero,
      color: LexiColors.brandBlack,
      child: Padding(
        padding: const EdgeInsets.all(LexiSpacing.s16),
        child: Row(
          children: [
            CircleAvatar(
              radius: 30,
              backgroundColor: LexiColors.brandWhite.withValues(alpha: 0.2),
              backgroundImage: avatarProvider,
              onBackgroundImageError: (_, _) {},
            ),
            const SizedBox(width: LexiSpacing.s12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    !isLoggedIn
                        ? 'مرحباً بك في Lexi Mega Store'
                        : 'مرحباً ${displayName?.trim().isNotEmpty == true ? displayName : 'عميلنا'}',
                    style: LexiTypography.labelLg.copyWith(
                      color: LexiColors.brandWhite,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: LexiSpacing.s4),
                  Text(
                    !isLoggedIn
                        ? 'سجّل الدخول لحفظ بياناتك واستخدامها مباشرة عند إتمام الطلب.'
                        : (subTitle?.trim().isNotEmpty == true
                              ? subTitle!.trim()
                              : 'يمكنك إدارة طلباتك وبياناتك من هذه الصفحة.'),
                    style: LexiTypography.bodySm.copyWith(
                      color: LexiColors.brandWhite.withValues(alpha: 0.86),
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: context.l10n.profileSupportTooltip,
              onPressed: onOpenSupport,
              icon: const FaIcon(
                LexiIcons.support,
                size: LexiIcons.secondarySize,
              ),
              color: LexiColors.brandPrimary,
            ),
          ],
        ),
      ),
    );
  }
}

class _AccountSummaryCard extends StatelessWidget {
  final CustomerUser customer;

  const _AccountSummaryCard({required this.customer});

  @override
  Widget build(BuildContext context) {
    return LexiCard(
      padding: const EdgeInsets.all(LexiSpacing.s16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('بيانات الحساب', style: LexiTypography.labelLg),
          const SizedBox(height: LexiSpacing.s8),
          _DataLine(label: 'الاسم', value: customer.fullName),
          _DataLine(label: 'البريد', value: customer.email),
          _DataLine(
            label: 'الهاتف',
            value: customer.phone.trim().isEmpty ? 'غير مضاف' : customer.phone,
          ),
          _DataLine(
            label: 'العنوان',
            value: customer.address1.trim().isEmpty
                ? 'غير مضاف'
                : customer.address1,
          ),
        ],
      ),
    );
  }
}

class _DataLine extends StatelessWidget {
  final String label;
  final String value;

  const _DataLine({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: LexiSpacing.s8),
      child: Row(
        children: [
          SizedBox(
            width: 88,
            child: Text(
              label,
              style: LexiTypography.bodySm.copyWith(
                color: LexiColors.textMuted,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: LexiSpacing.s8),
          Expanded(
            child: Text(
              value,
              style: LexiTypography.bodyMd,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsCard extends ConsumerWidget {
  final VoidCallback onLanguageTap;

  const _SettingsCard({required this.onLanguageTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(appSessionProvider);
    final isLoggedIn = session.isLoggedIn;

    return LexiCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          ListTile(
            leading: const Icon(
              FontAwesomeIcons.shieldHalved,
              color: LexiColors.neutral600,
            ),
            title: Text('الأمان', style: LexiTypography.labelLg),
          ),
          _buildAppLockTile(context, ref, isLoggedIn),
          const Divider(height: 1, color: LexiColors.neutral200),
          ListTile(
            onTap: onLanguageTap,
            leading: const Icon(
              FontAwesomeIcons.language,
              color: LexiColors.neutral600,
            ),
            title: Text('اللغة العربية', style: LexiTypography.bodyMd),
            subtitle: Text(
              'الواجهة مضبوطة على العربية فقط',
              style: LexiTypography.bodySm,
            ),
            trailing: const Icon(
              Icons.arrow_back_ios_new,
              size: 16,
              color: LexiColors.neutral400,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAppLockTile(
    BuildContext context,
    WidgetRef ref,
    bool isLoggedIn,
  ) {
    final lockService = ref.watch(appLockServiceProvider);
    final lockEnabled = lockService.lockEnabled;
    final statusText = !isLoggedIn
        ? 'سجّل الدخول أولاً'
        : lockEnabled
        ? 'مفعّل - انقر للإدارة'
        : 'غير مفعّل - انقر للتفعيل';

    return ListTile(
      leading: Icon(
        lockEnabled ? Icons.lock_rounded : Icons.lock_open_rounded,
        color: lockEnabled ? LexiColors.brandPrimary : LexiColors.neutral600,
      ),
      title: Text('قفل التطبيق', style: LexiTypography.bodyMd),
      subtitle: Text(statusText, style: LexiTypography.bodySm),
      trailing: const Icon(
        Icons.arrow_back_ios_new,
        size: 16,
        color: LexiColors.neutral400,
      ),
      onTap: isLoggedIn
          ? () => context.push(AppRoutePaths.securityEnable)
          : null,
    );
  }
}

class _ProfileActionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _ProfileActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: LexiSpacing.s8),
      child: LexiCard(
        padding: EdgeInsets.zero,
        onTap: onTap,
        child: ListTile(
          leading: FaIcon(
            icon,
            color: LexiColors.brandPrimary,
            size: LexiIcons.secondarySize,
          ),
          title: Text(title, style: LexiTypography.labelLg),
          subtitle: Text(subtitle, style: LexiTypography.bodySm),
          trailing: const Icon(
            Icons.arrow_back_ios_new,
            size: 16,
            color: LexiColors.neutral400,
          ),
        ),
      ),
    );
  }
}
