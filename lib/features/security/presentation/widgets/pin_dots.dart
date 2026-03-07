import 'package:flutter/material.dart';

/// Four masked dot indicators showing PIN entry progress.
class PinDots extends StatelessWidget {
  final int filled;
  final bool hasError;

  const PinDots({super.key, required this.filled, this.hasError = false});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(4, (i) {
        final isFilled = i < filled;
        final color = hasError
            ? Colors.red
            : isFilled
            ? Colors.white
            : Colors.white.withValues(alpha: 0.3);
        return AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          margin: const EdgeInsets.symmetric(horizontal: 10),
          width: isFilled ? 18 : 14,
          height: isFilled ? 18 : 14,
          decoration: BoxDecoration(shape: BoxShape.circle, color: color),
        );
      }),
    );
  }
}
