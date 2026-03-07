import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart' as intl;

import '../../../../../design_system/lexi_tokens.dart';
import '../../../../../design_system/lexi_typography.dart';
import '../../../../../shared/widgets/lexi_ui/lexi_ui.dart';
import '../../domain/entities/admin_merch_product.dart';
import '../controllers/admin_flash_deals_controller.dart';
import '../controllers/admin_merch_categories_controller.dart';
import '../controllers/admin_category_merch_controller.dart';
import '../../../../../core/utils/currency_formatter.dart';
import '../../../../../shared/ui/lexi_alert.dart';

class AdminEditFlashDealPage extends ConsumerStatefulWidget {
  const AdminEditFlashDealPage({super.key});

  @override
  ConsumerState<AdminEditFlashDealPage> createState() =>
      _AdminEditFlashDealPageState();
}

class _AdminEditFlashDealPageState
    extends ConsumerState<AdminEditFlashDealPage> {
  int _currentStep = 0;

  int? _selectedCategoryId;
  AdminMerchProduct? _selectedProduct;

  final _priceController = TextEditingController();
  DateTime _startDate = DateTime.now();
  DateTime _endDate = DateTime.now().add(const Duration(hours: 24));

  @override
  void dispose() {
    _priceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stepper(
        currentStep: _currentStep,
        onStepContinue: _handleContinue,
        onStepCancel: _handleCancel,
        controlsBuilder: (context, details) {
          return Padding(
            padding: const EdgeInsets.only(top: LexiSpacing.lg),
            child: Row(
              children: [
                Expanded(
                  child: LexiButton(
                    label: _currentStep == 2 ? 'تأكيد الجدولة' : 'متابعة',
                    onPressed: details.onStepContinue,
                  ),
                ),
                if (_currentStep > 0) ...[
                  const SizedBox(width: LexiSpacing.md),
                  Expanded(
                    child: LexiButton(
                      label: 'رجوع',
                      onPressed: details.onStepCancel,
                      variant: LexiButtonVariant.outline,
                    ),
                  ),
                ],
              ],
            ),
          );
        },
        steps: [
          Step(
            title: const Text('اختيار المنتج'),
            subtitle: _selectedProduct != null
                ? Text(_selectedProduct!.name)
                : null,
            content: _buildProductPicker(),
            isActive: _currentStep >= 0,
            state: _selectedProduct != null
                ? StepState.complete
                : StepState.indexed,
          ),
          Step(
            title: const Text('تحديد السعر'),
            subtitle: _priceController.text.isNotEmpty
                ? Text('${_priceController.text} ل.س')
                : null,
            content: _buildPricePicker(),
            isActive: _currentStep >= 1,
            state: _priceController.text.isNotEmpty
                ? StepState.complete
                : StepState.indexed,
          ),
          Step(
            title: const Text('الموعد'),
            content: _buildTimePicker(),
            isActive: _currentStep >= 2,
          ),
        ],
      ),
    );
  }

  Widget _buildProductPicker() {
    final categoriesState = ref.watch(adminMerchCategoriesControllerProvider);

    return categoriesState.when(
      data: (categories) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DropdownButtonFormField<int>(
              initialValue: _selectedCategoryId,
              decoration: const InputDecoration(
                labelText: 'اختر التصنيف',
                border: OutlineInputBorder(),
              ),
              items: categories
                  .map(
                    (c) => DropdownMenuItem(value: c.id, child: Text(c.name)),
                  )
                  .toList(),
              onChanged: (val) {
                setState(() {
                  _selectedCategoryId = val;
                  _selectedProduct = null;
                });
              },
            ),
            if (_selectedCategoryId != null) ...[
              const SizedBox(height: LexiSpacing.md),
              const Text('اختر المنتج:', style: LexiTypography.bodyBold),
              const SizedBox(height: LexiSpacing.sm),
              _ProductList(
                categoryId: _selectedCategoryId!,
                selectedProductId: _selectedProduct?.id,
                onSelected: (p) => setState(() => _selectedProduct = p),
              ),
            ],
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Text('خطأ: $e'),
    );
  }

  Widget _buildPricePicker() {
    if (_selectedProduct == null) return const Text('برجاء اختيار منتج أولاً');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LexiCard(
          child: Row(
            children: [
              if (_selectedProduct?.featuredImage != null)
                Image.network(
                  _selectedProduct!.featuredImage!,
                  width: 50,
                  height: 50,
                  fit: BoxFit.cover,
                ),
              const SizedBox(width: LexiSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _selectedProduct!.name,
                      style: LexiTypography.bodyBold,
                    ),
                    Text(
                      'السعر الحالي: ${CurrencyFormatter.formatAmount(_selectedProduct!.price)}',
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: LexiSpacing.lg),
        TextField(
          controller: _priceController,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'سعر العرض (ل.س)',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.sell_rounded),
          ),
        ),
      ],
    );
  }

  Widget _buildTimePicker() {
    final fmt = intl.DateFormat('yyyy/MM/dd HH:mm');
    return Column(
      children: [
        ListTile(
          title: const Text('وقت البدء'),
          subtitle: Text(fmt.format(_startDate)),
          trailing: const Icon(Icons.calendar_month_rounded),
          onTap: () => _pickDateTime(true),
        ),
        const Divider(),
        ListTile(
          title: const Text('وقت الانتهاء'),
          subtitle: Text(fmt.format(_endDate)),
          trailing: const Icon(Icons.calendar_month_rounded),
          onTap: () => _pickDateTime(false),
        ),
      ],
    );
  }

  Future<void> _pickDateTime(bool isStart) async {
    final date = await showDatePicker(
      context: context,
      initialDate: isStart ? _startDate : _endDate,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (date == null || !mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(isStart ? _startDate : _endDate),
    );
    if (time == null) return;

    setState(() {
      final dt = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );
      if (isStart) {
        _startDate = dt;
      } else {
        _endDate = dt;
      }
    });
  }

  void _handleContinue() {
    if (_currentStep == 0) {
      if (_selectedProduct == null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('برجاء اختيار منتج')));
        return;
      }
      setState(() => _currentStep++);
    } else if (_currentStep == 1) {
      if (_priceController.text.isEmpty) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('برجاء تحديد سعر العرض')));
        return;
      }
      setState(() => _currentStep++);
    } else if (_currentStep == 2) {
      _submit();
    }
  }

  void _handleCancel() {
    if (_currentStep > 0) {
      setState(() => _currentStep--);
    } else {
      Navigator.pop(context);
    }
  }

  Future<void> _submit() async {
    final price = double.tryParse(_priceController.text);
    if (price == null) return;

    await LexiAlert.loading(context, text: 'جاري جدولة العرض...');
    try {
      await ref
          .read(adminFlashDealsControllerProvider.notifier)
          .scheduleDeal(
            productId: _selectedProduct!.id,
            salePrice: price,
            startsAt: _startDate,
            endsAt: _endDate,
          );
      if (!mounted) return;
      await LexiAlert.dismiss(context);
      if (!mounted) return;
      await LexiAlert.success(context, text: 'تمت جدولة العرض بنجاح');
      if (!mounted) return;
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      await LexiAlert.dismiss(context);
      if (!mounted) return;
      await LexiAlert.error(context, text: 'خطأ: $e');
    }
  }
}

