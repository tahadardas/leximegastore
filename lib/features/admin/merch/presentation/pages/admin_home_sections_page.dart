import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../shared/ui/lexi_alert.dart';
import '../../../../../ui/widgets/lexi_safe_bottom.dart' show LexiSafeBottom;
import '../../domain/entities/admin_home_section.dart';
import '../controllers/admin_home_sections_controller.dart';
import '../controllers/admin_merch_categories_controller.dart';

import 'admin_home_section_items_page.dart';

class AdminHomeSectionsPage extends ConsumerStatefulWidget {
  const AdminHomeSectionsPage({super.key});

  @override
  ConsumerState<AdminHomeSectionsPage> createState() =>
      _AdminHomeSectionsPageState();
}

class _AdminHomeSectionsPageState extends ConsumerState<AdminHomeSectionsPage> {
  List<AdminHomeSection> _sections = const [];

  static const _types = _kHomeSectionTypes;

  @override
  Widget build(BuildContext context) {
    final sectionsAsync = ref.watch(adminHomeSectionsControllerProvider);

    return Scaffold(
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FloatingActionButton.small(
            heroTag: 'sections_save',
            onPressed: _sections.isEmpty ? null : _saveReorder,
            child: const Icon(Icons.save_outlined),
          ),
          const SizedBox(height: 8),
          FloatingActionButton(
            onPressed: _showAddSectionSheet,
            child: const Icon(Icons.add),
          ),
        ],
      ),
      body: sectionsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('تعذر تحميل الأقسام حالياً.'),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: () => ref
                    .read(adminHomeSectionsControllerProvider.notifier)
                    .refresh(),
                child: const Text('إعادة المحاولة'),
              ),
            ],
          ),
        ),
        data: (sections) {
          if (_sections.isEmpty || _sections.length != sections.length) {
            _sections = List<AdminHomeSection>.from(sections);
          }

          if (_sections.isEmpty) {
            return const Center(child: Text('لا توجد أقسام حتى الآن.'));
          }

          return ReorderableListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: _sections.length,
            onReorder: (oldIndex, newIndex) {
              setState(() {
                if (newIndex > oldIndex) {
                  newIndex -= 1;
                }
                final section = _sections.removeAt(oldIndex);
                _sections.insert(newIndex, section);
                _sections = List.generate(
                  _sections.length,
                  (index) => _sections[index].copyWith(sortOrder: index + 1),
                );
              });
            },
            itemBuilder: (context, index) {
              final section = _sections[index];
              return Card(
                key: ValueKey('section-${section.id}'),
                child: ListTile(
                  title: Text(section.titleAr),
                  subtitle: Text(
                    '${_types[section.type] ?? section.type} • العناصر: ${section.itemsCount}',
                  ),
                  trailing: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Switch(
                        value: section.isActive,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        onChanged: (value) async {
                          await ref
                              .read(
                                adminHomeSectionsControllerProvider.notifier,
                              )
                              .toggleActive(section, value);
                          if (!mounted) return;
                          setState(() => _sections = const []);
                        },
                      ),
                      IconButton(
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints.tightFor(
                          width: 36,
                          height: 36,
                        ),
                        visualDensity: VisualDensity.compact,
                        tooltip: 'إدارة العناصر',
                        icon: const Icon(Icons.view_list_outlined, size: 20),
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) =>
                                  AdminHomeSectionItemsPage(section: section),
                            ),
                          );
                        },
                      ),
                      IconButton(
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints.tightFor(
                          width: 36,
                          height: 36,
                        ),
                        visualDensity: VisualDensity.compact,
                        tooltip: 'حذف',
                        icon: const Icon(Icons.delete_outline, size: 20),
                        onPressed: () => _deleteSection(section.id),
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

  Future<void> _showAddSectionSheet() async {
    final request = await showModalBottomSheet<_CreateHomeSectionRequest>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        final categories =
            ref.read(adminMerchCategoriesControllerProvider).valueOrNull ??
            const [];
        return _AddSectionSheetContent(categories: categories);
      },
    );

    if (request == null || !mounted) return;

    await LexiAlert.loading(
      context,
      text:
          '\u062c\u0627\u0631\u064a \u0625\u0646\u0634\u0627\u0621 \u0627\u0644\u0642\u0633\u0645...',
    );
    var created = false;
    try {
      await ref
          .read(adminHomeSectionsControllerProvider.notifier)
          .create(
            titleAr: request.titleAr,
            type: request.type,
            termId: request.termId,
            isActive: request.isActive,
          );
      created = true;
    } catch (_) {
    } finally {
      if (mounted) {
        await LexiAlert.dismiss(context);
      }
    }

    if (!mounted) return;
    if (created) {
      await LexiAlert.success(
        context,
        text:
            '\u062a\u0645 \u0625\u0646\u0634\u0627\u0621 \u0627\u0644\u0642\u0633\u0645 \u0628\u0646\u062c\u0627\u062d.',
      );
      setState(() => _sections = const []);
      return;
    }

    await LexiAlert.error(
      context,
      text:
          '\u062a\u0639\u0630\u0631 \u0625\u0646\u0634\u0627\u0621 \u0627\u0644\u0642\u0633\u0645 \u062d\u0627\u0644\u064a\u0627\u064b.',
    );
  }

  Future<void> _saveReorder() async {
    await LexiAlert.loading(context, text: 'جاري حفظ ترتيب الأقسام...');
    var saved = false;
    try {
      await ref
          .read(adminHomeSectionsControllerProvider.notifier)
          .saveReorder(_sections);
      saved = true;
    } catch (_) {
    } finally {
      if (mounted) {
        await LexiAlert.dismiss(context);
      }
    }

    if (!mounted) return;
    if (saved) {
      await LexiAlert.success(context, text: 'تم حفظ ترتيب الأقسام بنجاح.');
    } else {
      await LexiAlert.error(context, text: 'تعذر حفظ ترتيب الأقسام حالياً.');
    }
  }

  Future<void> _deleteSection(int id) async {
    await LexiAlert.confirm(
      context,
      title: 'حذف القسم',
      text: 'هل تريد حذف هذا القسم نهائياً؟',
      onConfirm: () async {
        await LexiAlert.loading(context, text: 'جاري الحذف...');
        var deleted = false;
        try {
          await ref
              .read(adminHomeSectionsControllerProvider.notifier)
              .deleteSection(id);
          deleted = true;
        } catch (_) {
        } finally {
          if (mounted) {
            await LexiAlert.dismiss(context);
          }
        }

        if (!mounted) return;
        if (deleted) {
          await LexiAlert.success(context, text: 'تم حذف القسم بنجاح.');
          setState(() => _sections = const []);
        } else {
          await LexiAlert.error(context, text: 'تعذر حذف القسم حالياً.');
        }
      },
    );
  }
}

