import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../shared/ui/lexi_alert.dart';
import '../../../../product/presentation/controllers/products_controller.dart';
import '../../../../product/domain/usecases/get_products.dart';
import '../../domain/entities/admin_home_section.dart';
import '../../domain/entities/admin_merch_product.dart';
import '../controllers/admin_home_sections_controller.dart';
import '../../../../../ui/widgets/lexi_image.dart';
import '../../../../../design_system/lexi_tokens.dart';

class AdminHomeSectionItemsPage extends ConsumerStatefulWidget {
  final AdminHomeSection section;

  const AdminHomeSectionItemsPage({super.key, required this.section});

  @override
  ConsumerState<AdminHomeSectionItemsPage> createState() =>
      _AdminHomeSectionItemsPageState();
}

class _AdminHomeSectionItemsPageState
    extends ConsumerState<AdminHomeSectionItemsPage> {
  final _searchController = TextEditingController();
  List<AdminMerchProduct> _items = const [];
  List<AdminMerchProduct> _searchResults = const [];
  bool _isSearching = false;
  bool _didHydrate = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final asyncItems = ref.watch(
      adminHomeSectionItemsControllerProvider(widget.section.id),
    );

    return Scaffold(
      appBar: AppBar(
        title: Text('عناصر القسم: ${widget.section.titleAr}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.save_outlined),
            onPressed: _items.isEmpty ? null : _save,
          ),
        ],
      ),
      body: asyncItems.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => const Center(child: Text('تعذر تحميل عناصر القسم.')),
        data: (loaded) {
          if (!_didHydrate) {
            _items = List<AdminMerchProduct>.from(loaded);
            _didHydrate = true;
          }

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        decoration: const InputDecoration(
                          hintText: 'ابحث عن منتج لإضافته...',
                          border: OutlineInputBorder(),
                        ),
                        onSubmitted: (_) => _searchProducts(),
                      ),
                    ),
                    const SizedBox(width: 10),
                    FilledButton(
                      onPressed: _isSearching ? null : _searchProducts,
                      child: _isSearching
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('بحث'),
                    ),
                  ],
                ),
              ),
              if (_searchResults.isNotEmpty)
                SizedBox(
                  height: 190,
                  child: ListView.builder(
                    itemCount: _searchResults.length,
                    itemBuilder: (context, index) {
                      final product = _searchResults[index];
                      return ListTile(
                        title: Text(product.name),
                        subtitle: Text(
                          '${product.price.toStringAsFixed(0)} ل.س',
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.add_circle_outline),
                          onPressed: () => _addProduct(product),
                        ),
                      );
                    },
                  ),
                ),
              Expanded(
                child: _items.isEmpty
                    ? const Center(child: Text('لا توجد عناصر في هذا القسم.'))
                    : ReorderableListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                        itemCount: _items.length,
                        onReorder: (oldIndex, newIndex) {
                          setState(() {
                            if (newIndex > oldIndex) {
                              newIndex -= 1;
                            }
                            final item = _items.removeAt(oldIndex);
                            _items.insert(newIndex, item);
                          });
                        },
                        itemBuilder: (context, index) {
                          final item = _items[index];
                          return Card(
                            key: ValueKey('section-item-${item.id}'),
                            child: ListTile(
                              leading: LexiImage(
                                imageUrl: item.imageUrl,
                                width: 42,
                                height: 42,
                                borderRadius: BorderRadius.circular(
                                  LexiSpacing.xs,
                                ),
                                errorWidget: const Icon(
                                  Icons.inventory_2_outlined,
                                ),
                              ),
                              title: Text(item.name),
                              subtitle: Text(
                                '${item.price.toStringAsFixed(0)} ل.س',
                              ),
                              trailing: SizedBox(
                                width: 100, // Reduced from 140
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Switch(
                                      value: item.pinned,
                                      materialTapTargetSize:
                                          MaterialTapTargetSize.shrinkWrap,
                                      onChanged: (value) {
                                        setState(() {
                                          _items[index] = item.copyWith(
                                            pinned: value,
                                          );
                                        });
                                      },
                                    ),
                                    IconButton(
                                      padding: EdgeInsets.zero,
                                      constraints:
                                          const BoxConstraints.tightFor(
                                            width: 36,
                                            height: 36,
                                          ),
                                      onPressed: () {
                                        setState(() {
                                          _items.removeAt(index);
                                        });
                                      },
                                      icon: const Icon(
                                        Icons.delete_outline,
                                        size: 20,
                                      ),
                                      visualDensity: VisualDensity.compact,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _items.isEmpty ? null : _save,
        icon: const Icon(Icons.save),
        label: const Text('حفظ'),
      ),
    );
  }

  Future<void> _searchProducts() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) {
      setState(() => _searchResults = const []);
      return;
    }

    setState(() => _isSearching = true);
    try {
      final result = await ref.read(getProductsUseCaseProvider)(
        GetProductsParams(search: query, sort: 'newest', perPage: 20),
      );

      if (!mounted) return;
      setState(() {
        _searchResults = result.products
            .map(
              (p) => AdminMerchProduct(
                id: p.id,
                name: p.name,
                imageUrl: p.primaryImageUrl ?? p.primaryImage,
                price: p.price,
                regularPrice: p.regularPrice,
                inStock: p.inStock,
                pinned: false,
                sortOrder: null,
              ),
            )
            .toList();
      });
    } catch (_) {
      if (!mounted) return;
      await LexiAlert.error(context, text: 'تعذر تنفيذ البحث حالياً.');
    } finally {
      if (mounted) {
        setState(() => _isSearching = false);
      }
    }
  }

  void _addProduct(AdminMerchProduct product) {
    final exists = _items.any((item) => item.id == product.id);
    if (exists) {
      return;
    }

    setState(() {
      _items = [..._items, product];
    });
  }

  Future<void> _save() async {
    final pinned = _items.where((item) => item.pinned).toList();
    final others = _items.where((item) => !item.pinned).toList();
    final merged = [...pinned, ...others];

    final payload = List<AdminMerchProduct>.generate(
      merged.length,
      (index) => merged[index].copyWith(sortOrder: index + 1),
    );

    await LexiAlert.loading(context, text: 'جاري حفظ عناصر القسم...');
    try {
      await ref
          .read(
            adminHomeSectionItemsControllerProvider(widget.section.id).notifier,
          )
          .save(payload);
      if (!mounted) return;
      // Reset hydration so the list re-syncs from the server-confirmed state.
      _didHydrate = false;
      await LexiAlert.dismiss(context);
      if (!mounted) return;
      await LexiAlert.success(context, text: 'تم حفظ عناصر القسم بنجاح.');
    } catch (e) {
      if (!mounted) return;
      await LexiAlert.dismiss(context);
      if (!mounted) return;
      await LexiAlert.error(context, text: 'تعذر حفظ عناصر القسم حالياً.\n$e');
    }
  }
}
