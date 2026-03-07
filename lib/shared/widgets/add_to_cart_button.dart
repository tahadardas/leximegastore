import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../design_system/lexi_motion.dart';
import '../../design_system/lexi_tokens.dart';

/// A button that shows a cart icon when the item is not in the cart,
/// and transforms into a quantity counter (+/−) when the item is added.
class AddToCartButton extends StatefulWidget {
  /// Current quantity of this product in the cart. 0 = not in cart.
  final int qty;

  /// Whether the product can be added to cart (in stock, has price, etc.).
  final bool canAdd;

  /// Called when the user taps the add-to-cart icon (qty == 0).
  final FutureOr<void> Function()? onAdd;

  /// Called when the user taps the `+` button (qty > 0).
  final VoidCallback? onIncrement;

  /// Called when the user taps the `−` button (qty > 0).
  final VoidCallback? onDecrement;

  /// Size of the circle button when in "add" mode.
  final double size;

  /// Icon size inside the circle.
  final double iconSize;

  const AddToCartButton({
    super.key,
    required this.qty,
    this.canAdd = true,
    this.onAdd,
    this.onIncrement,
    this.onDecrement,
    this.size = 38,
    this.iconSize = 14,
  });

  @override
  State<AddToCartButton> createState() => _AddToCartButtonState();
}

class _AddToCartButtonState extends State<AddToCartButton>
    with SingleTickerProviderStateMixin {
  bool _busy = false;

  Future<void> _handleAdd() async {
    if (!widget.canAdd || widget.onAdd == null || _busy) return;
    _busy = true;
    HapticFeedback.mediumImpact();
    try {
      await widget.onAdd!.call();
    } finally {
      _busy = false;
    }
  }

  void _handleIncrement() {
    HapticFeedback.lightImpact();
    widget.onIncrement?.call();
  }

  void _handleDecrement() {
    HapticFeedback.lightImpact();
    widget.onDecrement?.call();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.qty <= 0) {
      return _buildAddButton();
    }
    return _buildCounter();
  }

  Widget _buildAddButton() {
    final isEnabled = widget.canAdd && widget.onAdd != null;
    return Tooltip(
      message: 'إضافة إلى السلة',
      child: Material(
        color: Colors.transparent,
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: isEnabled ? _handleAdd : null,
          child: Ink(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isEnabled ? LexiColors.primaryYellow : LexiColors.gray300,
              boxShadow: LexiShadows.cta,
            ),
            width: widget.size,
            height: widget.size,
            child: Center(
              child: FaIcon(
                FontAwesomeIcons.cartShopping,
                size: widget.iconSize,
                color: isEnabled ? LexiColors.darkBlack : LexiColors.gray500,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCounter() {
    const double btnSize = 30;
    const double counterHeight = 36;

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 250),
      switchInCurve: LexiMotion.standardCurve,
      child: Container(
        key: const ValueKey('cart_counter'),
        height: counterHeight,
        decoration: BoxDecoration(
          color: LexiColors.primaryYellow,
          borderRadius: BorderRadius.circular(counterHeight / 2),
          boxShadow: LexiShadows.cta,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Minus button
            SizedBox(
              width: btnSize,
              height: counterHeight,
              child: Material(
                color: Colors.transparent,
                shape: const CircleBorder(),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: _handleDecrement,
                  child: Center(
                    child: FaIcon(
                      widget.qty == 1
                          ? FontAwesomeIcons.trashCan
                          : FontAwesomeIcons.minus,
                      size: 12,
                      color: widget.qty == 1
                          ? LexiColors.discountRed
                          : LexiColors.darkBlack,
                    ),
                  ),
                ),
              ),
            ),
            // Quantity
            Container(
              constraints: const BoxConstraints(minWidth: 24),
              alignment: Alignment.center,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 180),
                transitionBuilder: (child, anim) =>
                    ScaleTransition(scale: anim, child: child),
                child: Text(
                  '${widget.qty}',
                  key: ValueKey<int>(widget.qty),
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    color: LexiColors.darkBlack,
                  ),
                ),
              ),
            ),
            // Plus button
            SizedBox(
              width: btnSize,
              height: counterHeight,
              child: Material(
                color: Colors.transparent,
                shape: const CircleBorder(),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: _handleIncrement,
                  child: const Center(
                    child: FaIcon(
                      FontAwesomeIcons.plus,
                      size: 12,
                      color: LexiColors.darkBlack,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
