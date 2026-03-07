import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:go_router/go_router.dart';

import '../../app/router/app_routes.dart';
import '../../design_system/lexi_tokens.dart';
import '../../design_system/lexi_typography.dart';
import '../../shared/widgets/lexi_ui/lexi_skeleton.dart';
import '../../ui/lexi_design/lexi_colors.dart';
import '../../ui/lexi_design/lexi_spacing.dart';
import 'search_controller.dart';
import 'widgets/search_category_chip.dart';
import 'widgets/search_product_tile.dart';
import 'widgets/search_suggestion_tile.dart';

class SearchScreen extends ConsumerStatefulWidget {
  final String initialQuery;

  const SearchScreen({super.key, this.initialQuery = ''});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialQuery);
    _focusNode = FocusNode();
    _controller.addListener(_onTextChanged);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      final notifier = ref.read(searchControllerProvider.notifier);
      notifier.trackSearchOpened();
      notifier.onQueryChanged(_controller.text);
    });
  }

  @override
  void dispose() {
    _controller.removeListener(_onTextChanged);
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    if (mounted) {
      setState(() {});
    }
    ref
        .read(searchControllerProvider.notifier)
        .onQueryChanged(_controller.text);
  }

  void _submitSearch([String? rawQuery]) {
    final query = (rawQuery ?? _controller.text).trim();
    if (query.isEmpty) {
      return;
    }

    unawaited(
      ref.read(searchControllerProvider.notifier).saveRecentSearch(query),
    );

    if (!mounted) {
      return;
    }

    context.pushNamedIfNotCurrent(
      AppRouteNames.searchResults,
      queryParameters: {'q': query},
    );
  }

  Future<void> _showClearAllDialog() async {
    final shouldClear = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('مسح سجل البحث'),
          content: const Text('حذف جميع عمليات البحث الأخيرة؟'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('إلغاء'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('مسح الكل'),
            ),
          ],
        );
      },
    );

    if (shouldClear != true) {
      return;
    }

    await ref.read(searchControllerProvider.notifier).clearRecentSearches();
  }

  void _useSuggestionAndSubmit(String value) {
    _controller.value = TextEditingValue(
      text: value,
      selection: TextSelection.collapsed(offset: value.length),
    );
    unawaited(
      ref.read(searchControllerProvider.notifier).recordSuggestionClick(value),
    );
    _submitSearch(value);
  }

  void _openCategory(int categoryId, String categoryName) {
    if (categoryId <= 0) {
      return;
    }

    context.pushNamedIfNotCurrent(
      AppRouteNames.categoryProducts,
      pathParameters: {'id': '$categoryId'},
      queryParameters: {'title': categoryName},
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(searchControllerProvider);
    final query = state.query.trim();
    final showRecents = query.isEmpty;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: LexiColors.neutral100,
        body: SafeArea(
          child: Column(
            children: [
              _SearchHeaderBar(
                controller: _controller,
                focusNode: _focusNode,
                onSubmit: _submitSearch,
                onBack: () => context.pop(),
                onClearTap: () {
                  _controller.clear();
                },
              ),
              if (showRecents)
                Expanded(
                  child: ListView(
                    padding: EdgeInsets.zero,
                    children: [
                      _RecentSearchesSection(
                        recentSearches: state.recentSearches,
                        onSearchTap: _useSuggestionAndSubmit,
                        onDeleteTap: (value) {
                          ref
                              .read(searchControllerProvider.notifier)
                              .removeRecentSearch(value);
                        },
                        onClearAll: _showClearAllDialog,
                      ),
                      _TrendingSearchesSection(
                        trendingSearches: state.trendingSearches,
                        isLoading: state.isLoadingTrending,
                        onSearchTap: _useSuggestionAndSubmit,
                      ),
                      const SizedBox(height: LexiCommercialSpacing.s24),
                    ],
                  ),
                )
              else
                Expanded(
                  child: _SuggestionsSection(
                    state: state,
                    query: query,
                    onSuggestionTap: _useSuggestionAndSubmit,
                    onProductTap: (productId) {
                      unawaited(
                        ref
                            .read(searchControllerProvider.notifier)
                            .recordProductClick(productId: productId),
                      );
                      context.pushNamedIfNotCurrent(
                        AppRouteNames.product,
                        pathParameters: {'id': '$productId'},
                      );
                    },
                    onCategoryTap: _openCategory,
                    onRetry: () {
                      ref
                          .read(searchControllerProvider.notifier)
                          .onQueryChanged(_controller.text);
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SearchHeaderBar extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onSubmit;
  final VoidCallback onBack;
  final VoidCallback onClearTap;

  const _SearchHeaderBar({
    required this.controller,
    required this.focusNode,
    required this.onSubmit,
    required this.onBack,
    required this.onClearTap,
  });

  @override
  Widget build(BuildContext context) {
    final hasValue = controller.text.trim().isNotEmpty;

    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(
        LexiCommercialSpacing.s8,
        LexiCommercialSpacing.s8,
        LexiCommercialSpacing.s8,
        LexiCommercialSpacing.s8,
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: onBack,
            icon: const Icon(Icons.arrow_back),
            tooltip: 'رجوع',
          ),
          Expanded(
            child: Container(
              height: 48,
              decoration: BoxDecoration(
                color: LexiCommercialColors.white,
                borderRadius: BorderRadius.circular(LexiRadius.full),
                border: Border.all(color: LexiCommercialColors.gray200),
              ),
              child: TextField(
                controller: controller,
                focusNode: focusNode,
                textInputAction: TextInputAction.search,
                scrollPadding: EdgeInsets.zero,
                textAlignVertical: TextAlignVertical.center,
                onSubmitted: onSubmit,
                decoration: InputDecoration(
                  hintText: 'ابحث عن المنتجات...',
                  hintStyle: LexiTypography.bodyMd.copyWith(
                    color: LexiColors.neutral500,
                  ),
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: const EdgeInsetsDirectional.only(
                    start: 8,
                    end: 12,
                    top: 12,
                    bottom: 12,
                  ),
                  prefixIcon: const Icon(
                    Icons.search,
                    size: 20,
                    color: LexiColors.neutral500,
                  ),
                  prefixIconConstraints: const BoxConstraints(
                    minWidth: 44,
                    minHeight: 44,
                  ),
                  suffixIcon: hasValue
                      ? IconButton(
                          tooltip: 'مسح',
                          onPressed: onClearTap,
                          icon: const Icon(
                            Icons.close,
                            size: 18,
                            color: LexiCommercialColors.gray500,
                          ),
                        )
                      : null,
                  suffixIconConstraints: const BoxConstraints(
                    minWidth: 44,
                    minHeight: 44,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RecentSearchesSection extends StatelessWidget {
  final List<String> recentSearches;
  final ValueChanged<String> onSearchTap;
  final ValueChanged<String> onDeleteTap;
  final VoidCallback onClearAll;

  const _RecentSearchesSection({
    required this.recentSearches,
    required this.onSearchTap,
    required this.onDeleteTap,
    required this.onClearAll,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(
            LexiCommercialSpacing.s16,
            LexiCommercialSpacing.s8,
            LexiCommercialSpacing.s16,
            0,
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'عمليات البحث الأخيرة',
                  style: LexiTypography.h3.copyWith(fontSize: 16),
                ),
              ),
              if (recentSearches.isNotEmpty)
                TextButton(
                  onPressed: onClearAll,
                  child: Text(
                    'مسح الكل',
                    style: LexiTypography.bodySm.copyWith(
                      color: LexiCommercialColors.darkBlack,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: LexiCommercialSpacing.s4),
        if (recentSearches.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: LexiCommercialSpacing.s16,
            ),
            child: Text(
              'لا توجد عمليات بحث حديثة بعد.',
              style: LexiTypography.bodySm.copyWith(
                color: LexiCommercialColors.gray500,
              ),
            ),
          )
        else
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: LexiCommercialSpacing.s16,
            ),
            child: Wrap(
              spacing: LexiCommercialSpacing.s8,
              runSpacing: LexiCommercialSpacing.s8,
              children: recentSearches
                  .map((value) {
                    return InputChip(
                      onPressed: () => onSearchTap(value),
                      onDeleted: () => onDeleteTap(value),
                      avatar: const Icon(Icons.history, size: 16),
                      deleteIcon: const Icon(Icons.close, size: 16),
                      label: Text(
                        value,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      shape: StadiumBorder(
                        side: BorderSide(color: LexiCommercialColors.gray200),
                      ),
                      backgroundColor: LexiCommercialColors.white,
                      labelStyle: LexiTypography.bodySm.copyWith(
                        color: LexiCommercialColors.darkBlack,
                        fontWeight: FontWeight.w700,
                      ),
                    );
                  })
                  .toList(growable: false),
            ),
          ),
      ],
    );
  }
}

class _TrendingSearchesSection extends StatelessWidget {
  final List<String> trendingSearches;
  final bool isLoading;
  final ValueChanged<String> onSearchTap;

  const _TrendingSearchesSection({
    required this.trendingSearches,
    required this.isLoading,
    required this.onSearchTap,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Padding(
        padding: EdgeInsets.all(LexiCommercialSpacing.s16),
        child: LexiSkeleton(height: 100, borderRadius: 12),
      );
    }

    if (trendingSearches.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: LexiCommercialSpacing.s24),
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: LexiCommercialSpacing.s16,
          ),
          child: Text(
            'الأكثر رواجاً',
            style: LexiTypography.h3.copyWith(fontSize: 16),
          ),
        ),
        const SizedBox(height: LexiCommercialSpacing.s8),
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: LexiCommercialSpacing.s16,
          ),
          child: Wrap(
            spacing: LexiCommercialSpacing.s8,
            runSpacing: LexiCommercialSpacing.s8,
            children: trendingSearches
                .map((value) {
                  return ActionChip(
                    onPressed: () => onSearchTap(value),
                    avatar: const FaIcon(
                      FontAwesomeIcons.fire,
                      size: 14,
                      color: LexiCommercialColors.discountRed,
                    ),
                    label: Text(
                      value,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    shape: StadiumBorder(
                      side: BorderSide(color: LexiCommercialColors.gray200),
                    ),
                    backgroundColor: LexiCommercialColors.white,
                    labelStyle: LexiTypography.bodySm.copyWith(
                      color: LexiCommercialColors.darkBlack,
                      fontWeight: FontWeight.w700,
                    ),
                  );
                })
                .toList(growable: false),
          ),
        ),
      ],
    );
  }
}

class _SuggestionsSection extends StatelessWidget {
  final SearchState state;
  final String query;
  final ValueChanged<String> onSuggestionTap;
  final ValueChanged<int> onProductTap;
  final void Function(int categoryId, String categoryName) onCategoryTap;
  final VoidCallback onRetry;

  const _SuggestionsSection({
    required this.state,
    required this.query,
    required this.onSuggestionTap,
    required this.onProductTap,
    required this.onCategoryTap,
    required this.onRetry,
  });

  bool get _hasAnyData =>
      state.suggestions.isNotEmpty ||
      state.suggestedProducts.isNotEmpty ||
      state.suggestedCategories.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    if (query.length < 2) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(LexiCommercialSpacing.s16),
          child: Text(
            'اكتب حرفين على الأقل لعرض الاقتراحات.',
            style: LexiTypography.bodyMd.copyWith(
              color: LexiCommercialColors.gray500,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    if (state.isLoadingSuggestions) {
      return _buildSkeleton();
    }

    if (!_hasAnyData) {
      if (state.phase == SearchPhase.error) {
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(LexiCommercialSpacing.s16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  state.suggestionMessage ?? 'تعذر تحميل الاقتراحات حالياً.',
                  style: LexiTypography.bodyMd.copyWith(
                    color: LexiCommercialColors.gray500,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: LexiCommercialSpacing.s8),
                FilledButton(
                  onPressed: onRetry,
                  child: const Text('إعادة المحاولة'),
                ),
              ],
            ),
          ),
        );
      }

      return Center(
        child: Padding(
          padding: const EdgeInsets.all(LexiCommercialSpacing.s16),
          child: Text(
            'لا توجد اقتراحات متاحة حالياً.',
            style: LexiTypography.bodyMd.copyWith(
              color: LexiCommercialColors.gray500,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsetsDirectional.fromSTEB(
        LexiCommercialSpacing.s16,
        LexiCommercialSpacing.s8,
        LexiCommercialSpacing.s16,
        LexiCommercialSpacing.s16,
      ),
      children: [
        if (state.suggestions.isNotEmpty) ...[
          const _SectionTitle(title: 'اقتراحات البحث'),
          const SizedBox(height: LexiCommercialSpacing.s4),
          ...state.suggestions.map(
            (item) => SearchSuggestionTile(
              text: item.text,
              highlight: item.highlight,
              onTap: () => onSuggestionTap(item.text),
            ),
          ),
          const SizedBox(height: LexiCommercialSpacing.s16),
        ],
        if (state.suggestedProducts.isNotEmpty) ...[
          const _SectionTitle(title: 'المنتجات'),
          const SizedBox(height: LexiCommercialSpacing.s4),
          ...state.suggestedProducts.map(
            (item) => SearchProductTile(
              id: item.id,
              name: item.name,
              imageUrl: item.image,
              price: item.price,
              regularPrice: item.regularPrice,
              salePrice: item.salePrice,
              rating: item.rating,
              reviewsCount: item.reviewsCount,
              inStock: item.inStock,
              onTap: () => onProductTap(item.id),
            ),
          ),
          const SizedBox(height: LexiCommercialSpacing.s16),
        ],
        if (state.suggestedCategories.isNotEmpty) ...[
          const _SectionTitle(title: 'الأقسام'),
          const SizedBox(height: LexiCommercialSpacing.s8),
          Wrap(
            spacing: LexiCommercialSpacing.s8,
            runSpacing: LexiCommercialSpacing.s8,
            children: state.suggestedCategories
                .map((item) {
                  return SearchCategoryChip(
                    name: item.name,
                    imageUrl: item.image,
                    onTap: () => onCategoryTap(item.id, item.name),
                  );
                })
                .toList(growable: false),
          ),
        ],
      ],
    );
  }

  Widget _buildSkeleton() {
    return ListView(
      padding: const EdgeInsets.all(LexiCommercialSpacing.s16),
      children: [
        const _SectionTitle(title: 'اقتراحات البحث'),
        const SizedBox(height: LexiCommercialSpacing.s8),
        ...List.generate(
          3,
          (_) => const Padding(
            padding: EdgeInsets.only(bottom: 10),
            child: LexiSkeleton(height: 18, borderRadius: 10),
          ),
        ),
        const SizedBox(height: LexiCommercialSpacing.s16),
        const _SectionTitle(title: 'المنتجات'),
        const SizedBox(height: LexiCommercialSpacing.s8),
        ...List.generate(
          3,
          (_) => const Padding(
            padding: EdgeInsets.only(bottom: 12),
            child: _SearchProductSkeletonRow(),
          ),
        ),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;

  const _SectionTitle({required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(title, style: LexiTypography.h3.copyWith(fontSize: 16));
  }
}

class _SearchProductSkeletonRow extends StatelessWidget {
  const _SearchProductSkeletonRow();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: const [
        LexiSkeleton(width: 44, height: 44, borderRadius: 12),
        SizedBox(width: LexiCommercialSpacing.s12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              LexiSkeleton(height: 14, borderRadius: 8),
              SizedBox(height: 6),
              LexiSkeleton(height: 12, width: 120, borderRadius: 8),
              SizedBox(height: 6),
              LexiSkeleton(height: 12, width: 90, borderRadius: 8),
            ],
          ),
        ),
      ],
    );
  }
}
