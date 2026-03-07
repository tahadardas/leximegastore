import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../app/theme/lexi_theme.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../shared/ui/lexi_alert.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../domain/entities/admin_shipping_city.dart';
import '../controllers/admin_shipping_controller.dart';

class AdminShippingPage extends ConsumerWidget {
  const AdminShippingPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final citiesAsync = ref.watch(adminShippingControllerProvider);

    return Scaffold(
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showCityDialog(context, ref),
        child: const Icon(Icons.add),
      ),
      body: citiesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => Center(child: Text('خطأ: $e')),
        data: (cities) {
          if (cities.isEmpty) {
            return const Center(child: Text('لا توجد مناطق شحن مضافة.'));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(LexiSpacing.md),
            itemCount: cities.length,
            itemBuilder: (context, index) {
              final city = cities[index];
              return Card(
                margin: const EdgeInsets.only(bottom: LexiSpacing.md),
                child: ListTile(
                  title: Text(
                    city.name,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(CurrencyFormatter.formatAmount(city.price)),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Switch(
                        value: city.isActive,
                        onChanged: (val) {
                          ref
                              .read(adminShippingControllerProvider.notifier)
                              .updateCity(city.id, isActive: val);
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.edit, color: LexiColors.primary),
                        onPressed: () =>
                            _showCityDialog(context, ref, city: city),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () => _confirmDelete(context, ref, city),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  void _showCityDialog(
    BuildContext context,
    WidgetRef ref, {
    AdminShippingCity? city,
  }) {
    showDialog(
      context: context,
      builder: (context) => _AdminShippingCityDialog(city: city),
    );
  }

  void _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    AdminShippingCity city,
  ) {
    LexiAlert.confirm(
      context,
      title: 'حذف المنطقة',
      text: 'هل أنت متأكد من حذف "${city.name}"؟',
      confirmText: 'حذف',
      cancelText: 'إلغاء',
      onConfirm: () {
        ref.read(adminShippingControllerProvider.notifier).deleteCity(city.id);
      },
    );
  }
}

class _AdminShippingCityDialog extends ConsumerStatefulWidget {
  final AdminShippingCity? city;
  const _AdminShippingCityDialog({this.city});

  @override
  ConsumerState<_AdminShippingCityDialog> createState() =>
      _AdminShippingCityDialogState();
}

class _AdminShippingCityDialogState
    extends ConsumerState<_AdminShippingCityDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _priceController;
  late TextEditingController _sortOrderController;
  bool _isActive = true;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.city?.name ?? '');
    _priceController = TextEditingController(
      text: widget.city?.price.toString() ?? '',
    );
    _sortOrderController = TextEditingController(
      text: widget.city?.sortOrder.toString() ?? '0',
    );
    _isActive = widget.city?.isActive ?? true;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _priceController.dispose();
    _sortOrderController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.city != null;
    return AlertDialog(
      title: Text(isEditing ? 'تعديل منطقة' : 'إضافة منطقة'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'اسم المنطقة'),
                validator: (v) => v!.isEmpty ? 'مطلوب' : null,
              ),
              const SizedBox(height: LexiSpacing.sm),
              TextFormField(
                controller: _priceController,
                decoration: const InputDecoration(labelText: 'سعر التوصيل'),
                keyboardType: TextInputType.number,
                validator: (v) => v!.isEmpty ? 'مطلوب' : null,
              ),
              const SizedBox(height: LexiSpacing.sm),
              TextFormField(
                controller: _sortOrderController,
                decoration: const InputDecoration(
                  labelText: 'الترتيب (Sort Order)',
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: LexiSpacing.sm),
              SwitchListTile(
                title: const Text('نشط'),
                value: _isActive,
                onChanged: (val) => setState(() => _isActive = val),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('إلغاء'),
        ),
        AppButton(
          label: isEditing ? 'حفظ' : 'إضافة',
          onPressed: () async {
            if (_formKey.currentState!.validate()) {
              final name = _nameController.text;
              final price = double.parse(_priceController.text);
              final sortOrder = int.tryParse(_sortOrderController.text) ?? 0;

              if (isEditing) {
                await ref
                    .read(adminShippingControllerProvider.notifier)
                    .updateCity(
                      widget.city!.id,
                      name: name,
                      price: price,
                      isActive: _isActive,
                      sortOrder: sortOrder,
                    );
              } else {
                await ref
                    .read(adminShippingControllerProvider.notifier)
                    .createCity(
                      name: name,
                      price: price,
                      isActive: _isActive,
                      sortOrder: sortOrder,
                    );
              }
              if (!context.mounted) return;
              Navigator.pop(context);
            }
          },
        ),
      ],
    );
  }
}
