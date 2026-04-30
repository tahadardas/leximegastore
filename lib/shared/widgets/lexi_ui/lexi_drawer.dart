import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:go_router/go_router.dart';

import '../../../core/auth/auth_session_controller.dart';
import '../../../core/session/app_session.dart';
import '../../../design_system/lexi_tokens.dart';
import '../../../design_system/lexi_typography.dart';

class LexiDrawer extends ConsumerWidget {
  const LexiDrawer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(appSessionProvider);
    final userLabel = session.displayName;
    final canAccessDashboard = session.isAdmin;
    final canAccessCourierDashboard = session.isDeliveryAgent;
    final isLoggedIn = session.isLoggedIn;

    return Drawer(
      backgroundColor: LexiColors.brandWhite,
      child: Column(
        children: [
          _DrawerHeader(userLabel: userLabel),
          if (session.isLoading)
            const SizedBox(
              height: 2,
              child: LinearProgressIndicator(color: LexiColors.brandPrimary),
            ),
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                _DrawerItem(
                  icon: FontAwesomeIcons.house,
                  title: 'الرئيسية',
                  onTap: () => _go(context, '/'),
                ),
                _DrawerItem(
                  icon: FontAwesomeIcons.shapes,
                  title: 'الأقسام',
                  onTap: () => _go(context, '/categories'),
                ),
                _DrawerItem(
                  icon: FontAwesomeIcons.bolt,
                  title: 'العروض',
                  onTap: () => _go(context, '/deals'),
                ),
                _DrawerItem(
                  icon: FontAwesomeIcons.cartShopping,
                  title: 'السلة',
                  onTap: () => _go(context, '/cart'),
                ),
                _DrawerItem(
                  icon: FontAwesomeIcons.clockRotateLeft,
                  title: 'شام كاش غير المكتملة',
                  onTap: () => _go(context, '/orders/incomplete-shamcash'),
                ),
                if (isLoggedIn)
                  _DrawerItem(
                    icon: FontAwesomeIcons.box,
                    title: 'طلباتي',
                    onTap: () => _go(context, '/orders'),
                  )
                else
                  _DrawerItem(
                    icon: FontAwesomeIcons.locationCrosshairs,
                    title: 'تتبع طلب',
                    onTap: () => _go(context, '/track-order'),
                  ),
                if (isLoggedIn)
                  _DrawerItem(
                    icon: FontAwesomeIcons.user,
                    title: 'حسابي',
                    onTap: () => _go(context, '/profile'),
                  )
                else
                  _DrawerItem(
                    icon: FontAwesomeIcons.rightToBracket,
                    title: 'تسجيل الدخول',
                    onTap: () => _go(context, '/login'),
                  ),
                _DrawerItem(
                  icon: FontAwesomeIcons.heart,
                  title: 'المفضلة',
                  onTap: () => _go(context, '/wishlist'),
                ),
                const Divider(
                  height: LexiSpacing.lg,
                  color: LexiColors.neutral200,
                ),
                if (canAccessDashboard)
                  _DrawerItem(
                    icon: Icons.dashboard_outlined,
                    title: 'لوحة التحكم',
                    subtitle: 'صلاحية مدير',
                    onTap: () => _go(context, '/admin/dashboard'),
                  ),
                if (canAccessCourierDashboard)
                  _DrawerItem(
                    icon: FontAwesomeIcons.truck,
                    title: 'لوحة تحكم المندوب',
                    subtitle: 'طلبات التوصيل والحالة',
                    onTap: () => _go(context, '/delivery/dashboard'),
                  ),
              ],
            ),
          ),
          if (isLoggedIn)
            Padding(
              padding: const EdgeInsets.all(LexiSpacing.md),
              child: OutlinedButton.icon(
                onPressed: () async {
                  await ref.read(authSessionControllerProvider).logout();
                  if (!context.mounted) return;
                  _go(context, '/profile');
                },
                icon: const Icon(Icons.logout_outlined),
                label: const Text('تسجيل الخروج'),
              ),
            ),
        ],
      ),
    );
  }

  void _go(BuildContext context, String path) {
    Navigator.of(context).pop();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.go(path);
    });
  }
}

class _DrawerHeader extends StatelessWidget {
  final String? userLabel;

  const _DrawerHeader({required this.userLabel});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(LexiSpacing.md),
      decoration: const BoxDecoration(
        color: LexiColors.brandBlack,
        border: Border(
          bottom: BorderSide(color: LexiColors.brandPrimary, width: 2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(LexiRadius.sm),
            child: Image.asset(
              'assets/images/logo_long.jpg',
              height: 52,
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(height: LexiSpacing.sm),
          Text(
            userLabel == null ? 'أهلًا بك زائرنا الكريم' : 'مرحبًا، $userLabel',
            style: LexiTypography.bodySm.copyWith(color: LexiColors.brandWhite),
          ),
        ],
      ),
    );
  }
}

class _DrawerItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;

  const _DrawerItem({
    required this.icon,
    required this.title,
    required this.onTap,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      leading: FaIcon(icon, color: LexiColors.brandBlack, size: 18),
      title: Text(title, style: LexiTypography.bodyMd),
      subtitle: subtitle == null
          ? null
          : Text(subtitle!, style: LexiTypography.bodySm),
      trailing: const Icon(
        Icons.arrow_back_ios_new,
        size: 14,
        color: LexiColors.neutral400,
      ),
    );
  }
}
