import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:quickalert/quickalert.dart';

import '../../../../../core/errors/user_friendly_errors.dart';
import '../../../../../core/utils/currency_formatter.dart';
import '../../../../../design_system/lexi_tokens.dart';
import '../../../../../design_system/lexi_typography.dart';
import '../../../../../shared/widgets/lexi_network_image.dart';
import '../controllers/admin_intel_controller.dart';
import '../../domain/entities/admin_intel_models.dart';

class StoreIntelligencePage extends ConsumerStatefulWidget {
  const StoreIntelligencePage({super.key});

  @override
  ConsumerState<StoreIntelligencePage> createState() =>
      _StoreIntelligencePageState();
}

class _StoreIntelligencePageState extends ConsumerState<StoreIntelligencePage> {
  Future<void> _refreshAll() {
    return ref.read(adminIntelRefreshControllerProvider.notifier).refreshAll();
  }

  Future<void> _createOfferDraft(AdminIntelOpportunity item) async {
    QuickAlert.show(
      context: context,
      type: QuickAlertType.loading,
      title: 'جاري التنفيذ',
      text: 'يتم إنشاء مسودة عرض تجريبي...',
      barrierDismissible: false,
    );
    try {
      final result = await ref
          .read(adminIntelActionsControllerProvider)
          .createOfferDraftForProduct(
            productId: item.productId,
            productName: item.name,
          );
      if (!mounted) {
        return;
      }
      Navigator.of(context, rootNavigator: true).pop();
      await QuickAlert.show(
        context: context,
        type: QuickAlertType.success,
        title: 'تم بنجاح',
        text: result.message.isEmpty
            ? 'تم إنشاء مسودة عرض وبانتظار الاعتماد.'
            : result.message,
      );
      await _refreshAll();
    } catch (error) {
      if (!mounted) {
        return;
      }
      Navigator.of(context, rootNavigator: true).pop();
      await QuickAlert.show(
        context: context,
        type: QuickAlertType.error,
        title: 'تعذر التنفيذ',
        text: UserFriendlyErrors.from(
          error,
          fallback: 'تعذر إنشاء مسودة العرض حالياً.',
        ),
      );
    }
  }

  Future<void> _pinProductToHome(int productId) async {
    final section = await _pickSection();
    if (section == null || !mounted) {
      return;
    }

    QuickAlert.show(
      context: context,
      type: QuickAlertType.loading,
      title: 'جاري التنفيذ',
      text: 'يتم تثبيت المنتج في الرئيسية...',
      barrierDismissible: false,
    );
    try {
      final result = await ref
          .read(adminIntelActionsControllerProvider)
          .pinHome(productId: productId, section: section);
      if (!mounted) {
        return;
      }
      Navigator.of(context, rootNavigator: true).pop();
      await QuickAlert.show(
        context: context,
        type: QuickAlertType.success,
        title: 'تم بنجاح',
        text: result.message.isEmpty
            ? 'تم تثبيت المنتج في الرئيسية.'
            : result.message,
      );
      await _refreshAll();
    } catch (error) {
      if (!mounted) {
        return;
      }
      Navigator.of(context, rootNavigator: true).pop();
      await QuickAlert.show(
        context: context,
        type: QuickAlertType.error,
        title: 'تعذر التنفيذ',
        text: UserFriendlyErrors.from(
          error,
          fallback: 'تعذر تثبيت المنتج حالياً.',
        ),
      );
    }
  }

