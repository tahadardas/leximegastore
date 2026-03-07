import 'package:flutter/material.dart';

import 'lexi_sidebar.dart';
import 'lexi_sidebar_controller.dart';

/// Wraps a page with a right-side animated sidebar, dark overlay,
/// and drag-to-open / drag-to-close gesture support.
///
/// Usage:
/// ```dart
/// LexiSidebarLayout(
///   controller: _sidebarController,
///   sidebar: LexiSidebar(items: [...]),
///   child: Scaffold(...),
/// )
/// ```
class LexiSidebarLayout extends StatelessWidget {
  /// The main page content.
  final Widget child;

  /// The sidebar widget (typically [LexiSidebar]).
  final Widget sidebar;

  /// The controller that drives open / close / drag.
  final LexiSidebarController controller;

  /// Overlay opacity when the sidebar is fully open.
  static const double _overlayOpacity = 0.4;

  /// Width of the right-edge zone that triggers a drag-open.
  static const double _edgeDragWidth = 20;

  const LexiSidebarLayout({
    super.key,
    required this.child,
    required this.sidebar,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final sidebarWidth = (screenWidth * LexiSidebar.widthFraction).clamp(
      0.0,
      LexiSidebar.maxWidth,
    );

    return GestureDetector(
      // ── Drag-to-open from right edge / drag-to-close ──
      onHorizontalDragStart: (details) {
        // Allow drag-open only from the right edge area
        // Allow drag-close when the sidebar is partially or fully open
      },
      onHorizontalDragUpdate: (details) {
        // In RTL sidebar (right-side), dragging left (negative dx) opens,
        // dragging right (positive dx) closes.
        final delta = details.primaryDelta ?? 0;
        final currentValue = controller.animation.value;
        final change = -delta / sidebarWidth;
        controller.dragUpdate(currentValue + change);
      },
      onHorizontalDragEnd: (details) {
        final velocity = details.primaryVelocity ?? 0;
        controller.dragEnd(velocity, controller.animation.value);
      },
      child: Stack(
        children: [
          // ── Layer 1: Main content ──
          child,

          // ── Layer 2: Dark overlay ──
          AnimatedBuilder(
            animation: controller.animation,
            builder: (context, _) {
              if (controller.animation.value == 0) {
                return const SizedBox.shrink();
              }

              return GestureDetector(
                onTap: controller.close,
                behavior: HitTestBehavior.opaque,
                child: Container(
                  color: Colors.black.withValues(
                    alpha: _overlayOpacity * controller.animation.value,
                  ),
                ),
              );
            },
          ),

          // ── Layer 3: Sidebar panel ──
          AnimatedBuilder(
            animation: controller.animation,
            builder: (context, child) {
              // Translate from off-screen (right) to on-screen.
              // value 0 → fully off-screen (translateX = sidebarWidth)
              // value 1 → fully visible  (translateX = 0)
              final translateX =
                  sidebarWidth * (1 - controller.animation.value);

              return Positioned(
                top: 0,
                bottom: 0,
                right: 0,
                width: sidebarWidth,
                child: Transform.translate(
                  offset: Offset(translateX, 0),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      boxShadow: controller.animation.value > 0
                          ? [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.15),
                                blurRadius: 16,
                                offset: const Offset(-4, 0),
                              ),
                            ]
                          : [],
                    ),
                    child: sidebar,
                  ),
                ),
              );
            },
          ),

          // ── Invisible right-edge drag zone (when sidebar is closed) ──
          AnimatedBuilder(
            animation: controller.animation,
            builder: (context, _) {
              if (controller.animation.value > 0) {
                return const SizedBox.shrink();
              }

              return Positioned(
                top: 0,
                bottom: 0,
                right: 0,
                width: _edgeDragWidth,
                child: GestureDetector(
                  onHorizontalDragUpdate: (details) {
                    final delta = details.primaryDelta ?? 0;
                    final currentValue = controller.animation.value;
                    final change = -delta / sidebarWidth;
                    controller.dragUpdate(currentValue + change);
                  },
                  onHorizontalDragEnd: (details) {
                    final velocity = details.primaryVelocity ?? 0;
                    controller.dragEnd(velocity, controller.animation.value);
                  },
                  behavior: HitTestBehavior.translucent,
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