class _CreateHomeSectionRequest {
  final String titleAr;
  final String type;
  final int? termId;
  final bool isActive;

  const _CreateHomeSectionRequest({
    required this.titleAr,
    required this.type,
    required this.termId,
    required this.isActive,
  });
}

const _kHomeSectionTypes = <String, String>{
  'hero_banner': 'بانر رئيسي',
  'manual_products': 'يدوي',
  'category': 'تصنيف',
  'on_sale': 'عروض',
  'newest': 'الأحدث',
  'top_rated': 'الأعلى تقييماً',
  'flash_deals': 'صفقات سريعة',
};

class _AddSectionSheetContent extends StatefulWidget {
  final List<dynamic> categories;
  const _AddSectionSheetContent({required this.categories});

  @override
  State<_AddSectionSheetContent> createState() =>
      _AddSectionSheetContentState();
}

class _AddSectionSheetContentState extends State<_AddSectionSheetContent> {
  final _titleController = TextEditingController();
  String _type = 'manual_products';
  int? _termId;
  bool _isActive = true;
  String? _validationMessage;

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final viewInsetsBottom = MediaQuery.of(context).viewInsets.bottom;
    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.only(bottom: viewInsetsBottom),
        child: LexiSafeBottom(
          keyboardAware: false,
          child: Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            padding: const EdgeInsetsDirectional.fromSTEB(16, 16, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: _titleController,
                  decoration: const InputDecoration(
                    labelText:
                        '\u0639\u0646\u0648\u0627\u0646 \u0627\u0644\u0642\u0633\u0645',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  initialValue: _type,
                  decoration: const InputDecoration(
                    labelText: '\u0627\u0644\u0646\u0648\u0639',
                    border: OutlineInputBorder(),
                  ),
                  items: _kHomeSectionTypes.entries
                      .map(
                        (entry) => DropdownMenuItem<String>(
                          value: entry.key,
                          child: Text(entry.value),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value == null) return;
                    setState(() {
                      _validationMessage = null;
                      _type = value;
                      if (_type != 'category') {
                        _termId = null;
                      }
                    });
                  },
                ),
                if (_type == 'category') ...[
                  const SizedBox(height: 10),
                  DropdownButtonFormField<int>(
                    initialValue: _termId,
                    decoration: const InputDecoration(
                      labelText:
                          '\u0627\u062e\u062a\u0631 \u0627\u0644\u062a\u0635\u0646\u064a\u0641',
                      border: OutlineInputBorder(),
                    ),
                    items: widget.categories
                        .map(
                          (item) => DropdownMenuItem<int>(
                            value: item.id as int,
                            child: Text(item.name as String),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      setState(() {
                        _validationMessage = null;
                        _termId = value;
                      });
                    },
                  ),
                ],
                if (_validationMessage != null) ...[
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      _validationMessage!,
                      style: const TextStyle(color: Colors.red),
                    ),
                  ),
                ],
                const SizedBox(height: 10),
                SwitchListTile(
                  value: _isActive,
                  onChanged: (value) => setState(() => _isActive = value),
                  title: const Text('\u0646\u0634\u0637'),
                  contentPadding: EdgeInsets.zero,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('\u0625\u0644\u063a\u0627\u0621'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          final title = _titleController.text.trim();
                          if (title.isEmpty) {
                            setState(() {
                              _validationMessage =
                                  '\u064a\u0631\u062c\u0649 \u0625\u062f\u062e\u0627\u0644 \u0639\u0646\u0648\u0627\u0646 \u0627\u0644\u0642\u0633\u0645.';
                            });
                            return;
                          }
                          if (_type == 'category' && _termId == null) {
                            setState(() {
                              _validationMessage =
                                  '\u064a\u0631\u062c\u0649 \u0627\u062e\u062a\u064a\u0627\u0631 \u062a\u0635\u0646\u064a\u0641.';
                            });
                            return;
                          }

                          Navigator.of(context).pop(
                            _CreateHomeSectionRequest(
                              titleAr: title,
                              type: _type,
                              termId: _termId,
                              isActive: _isActive,
                            ),
                          );
                        },
                        child: const Text('\u0625\u0636\u0627\u0641\u0629'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

