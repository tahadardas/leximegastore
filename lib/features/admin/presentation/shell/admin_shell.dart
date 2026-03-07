import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../design_system/lexi_tokens.dart';
import '../../../../design_system/lexi_typography.dart';
import '../controllers/admin_auth_controller.dart';

// ───────────────────────────────────────────────────────────────
// Navigation model
// ───────────────────────────────────────────────────────────────

class _NavItem {
  final IconData icon;
  final String label;
  final String route;
  final bool needsAdmin;
  final bool needsIntel;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.route,
    this.needsAdmin = false,
    this.needsIntel = false,
  });
}

class _NavGroup {
  final String? header;
  final List<_NavItem> items;

  const _NavGroup({this.header, required this.items});
}

const List<_NavGroup> _kNavGroups = [
  _NavGroup(
    items: [
      _NavItem(
        icon: Icons.dashboard_rounded,
        label: 'لوحة المعلومات',
        route: '/admin/dashboard',
      ),
      _NavItem(
        icon: Icons.insights_rounded,
        label: 'ذكاء المتجر',
        route: '/admin/intel',
        needsIntel: true,
      ),
    ],
  ),
  _NavGroup(
    header: 'الطلبات',
    items: [
      _NavItem(
        icon: Icons.shopping_bag_rounded,
        label: 'الطلبات',
        route: '/admin/orders',
      ),
      _NavItem(
        icon: Icons.account_balance_wallet_rounded,
        label: 'شام كاش',
        route: '/admin/shamcash',
        needsAdmin: true,
      ),
    ],
  ),
  _NavGroup(
    header: 'المتجر',
    items: [
      _NavItem(
        icon: Icons.view_carousel_rounded,
        label: 'أقسام الرئيسية',
        route: '/admin/merch/home-sections',
      ),
      _NavItem(
        icon: Icons.photo_library_rounded,
        label: 'بانرات إعلانية',
        route: '/admin/merch/ad-banners',
      ),
      _NavItem(
        icon: Icons.flash_on_rounded,
        label: 'العروض السريعة',
        route: '/admin/merch/deals',
      ),
      _NavItem(
        icon: Icons.star_rounded,
        label: 'المراجعات',
        route: '/admin/merch/reviews',
      ),
      _NavItem(
        icon: Icons.reorder_rounded,
        label: 'ترتيب التصنيفات',
        route: '/admin/merch/categories',
      ),
      _NavItem(
        icon: Icons.push_pin_rounded,
        label: 'منتجات التصنيف',
        route: '/admin/merch/category-products',
      ),
    ],
  ),
  _NavGroup(
    header: 'الإدارة',
    items: [
      _NavItem(
        icon: Icons.local_shipping_rounded,
        label: 'الشحن',
        route: '/admin/shipping/cities',
      ),
      _NavItem(
        icon: Icons.discount_rounded,
        label: 'الكوبونات',
        route: '/admin/coupons',
      ),
      _NavItem(
        icon: Icons.support_agent_rounded,
        label: 'صندوق الدعم',
        route: '/admin/support',
      ),
      _NavItem(
        icon: Icons.analytics_rounded,
        label: 'تقارير المندوبين',
        route: '/admin/couriers/reports',
      ),
      _NavItem(
        icon: Icons.campaign_rounded,
        label: 'إرسال إشعارات',
        route: '/admin/notifications/send',
      ),
      _NavItem(
        icon: Icons.mail_rounded,
        label: 'إعدادات الإشعارات',
        route: '/admin/notification-settings',
      ),
    ],
  ),
];

// ───────────────────────────────────────────────────────────────
// Breakpoints
// ───────────────────────────────────────────────────────────────

const double _kDesktopBreakpoint = 900;
const double _kTabletBreakpoint = 600;
const double _kSidebarWidth = 250;
const double _kRailWidth = 72;

// ───────────────────────────────────────────────────────────────
// Main Shell
// ───────────────────────────────────────────────────────────────

class AdminShell extends ConsumerWidget {
  final Widget navigationShell;

  const AdminShell({super.key, required this.navigationShell});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final adminUser = ref.watch(adminAuthControllerProvider).asData?.value;
    final isAdministrator = adminUser?.roles.contains('administrator') == true;
    final isShopManager = adminUser?.roles.contains('shop_manager') == true;
    final canAccessIntel = isAdministrator || isShopManager;
    final currentPath = GoRouterState.of(context).uri.path;
    final screenWidth = MediaQuery.sizeOf(context).width;

