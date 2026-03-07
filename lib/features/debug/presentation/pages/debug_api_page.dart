import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../config/constants/endpoints.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../design_system/lexi_tokens.dart';
import '../../../../design_system/lexi_typography.dart';
import '../../../../shared/widgets/lexi_ui/lexi_app_bar.dart';

class DebugApiPage extends ConsumerStatefulWidget {
  const DebugApiPage({super.key});

  @override
  ConsumerState<DebugApiPage> createState() => _DebugApiPageState();
}

class _DebugApiPageState extends ConsumerState<DebugApiPage> {
  bool _loading = false;
  String _result = 'اضغط أحد الأزرار لاختبار الاتصال بالواجهة البرمجية.';

  Future<void> _testProducts() {
    return _runTest(
      label: 'المنتجات',
      path: Endpoints.productsPath,
      queryParameters: const {'page': 1, 'per_page': 20},
    );
  }

  Future<void> _testCategories() {
    return _runTest(label: 'الأقسام', path: Endpoints.categoriesPath);
  }

  Future<void> _runTest({
    required String label,
    required String path,
    Map<String, dynamic>? queryParameters,
  }) async {
    setState(() {
      _loading = true;
      _result = 'جارٍ اختبار $label...';
    });

    final client = ref.read(dioClientProvider);

    try {
      final response = await client.get(
        path,
        queryParameters: queryParameters,
        options: Options(extra: const {'requiresAuth': false}),
      );

      final items = extractList(response.data);
      final firstItem = items.isNotEmpty
          ? _pretty(items.first)
          : 'لا يوجد عناصر.';
      final resolvedUrl = response.realUri.toString();
      final statusCode = response.statusCode ?? -1;

      final report = StringBuffer()
        ..writeln('نوع الاختبار: $label')
        ..writeln('الرابط النهائي: $resolvedUrl')
        ..writeln('رمز الحالة: $statusCode')
        ..writeln('عدد العناصر: ${items.length}')
        ..writeln('أول عنصر (JSON):')
        ..writeln(firstItem);

      final output = report.toString().trimRight();
      if (kDebugMode) {
        debugPrint('[DebugApiPage] $output');
      }

      setState(() {
        _result = output;
      });
    } on DioException catch (e) {
      final statusCode = e.response?.statusCode ?? -1;
      final resolvedUrl = e.requestOptions.uri.toString();
      final body = _snippet(e.response?.data ?? e.message);

      final report = StringBuffer()
        ..writeln('نوع الاختبار: $label')
        ..writeln('الرابط النهائي: $resolvedUrl')
        ..writeln('رمز الحالة: $statusCode')
        ..writeln('فشل الطلب: ${e.message}')
        ..writeln('مقتطف الاستجابة:')
        ..writeln(body);

      final output = report.toString().trimRight();
      if (kDebugMode) {
        debugPrint('[DebugApiPage][ERROR] $output');
      }

      setState(() {
        _result = output;
      });
    } catch (e, st) {
      final output = 'فشل غير متوقع أثناء اختبار $label:\n$e\n$st';
      if (kDebugMode) {
        debugPrint('[DebugApiPage][ERROR] $output');
      }
      setState(() {
        _result = output;
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  String _pretty(dynamic value) {
    try {
      return const JsonEncoder.withIndent('  ').convert(value);
    } catch (_) {
      return value.toString();
    }
  }

  String _snippet(dynamic value) {
    String text;
    try {
      if (value is String) {
        text = value;
      } else {
        text = jsonEncode(value);
      }
    } catch (_) {
      text = value?.toString() ?? '';
    }

    if (text.length <= 500) {
      return text;
    }

    return '${text.substring(0, 500)}...';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const LexiAppBar(title: 'فحص API'),
      body: Padding(
        padding: const EdgeInsets.all(LexiSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(
              spacing: LexiSpacing.sm,
              runSpacing: LexiSpacing.sm,
              children: [
                ElevatedButton.icon(
                  onPressed: _loading ? null : _testProducts,
                  icon: const Icon(Icons.inventory_2_outlined),
                  label: const Text('اختبار المنتجات'),
                ),
                ElevatedButton.icon(
                  onPressed: _loading ? null : _testCategories,
                  icon: const Icon(Icons.category_outlined),
                  label: const Text('اختبار الأقسام'),
                ),
              ],
            ),
            const SizedBox(height: LexiSpacing.md),
            if (_loading)
              const LinearProgressIndicator(color: LexiColors.brandPrimary)
            else
              const SizedBox(height: 4),
            const SizedBox(height: LexiSpacing.md),
            Expanded(
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(LexiSpacing.md),
                decoration: BoxDecoration(
                  color: LexiColors.neutral100,
                  borderRadius: BorderRadius.circular(LexiRadius.md),
                  border: Border.all(color: LexiColors.neutral200),
                ),
                child: SingleChildScrollView(
                  child: SelectableText(
                    _result,
                    style: LexiTypography.bodySm.copyWith(
                      fontFamily: 'monospace',
                      color: LexiColors.brandBlack,
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
