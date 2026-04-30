import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../shared/ui/lexi_alert.dart';
import '../../domain/entities/admin_merch_product.dart';
import '../controllers/admin_category_merch_controller.dart';
import '../controllers/admin_merch_categories_controller.dart';

class AdminMerchCategoryProductsPage extends ConsumerStatefulWidget {
  const AdminMerchCategoryProductsPage({super.key});

  @override
  ConsumerState<AdminMerchCategoryProductsPage> createState() =>
      _AdminMerchCategoryProductsPageState();
}

class _AdminMerchCategoryProductsPageState
    extends ConsumerState<AdminMerchCategoryProductsPage> {
  final _searchController = TextEditingController();

  int? _selectedCategoryId;
  List<AdminMerchProduct> _working = const [];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final categoriesAsync = ref.watch(adminMerchCategoriesControllerProvider);

    return Scaffold(
      body: categoriesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => _SimpleError(
          message: 'تعذر تحميل التصنيفات.',
          onRetry: () => ref
              .read(adminMerchCategoriesControllerProvider.notifier)
              .refresh(),
        ),
        data: (categories) {
          if (categories.isEmpty) {
            return const Center(child: Text('لا توجد تصنيفات متاحة.'));
          }

          _selectedCategoryId ??= categories.first.id;
          final selected = categories.firstWhere(
            (item) => item.id == _selectedCategoryId,
            orElse: () => categories.first,
          );

          final productsAsync = ref.watch(
            adminCategoryMerchControllerProvider(selected.id),
          );

          return productsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (_, _) => _SimpleError(
              message: 'تعذر تحميل منتجات التصنيف.',
              onRetry: () => ref
                  .read(
                    adminCategoryMerchControllerProvider(selected.id).notifier,
                  )
                  .search(_searchController.text),
            ),
            data: (products) {
              if (_working.isEmpty || _working.length != products.length) {
                _working = List<AdminMerchProduct>.from(products);
              }

              return Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        DropdownButtonFormField<int>(
                          initialValue: selected.id,
                          decoration: const InputDecoration(
                            labelText: 'التصنيف',
                            border: OutlineInputBorder(),
                          ),
                          items: categories
                              .map(
                                (item) => DropdownMenuItem<int>(
                                  value: item.id,
                                  child: Text(item.hierarchyLabel),
                                ),
                              )
                              .toList(),
                          onChanged: (value) {
                            if (value == null) return;
                            setState(() {
                              _selectedCategoryId = value;
                              _working = const [];
                            });
                          },
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          controller: _searchController,
                          decoration: InputDecoration(
                            hintText: 'ابحث عن منتج داخل التصنيف...',
                            border: const OutlineInputBorder(),
                            suffixIcon: IconButton(
                              icon: const Icon(Icons.search),
                              onPressed: () {
                                ref
                                    .read(
                                      adminCategoryMerchControllerProvider(
                                        selected.id,
                                      ).notifier,
                                    )
                                    .search(_searchController.text);
                              },
                            ),
                          ),
                          onSubmitted: (_) {
                            ref
                                .read(
                                  adminCategoryMerchControllerProvider(
                                    selected.id,
                                  ).notifier,
                                )
                                .search(_searchController.text);
                          },
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: DefaultTabController(
                      length: 2,
                      child: Column(
                        children: [
                          const TabBar(
                            tabs: [
                              Tab(text: 'مثبتة'),
                              Tab(text: 'باقي المنتجات'),
                            ],
                          ),
                          Expanded(
                            child: TabBarView(
                              children: [
                                _buildPinnedList(selected.id),
                                _buildUnpinnedList(selected.id),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsetsDirectional.fromSTEB(
                      16,
                      0,
                      16,
                      16,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => _resetOrder(selected.id),
                            icon: const Icon(Icons.restore),
                            label: const Text('إعادة تعيين الترتيب'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () => _save(selected.id),
                            icon: const Icon(Icons.save_outlined),
                            label: const Text('حفظ'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildPinnedList(int termId) {
    final pinned = _working.where((item) => item.pinned).toList();
    if (pinned.isEmpty) {
      return const Center(child: Text('لا توجد منتجات مثبتة.'));
    }

    return ReorderableListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: pinned.length,
      onReorder: (oldIndex, newIndex) {
        setState(() {
          if (newIndex > oldIndex) {
            newIndex -= 1;
          }
          final moved = pinned.removeAt(oldIndex);
          pinned.insert(newIndex, moved);
          final others = _working.where((item) => !item.pinned).toList();
          _working = [...pinned, ...others];
        });
      },
      itemBuilder: (context, index) {
        final product = pinned[index];
        return _ProductRow(
          key: ValueKey('pinned_${product.id}'),
          product: product,
          onPinChanged: (value) => _setPinned(product.id, value),
        );
      },
    );
  }

  Widget _buildUnpinnedList(int termId) {
    final others = _working.where((item) => !item.pinned).toList();
    if (others.isEmpty) {
      return const Center(child: Text('لا توجد منتجات غير مثبتة.'));
    }

    return ReorderableListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: others.length,
      onReorder: (oldIndex, newIndex) {
        setState(() {
          if (newIndex > oldIndex) {
            newIndex -= 1;
          }
          final moved = others.removeAt(oldIndex);
          others.insert(newIndex, moved);
          final pinned = _working.where((item) => item.pinned).toList();
          _working = [...pinned, ...others];
        });
      },
      itemBuilder: (context, index) {
        final product = others[index];
        return _ProductRow(
          key: ValueKey('other_${product.id}'),
          product: product,
          onPinChanged: (value) => _setPinned(product.id, value),
        );
      },
    );
  }

  void _setPinned(int productId, bool pinned) {
    setState(() {
      _working = _working
          .map(
            (item) =>
                item.id == productId ? item.copyWith(pinned: pinned) : item,
          )
          .toList();

      final pinnedItems = _working.where((item) => item.pinned).toList();
      final otherItems = _working.where((item) => !item.pinned).toList();
      _working = [...pinnedItems, ...otherItems];
    });
  }

  Future<void> _save(int termId) async {
    final pinned = _working.where((item) => item.pinned).toList();
    final others = _working.where((item) => !item.pinned).toList();
    final merged = [...pinned, ...others];

    final payload = List<AdminMerchProduct>.generate(
      merged.length,
      (index) => merged[index].copyWith(sortOrder: index + 1),
    );

    await LexiAlert.loading(context, text: 'جاري حفظ الترتيب...');
    try {
      await ref
          .read(adminCategoryMerchControllerProvider(termId).notifier)
          .save(payload);
      if (!mounted) return;
      setState(() => _working = const []);
      await LexiAlert.dismiss(context);
      if (!mounted) return;
      await LexiAlert.success(context, text: 'تم حفظ ترتيب المنتجات بنجاح.');
    } catch (_) {
      if (!mounted) return;
      await LexiAlert.dismiss(context);
      if (!mounted) return;
      await LexiAlert.error(context, text: 'تعذر حفظ الترتيب حالياً.');
    }
  }

  Future<void> _resetOrder(int termId) async {
    await LexiAlert.confirm(
      context,
      title: 'إعادة تعيين الترتيب',
      text: 'سيتم حذف كل ترتيب يدوي لهذا التصنيف. متابعة؟',
      confirmText: 'متابعة',
      cancelText: 'إلغاء',
      onConfirm: () async {
        await LexiAlert.loading(context, text: 'جاري إعادة التعيين...');
        try {
          await ref
              .read(adminCategoryMerchControllerProvider(termId).notifier)
              .clearOrder();
          if (!mounted) return;
          await LexiAlert.dismiss(context);
          if (!mounted) return;
          await LexiAlert.success(context, text: 'تمت إعادة التعيين بنجاح.');
          setState(() => _working = const []);
        } catch (_) {
          if (!mounted) return;
          await LexiAlert.dismiss(context);
          if (!mounted) return;
          await LexiAlert.error(context, text: 'تعذر إعادة التعيين حالياً.');
        }
      },
    );
  }
}

class _ProductRow extends StatelessWidget {
  final AdminMerchProduct product;
  final ValueChanged<bool> onPinChanged;

  const _ProductRow({
    required super.key,
    required this.product,
    required this.onPinChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: SizedBox(
          width: 44,
          height: 44,
          child: product.imageUrl.trim().isEmpty
              ? const Icon(Icons.inventory_2_outlined)
              : Image.network(product.imageUrl, fit: BoxFit.cover),
        ),
        title: Text(product.name, maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Text(
          '${product.price.toStringAsFixed(0)} ل.س • ${product.inStock ? 'متوفر' : 'غير متوفر'}',
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Switch(value: product.pinned, onChanged: onPinChanged),
            const Icon(Icons.drag_handle),
          ],
        ),
      ),
    );
  }
}

class _SimpleError extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _SimpleError({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(message),
          const SizedBox(height: 10),
          OutlinedButton(
            onPressed: onRetry,
            child: const Text('إعادة المحاولة'),
          ),
        ],
      ),
    );
  }
}
