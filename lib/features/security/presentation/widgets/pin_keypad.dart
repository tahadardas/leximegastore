import 'package:flutter/material.dart';

import '../../../../../design_system/lexi_tokens.dart';
import '../../../../../design_system/lexi_typography.dart';

/// Numeric keypad widget for PIN entry.
///
/// Emits individual digit strings via [onDigit] and backspace via [onBackspace].
/// When [disabled] is true the entire keypad is grayed out and non-interactive.
class PinKeypad extends StatelessWidget {
  final ValueChanged<String> onDigit;
  final VoidCallback onBackspace;
  final bool disabled;

  const PinKeypad({
    super.key,
    required this.onDigit,
    required this.onBackspace,
    this.disabled = false,
  });

  @override
  Widget build(BuildContext context) {
    const digits = [
      ['1', '2', '3'],
      ['4', '5', '6'],
      ['7', '8', '9'],
    ];

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ...digits.map(
          (row) => Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: row
                .map(
                  (d) => _KeypadButton(
                    label: d,
                    onTap: disabled ? null : () => onDigit(d),
                  ),
                )
                .toList(),
          ),
        ),
        // Bottom row: empty, 0, backspace
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const _KeypadButton(label: '', onTap: null),
            _KeypadButton(
              label: '0',
              onTap: disabled ? null : () => onDigit('0'),
            ),
            _KeypadButton(
              icon: Icons.backspace_outlined,
              label: '',
              onTap: disabled ? null : onBackspace,
            ),
          ],
        ),
      ],
    );
  }
}

class _KeypadButton extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  final IconData? icon;

  const _KeypadButton({required this.label, required this.onTap, this.icon});

  @override
  Widget build(BuildContext context) {
    if (label.isEmpty && icon == null) {
      return const SizedBox(width: 88, height: 72);
    }

    return SizedBox(
      width: 88,
      height: 72,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(LexiRadius.lg),
          onTap: onTap,
          child: Center(
            child: icon != null
                ? Icon(
                    icon,
                    color: onTap != null
                        ? Colors.white
                        : Colors.white.withValues(alpha: 0.3),
                    size: 24,
                  )
                : Text(
                    label,
                    style: LexiTypography.h2.copyWith(
                      color: onTap != null
                          ? Colors.white
                          : Colors.white.withValues(alpha: 0.3),
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}
