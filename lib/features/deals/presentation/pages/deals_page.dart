import 'package:flutter/widgets.dart';

import '../../../product/presentation/pages/products_listing_page.dart';

class DealsPage extends StatelessWidget {
  const DealsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const ProductsListingPage(
      title:
          '\u0627\u0644\u0639\u0631\u0648\u0636 \u0627\u0644\u0633\u0631\u064a\u0639\u0629',
      filterType: ProductsListingFilterType.deals,
      initialSort: 'flash_deals',
    );
  }
}
