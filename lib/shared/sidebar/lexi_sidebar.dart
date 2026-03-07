import 'package:flutter/material.dart';

/// A menu item descriptor for the sidebar.
class LexiSidebarItem {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  const LexiSidebarItem({required this.icon, required this.label, this.onTap});
}

/// The visual sidebar content widget.
///
/// Displays a branded header and list of [LexiSidebarItem]s.
class LexiSidebar extends StatelessWidget {
  /// Menu items to render in the sidebar.
  final List<LexiSidebarItem> items;

  /// Maximum width of the sidebar in logical pixels.
  static const double maxWidth = 320;

  /// Fraction of screen width used for the sidebar.
  static const double widthFraction = 0.8;

  /// Header background color.
  static const Color _headerColor = Color(0xFFFACB21);

  /// Text / icon color (dark).
  static const Color _contentColor = Color(0xFF0C0B0A);

  /// Header height.
  static const double _headerHeight = 120;

  const LexiSidebar({super.key, required this.items});

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final sidebarWidth = (screenWidth * widthFraction).clamp(0.0, maxWidth);

    return Material(
      elevation: 0,
      color: Colors.white,
      child: SizedBox(
        width: sidebarWidth,
        child: Column(
          children: [
            // ── Header ──
            Container(
              width: double.infinity,
              height: _headerHeight,
              color: _headerColor,
              alignment: Alignment.centerRight,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: const SafeArea(
                bottom: false,
                child: Text(
                  'Lexi Mega Store',
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: _contentColor,
                  ),
                ),
              ),
            ),

            // ── Menu Items ──
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: items.length,
                separatorBuilder: (context, index) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final item = items[index];
                  return InkWell(
                    onTap: item.onTap,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 14,
                      ),
                      child: Row(
                        children: [
                          Icon(item.icon, color: _contentColor, size: 24),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Text(
                              item.label,
                              style: const TextStyle(
                                fontFamily: 'Cairo',
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: _contentColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
