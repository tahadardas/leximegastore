import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:go_router/go_router.dart';

import '../../design_system/lexi_tokens.dart';
import '../../design_system/lexi_typography.dart';
import '../../shared/widgets/error_state.dart';
import '../../shared/widgets/lexi_ui/lexi_app_bar.dart';
import '../../shared/widgets/lexi_ui/lexi_drawer.dart';
import '../../ui/widgets/offline_banner.dart';
import 'domain/entities/category_entity.dart';
import 'presentation/controllers/categories_controller.dart';
import 'widgets/category_child_tile.dart';
import 'widgets/category_parent_tile.dart';

/// Builds `{ parentId: [children...] }` for categories tree rendering.
Map<int, List<CategoryEntity>> buildChildrenMap(
  List<CategoryEntity> categories,
) {
  final map = <int, List<CategoryEntity>>{};
  for (final category in categories) {
    if (category.parentId <= 0) {
      continue;
    }
    map.putIfAbsent(category.parentId, () => <CategoryEntity>[]).add(category);
  }
  for (final entry in map.entries) {
    entry.value.sort(_sortCategories);
  }
  return map;
}

int _sortCategories(CategoryEntity a, CategoryEntity b) {
  if (a.sortOrder != b.sortOrder) {
    return a.sortOrder.compareTo(b.sortOrder);
  }
  return a.name.compareTo(b.name);
}

class CategoriesScreen extends ConsumerStatefulWidget {
  const CategoriesScreen({super.key});

  @override
  ConsumerState<CategoriesScreen> createState() => _CategoriesScreenState();
}

class _CategoriesScreenState extends ConsumerState<CategoriesScreen> {
  int? _expandedParentId;

