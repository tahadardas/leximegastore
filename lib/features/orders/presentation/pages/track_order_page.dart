import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/utils/order_number_utils.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_text_field.dart';
import '../../../../shared/widgets/lexi_ui/lexi_app_bar.dart';
import '../../../../design_system/lexi_tokens.dart';
import '../controllers/order_lookup_controller.dart';

class TrackOrderPage extends ConsumerStatefulWidget {
  const TrackOrderPage({super.key});

  @override
  ConsumerState<TrackOrderPage> createState() => _TrackOrderPageState();
}

class _TrackOrderPageState extends ConsumerState<TrackOrderPage> {
  final _formKey = GlobalKey<FormState>();
  final _orderNumberController = TextEditingController();

  @override
  void dispose() {
    _orderNumberController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(trackOrderControllerProvider);

    ref.listen(trackOrderControllerProvider, (prev, next) {
      final value = next.valueOrNull;
      if (value == null) {
        return;
      }

      context.push(
        '/orders/status?order_number=${Uri.encodeComponent(value.orderNumber)}',
      );
      ref.invalidate(trackOrderControllerProvider);
    });

    return Scaffold(
      backgroundColor: LexiColors.neutral50,
      appBar: const LexiAppBar(title: 'تتبع الطلب'),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(LexiSpacing.s16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AppTextField(
                controller: _orderNumberController,
                label: 'أدخل رقم الطلب',
                hint: '#12345',
                keyboardType: TextInputType.number,
                validator: (v) {
                  final normalized = normalizeOrderLookupInput(v ?? '');
                  if (normalized.isEmpty) {
                    return 'الرجاء إدخال رقم الطلب';
                  }
                  if (normalized.length < 3 || normalized.length > 32) {
                    return 'رقم الطلب غير صالح';
                  }
                  return null;
                },
              ),
              const SizedBox(height: LexiSpacing.s16),
              AppButton(
                label: 'تتبع',
                icon: Icons.search,
                isLoading: state.isLoading,
                onPressed: () {
                  if (!_formKey.currentState!.validate()) {
                    return;
                  }
                  final normalizedOrderNumber = normalizeOrderLookupInput(
                    _orderNumberController.text,
                  );
                  ref
                      .read(trackOrderControllerProvider.notifier)
                      .track(orderNumber: normalizedOrderNumber);
                },
              ),
              if (state.hasError) ...[
                const SizedBox(height: LexiSpacing.s16),
                Container(
                  padding: const EdgeInsets.all(LexiSpacing.s16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    'تعذر تتبع الطلب. تحقق من الرقم وحاول مرة أخرى.',
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
