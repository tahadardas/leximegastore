import 'dart:async';
import 'package:flutter/material.dart';

class LexiCountdownTimer extends StatefulWidget {
  final DateTime endTime;
  final VoidCallback? onFinished;
  final TextStyle? textStyle;
  final Color? boxColor;

  const LexiCountdownTimer({
    super.key,
    required this.endTime,
    this.onFinished,
    this.textStyle,
    this.boxColor,
  });

  @override
  State<LexiCountdownTimer> createState() => _LexiCountdownTimerState();
}

class _LexiCountdownTimerState extends State<LexiCountdownTimer> {
  Timer? _timer;
  Duration _remaining = Duration.zero;

  @override
  void initState() {
    super.initState();
    _calculateRemaining();
    _startTimer();
  }

  void _calculateRemaining() {
    final now = DateTime.now();
    if (widget.endTime.isBefore(now)) {
      _remaining = Duration.zero;
      widget.onFinished?.call();
      _timer?.cancel();
    } else {
      _remaining = widget.endTime.difference(now);
    }
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      setState(() {
        _calculateRemaining();
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Widget _buildTimeBox(String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: widget.boxColor ?? Colors.red,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        value,
        style: widget.textStyle?.copyWith(
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ) ??
            const TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.white,
              fontSize: 12,
            ),
      ),
    );
  }

  Widget _buildSeparator() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Text(
        ':',
        style: TextStyle(
          color: widget.boxColor ?? Colors.red,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_remaining == Duration.zero) {
      return const SizedBox.shrink();
    }

    final days = _remaining.inDays;
    final hours = _remaining.inHours % 24;
    final minutes = _remaining.inMinutes % 60;
    final seconds = _remaining.inSeconds % 60;

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        if (days > 0) ...[
          _buildTimeBox(days.toString().padLeft(2, '0')),
          _buildSeparator(),
        ],
        _buildTimeBox(hours.toString().padLeft(2, '0')),
        _buildSeparator(),
        _buildTimeBox(minutes.toString().padLeft(2, '0')),
        _buildSeparator(),
        _buildTimeBox(seconds.toString().padLeft(2, '0')),
      ],
    );
  }
}
