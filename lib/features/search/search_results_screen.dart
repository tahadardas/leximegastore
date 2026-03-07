import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:go_router/go_router.dart';

import '../../design_system/lexi_tokens.dart';
import '../../design_system/lexi_typography.dart';
import '../../shared/widgets/lexi_ui/lexi_skeleton.dart';
import '../../ui/widgets/lexi_safe_bottom.dart';
import 'search_controller.dart';
import 'widgets/search_product_tile.dart';

class SearchResultsScreen extends ConsumerStatefulWidget {
  final String initialQuery;

  const SearchResultsScreen({super.key, required this.initialQuery});

  @override
  ConsumerState<SearchResultsScreen> createState() =>
      _SearchResultsScreenState();
}

class _SearchResultsScreenState extends ConsumerState<SearchResultsScreen> {
  static const int _perPage = 20;

  late final TextEditingController _queryController;
  late final FocusNode _focusNode;
  late final ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _queryController = TextEditingController(text: widget.initialQuery);
    _focusNode = FocusNode();
    _scrollController = ScrollController()..addListener(_onScroll);
    _queryController.addListener(_onQueryTextChanged);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      final notifier = ref.read(searchControllerProvider.notifier);
      notifier.setQueryWithoutSearch(_queryController.text);
      unawaited(
        notifier.searchProducts(
          rawQuery: _queryController.text,
          reset: true,
          perPage: _perPage,
        ),
      );
    });
  }

  @override
  void dispose() {
    _queryController.removeListener(_onQueryTextChanged);
    _scrollController.removeListener(_onScroll);
    _queryController.dispose();
    _focusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onQueryTextChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  void _onScroll() {
    if (!_scrollController.hasClients) {
      return;
    }

    if (_scrollController.position.extentAfter > 260) {
      return;
    }

    unawaited(ref.read(searchControllerProvider.notifier).loadMoreResults());
  }

  Future<void> _runSearch({required bool reset}) async {
    await ref
        .read(searchControllerProvider.notifier)
        .searchProducts(
          rawQuery: _queryController.text,
          reset: reset,
          perPage: _perPage,
        );
  }

  Future<void> _applySort(String sort) async {
    final notifier = ref.read(searchControllerProvider.notifier);
    notifier.setResultsSort(sort);
    await notifier.searchProducts(
      rawQuery: _queryController.text,
      reset: true,
      perPage: _perPage,
      sort: sort,
    );
  }

  void _showNotReadyMessage(String label) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        lexiFloatingSnackBar(context, content: Text('$label سيتوفر قريباً.')),
      );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(searchControllerProvider);

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: LexiColors.neutral100,
        body: SafeArea(
          child: Column(
            children: [
              _ResultsHeaderBar(
                controller: _queryController,
                focusNode: _focusNode,
                onBack: () => context.pop(),
                onSubmit: (_) => _runSearch(reset: true),
                onClearTap: () {
                  _queryController.clear();
                  ref.read(searchControllerProvider.notifier).clearResults();
                },
              ),
              Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(
                  LexiSpacing.md,
                  0,
                  LexiSpacing.md,
                  LexiSpacing.sm,
                ),
                child: Row(
                  children: [
                    const Spacer(),
                    _SortMenuPillButton(
                      value: state.resultsSort,
                      onSelected: _applySort,
                    ),
                    const SizedBox(width: LexiSpacing.sm),
                    _FilterPillButton(
                      icon: FontAwesomeIcons.sliders,
                      label: 'تصفية',
                      onTap: () => _showNotReadyMessage('عوامل التصفية'),
                    ),
                  ],
                ),
              ),
              Expanded(child: _buildBody(state)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBody(SearchState state) {
    if (state.isLoadingResults && state.results.isEmpty) {
      return const _SearchResultsSkeleton();
    }

    if (state.resultsMessage != null && state.results.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(LexiSpacing.md),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                state.resultsMessage!,
                style: LexiTypography.bodyMd.copyWith(
                  color: LexiColors.neutral700,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: LexiSpacing.sm),
              FilledButton(
                onPressed: () => _runSearch(reset: true),
                child: const Text('إعادة المحاولة'),
              ),
            ],
          ),
        ),
      );
    }

    if (state.results.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(LexiSpacing.md),
          child: Text(
            'لم يتم العثور على نتائج. جرّب كلمة مختلفة.',
            style: LexiTypography.bodyMd.copyWith(color: LexiColors.neutral600),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => _runSearch(reset: true),
      child: ListView.separated(
        controller: _scrollController,
        padding: const EdgeInsetsDirectional.fromSTEB(
          LexiSpacing.md,
          LexiSpacing.sm,
          LexiSpacing.md,
          LexiSpacing.xl,
        ),
        itemCount: state.results.length + (state.isLoadingMoreResults ? 1 : 0),
        separatorBuilder: (_, _) => const SizedBox(height: LexiSpacing.xs),
        itemBuilder: (context, index) {
          if (index >= state.results.length) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: LexiSpacing.md),
              child: Center(
                child: SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            );
          }

          final item = state.results[index];
          return SearchProductTile(
            id: item.id,
            name: item.name,
            imageUrl: item.primaryImageUrl ?? item.primaryImage,
            price: item.price,
            regularPrice: item.regularPrice,
            salePrice: item.salePrice ?? 0,
            rating: item.rating,
            reviewsCount: item.reviewsCount,
            inStock: item.inStock,
            onTap: () {
              unawaited(
                ref
                    .read(searchControllerProvider.notifier)
                    .recordProductClick(productId: item.id),
              );
              context.push('/product/${item.id}');
            },
          );
        },
      ),
    );
  }
}