  Future<String?> _pickSection() {
    return showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const ListTile(title: Text('اختر القسم المراد التثبيت فيه')),
              ListTile(
                leading: const FaIcon(FontAwesomeIcons.bolt, size: 16),
                title: const Text('عروض البرق'),
                onTap: () => Navigator.of(context).pop('flash_deals'),
              ),
              ListTile(
                leading: const FaIcon(FontAwesomeIcons.fire, size: 16),
                title: const Text('المنتجات الرائجة'),
                onTap: () => Navigator.of(context).pop('trending'),
              ),
              ListTile(
                leading: const FaIcon(FontAwesomeIcons.trophy, size: 16),
                title: const Text('الأكثر مبيعًا'),
                onTap: () => Navigator.of(context).pop('best_seller'),
              ),
              const SizedBox(height: LexiSpacing.sm),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 7,
      child: Scaffold(
        backgroundColor: LexiColors.neutral100,
        floatingActionButton: FloatingActionButton.small(
          heroTag: 'intel_refresh',
          onPressed: _refreshAll,
          child: const FaIcon(FontAwesomeIcons.arrowsRotate, size: 16),
        ),
        body: Column(
          children: [
            Material(
              color: Theme.of(context).colorScheme.surface,
              child: const TabBar(
                isScrollable: true,
                tabs: [
                  Tab(text: 'نظرة عامة'),
                  Tab(text: 'المنتجات الرائجة'),
                  Tab(text: 'فرص التحسين'),
                  Tab(text: 'المفضلة'),
                  Tab(text: 'البحث'),
                  Tab(text: 'باقات مقترحة'),
                  Tab(text: 'تنبيهات المخزون'),
                ],
              ),
            ),
            Expanded(
              child: TabBarView(
                children: [
                  _OverviewTab(onRefresh: _refreshAll),
                  _TrendingTab(onRefresh: _refreshAll),
                  _OpportunitiesTab(
                    onRefresh: _refreshAll,
                    onCreateDraft: _createOfferDraft,
                    onPinHome: _pinProductToHome,
                  ),
                  _WishlistTab(onRefresh: _refreshAll),
                  _SearchTab(onRefresh: _refreshAll),
                  _BundlesTab(onRefresh: _refreshAll),
                  _StockAlertsTab(onRefresh: _refreshAll),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OverviewTab extends ConsumerWidget {
  final Future<void> Function() onRefresh;

  const _OverviewTab({required this.onRefresh});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedRange = ref.watch(adminIntelOverviewRangeProvider);
    final overviewAsync = ref.watch(adminIntelOverviewProvider);
    final todayAsync = ref.watch(adminIntelOverviewByRangeProvider('today'));
    final weekAsync = ref.watch(adminIntelOverviewByRangeProvider('7d'));

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(LexiSpacing.md),
        children: [
          Wrap(
            spacing: LexiSpacing.sm,
            children: [
              _RangeChip(
                label: 'اليوم',
                selected: selectedRange == 'today',
                onTap: () =>
                    ref.read(adminIntelOverviewRangeProvider.notifier).state =
                        'today',
              ),
              _RangeChip(
                label: 'آخر 7 أيام',
                selected: selectedRange == '7d',
                onTap: () =>
                    ref.read(adminIntelOverviewRangeProvider.notifier).state =
                        '7d',
              ),
              _RangeChip(
                label: 'آخر 30 يوم',
                selected: selectedRange == '30d',
                onTap: () =>
                    ref.read(adminIntelOverviewRangeProvider.notifier).state =
                        '30d',
              ),
            ],
          ),
          const SizedBox(height: LexiSpacing.md),
          overviewAsync.when(
            loading: () => const _LoadingCard(),
            error: (error, _) => _ErrorCard(
              message: UserFriendlyErrors.from(
                error,
                fallback: 'تعذر تحميل مؤشرات الأداء.',
              ),
            ),
            data: (overview) => Column(
              children: [
                GridView.count(
                  crossAxisCount: 2,
                  crossAxisSpacing: LexiSpacing.sm,
                  mainAxisSpacing: LexiSpacing.sm,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  childAspectRatio: 1.35,
                  children: [
                    _KpiCard(
                      title: 'الجلسات',
                      value: overview.sessions.toString(),
                      icon: FontAwesomeIcons.users,
                      color: LexiColors.info,
                    ),
                    _KpiCard(
                      title: 'مشاهدات المنتجات',
                      value: overview.productViews.toString(),
                      icon: FontAwesomeIcons.eye,
                      color: LexiColors.brandBlack,
                    ),
                    _KpiCard(
                      title: 'الإضافة للسلة',
                      value: overview.addToCart.toString(),
                      icon: FontAwesomeIcons.cartShopping,
                      color: LexiColors.warning,
                    ),
                    _KpiCard(
                      title: 'بدء الدفع',
                      value: overview.checkoutStart.toString(),
                      icon: FontAwesomeIcons.cashRegister,
                      color: LexiColors.info,
                    ),
                    _KpiCard(
                      title: 'المشتريات',
                      value: overview.purchases.toString(),
                      icon: FontAwesomeIcons.receipt,
                      color: LexiColors.success,
                    ),
                    _KpiCard(
                      title: 'الإيراد',
                      value: CurrencyFormatter.formatAmount(overview.revenue),
                      icon: FontAwesomeIcons.coins,
                      color: LexiColors.brandPrimary,
                    ),
                  ],
                ),
                const SizedBox(height: LexiSpacing.md),
                _RatePanel(overview: overview),
              ],
            ),
          ),
          const SizedBox(height: LexiSpacing.md),
          _ConversionCompareCard(todayAsync: todayAsync, weekAsync: weekAsync),
        ],
      ),
    );
  }
}

class _TrendingTab extends ConsumerWidget {
  final Future<void> Function() onRefresh;

  const _TrendingTab({required this.onRefresh});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedRange = ref.watch(adminIntelTrendingRangeProvider);
    final async = ref.watch(adminIntelTrendingProvider);

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(LexiSpacing.md),
        children: [
          Wrap(
            spacing: LexiSpacing.sm,
            children: [
              _RangeChip(
                label: 'آخر 24 ساعة',
                selected: selectedRange == '24h',
                onTap: () =>
                    ref.read(adminIntelTrendingRangeProvider.notifier).state =
                        '24h',
              ),
              _RangeChip(
                label: 'آخر 7 أيام',
                selected: selectedRange == '7d',
                onTap: () =>
                    ref.read(adminIntelTrendingRangeProvider.notifier).state =
                        '7d',
              ),
            ],
          ),
          const SizedBox(height: LexiSpacing.md),
          async.when(
            loading: () => const _LoadingCard(),
            error: (error, _) => _ErrorCard(
              message: UserFriendlyErrors.from(
                error,
                fallback: 'تعذر تحميل المنتجات الرائجة.',
              ),
            ),
            data: (items) {
              if (items.isEmpty) {
                return const _EmptyCard(
                  text: 'لا توجد بيانات رائجة في المدى المختار.',
                );
              }
              return Column(
                children: items
                    .map(
                      (item) => _ProductStatTile(
                        image: item.image,
                        title: item.name,
                        subtitle:
                            'المشاهدات: ${item.views}  •  السلة: ${item.addToCart}  •  المشتريات: ${item.purchases}',
                        trailing:
                            'النقاط ${item.score} • ${CurrencyFormatter.formatAmount(item.price)}',
                      ),
                    )
                    .toList(growable: false),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _OpportunitiesTab extends ConsumerWidget {
  final Future<void> Function() onRefresh;
  final Future<void> Function(AdminIntelOpportunity item) onCreateDraft;
  final Future<void> Function(int productId) onPinHome;

  const _OpportunitiesTab({
    required this.onRefresh,
    required this.onCreateDraft,
    required this.onPinHome,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(adminIntelOpportunitiesProvider);
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(LexiSpacing.md),
        children: [
          async.when(
            loading: () => const _LoadingCard(),
            error: (error, _) => _ErrorCard(
              message: UserFriendlyErrors.from(
                error,
                fallback: 'تعذر تحميل فرص التحسين.',
              ),
            ),
            data: (items) {
              if (items.isEmpty) {
                return const _EmptyCard(text: 'لا توجد فرص حرجة حالياً.');
              }
              return Column(
                children: items
                    .map((item) {
                      final conversionPercent = (item.conversionRate * 100)
                          .toStringAsFixed(2);
                      return Card(
                        color: Colors.white,
                        margin: const EdgeInsets.only(bottom: LexiSpacing.sm),
                        child: Padding(
                          padding: const EdgeInsets.all(LexiSpacing.sm),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _ProductStatTile(
                                image: item.image,
                                title: item.name,
                                subtitle:
                                    'مشاهدات ${item.views} • سلة ${item.addToCart} • مشتريات ${item.purchases}',
                                trailing:
                                    'تحويل $conversionPercent% • ${CurrencyFormatter.formatAmount(item.price)}',
                              ),
                              const SizedBox(height: LexiSpacing.sm),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(LexiSpacing.sm),
                                decoration: BoxDecoration(
                                  color: LexiColors.neutral100,
                                  borderRadius: BorderRadius.circular(
                                    LexiRadius.sm,
                                  ),
                                ),
                                child: Text(
                                  item.suggestedActionAr,
                                  style: LexiTypography.bodyMd,
                                ),
                              ),
                              const SizedBox(height: LexiSpacing.sm),
                              Row(
                                children: [
                                  Expanded(
                                    child: OutlinedButton.icon(
                                      onPressed: () => onCreateDraft(item),
                                      icon: const FaIcon(
                                        FontAwesomeIcons.wandMagicSparkles,
                                        size: 14,
                                      ),
                                      label: const Text('إنشاء عرض تجريبي'),
                                    ),
                                  ),
                                  const SizedBox(width: LexiSpacing.sm),
                                  Expanded(
                                    child: ElevatedButton.icon(
                                      onPressed: () =>
                                          onPinHome(item.productId),
                                      icon: const FaIcon(
                                        FontAwesomeIcons.thumbtack,
                                        size: 14,
                                      ),
                                      label: const Text('تثبيت في الرئيسية'),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    })
                    .toList(growable: false),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _WishlistTab extends ConsumerWidget {
  final Future<void> Function() onRefresh;

  const _WishlistTab({required this.onRefresh});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(adminIntelWishlistTopProvider);
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(LexiSpacing.md),
        children: [
          async.when(
            loading: () => const _LoadingCard(),
            error: (error, _) => _ErrorCard(
              message: UserFriendlyErrors.from(
                error,
                fallback: 'تعذر تحميل بيانات المفضلة.',
              ),
            ),
            data: (items) {
              if (items.isEmpty) {
                return const _EmptyCard(text: 'لا توجد بيانات مفضلة حالياً.');
              }
              return Column(
                children: items
                    .map(
                      (item) => _ProductStatTile(
                        image: item.image,
                        title: item.name,
                        subtitle:
                            'عدد الإضافات للمفضلة: ${item.favoritesCount}',
                        trailing: CurrencyFormatter.formatAmount(item.price),
                      ),
                    )
                    .toList(growable: false),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _SearchTab extends ConsumerWidget {
  final Future<void> Function() onRefresh;

  const _SearchTab({required this.onRefresh});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(adminIntelSearchProvider);

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(LexiSpacing.md),
        children: [
          async.when(
            loading: () => const _LoadingCard(),
            error: (error, _) => _ErrorCard(
              message: UserFriendlyErrors.from(
                error,
                fallback: 'تعذر تحميل تحليلات البحث.',
              ),
            ),
            data: (data) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _SectionTitle('أكثر عبارات البحث'),
                const SizedBox(height: LexiSpacing.sm),
                if (data.topQueries.isEmpty)
                  const _EmptyCard(text: 'لا توجد بيانات بحث بعد.')
                else
                  ...data.topQueries.map(
                    (item) => _SimpleStatTile(
                      title: item.query,
                      value: '${item.searches} مرة',
                      icon: FontAwesomeIcons.magnifyingGlass,
                    ),
                  ),
                const SizedBox(height: LexiSpacing.md),
                const _SectionTitle('بحث بدون نتائج'),
                const SizedBox(height: LexiSpacing.sm),
                if (data.zeroResultQueries.isEmpty)
                  const _EmptyCard(text: 'لا توجد عبارات بدون نتائج.')
                else
                  ...data.zeroResultQueries.map(
                    (item) => _SimpleStatTile(
                      title: item.query,
                      value:
                          '${item.zeroResults} بدون نتائج • ${item.searches} بحث',
                      icon: FontAwesomeIcons.circleExclamation,
                      iconColor: LexiColors.warning,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BundlesTab extends ConsumerWidget {
  final Future<void> Function() onRefresh;

  const _BundlesTab({required this.onRefresh});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedId = ref.watch(adminIntelSelectedBundleProductIdProvider);
    final trendingAsync = ref.watch(adminIntelTrendingProvider);
    final bundlesAsync = ref.watch(adminIntelBundlesProvider);

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(LexiSpacing.md),
        children: [
          const _SectionTitle('اختر منتجًا لتحليل الباقات'),
          const SizedBox(height: LexiSpacing.sm),
          trendingAsync.when(
            loading: () => const _LoadingCard(),
            error: (error, _) => _ErrorCard(
              message: UserFriendlyErrors.from(
                error,
                fallback: 'تعذر تحميل المنتجات المقترحة.',
              ),
            ),
            data: (items) {
              if (items.isEmpty) {
                return const _EmptyCard(
                  text: 'لا توجد منتجات متاحة لاستخراج الباقات.',
                );
              }
              return Wrap(
                spacing: LexiSpacing.sm,
                runSpacing: LexiSpacing.sm,
                children: items
                    .take(12)
                    .map((item) {
                      return ChoiceChip(
                        selected: selectedId == item.productId,
                        label: Text(
                          item.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        onSelected: (_) {
                          ref
                              .read(adminIntelActionsControllerProvider)
                              .selectBundleProduct(item.productId);
                        },
                      );
                    })
                    .toList(growable: false),
              );
            },
          ),
          const SizedBox(height: LexiSpacing.md),
          bundlesAsync.when(
            loading: () => const _LoadingCard(),
            error: (error, _) => _ErrorCard(
              message: UserFriendlyErrors.from(
                error,
                fallback: 'تعذر تحميل الباقات المقترحة.',
              ),
            ),
            data: (bundle) {
              if (bundle.productId <= 0) {
                return const _EmptyCard(
                  text: 'اختر منتجًا أولاً لعرض المنتجات المشتراة معه.',
                );
              }
              if (bundle.withProducts.isEmpty) {
                return const _EmptyCard(
                  text: 'لا توجد باقات مقترحة لهذا المنتج في الفترة الحالية.',
                );
              }
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(LexiSpacing.sm),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'المنتج الأساسي: ${bundle.productName}',
                        style: LexiTypography.bodyMd.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: LexiSpacing.sm),
                      ...bundle.withProducts.map(
                        (item) => _ProductStatTile(
                          image: item.image,
                          title: item.name,
                          subtitle: 'تم شراؤه معًا ${item.count} مرة',
                          trailing: 'ID ${item.id}',
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _StockAlertsTab extends ConsumerWidget {
  final Future<void> Function() onRefresh;

  const _StockAlertsTab({required this.onRefresh});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(adminIntelStockAlertsProvider);
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(LexiSpacing.md),
        children: [
          async.when(
            loading: () => const _LoadingCard(),
            error: (error, _) => _ErrorCard(
              message: UserFriendlyErrors.from(
                error,
                fallback: 'تعذر تحميل تنبيهات المخزون.',
              ),
            ),
            data: (data) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _SectionTitle('نفاد المخزون'),
                const SizedBox(height: LexiSpacing.sm),
                if (data.outOfStock.isEmpty)
                  const _EmptyCard(text: 'لا توجد منتجات نافدة حالياً.')
                else
                  ...data.outOfStock.map(
                    (item) => _ProductStatTile(
                      image: item.image,
                      title: item.name,
                      subtitle: 'المخزون: ${item.stockQty}',
                      trailing: CurrencyFormatter.formatAmount(item.price),
                    ),
                  ),
                const SizedBox(height: LexiSpacing.md),
                const _SectionTitle('مخزون منخفض'),
                const SizedBox(height: LexiSpacing.sm),
                if (data.lowStock.isEmpty)
                  const _EmptyCard(text: 'لا توجد منتجات بمخزون منخفض حالياً.')
                else
                  ...data.lowStock.map(
                    (item) => _ProductStatTile(
                      image: item.image,
                      title: item.name,
                      subtitle:
                          'المتوفر ${item.stockQty} • الحد الأدنى ${item.lowStockThreshold}',
                      trailing: CurrencyFormatter.formatAmount(item.price),
                    ),
                  ),
                const SizedBox(height: LexiSpacing.md),
                const _SectionTitle('طلب مرتفع + مخزون منخفض'),
                const SizedBox(height: LexiSpacing.sm),
                if (data.highDemandLowStock.isEmpty)
                  const _EmptyCard(
                    text: 'لا توجد حالات ضغط مرتفع على مخزون منخفض حالياً.',
                  )
                else
                  ...data.highDemandLowStock.map(
                    (item) => _ProductStatTile(
                      image: item.image,
                      title: item.name,
                      subtitle:
                          'مشاهدات 7 أيام: ${item.views7d} • المتوفر: ${item.stockQty}',
                      trailing: CurrencyFormatter.formatAmount(item.price),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ConversionCompareCard extends StatelessWidget {
  final AsyncValue<AdminIntelOverview> todayAsync;
  final AsyncValue<AdminIntelOverview> weekAsync;

  const _ConversionCompareCard({
    required this.todayAsync,
    required this.weekAsync,
  });

  @override
  Widget build(BuildContext context) {
    final today = todayAsync.valueOrNull;
    final week = weekAsync.valueOrNull;
    if (today == null || week == null) {
      return const _LoadingCard();
    }

    final todayRate = today.conversionRate * 100;
    final weekRate = week.conversionRate * 100;
    final diff = todayRate - weekRate;
    final trendUp = diff >= 0;
    final diffText = diff.abs().toStringAsFixed(2);

    return Card(
      child: ListTile(
        leading: FaIcon(
          trendUp
              ? FontAwesomeIcons.arrowTrendUp
              : FontAwesomeIcons.arrowTrendDown,
          color: trendUp ? LexiColors.success : LexiColors.error,
          size: 16,
        ),
        title: const Text('مقارنة التحويل: اليوم مقابل آخر 7 أيام'),
        subtitle: Text(
          'اليوم ${todayRate.toStringAsFixed(2)}% • 7 أيام ${weekRate.toStringAsFixed(2)}%',
        ),
        trailing: Text(
          '${trendUp ? '+' : '-'}$diffText%',
          style: LexiTypography.bodyMd.copyWith(
            fontWeight: FontWeight.w700,
            color: trendUp ? LexiColors.success : LexiColors.error,
          ),
        ),
      ),
    );
  }
}

class _RatePanel extends StatelessWidget {
  final AdminIntelOverview overview;

  const _RatePanel({required this.overview});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(LexiSpacing.sm),
        child: Column(
          children: [
            _SimpleStatTile(
              title: 'معدل التحويل',
              value: '${(overview.conversionRate * 100).toStringAsFixed(2)}%',
              icon: FontAwesomeIcons.percent,
            ),
            _SimpleStatTile(
              title: 'معدل الإضافة للسلة',
              value: '${(overview.addToCartRate * 100).toStringAsFixed(2)}%',
              icon: FontAwesomeIcons.cartPlus,
            ),
            _SimpleStatTile(
              title: 'معدل بدء الدفع',
              value: '${(overview.checkoutRate * 100).toStringAsFixed(2)}%',
              icon: FontAwesomeIcons.cashRegister,
            ),
            _SimpleStatTile(
              title: 'متوسط قيمة الطلب',
              value: CurrencyFormatter.formatAmount(overview.avgOrderValue),
              icon: FontAwesomeIcons.moneyBillTrendUp,
            ),
          ],
        ),
      ),
    );
  }
}

class _KpiCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _KpiCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(LexiSpacing.sm),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            FaIcon(icon, color: color, size: 16),
            const SizedBox(height: LexiSpacing.xs),
            Text(
              value,
              style: LexiTypography.bodyMd.copyWith(
                fontWeight: FontWeight.w700,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: LexiSpacing.xs),
            Text(
              title,
              style: LexiTypography.bodySm,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _RangeChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _RangeChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      selected: selected,
      label: Text(label),
      onSelected: (_) => onTap(),
    );
  }
}

class _ProductStatTile extends StatelessWidget {
  final String image;
  final String title;
  final String subtitle;
  final String trailing;

  const _ProductStatTile({
    required this.image,
    required this.title,
    required this.subtitle,
    required this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: LexiSpacing.sm),
      child: ListTile(
        contentPadding: const EdgeInsets.all(LexiSpacing.sm),
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(LexiRadius.sm),
          child: SizedBox(
            width: 48,
            height: 48,
            child: LexiNetworkImage(imageUrl: image),
          ),
        ),
        title: Text(
          title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: LexiTypography.bodyMd.copyWith(fontWeight: FontWeight.w700),
        ),
        subtitle: Text(
          subtitle,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: LexiTypography.bodySm,
        ),
        trailing: SizedBox(
          width: 130,
          child: Text(
            trailing,
            textAlign: TextAlign.end,
            style: LexiTypography.bodySm.copyWith(fontWeight: FontWeight.w700),
          ),
        ),
      ),
    );
  }
}

class _SimpleStatTile extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color iconColor;

  const _SimpleStatTile({
    required this.title,
    required this.value,
    required this.icon,
    this.iconColor = LexiColors.brandBlack,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      visualDensity: const VisualDensity(vertical: -2),
      contentPadding: EdgeInsets.zero,
      leading: FaIcon(icon, size: 14, color: iconColor),
      title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
      trailing: Text(
        value,
        style: LexiTypography.bodySm.copyWith(fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;

  const _SectionTitle(this.title);

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: LexiTypography.bodyMd.copyWith(fontWeight: FontWeight.w800),
    );
  }
}

class _LoadingCard extends StatelessWidget {
  const _LoadingCard();

  @override
  Widget build(BuildContext context) {
    return const Card(
      child: Padding(
        padding: EdgeInsets.all(LexiSpacing.md),
        child: Center(child: CircularProgressIndicator()),
      ),
    );
  }
}

class _EmptyCard extends StatelessWidget {
  final String text;

  const _EmptyCard({required this.text});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(LexiSpacing.md),
        child: Center(child: Text(text, textAlign: TextAlign.center)),
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  final String message;

  const _ErrorCard({required this.message});

  @override
  Widget build(BuildContext context) {
    return Card(
      color: LexiColors.error.withValues(alpha: 0.08),
      child: Padding(
        padding: const EdgeInsets.all(LexiSpacing.md),
        child: Text(
          message,
          style: LexiTypography.bodyMd.copyWith(color: LexiColors.error),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
