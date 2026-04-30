import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:go_router/go_router.dart';

import '../../../../design_system/lexi_tokens.dart';
import '../../../../design_system/lexi_typography.dart';

class LexiAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final List<Widget>? actions;
  final Widget? leading;
  final bool centerTitle;
  final bool showLogo;
  final bool showBottomAccent;
  final Color? backgroundColor;

  const LexiAppBar({
    super.key,
    required this.title,
    this.actions,
    this.leading,
    this.centerTitle = false,
    this.showLogo = true,
    this.showBottomAccent = true,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    final router = GoRouter.of(context);
    final navigator = Navigator.of(context);
    final canPop = router.canPop() || navigator.canPop();
    final hasDrawer = Scaffold.maybeOf(context)?.hasDrawer ?? false;

    Widget? resolvedLeading = leading;
    if (resolvedLeading == null && !canPop && showLogo && !hasDrawer) {
      resolvedLeading = Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(LexiRadius.sm),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () {
                final router = GoRouter.of(context);
                router.go('/');
              },
              child: Image.asset(
                'assets/images/logo_long.jpg',
                width: 120, // Adjusted for long logo
                height: 36,
                fit: BoxFit
                    .contain, // Changed to contain to preserve aspect ratio
              ),
            ),
          ),
        ),
      );
    }
    if (resolvedLeading == null && canPop) {
      resolvedLeading = IconButton(
        onPressed: () {
          if (router.canPop()) {
            router.pop();
            return;
          }
          navigator.maybePop();
        },
        icon: const FaIcon(
          FontAwesomeIcons.chevronRight,
          size: LexiIconSizes.sm,
          color: LexiColors.brandBlack,
        ),
        constraints: const BoxConstraints(
          minWidth: LexiTouchTargets.min,
          minHeight: LexiTouchTargets.min,
        ),
      );
    }

    return AppBar(
      toolbarHeight: 64,
      backgroundColor: backgroundColor ?? LexiColors.brandWhite,
      foregroundColor: LexiColors.brandBlack,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: centerTitle,
      leading: resolvedLeading,
      iconTheme: const IconThemeData(color: LexiColors.brandBlack),
      title: Text(
        title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: LexiTypography.h3.copyWith(
          color: LexiColors.brandBlack,
          fontWeight: FontWeight.w700,
        ),
      ),
      actions: actions,
      bottom: showBottomAccent
          ? PreferredSize(
              preferredSize: const Size.fromHeight(2),
              child: Container(
                height: 2,
                width: double.infinity,
                color: LexiColors.neutral200,
              ),
            )
          : null,
    );
  }

  @override
  Size get preferredSize => Size.fromHeight(showBottomAccent ? 66 : 64);
}
