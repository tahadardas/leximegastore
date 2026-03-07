import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../app/theme/lexi_theme.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../shared/ui/lexi_alert.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../domain/entities/admin_coupon.dart';
import '../controllers/admin_coupons_controller.dart';

class AdminCouponsPage extends ConsumerWidget {
  const AdminCouponsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final couponsAsync = ref.watch(adminCouponsControllerProvider);

    return Scaffold(
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showCouponDialog(context, ref),
        child: const Icon(Icons.add),
      ),
      body: couponsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => Center(child: Text('\u062e\u0637\u0623: $e')),
        data: (coupons) {
          if (coupons.isEmpty) {
            return const Center(child: Text('لا توجد كوبونات مضافة.'));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(LexiSpacing.md),
            itemCount: coupons.length,
            itemBuilder: (context, index) {
              final coupon = coupons[index];
              final isExpired =
                  coupon.dateExpires != null &&
                  coupon.dateExpires!.isBefore(DateTime.now());

              return Card(
                margin: const EdgeInsets.only(bottom: LexiSpacing.md),
                child: ListTile(
                  title: Row(
                    children: [
                      Text(
                        coupon.code.toUpperCase(),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Courier',
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(width: LexiSpacing.sm),
                      if (isExpired)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.red.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'منتهي',
                            style: TextStyle(color: Colors.red, fontSize: 10),
                          ),
                        ),
                    ],
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_describeDiscount(coupon)),
                      if (coupon.usageLimit != null)
                        Text(
                          'الاستخدام: ${coupon.usageCount} / ${coupon.usageLimit}',
                          style: const TextStyle(fontSize: 12),
                        ),
                      if (coupon.dateExpires != null)
                        Text(
                          'ينتهي في: ${DateFormat('yyyy-MM-dd').format(coupon.dateExpires!)}',
                          style: const TextStyle(fontSize: 12),
                        ),
                    ],
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit, color: LexiColors.primary),
                        onPressed: () =>
                            _showCouponDialog(context, ref, coupon: coupon),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () => _confirmDelete(context, ref, coupon),
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

  String _describeDiscount(AdminCoupon coupon) {
    if (coupon.discountType == 'percent') {
      return 'خصم ${coupon.amount}%';
    } else if (coupon.discountType == 'fixed_cart') {
      return 'خصم ثابت ${CurrencyFormatter.formatAmount(coupon.amount)}';
    } else {
      return 'خصم منتج ${CurrencyFormatter.formatAmount(coupon.amount)}';
    }
  }

  void _showCouponDialog(
    BuildContext context,
    WidgetRef ref, {
    AdminCoupon? coupon,
  }) {
    showDialog(
      context: context,
      builder: (context) => _AdminCouponDialog(coupon: coupon),
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref, AdminCoupon coupon) {
    LexiAlert.confirm(
      context,
      title: 'حذف الكوبون',
      text: 'هل أنت متأكد من حذف الكوبون "${coupon.code}"؟',
      confirmText: 'حذف',
      cancelText: 'إلغاء',
      onConfirm: () {
        ref
            .read(adminCouponsControllerProvider.notifier)
            .deleteCoupon(coupon.id);
      },
    );
  }
}

class _AdminCouponDialog extends ConsumerStatefulWidget {
  final AdminCoupon? coupon;
  const _AdminCouponDialog({this.coupon});

  @override
  ConsumerState<_AdminCouponDialog> createState() => _AdminCouponDialogState();
}

class _AdminCouponDialogState extends ConsumerState<_AdminCouponDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _codeController;
  late TextEditingController _amountController;
  late TextEditingController _descriptionController;
  late TextEditingController _usageLimitController;
  late TextEditingController _minAmountController;

  String _discountType = 'fixed_cart';
  DateTime? _dateExpires;
  bool _individualUse = false;
  bool _excludeSaleItems = false;

  @override
  void initState() {
    super.initState();
    final c = widget.coupon;
    _codeController = TextEditingController(text: c?.code ?? '');
    _amountController = TextEditingController(text: c?.amount.toString() ?? '');
    _descriptionController = TextEditingController(text: c?.description ?? '');
    _usageLimitController = TextEditingController(
      text: c?.usageLimit?.toString() ?? '',
    );
    _minAmountController = TextEditingController(
      text: c?.minimumAmount.toString() ?? '',
    );

    if (c != null) {
      _discountType = c.discountType;
      _dateExpires = c.dateExpires;
      _individualUse = c.individualUse;
      _excludeSaleItems = c.excludeSaleItems;
    }
  }

  @override
  void dispose() {
    _codeController.dispose();
    _amountController.dispose();
    _descriptionController.dispose();
    _usageLimitController.dispose();
    _minAmountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.coupon != null;
    return AlertDialog(
      title: Text(isEditing ? 'تعديل كوبون' : 'إضافة كوبون'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _codeController,
                decoration: const InputDecoration(labelText: 'رمز الكوبون'),
                validator: (v) => v!.isEmpty ? 'مطلوب' : null,
              ),
              const SizedBox(height: LexiSpacing.sm),
              DropdownButtonFormField<String>(
                initialValue: _discountType,
                decoration: const InputDecoration(labelText: 'نوع الخصم'),
                items: const [
                  DropdownMenuItem(value: 'percent', child: Text('نسبة مئوية')),
                  DropdownMenuItem(
                    value: 'fixed_cart',
                    child: Text('خصم ثابت للسلة'),
                  ),
                  DropdownMenuItem(
                    value: 'fixed_product',
                    child: Text('خصم ثابت للمنتج'),
                  ),
                ],
                onChanged: (val) {
                  if (val != null) _discountType = val;
                },
              ),
              const SizedBox(height: LexiSpacing.sm),
              TextFormField(
                controller: _amountController,
                decoration: const InputDecoration(labelText: 'قيمة الخصم'),
                keyboardType: TextInputType.numberWithOptions(decimal: true),
                validator: (v) => v!.isEmpty ? 'مطلوب' : null,
              ),
              const SizedBox(height: LexiSpacing.sm),
              TextFormField(
                controller: _minAmountController,
                decoration: const InputDecoration(labelText: 'أقل قيمة للطلب'),
                keyboardType: TextInputType.numberWithOptions(decimal: true),
              ),
              const SizedBox(height: LexiSpacing.sm),
              TextFormField(
                controller: _usageLimitController,
                decoration: const InputDecoration(
                  labelText: 'حد الاستخدام',
                  helperText: 'اتركه فارغاً، لعدد غير محدود',
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: LexiSpacing.sm),
              ListTile(
                title: const Text('تاريخ الانتهاء'),
                subtitle: Text(
                  _dateExpires == null
                      ? 'لا يوجد'
                      : DateFormat('yyyy-MM-dd').format(_dateExpires!),
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_dateExpires != null)
                      IconButton(
                        icon: const Icon(Icons.clear, size: 20),
                        onPressed: () => setState(() => _dateExpires = null),
                      ),
                    IconButton(
                      icon: const Icon(Icons.calendar_today, size: 20),
                      onPressed: _pickDate,
                    ),
                  ],
                ),
              ),
              CheckboxListTile(
                title: const Text('استخدام فردي فقط'),
                value: _individualUse,
                onChanged: (val) =>
                    setState(() => _individualUse = val == true),
              ),
              CheckboxListTile(
                title: const Text('استبعاد المنتجات المخفضة'),
                value: _excludeSaleItems,
                onChanged: (val) =>
                    setState(() => _excludeSaleItems = val == true),
              ),
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(labelText: 'وصف (اختياري)'),
                maxLines: 2,
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
        AppButton(label: isEditing ? 'حفظ' : 'إضافة', onPressed: _save),
      ],
    );
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _dateExpires ?? now.add(const Duration(days: 7)),
      firstDate: now.subtract(const Duration(days: 1)),
      lastDate: now.add(const Duration(days: 365 * 2)),
    );
    if (picked != null) {
      setState(() => _dateExpires = picked);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final code = _codeController.text.trim();
    final amount = double.tryParse(_amountController.text) ?? 0;
    final minAmount = double.tryParse(_minAmountController.text);
    final usageLimit = int.tryParse(_usageLimitController.text);
    final description = _descriptionController.text.trim();

    if (widget.coupon != null) {
      // Update
      await ref
          .read(adminCouponsControllerProvider.notifier)
          .updateCoupon(
            widget.coupon!.id,
            code: code,
            discountType: _discountType,
            amount: amount,
            minimumAmount: minAmount,
            usageLimit: usageLimit,
            description: description,
            dateExpires: _dateExpires,
            clearDateExpires: _dateExpires == null,
            individualUse: _individualUse,
            excludeSaleItems: _excludeSaleItems,
          );
    } else {
      // Create
      await ref
          .read(adminCouponsControllerProvider.notifier)
          .createCoupon(
            code: code,
            discountType: _discountType,
            amount: amount,
            minimumAmount: minAmount,
            usageLimit: usageLimit,
            description: description,
            dateExpires: _dateExpires,
            individualUse: _individualUse,
            excludeSaleItems: _excludeSaleItems,
          );
    }

    if (!mounted) return;
    Navigator.pop(context);
  }
}
