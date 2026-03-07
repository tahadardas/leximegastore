import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/errors/app_exception.dart';
import '../../../../../design_system/lexi_tokens.dart';
import '../../../../../shared/ui/lexi_alert.dart';
import '../../../../../shared/widgets/lexi_network_image.dart';
import '../../../../home/domain/entities/home_ad_banner_entity.dart';
import '../../../../home/presentation/controllers/home_ad_banners_controller.dart';
import '../../../../home/presentation/widgets/banner_carousel_widget.dart';
import '../../domain/entities/admin_ad_banner.dart';
import '../../domain/entities/admin_home_section.dart';
import '../controllers/admin_ad_banners_controller.dart';
import '../controllers/admin_home_sections_controller.dart';
import 'admin_home_section_items_page.dart';
import 'admin_home_sections_page.dart';

class AdminAdBannersPage extends ConsumerStatefulWidget {
  const AdminAdBannersPage({super.key});

  @override
  ConsumerState<AdminAdBannersPage> createState() => _AdminAdBannersPageState();
}

class _AdminAdBannersPageState extends ConsumerState<AdminAdBannersPage> {
  List<AdminAdBanner> _items = const [];
  bool _didHydrateFromServer = false;
  bool _isSaving = false;

  int _previewIndex = 0;

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bannersAsync = ref.watch(adminAdBannersControllerProvider);
    final sectionsAsync = ref.watch(adminHomeSectionsControllerProvider);
    final heroSection = _findHeroSection(sectionsAsync.valueOrNull ?? const []);

    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FloatingActionButton.small(
            heroTag: 'banners_refresh',
            onPressed: _isSaving
                ? null
                : () {
                    _didHydrateFromServer = false;
                    ref
                        .read(adminAdBannersControllerProvider.notifier)
                        .refresh();
                    ref
                        .read(adminHomeSectionsControllerProvider.notifier)
                        .refresh();
                  },
            child: const Icon(Icons.refresh_rounded, size: 18),
          ),
          const SizedBox(height: 8),
          FloatingActionButton.small(
            heroTag: 'banners_save',
            onPressed: (_didHydrateFromServer && !_isSaving) ? _save : null,
            child: const Icon(Icons.save_outlined, size: 18),
          ),
          const SizedBox(height: 8),
          FloatingActionButton.extended(
            heroTag: 'banners_add',
            onPressed: _isSaving ? null : _addBanner,
            icon: const Icon(Icons.add_photo_alternate_outlined),
            label: const Text('إضافة بانر'),
          ),
        ],
      ),
      body: bannersAsync.when(
        loading: () {
          return const Center(child: CircularProgressIndicator());
        },
        error: (error, stackTrace) {
          return Center(
            child: FilledButton.icon(
              onPressed: () {
                _didHydrateFromServer = false;
                ref.read(adminAdBannersControllerProvider.notifier).refresh();
              },
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('إعادة المحاولة'),
            ),
          );
        },
        data: (items) {
          if (!_didHydrateFromServer) {
            _items = List<AdminAdBanner>.generate(items.length, (index) {
              final item = items[index];
              if (item.id.trim().isNotEmpty) return item;
              return item.copyWith(
                id: 'banner_${index + 1}_${item.imageUrl.hashCode}_${item.linkUrl.hashCode}',
              );
            })..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
            _didHydrateFromServer = true;
          }

          final activeBanners = _items.where((e) => e.isActive).toList();
          final hasActiveBanners = activeBanners.isNotEmpty;
          final previewItems = hasActiveBanners ? activeBanners : _items;
          if (_previewIndex >= previewItems.length && previewItems.isNotEmpty) {
            _previewIndex = 0;
          }

          return Column(
            children: [
              _StudioTopPanel(
                heroSection: heroSection,
                total: _items.length,
                active: activeBanners.length,
                isHeroLoading: sectionsAsync.isLoading,
                onManageHeroProducts: heroSection == null
                    ? null
                    : () => _openHeroProductsEditor(heroSection),
                onOpenSections: _openHomeSectionsPage,
              ),
              const SizedBox(height: 8),
              _buildPreview(
                previewItems: previewItems,
                heroSection: heroSection,
                isUsingDraftPreview: !hasActiveBanners && _items.isNotEmpty,
              ),
              const SizedBox(height: 8),
              Expanded(
                child: _items.isEmpty
                    ? Center(
                        child: FilledButton.icon(
                          onPressed: _isSaving ? null : _addBanner,
                          icon: const Icon(Icons.add_rounded),
                          label: const Text('إضافة أول بانر'),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsetsDirectional.fromSTEB(
                          12,
                          0,
                          12,
                          92,
                        ),
                        itemCount: _items.length,
                        itemBuilder: (context, index) {
                          final item = _items[index];
                          return _buildBannerTile(item, index);
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildPreview({
    required List<AdminAdBanner> previewItems,
    required AdminHomeSection? heroSection,
    required bool isUsingDraftPreview,
  }) {
    final safeIndex = previewItems.isEmpty
        ? 0
        : _previewIndex.clamp(0, previewItems.length - 1);
    final hasHeroSection = heroSection != null;
    final heroIsActive = heroSection?.isActive ?? false;
    final heroItemsCount = heroSection?.itemsCount ?? 0;

    late final String heroStatusText;
    late final Color heroStatusBg;
    late final Color heroStatusBorder;
    late final Color heroStatusTextColor;
    late final IconData heroStatusIcon;

    if (!hasHeroSection) {
      heroStatusText =
          'لا يوجد قسم hero_banner، لذلك لن تظهر المنتجات المتحركة في الرئيسية.';
      heroStatusBg = const Color(0xFFFFF4D6);
      heroStatusBorder = const Color(0xFFFFD98A);
      heroStatusTextColor = const Color(0xFF8A5A00);
      heroStatusIcon = Icons.warning_amber_rounded;
    } else if (!heroIsActive) {
      heroStatusText =
          'قسم hero_banner متوقف حاليًا. فعّله من الأقسام لعرض المنتجات المتحركة.';
      heroStatusBg = const Color(0xFFFFF4D6);
      heroStatusBorder = const Color(0xFFFFD98A);
      heroStatusTextColor = const Color(0xFF8A5A00);
      heroStatusIcon = Icons.pause_circle_outline_rounded;
    } else if (heroItemsCount <= 0) {
      heroStatusText =
          'قسم hero_banner نشط لكن بدون منتجات. أضف منتجات من زر "المنتجات المتحركة".';
      heroStatusBg = const Color(0xFFFFF4D6);
      heroStatusBorder = const Color(0xFFFFD98A);
      heroStatusTextColor = const Color(0xFF8A5A00);
      heroStatusIcon = Icons.playlist_add_circle_outlined;
    } else {
      heroStatusText =
          'مصدر المنتجات المتحركة في الرئيسية هو hero_banner فقط ($heroItemsCount منتج).';
      heroStatusBg = const Color(0xFFEFFAF2);
      heroStatusBorder = const Color(0xFFB8E7C5);
      heroStatusTextColor = const Color(0xFF1E6B35);
      heroStatusIcon = Icons.check_circle_outline_rounded;
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E8F1)),
      ),
      child: Column(
        children: [
          if (isUsingDraftPreview) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF4D6),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFFFD98A)),
              ),
              child: const Row(
                children: [
                  Icon(
                    Icons.visibility_outlined,
                    size: 18,
                    color: Color(0xFF8A5A00),
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'لا توجد بانرات نشطة الآن، لذلك المعاينة تعرض جميع البانرات (بما فيها المتوقفة).',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF8A5A00),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
          ],
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: heroStatusBg,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: heroStatusBorder),
            ),
            child: Row(
              children: [
                Icon(heroStatusIcon, size: 18, color: heroStatusTextColor),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    heroStatusText,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: heroStatusTextColor,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Text(
                'معاينة حيّة',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
              const Spacer(),
              if (previewItems.length > 1)
                Text('${safeIndex + 1}/${previewItems.length}'),
            ],
          ),
          const SizedBox(height: 8),
          if (previewItems.isEmpty)
            Container(
              height: 150,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: const Color(0xFFF3F5FA),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text('لا يوجد عناصر للمعاينة'),
            )
          else
            BannerCarouselWidget(
              banners: previewItems
                  .map(_toHomeBannerEntity)
                  .toList(growable: false),
              currentIndex: safeIndex,
              onPageChanged: (index) {
                if (!mounted) {
                  return;
                }
                setState(() => _previewIndex = index);
              },
              onTapBanner: (_) {},
            ),
        ],
      ),
    );
  }

  HomeAdBannerEntity _toHomeBannerEntity(AdminAdBanner item) {
    return HomeAdBannerEntity(
      id: item.id,
      imageUrl: item.imageUrl,
      linkUrl: item.linkUrl,
      titleAr: item.titleAr,
      subtitleAr: item.subtitleAr,
      badge: item.badge,
      isActive: item.isActive,
      sortOrder: item.sortOrder,
      gradientStart: item.gradientStart,
      gradientEnd: item.gradientEnd,
      ctaText: item.ctaText,
      textColorHex: item.textColorHex,
      badgeColorHex: item.badgeColorHex,
    );
  }

  Widget _buildBannerTile(AdminAdBanner item, int index) {
    return Container(
      key: ValueKey('banner-${item.id}'),
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: item.isActive
              ? LexiColors.primaryYellow.withValues(alpha: 0.45)
              : const Color(0xFFE4E7F0),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Row(
          children: [
            SizedBox(
              width: 30,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    icon: const Icon(Icons.keyboard_arrow_up_rounded, size: 18),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints.tightFor(
                      width: 24,
                      height: 24,
                    ),
                    visualDensity: VisualDensity.compact,
                    onPressed: index > 0
                        ? () => _moveBanner(index, index - 1)
                        : null,
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.keyboard_arrow_down_rounded,
                      size: 18,
                    ),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints.tightFor(
                      width: 24,
                      height: 24,
                    ),
                    visualDensity: VisualDensity.compact,
                    onPressed: index < (_items.length - 1)
                        ? () => _moveBanner(index, index + 1)
                        : null,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(
                width: 80,
                height: 80,
                child: item.imageUrl.trim().isEmpty
                    ? Container(
                        color: const Color(0xFFF2F4FA),
                        alignment: Alignment.center,
                        child: const Icon(Icons.image_not_supported_outlined),
                      )
                    : LexiNetworkImage(
                        imageUrl: item.imageUrl,
                        fit: BoxFit.cover,
                        errorWidget: Container(
                          color: const Color(0xFFF2F4FA),
                          alignment: Alignment.center,
                          child: const Icon(Icons.broken_image_outlined),
                        ),
                      ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.titleAr.trim().isEmpty
                        ? 'بانر ${index + 1}'
                        : item.titleAr.trim(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    item.subtitleAr.trim().isEmpty
                        ? (item.linkUrl.trim().isEmpty
                              ? 'بدون رابط'
                              : item.linkUrl.trim())
                        : item.subtitleAr.trim(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: LexiColors.neutral600,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: item.isActive
                              ? LexiColors.success.withValues(alpha: 0.12)
                              : LexiColors.neutral300.withValues(alpha: 0.4),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          item.isActive ? 'نشط' : 'متوقف',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: item.isActive
                                ? LexiColors.success
                                : LexiColors.neutral700,
                          ),
                        ),
                      ),
                      if (item.badge.trim().isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: _hexToColor(
                              item.badgeColorHex,
                              LexiColors.primaryYellow,
                            ).withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            item.badge.trim(),
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Switch(
                  value: item.isActive,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  onChanged: (value) {
                    setState(() {
                      _items[index] = item.copyWith(isActive: value);
                    });
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.edit_outlined, size: 20),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints.tightFor(
                    width: 32,
                    height: 32,
                  ),
                  visualDensity: VisualDensity.compact,
                  onPressed: _isSaving ? null : () => _editBanner(index),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, size: 20),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints.tightFor(
                    width: 32,
                    height: 32,
                  ),
                  visualDensity: VisualDensity.compact,
                  onPressed: _isSaving ? null : () => _removeBanner(index),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  AdminHomeSection? _findHeroSection(List<AdminHomeSection> sections) {
    for (final section in sections) {
      if (section.type == 'hero_banner') {
        return section;
      }
    }
    return null;
  }

  Future<void> _openHomeSectionsPage() async {
    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const AdminHomeSectionsPage()));
    if (!mounted) return;
    await ref.read(adminHomeSectionsControllerProvider.notifier).refresh();
    setState(() {});
  }

  Future<void> _openHeroProductsEditor(AdminHomeSection section) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AdminHomeSectionItemsPage(section: section),
      ),
    );
    if (!mounted) return;
    await ref.read(adminHomeSectionsControllerProvider.notifier).refresh();
    ref.invalidate(homeAdBannersControllerProvider);
    setState(() {});
  }

  void _moveBanner(int fromIndex, int toIndex) {
    if (fromIndex == toIndex ||
        fromIndex < 0 ||
        toIndex < 0 ||
        fromIndex >= _items.length ||
        toIndex >= _items.length) {
      return;
    }

    setState(() {
      final moved = _items.removeAt(fromIndex);
      _items.insert(toIndex, moved);
    });
  }

  Future<void> _addBanner() async {
    final created = await _showEditor();
    if (!mounted || created == null) return;
    setState(() {
      _items = [..._items, created.copyWith(sortOrder: _items.length + 1)];
    });
  }

  Future<void> _editBanner(int index) async {
    final updated = await _showEditor(initial: _items[index]);
    if (!mounted || updated == null) return;
    setState(() {
      _items[index] = updated.copyWith(sortOrder: index + 1);
    });
  }

  Future<void> _removeBanner(int index) async {
    await LexiAlert.confirm(
      context,
      title: 'حذف البانر',
      text: 'هل تريد حذف هذا البانر؟',
      onConfirm: () async {
        if (!mounted) return;
        setState(() {
          _items.removeAt(index);
        });
      },
    );
  }

  Future<AdminAdBanner?> _showEditor({AdminAdBanner? initial}) async {
    final imageController = TextEditingController(
      text: initial?.imageUrl ?? '',
    );
    final linkController = TextEditingController(text: initial?.linkUrl ?? '');
    final titleController = TextEditingController(text: initial?.titleAr ?? '');
    final subtitleController = TextEditingController(
      text: initial?.subtitleAr ?? '',
    );
    final badgeController = TextEditingController(text: initial?.badge ?? '');
    final ctaController = TextEditingController(
      text: initial?.ctaText.trim().isEmpty == true
          ? 'تسوق الآن'
          : (initial?.ctaText ?? 'تسوق الآن'),
    );
    final gradientStartController = TextEditingController(
      text: _normalizeHex(initial?.gradientStart ?? 'FF131313'),
    );
    final gradientEndController = TextEditingController(
      text: _normalizeHex(initial?.gradientEnd ?? 'FF2A2417'),
    );
    final textColorController = TextEditingController(
      text: _normalizeHex(initial?.textColorHex ?? 'FFFFFFFF'),
    );
    final badgeColorController = TextEditingController(
      text: _normalizeHex(initial?.badgeColorHex ?? 'FFFACB21'),
    );

    var isActive = initial?.isActive ?? true;
    String? validationError;

    final result = await showModalBottomSheet<AdminAdBanner>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        final bottom = MediaQuery.of(sheetContext).viewInsets.bottom;
        return Padding(
          padding: EdgeInsets.only(bottom: bottom),
          child: StatefulBuilder(
            builder: (context, setModalState) {
              return Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                ),
                padding: const EdgeInsetsDirectional.fromSTEB(14, 14, 14, 16),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: Text(
                          'محرر البانر',
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 18,
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: imageController,
                        onChanged: (_) =>
                            setModalState(() => validationError = null),
                        decoration: const InputDecoration(
                          labelText: 'رابط الصورة *',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: linkController,
                        onChanged: (_) => setModalState(() {}),
                        decoration: const InputDecoration(
                          labelText: 'الرابط عند الضغط (اختياري)',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: titleController,
                        onChanged: (_) => setModalState(() {}),
                        decoration: const InputDecoration(
                          labelText: 'العنوان (اختياري)',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: subtitleController,
                        onChanged: (_) => setModalState(() {}),
                        decoration: const InputDecoration(
                          labelText: 'وصف قصير (اختياري)',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: badgeController,
                              onChanged: (_) => setModalState(() {}),
                              decoration: const InputDecoration(
                                labelText: 'شارة (Badge)',
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              controller: ctaController,
                              onChanged: (_) => setModalState(() {}),
                              decoration: const InputDecoration(
                                labelText: 'نص CTA',
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: gradientStartController,
                              onChanged: (_) => setModalState(() {}),
                              decoration: const InputDecoration(
                                labelText: 'Gradient Start',
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              controller: gradientEndController,
                              onChanged: (_) => setModalState(() {}),
                              decoration: const InputDecoration(
                                labelText: 'Gradient End',
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: textColorController,
                              onChanged: (_) => setModalState(() {}),
                              decoration: const InputDecoration(
                                labelText: 'لون النص',
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              controller: badgeColorController,
                              onChanged: (_) => setModalState(() {}),
                              decoration: const InputDecoration(
                                labelText: 'لون الشارة',
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                        ],
                      ),
                      SwitchListTile(
                        value: isActive,
                        onChanged: (v) => setModalState(() => isActive = v),
                        contentPadding: EdgeInsets.zero,
                        title: const Text('نشط'),
                      ),
                      if (validationError != null)
                        Align(
                          alignment: Alignment.centerRight,
                          child: Text(
                            validationError!,
                            style: const TextStyle(color: Colors.red),
                          ),
                        ),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => Navigator.pop(sheetContext),
                              child: const Text('إلغاء'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: FilledButton(
                              onPressed: () {
                                final imageUrl = imageController.text.trim();
                                if (imageUrl.isEmpty) {
                                  setModalState(
                                    () =>
                                        validationError = 'رابط الصورة مطلوب.',
                                  );
                                  return;
                                }
                                Navigator.pop(
                                  sheetContext,
                                  AdminAdBanner(
                                    id:
                                        initial?.id ??
                                        'ad_${DateTime.now().microsecondsSinceEpoch}',
                                    imageUrl: imageUrl,
                                    linkUrl: linkController.text.trim(),
                                    titleAr: titleController.text.trim(),
                                    subtitleAr: subtitleController.text.trim(),
                                    badge: badgeController.text.trim(),
                                    ctaText: ctaController.text.trim(),
                                    gradientStart: _normalizeHex(
                                      gradientStartController.text,
                                      fallback: 'FF131313',
                                    ),
                                    gradientEnd: _normalizeHex(
                                      gradientEndController.text,
                                      fallback: 'FF2A2417',
                                    ),
                                    textColorHex: _normalizeHex(
                                      textColorController.text,
                                      fallback: 'FFFFFFFF',
                                    ),
                                    badgeColorHex: _normalizeHex(
                                      badgeColorController.text,
                                      fallback: 'FFFACB21',
                                    ),
                                    isActive: isActive,
                                    sortOrder: initial?.sortOrder ?? 0,
                                  ),
                                );
                              },
                              child: const Text('حفظ'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );

    imageController.dispose();
    linkController.dispose();
    titleController.dispose();
    subtitleController.dispose();
    badgeController.dispose();
    ctaController.dispose();
    gradientStartController.dispose();
    gradientEndController.dispose();
    textColorController.dispose();
    badgeColorController.dispose();
    return result;
  }

  Future<void> _save() async {
    if (_isSaving || !_didHydrateFromServer) return;

    final normalized = List.generate(
      _items.length,
      (index) => _items[index].copyWith(sortOrder: index + 1),
    );

    setState(() => _isSaving = true);
    await LexiAlert.loading(context, text: 'جاري حفظ البنرات...');

    var saved = false;
    String? errorText;
    try {
      await ref
          .read(adminAdBannersControllerProvider.notifier)
          .save(normalized);
      await ref.read(adminAdBannersControllerProvider.notifier).refresh();
      ref.invalidate(homeAdBannersControllerProvider);
      saved = true;
    } catch (e) {
      errorText = _friendlyError(e);
    } finally {
      if (mounted) {
        await LexiAlert.dismiss(context);
        setState(() => _isSaving = false);
      }
    }

    if (!mounted) return;
    if (saved) {
      setState(() {
        _items = normalized;
        _didHydrateFromServer = false;
      });
      await LexiAlert.success(context, text: 'تم حفظ البنرات بنجاح.');
      return;
    }

    await LexiAlert.error(
      context,
      text: errorText ?? 'تعذر حفظ البنرات حاليًا.',
    );
  }

  String _friendlyError(Object error) {
    if (error is AppException) return error.message;
    return 'تعذر حفظ البنرات حاليًا.';
  }

  String _normalizeHex(String raw, {String fallback = 'FFFFFFFF'}) {
    var cleaned = raw.replaceAll('#', '').trim().toUpperCase();
    if (cleaned.length == 6) {
      cleaned = 'FF$cleaned';
    }
    if (cleaned.length != 8 || !RegExp(r'^[0-9A-F]{8}$').hasMatch(cleaned)) {
      return fallback;
    }
    return cleaned;
  }

  static Color _hexToColor(String hex, Color fallback) {
    try {
      final normalized = hex.replaceAll('#', '').trim();
      final value = int.parse(
        normalized.length == 6 ? 'FF$normalized' : normalized,
        radix: 16,
      );
      return Color(value);
    } catch (_) {
      return fallback;
    }
  }
}

class _StudioTopPanel extends StatelessWidget {
  final AdminHomeSection? heroSection;
  final int total;
  final int active;
  final bool isHeroLoading;
  final VoidCallback? onManageHeroProducts;
  final VoidCallback onOpenSections;

  const _StudioTopPanel({
    required this.heroSection,
    required this.total,
    required this.active,
    required this.isHeroLoading,
    required this.onManageHeroProducts,
    required this.onOpenSections,
  });

  @override
  Widget build(BuildContext context) {
    final hasHeroSection = heroSection != null;
    final heroStateText = isHeroLoading
        ? '\u062c\u0627\u0631\u064a \u062a\u062d\u0645\u064a\u0644 \u0625\u0639\u062f\u0627\u062f\u0627\u062a \u0627\u0644\u0645\u0646\u062a\u062c\u0627\u062a \u0627\u0644\u0645\u062a\u062d\u0631\u0643\u0629...'
        : !hasHeroSection
        ? '\u0644\u0627 \u064a\u0648\u062c\u062f \u0642\u0633\u0645 hero_banner \u062d\u062a\u0649 \u0627\u0644\u0622\u0646.'
        : heroSection!.isActive
        ? '\u0642\u0633\u0645 \u0627\u0644\u0645\u0646\u062a\u062c\u0627\u062a \u0627\u0644\u0645\u062a\u062d\u0631\u0643\u0629 \u0646\u0634\u0637 (${heroSection!.itemsCount} \u0645\u0646\u062a\u062c).'
        : '\u0642\u0633\u0645 \u0627\u0644\u0645\u0646\u062a\u062c\u0627\u062a \u0627\u0644\u0645\u062a\u062d\u0631\u0643\u0629 \u0645\u062a\u0648\u0642\u0641 \u062d\u0627\u0644\u064a\u0627\u064b.';

    return Container(
      margin: const EdgeInsetsDirectional.fromSTEB(12, 12, 12, 0),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E8F1)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: LexiColors.primaryYellow,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.campaign_rounded,
                  color: LexiColors.brandBlack,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  '\u0628\u0646\u0631\u0627\u062a \u0627\u0644\u0635\u0641\u062d\u0629 \u0627\u0644\u0631\u0626\u064a\u0633\u064a\u0629',
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    color: LexiColors.brandBlack,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: LexiColors.neutral100,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '\u0646\u0634\u0637 $active/$total',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFF5F8FF),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFDDE7FF)),
            ),
            child: Text(
              heroStateText,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: LexiColors.neutral700,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: onManageHeroProducts,
                  style: FilledButton.styleFrom(
                    backgroundColor: LexiColors.primaryYellow,
                    foregroundColor: LexiColors.brandBlack,
                  ),
                  icon: const Icon(Icons.view_carousel_outlined, size: 18),
                  label: const Text(
                    '\u0627\u0644\u0645\u0646\u062a\u062c\u0627\u062a \u0627\u0644\u0645\u062a\u062d\u0631\u0643\u0629',
                  ),
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton(
                onPressed: onOpenSections,
                child: const Text('\u0627\u0644\u0623\u0642\u0633\u0627\u0645'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
