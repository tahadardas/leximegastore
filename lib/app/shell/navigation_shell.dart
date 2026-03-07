import 'package:convex_bottom_bar/convex_bottom_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:go_router/go_router.dart';

import '../../core/errors/global_error_handler.dart';
import '../../design_system/lexi_icons.dart';
import '../../design_system/lexi_tokens.dart';
import '../../features/cart/presentation/controllers/cart_controller.dart';
import '../../features/wishlist/presentation/controllers/wishlist_controller.dart';
import '../../shared/ui/lexi_alert.dart';
import '../../ui/widgets/lexi_safe_bottom.dart';
import '../router/app_routes.dart';

class NavigationShell extends ConsumerStatefulWidget {
  final Widget child;

  const NavigationShell({super.key, required this.child});

  @override
  ConsumerState<NavigationShell> createState() => _NavigationShellState();
}

class _NavigationShellState extends ConsumerState<NavigationShell> {
  int _currentIndexFromPath(String location) {
    if (location.startsWith(AppRoutePaths.categories)) return 1;
    if (location.startsWith(AppRoutePaths.deals)) return 2;
    if (location.startsWith(AppRoutePaths.wishlist)) return 3;
    if (location.startsWith(AppRoutePaths.profile)) return 4;
    if (location.startsWith(AppRoutePaths.cart)) return 5;
    return 0;
  }

  String _pathForIndex(int index) {
    switch (index) {
      case 0:
        return AppRoutePaths.home;
      case 1:
        return AppRoutePaths.categories;
      case 2:
        return AppRoutePaths.deals;
      case 3:
        return AppRoutePaths.wishlist;
      case 4:
        return AppRoutePaths.profile;
      case 5:
        return AppRoutePaths.cart;
      default:
        return AppRoutePaths.home;
    }
  }

  String _routeNameForIndex(int index) {
    switch (index) {
      case 0:
        return AppRouteNames.home;
      case 1:
        return AppRouteNames.categories;
      case 2:
        return AppRouteNames.deals;
      case 3:
        return AppRouteNames.wishlist;
      case 4:
        return AppRouteNames.profile;
      case 5:
        return AppRouteNames.cart;
      default:
        return AppRouteNames.home;
    }
  }

  void _onTap(BuildContext context, int index) {
    final path = _pathForIndex(index);
    final currentPath = GoRouterState.of(context).uri.path;
    if (currentPath == path) {
      return;
    }
    context.goNamedSafe(_routeNameForIndex(index));
  }

  Future<void> _showExitDialog() async {
    final shouldExit = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('هل تريد الخروج من التطبيق؟'),
        content: const Text('يمكنك المتابعة بالتسوق بالضغط على إلغاء.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('إلغاء'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: LexiColors.error),
            child: const Text('خروج'),
          ),
        ],
      ),
    );

    if (shouldExit == true) {
      SystemNavigator.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(globalErrorProvider, (previous, next) {
      if (next.message != null) {
        LexiAlert.error(context, text: next.message!);
        ref.read(globalErrorProvider.notifier).clear();
      }
    });

    final cartState = ref.watch(cartControllerProvider).valueOrNull;
    final cartCount = cartState?.totalQty ?? 0;
    final wishlistState = ref.watch(wishlistControllerProvider).valueOrNull;
    final wishlistCount = wishlistState?.length ?? 0;
    final navBadges = <int, dynamic>{
      if (wishlistCount > 0) 3: wishlistCount > 99 ? '99+' : '$wishlistCount',
      if (cartCount > 0) 5: cartCount > 99 ? '99+' : '$cartCount',
    };

    final routePath = GoRouterState.of(context).uri.path;
    final selectedIndex = _currentIndexFromPath(routePath);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;

        if (selectedIndex != 0) {
          context.goNamedSafe(AppRouteNames.home);
        } else {
          await _showExitDialog();
        }
      },
      child: Scaffold(
        body: widget.child,
        bottomNavigationBar: LexiSafeBottom(
          keyboardAware: false,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: LexiColors.white,
              boxShadow: LexiShadows.card,
              border: const Border(top: BorderSide(color: LexiColors.gray200)),
            ),
            child: ConvexAppBar.badge(
              navBadges,
              initialActiveIndex: selectedIndex,
              onTap: (index) => _onTap(context, index),
              backgroundColor: LexiColors.white,
              activeColor: LexiColors.brandPrimary,
              color: LexiColors.gray500,
              elevation: 0,
              height: 58,
              top: -10,
              style: TabStyle.react,
              items: const [
                TabItem(icon: FontAwesomeIcons.house, title: 'الرئيسية'),
                TabItem(icon: LexiIcons.categories, title: 'الأقسام'),
                TabItem(icon: LexiIcons.deals, title: 'العروض'),
                TabItem(icon: LexiIcons.wishlist, title: 'المفضلة'),
                TabItem(icon: LexiIcons.profile, title: 'حسابي'),
                TabItem(icon: LexiIcons.cart, title: 'السلة'),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