  @override
  Widget build(BuildContext context) {
    final categoriesAsync = ref.watch(categoriesControllerProvider);

    return Scaffold(
      drawer: const LexiDrawer(),
      appBar: const LexiAppBar(title: 'الأقسام'),
      body: Column(
        children: [
          OfflineBanner(
            onRetry: () =>
                ref.read(categoriesControllerProvider.notifier).refresh(),
          ),
          Expanded(
            child: categoriesAsync.when(
              loading: () => const _CategoriesSkeleton(),
              error: (_, _) => ErrorState(
                message: 'تعذر تحميل الأقسام حالياً. حاول مرة أخرى.',
                onRetry: () {
                  ref.read(categoriesControllerProvider.notifier).refresh();
                },
              ),
              data: (categories) {
                final mainCategories =
                    categories.where((c) => c.parentId == 0).toList()
                      ..sort(_sortCategories);
                final childrenMap = buildChildrenMap(categories);

                return RefreshIndicator(
                  color: LexiColors.brandPrimary,
                  onRefresh: () =>
                      ref.read(categoriesControllerProvider.notifier).refresh(),
                  child: ListView.builder(
                    padding: const EdgeInsets.all(LexiSpacing.md),
                    itemCount: mainCategories.isEmpty
                        ? 2
                        : mainCategories.length + 1,
                    itemBuilder: (context, index) {
                      if (index == 0) {
                        return const _CategoriesHeaderBlock();
                      }

                      if (mainCategories.isEmpty) {
                        return const _EmptyCategories();
                      }

                      final parent = mainCategories[index - 1];
                      final children = childrenMap[parent.id] ?? const [];
                      final isExpanded = _expandedParentId == parent.id;
                      final hasChildren =
                          children.isNotEmpty || parent.childrenCount > 0;

                      return Padding(
                        padding: const EdgeInsets.only(bottom: LexiSpacing.sm),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CategoryParentTile(
                              category: parent,
                              hasChildren: hasChildren,
                              isExpanded: isExpanded,
                              onTap: () => _openCategory(parent),
                              onArrowTap: hasChildren
                                  ? () => _toggleExpand(parent.id)
                                  : null,
                            ),
                            _AnimatedChildrenSection(
                              isExpanded: isExpanded,
                              children: children,
                              expectedChildrenCount: parent.childrenCount,
                              onChildTap: _openCategory,
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _toggleExpand(int parentId) {
    setState(() {
      _expandedParentId = _expandedParentId == parentId ? null : parentId;
    });
  }

  void _openCategory(CategoryEntity category) {
    context.push(
      '/categories/${category.id}/products?title=${Uri.encodeComponent(category.name)}',
    );
  }
}

class _CategoriesHeaderBlock extends StatelessWidget {
  const _CategoriesHeaderBlock();

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(LexiSpacing.md),
          decoration: BoxDecoration(
            color: LexiColors.brandBlack,
            borderRadius: BorderRadius.circular(LexiRadius.lg),
            border: Border.all(
              color: LexiColors.brandPrimary.withValues(alpha: 0.35),
            ),
            boxShadow: LexiShadows.sm,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: LexiColors.brandPrimary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(LexiRadius.sm),
                    ),
                    child: const Icon(
                      FontAwesomeIcons.layerGroup,
                      color: LexiColors.brandPrimary,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: LexiSpacing.md),
                  Expanded(
                    child: Text(
                      'تصفّح الأقسام الرئيسية ثم افتح الأقسام الفرعية من السهم.',
                      style: LexiTypography.bodySm.copyWith(
                        color: LexiColors.brandWhite,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: LexiSpacing.sm),
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    minWidth: 96,
                    maxWidth: 128,
                    minHeight: 36,
                  ),
                  child: OutlinedButton(
                    onPressed: () => context.go('/'),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: LexiColors.brandPrimary),
                      foregroundColor: LexiColors.brandPrimary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(LexiRadius.md),
                      ),
                      padding: const EdgeInsets.symmetric(
                        vertical: 8,
                        horizontal: 12,
                      ),
                    ),
                    child: const Text(
                      'الرئيسية',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: LexiSpacing.lg),
        Text(
          'الأقسام الرئيسية',
          style: LexiTypography.h3,
          textAlign: TextAlign.start,
        ),
        const SizedBox(height: LexiSpacing.sm),
      ],
    );
  }
}

class _AnimatedChildrenSection extends StatelessWidget {
  final bool isExpanded;
  final List<CategoryEntity> children;
  final int expectedChildrenCount;
  final ValueChanged<CategoryEntity> onChildTap;

  const _AnimatedChildrenSection({
    required this.isExpanded,
    required this.children,
    required this.expectedChildrenCount,
    required this.onChildTap,
  });

  @override
  Widget build(BuildContext context) {
    final showChildren =
        isExpanded && (children.isNotEmpty || expectedChildrenCount > 0);

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 260),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      transitionBuilder: (child, animation) {
        return ClipRect(
          child: Align(
            alignment: Alignment.topCenter,
            heightFactor: animation.value,
            child: child,
          ),
        );
      },
      child: !showChildren
          ? const SizedBox.shrink()
          : Padding(
              key: const ValueKey<String>('expanded_children'),
              padding: const EdgeInsetsDirectional.only(start: 26, top: 8),
              child: children.isEmpty
                  ? Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(LexiSpacing.sm),
                      decoration: BoxDecoration(
                        color: LexiColors.neutral50,
                        borderRadius: BorderRadius.circular(LexiRadius.md),
                        border: Border.all(color: LexiColors.neutral200),
                      ),
                      child: Text(
                        'لا توجد أقسام فرعية متاحة حالياً.',
                        style: LexiTypography.bodySm.copyWith(
                          color: LexiColors.neutral600,
                        ),
                      ),
                    )
                  : Column(
                      mainAxisSize: MainAxisSize.min,
                      children: children.map((child) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: CategoryChildTile(
                            category: child,
                            onTap: () => onChildTap(child),
                          ),
                        );
                      }).toList(),
                    ),
            ),
    );
  }
}

class _EmptyCategories extends StatelessWidget {
  const _EmptyCategories();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: LexiSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              FontAwesomeIcons.shapes,
              size: 42,
              color: LexiColors.neutral400,
            ),
            const SizedBox(height: LexiSpacing.sm),
            Text('لا توجد أقسام متاحة حالياً', style: LexiTypography.bodyLg),
          ],
        ),
      ),
    );
  }
}

class _CategoriesSkeleton extends StatelessWidget {
  const _CategoriesSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.all(LexiSpacing.md),
      itemCount: 8,
      itemBuilder: (context, index) {
        return Container(
          margin: const EdgeInsets.only(bottom: LexiSpacing.sm),
          padding: const EdgeInsets.all(LexiSpacing.sm),
          decoration: BoxDecoration(
            color: LexiColors.brandWhite,
            borderRadius: BorderRadius.circular(LexiRadius.lg),
            border: Border.all(color: LexiColors.neutral200),
          ),
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: LexiColors.neutral200,
                  borderRadius: BorderRadius.circular(LexiRadius.sm),
                ),
              ),
              const SizedBox(width: LexiSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      height: 14,
                      width: 140,
                      decoration: BoxDecoration(
                        color: LexiColors.neutral200,
                        borderRadius: BorderRadius.circular(99),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      height: 12,
                      width: 80,
                      decoration: BoxDecoration(
                        color: LexiColors.neutral200,
                        borderRadius: BorderRadius.circular(99),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: LexiColors.neutral200,
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