class _ProductList extends ConsumerWidget {
  final int categoryId;
  final int? selectedProductId;
  final ValueChanged<AdminMerchProduct> onSelected;

  const _ProductList({
    required this.categoryId,
    this.selectedProductId,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final productsState = ref.watch(
      adminCategoryMerchControllerProvider(categoryId),
    );

    return productsState.when(
      data: (products) {
        if (products.isEmpty) {
          return const Text('لا يوجد منتجات في هذا التصنيف');
        }
        return Container(
          constraints: const BoxConstraints(maxHeight: 300),
          decoration: BoxDecoration(
            border: Border.all(
              color: LexiColors.brandGrey.withValues(alpha: 0.2),
            ),
            borderRadius: BorderRadius.circular(LexiSpacing.sm),
          ),
          child: ListView.separated(
            shrinkWrap: true,
            itemCount: products.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final p = products[index];
              final isSelected = p.id == selectedProductId;
              return ListTile(
                selected: isSelected,
                selectedTileColor: LexiColors.brandPrimary.withValues(
                  alpha: 0.05,
                ),
                leading: CircleAvatar(
                  backgroundImage: p.imageUrl.isNotEmpty
                      ? NetworkImage(p.imageUrl)
                      : null,
                  onBackgroundImageError: p.imageUrl.isNotEmpty
                      ? (_, stackTrace) {}
                      : null,
                  child: p.imageUrl.isEmpty
                      ? const Icon(Icons.inventory_2_outlined)
                      : null,
                ),
                title: Text(p.name, style: LexiTypography.bodySmallBold),
                subtitle: Text(
                  CurrencyFormatter.formatAmount(p.price),
                  style: LexiTypography.bodySmall,
                ),
                onTap: () => onSelected(p),
              );
            },
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Text('خطأ في تحميل المنتجات: $e'),
    );
  }
}