class _ResultsHeaderBar extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onSubmit;
  final VoidCallback onBack;
  final VoidCallback onClearTap;

  const _ResultsHeaderBar({
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
        LexiSpacing.sm,
        LexiSpacing.sm,
        LexiSpacing.sm,
        LexiSpacing.sm,
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
                color: LexiColors.brandWhite,
                borderRadius: BorderRadius.circular(LexiRadius.full),
                border: Border.all(color: LexiColors.neutral200),
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
                            color: LexiColors.neutral600,
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

class _SortMenuPillButton extends StatelessWidget {
  final String value;
  final ValueChanged<String> onSelected;

  const _SortMenuPillButton({required this.value, required this.onSelected});

  static const _options = <String>[
    'relevance',
    'newest',
    'price_asc',
    'price_desc',
    'top_rated',
    'on_sale',
  ];

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      padding: EdgeInsets.zero,
      onSelected: onSelected,
      itemBuilder: (context) {
        return _options
            .map(
              (option) => PopupMenuItem<String>(
                value: option,
                child: Text(_labelFor(option)),
              ),
            )
            .toList(growable: false);
      },
      child: _FilterPillButton(
        icon: FontAwesomeIcons.arrowDownWideShort,
        label: _labelFor(value),
        onTap: () {},
        interactive: false,
      ),
    );
  }

  String _labelFor(String sort) {
    switch (sort) {
      case 'newest':
        return 'الأحدث';
      case 'price_asc':
        return 'السعر: من الأقل إلى الأعلى';
      case 'price_desc':
        return 'السعر: من الأعلى إلى الأقل';
      case 'top_rated':
        return 'الأعلى تقييماً';
      case 'on_sale':
        return 'ضمن التخفيضات';
      case 'relevance':
      default:
        return 'الأكثر صلة';
    }
  }
}

class _FilterPillButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool interactive;

  const _FilterPillButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.interactive = true,
  });

  @override
  Widget build(BuildContext context) {
    final content = Ink(
      padding: const EdgeInsets.symmetric(
        horizontal: LexiSpacing.sm,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: LexiColors.brandWhite,
        borderRadius: BorderRadius.circular(LexiRadius.full),
        border: Border.all(color: LexiColors.neutral200),
      ),
      child: Row(
        children: [
          FaIcon(icon, size: 12, color: LexiColors.neutral700),
          const SizedBox(width: 6),
          Text(
            label,
            style: LexiTypography.bodySm.copyWith(
              fontWeight: FontWeight.w700,
              color: LexiColors.brandBlack,
            ),
          ),
        ],
      ),
    );

    if (!interactive) {
      return content;
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(LexiRadius.full),
        child: content,
      ),
    );
  }
}

class _SearchResultsSkeleton extends StatelessWidget {
  const _SearchResultsSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.all(LexiSpacing.md),
      itemCount: 8,
      separatorBuilder: (_, _) => const SizedBox(height: LexiSpacing.sm),
      itemBuilder: (context, index) {
        return Row(
          children: const [
            LexiSkeleton(width: 44, height: 44, borderRadius: 12),
            SizedBox(width: LexiSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  LexiSkeleton(height: 14, borderRadius: 8),
                  SizedBox(height: 6),
                  LexiSkeleton(height: 12, width: 150, borderRadius: 8),
                  SizedBox(height: 6),
                  LexiSkeleton(height: 12, width: 90, borderRadius: 8),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}
