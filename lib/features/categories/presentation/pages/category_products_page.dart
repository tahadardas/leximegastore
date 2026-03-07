import 'package:flutter/widgets.dart';

import '../../../product/presentation/pages/products_listing_page.dart';

class CategoryProductsPage extends StatelessWidget {
  final int? categoryId;
  final int? brandId;
  final String? brandName;
  final String title;
  final String initialSort;
  final String initialSearch;

  const CategoryProductsPage({
    super.key,
    this.categoryId,
    this.brandId,
    this.brandName,
    required this.title,
    this.initialSort = 'manual',
    this.initialSearch = '',
  }) : assert(
         (categoryId != null && categoryId > 0) ||
             (brandId != null && brandId > 0) ||
             (brandName != null && brandName != ''),
         'Either categoryId, brandId, or brandName must be provided.',
       );

  @override
  Widget build(BuildContext context) {
    final normalizedBrand = (brandName ?? '').trim();
    final isBrandMode = (brandId ?? 0) > 0 || normalizedBrand.isNotEmpty;

    return ProductsListingPage(
      title: title,
      filterType: isBrandMode
          ? ProductsListingFilterType.brand
          : ProductsListingFilterType.category,
      filterId: isBrandMode ? brandId : categoryId,
      filterName: isBrandMode ? normalizedBrand : null,
      initialSort: initialSort,
      initialSearch: initialSearch,
    );
  }
}
