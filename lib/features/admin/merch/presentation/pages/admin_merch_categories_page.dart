import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/admin_merch_category.dart';
import '../controllers/admin_merch_categories_controller.dart';

class AdminMerchCategoriesPage extends ConsumerStatefulWidget {
  const AdminMerchCategoriesPage({super.key});

  @override
  ConsumerState<AdminMerchCategoriesPage> createState() =>
      _AdminMerchCategoriesPageState();
}

class _AdminMerchCategoriesPageState
    extends ConsumerState<AdminMerchCategoriesPage> {
  List<AdminMerchCategory> _items = const [];
  bool _isSaving = false;

  @override
  Widget build(BuildContext context) {
    final asyncCategories = ref.watch(adminMerchCategoriesControllerProvider);

    return Scaffold(
      body: asyncCategories.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('تعذر تحميل التصنيفات حالياً.'),
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: () => ref
                      .read(adminMerchCategoriesControllerProvider.notifier)
                      .refresh(),
                  child: const Text('إعادة المحاولة'),
                ),
              ],
            ),
          ),
        ),
        data: (categories) {
          if (_items.isEmpty || _items.length != categories.length) {
            _items = List<AdminMerchCategory>.from(categories);
          }

          if (_items.isEmpty) {
            return const Center(child: Text('لا توجد تصنيفات متاحة.'));
          }

          return ReorderableListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: _items.length,
            onReorder: (oldIndex, newIndex) {
              setState(() {
                if (newIndex > oldIndex) {
                  newIndex -= 1;
                }
                final item = _items.removeAt(oldIndex);
                _items.insert(newIndex, item);
                _items = List.generate(
                  _items.length,
                  (index) => _items[index].copyWith(sortOrder: index + 1),
                );
              });
            },
            itemBuilder: (context, index) {
              final category = _items[index];
              return Card(
                key: ValueKey(category.id),
                child: ListTile(
                  leading: CircleAvatar(child: Text('${index + 1}')),
                  title: Padding(
                    padding: EdgeInsetsDirectional.only(
                      start: category.depth * 14.0,
                    ),
                    child: Text(category.name),
                  ),
                  subtitle: Text('عدد المنتجات: ${category.count}'),
                  trailing: const Icon(Icons.drag_handle),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: (_items.isEmpty || _isSaving) ? null : _save,
        icon: _isSaving
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.save),
        label: Text(_isSaving ? 'جاري الحفظ...' : 'حفظ'),
      ),
    );
  }

  Future<void> _save() async {
    if (_isSaving || _items.isEmpty) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('حفظ الترتيب'),
        content: const Text('هل تريد حفظ ترتيب التصنيفات الحالي؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('تأكيد'),
          ),
        ],
      ),
    );

    if (!mounted || confirmed != true) {
      return;
    }

    setState(() => _isSaving = true);
    try {
      await ref
          .read(adminMerchCategoriesControllerProvider.notifier)
          .saveOrder(_items);
      if (!mounted) return;
      setState(() => _items = const []);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('تم حفظ الترتيب بنجاح.')));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('تعذر حفظ الترتيب حالياً.')));
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }
}