    final isDesktop = screenWidth >= _kDesktopBreakpoint;
    final isTablet =
        screenWidth >= _kTabletBreakpoint && screenWidth < _kDesktopBreakpoint;
    final isMobile = screenWidth < _kTabletBreakpoint;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        final router = GoRouter.of(context);
        if (router.canPop()) {
          router.pop();
          return;
        }
        if (currentPath != AppRoutePaths.adminDashboard) {
          context.go(AppRoutePaths.adminDashboard);
          return;
        }
        context.goNamedSafe(AppRouteNames.home);
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F6FA),
        drawer: isMobile
            ? _AdminDrawer(
                currentPath: currentPath,
                isAdministrator: isAdministrator,
                canAccessIntel: canAccessIntel,
                adminName: adminUser?.displayName ?? 'Admin',
              )
            : null,
        body: Row(
          children: [
            // ── Side navigation ──
            if (isDesktop)
              _AdminSidebar(
                currentPath: currentPath,
                isAdministrator: isAdministrator,
                canAccessIntel: canAccessIntel,
                adminName: adminUser?.displayName ?? 'Admin',
              ),
            if (isTablet)
              _AdminRail(
                currentPath: currentPath,
                isAdministrator: isAdministrator,
                canAccessIntel: canAccessIntel,
              ),

            // ── Main content ──
            Expanded(
              child: Column(
                children: [
                  _AdminTopBar(
                    currentPath: currentPath,
                    adminName: adminUser?.displayName ?? 'Admin',
                    showMenu: isMobile,
                  ),
                  Expanded(child: navigationShell),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ───────────────────────────────────────────────────────────────
// Top Bar
// ───────────────────────────────────────────────────────────────

class _AdminTopBar extends StatelessWidget {
  final String currentPath;
  final String adminName;
  final bool showMenu;

  const _AdminTopBar({
    required this.currentPath,
    required this.adminName,
    required this.showMenu,
  });

  String _pageTitle(String path) {
    for (final group in _kNavGroups) {
      for (final item in group.items) {
        if (path.startsWith(item.route)) return item.label;
      }
    }
    if (path.contains('/admin/orders/')) return 'تفاصيل الطلب';
    if (path.contains('/admin/support/')) return 'تذكرة الدعم';
    return 'لوحة التحكم';
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: true,
      bottom: false,
      child: Container(
        height: 64,
        padding: const EdgeInsets.symmetric(horizontal: LexiSpacing.s16),
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(
            bottom: BorderSide(color: LexiColors.borderSubtle, width: 1),
          ),
        ),
        child: Row(
          children: [
            if (showMenu)
              IconButton(
                icon: const Icon(Icons.menu_rounded),
                onPressed: () => Scaffold.of(context).openDrawer(),
              ),
            if (showMenu) const SizedBox(width: 8),
            Expanded(
              child: Text(
                _pageTitle(currentPath),
                style: LexiTypography.h3.copyWith(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            // Exit button
            TextButton.icon(
              onPressed: () => context.go('/'),
              icon: const Icon(
                Icons.storefront_rounded,
                size: 18,
                color: LexiColors.textSecondary,
              ),
              label: Text(
                'العودة للمتجر',
                style: LexiTypography.caption.copyWith(
                  color: LexiColors.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ───────────────────────────────────────────────────────────────
// Full Sidebar (Desktop ≥ 900px)
// ───────────────────────────────────────────────────────────────

class _AdminSidebar extends StatelessWidget {
  final String currentPath;
  final bool isAdministrator;
  final bool canAccessIntel;
  final String adminName;

  const _AdminSidebar({
    required this.currentPath,
    required this.isAdministrator,
    required this.canAccessIntel,
    required this.adminName,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: _kSidebarWidth,
      decoration: const BoxDecoration(
        color: Color(0xFF111827),
        boxShadow: [
          BoxShadow(
            color: Color(0x18000000),
            blurRadius: 12,
            offset: Offset(2, 0),
          ),
        ],
      ),
      child: Column(
        children: [
          // ── Brand header ──
          Container(
            height: 64,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            alignment: Alignment.centerRight,
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: LexiColors.primaryYellow,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Center(
                    child: Text(
                      'L',
                      style: TextStyle(
                        color: Color(0xFF111827),
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Lexi Admin',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.3,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          const Divider(color: Color(0xFF1F2937), height: 1),

          // ── Nav items ──
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
              children: [
                for (final group in _kNavGroups) ...[
                  if (group.header != null) ...[
                    const SizedBox(height: 16),
                    Padding(
                      padding: const EdgeInsets.only(right: 12, bottom: 6),
                      child: Text(
                        group.header!,
                        style: const TextStyle(
                          color: Color(0xFF6B7280),
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ],
                  for (final item in group.items)
                    if (_shouldShow(item))
                      _SidebarTile(
                        icon: item.icon,
                        label: item.label,
                        isActive: currentPath.startsWith(item.route),
                        onTap: () => context.push(item.route),
                      ),
                ],
              ],
            ),
          ),

          // ── Admin footer ──
          const Divider(color: Color(0xFF1F2937), height: 1),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: const Color(0xFF374151),
                  child: Text(
                    adminName.isNotEmpty ? adminName[0].toUpperCase() : 'A',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    adminName,
                    style: const TextStyle(
                      color: Color(0xFF9CA3AF),
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  bool _shouldShow(_NavItem item) {
    if (item.needsAdmin && !isAdministrator) return false;
    if (item.needsIntel && !canAccessIntel) return false;
    return true;
  }
}

// ───────────────────────────────────────────────────────────────
// Sidebar tile
// ───────────────────────────────────────────────────────────────

class _SidebarTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _SidebarTile({
    required this.icon,
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Material(
        color: isActive ? const Color(0xFF1F2937) : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          hoverColor: const Color(0xFF1F2937),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                Icon(
                  icon,
                  size: 20,
                  color: isActive
                      ? LexiColors.primaryYellow
                      : const Color(0xFF9CA3AF),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      color: isActive ? Colors.white : const Color(0xFF9CA3AF),
                      fontSize: 13.5,
                      fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (isActive)
                  Container(
                    width: 4,
                    height: 20,
                    decoration: BoxDecoration(
                      color: LexiColors.primaryYellow,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ───────────────────────────────────────────────────────────────
// Icon Rail (Tablet 600–900px)
// ───────────────────────────────────────────────────────────────

class _AdminRail extends StatelessWidget {
  final String currentPath;
  final bool isAdministrator;
  final bool canAccessIntel;

  const _AdminRail({
    required this.currentPath,
    required this.isAdministrator,
    required this.canAccessIntel,
  });

  bool _shouldShow(_NavItem item) {
    if (item.needsAdmin && !isAdministrator) return false;
    if (item.needsIntel && !canAccessIntel) return false;
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final allItems = <_NavItem>[];
    for (final group in _kNavGroups) {
      for (final item in group.items) {
        if (_shouldShow(item)) allItems.add(item);
      }
    }

    return Container(
      width: _kRailWidth,
      decoration: const BoxDecoration(
        color: Color(0xFF111827),
        boxShadow: [
          BoxShadow(
            color: Color(0x18000000),
            blurRadius: 8,
            offset: Offset(2, 0),
          ),
        ],
      ),
      child: Column(
        children: [
          const SizedBox(height: 16),
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: LexiColors.primaryYellow,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Center(
              child: Text(
                'L',
                style: TextStyle(
                  color: Color(0xFF111827),
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          const Divider(color: Color(0xFF1F2937), height: 1),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 8),
              children: [
                for (final item in allItems)
                  _RailIcon(
                    icon: item.icon,
                    label: item.label,
                    isActive: currentPath.startsWith(item.route),
                    onTap: () => context.push(item.route),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RailIcon extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _RailIcon({
    required this.icon,
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: label,
      preferBelow: false,
      child: InkWell(
        onTap: onTap,
        child: Container(
          width: _kRailWidth,
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            border: isActive
                ? const Border(
                    left: BorderSide(color: LexiColors.primaryYellow, width: 3),
                  )
                : null,
          ),
          child: Icon(
            icon,
            size: 22,
            color: isActive
                ? LexiColors.primaryYellow
                : const Color(0xFF6B7280),
          ),
        ),
      ),
    );
  }
}

// ───────────────────────────────────────────────────────────────
// Mobile Drawer (< 600px) — same content as sidebar
// ───────────────────────────────────────────────────────────────

class _AdminDrawer extends StatelessWidget {
  final String currentPath;
  final bool isAdministrator;
  final bool canAccessIntel;
  final String adminName;

  const _AdminDrawer({
    required this.currentPath,
    required this.isAdministrator,
    required this.canAccessIntel,
    required this.adminName,
  });

  bool _shouldShow(_NavItem item) {
    if (item.needsAdmin && !isAdministrator) return false;
    if (item.needsIntel && !canAccessIntel) return false;
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: const Color(0xFF111827),
      child: SafeArea(
        child: Column(
          children: [
            // ── Brand header ──
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(20, 20, 20, 12),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: LexiColors.primaryYellow,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Center(
                      child: Text(
                        'L',
                        style: TextStyle(
                          color: Color(0xFF111827),
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'Lexi Admin',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            const Divider(color: Color(0xFF1F2937), height: 1),

            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(
                  vertical: 12,
                  horizontal: 10,
                ),
                children: [
                  for (final group in _kNavGroups) ...[
                    if (group.header != null) ...[
                      const SizedBox(height: 16),
                      Padding(
                        padding: const EdgeInsets.only(right: 12, bottom: 6),
                        child: Text(
                          group.header!,
                          style: const TextStyle(
                            color: Color(0xFF6B7280),
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ],
                    for (final item in group.items)
                      if (_shouldShow(item))
                        _SidebarTile(
                          icon: item.icon,
                          label: item.label,
                          isActive: currentPath.startsWith(item.route),
                          onTap: () {
                            Navigator.pop(context);
                            context.push(item.route);
                          },
                        ),
                  ],
                ],
              ),
            ),

            const Divider(color: Color(0xFF1F2937), height: 1),
            // ── Exit ──
            Padding(
              padding: const EdgeInsets.all(10),
              child: _SidebarTile(
                icon: Icons.storefront_rounded,
                label: 'العودة للمتجر',
                isActive: false,
                onTap: () {
                  Navigator.pop(context);
                  context.go('/');
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
