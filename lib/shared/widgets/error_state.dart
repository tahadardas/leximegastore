import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../design_system/lexi_tokens.dart';
import '../../design_system/lexi_typography.dart';

class ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  final Object? error;
  final StackTrace? stackTrace;
  final String? technicalDetails;
  final EdgeInsetsGeometry padding;
  final IconData icon;

  const ErrorState({
    super.key,
    required this.message,
    required this.onRetry,
    this.error,
    this.stackTrace,
    this.technicalDetails,
    this.padding = const EdgeInsets.all(LexiSpacing.lg),
    this.icon = Icons.error_outline,
  });

  @override
  Widget build(BuildContext context) {
    final details = _buildDetails();

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      child: Padding(
        padding: padding,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 56, color: LexiColors.error),
                const SizedBox(height: LexiSpacing.sm),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style:
                      (Theme.of(context).textTheme.bodyLarge ??
                              LexiTypography.bodyLg)
                          .copyWith(color: LexiColors.textSecondary),
                ),
                const SizedBox(height: LexiSpacing.md),
                TextButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh),
                  label: const Text('إعادة المحاولة'),
                ),
                if (details != null) ...[
                  const SizedBox(height: LexiSpacing.sm),
                  Card(
                    color: LexiColors.background,
                    elevation: 0,
                    child: ExpansionTile(
                      tilePadding: const EdgeInsets.symmetric(
                        horizontal: LexiSpacing.md,
                      ),
                      childrenPadding: const EdgeInsetsDirectional.fromSTEB(
                        LexiSpacing.md,
                        0,
                        LexiSpacing.md,
                        LexiSpacing.md,
                      ),
                      title: const Text(
                        'تفاصيل تقنية (للمطور)',
                        style: TextStyle(fontSize: 13),
                      ),
                      children: [
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(LexiSpacing.sm),
                          decoration: BoxDecoration(
                            color: LexiColors.white,
                            borderRadius: BorderRadius.circular(LexiRadius.sm),
                          ),
                          child: SelectableText(
                            details,
                            style: const TextStyle(
                              fontSize: 12,
                              fontFamily: 'monospace',
                              color: LexiColors.textSecondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  String? _buildDetails() {
    if (!kDebugMode) {
      return null;
    }

    final parts = <String>[];

    if (technicalDetails != null && technicalDetails!.trim().isNotEmpty) {
      parts.add(technicalDetails!.trim());
    }

    if (error != null) {
      parts.add('error: $error');
    }

    if (stackTrace != null) {
      parts.add('stackTrace: $stackTrace');
    }

    if (parts.isEmpty) {
      return null;
    }

    return parts.join('\n\n');
  }
}

