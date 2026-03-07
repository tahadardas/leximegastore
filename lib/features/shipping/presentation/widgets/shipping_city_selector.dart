import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/lexi_theme.dart';
import '../../domain/entities/city.dart';
import '../controllers/shipping_controller.dart';

class ShippingCitySelector extends ConsumerWidget {
  const ShippingCitySelector({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final citiesAsync = ref.watch(citiesProvider);
    final selectedCity = ref.watch(selectedCityProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'المدينة',
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: LexiColors.secondaryText),
        ),
        const SizedBox(height: LexiSpacing.xs),
        citiesAsync.when(
          loading: () => const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: SizedBox(
              height: 2,
              child: LinearProgressIndicator(
                backgroundColor: LexiColors.lightGray,
                color: LexiColors.primary,
              ),
            ),
          ),
          error: (e, st) => Row(
            key: const ValueKey('cities_error'),
            children: [
              const Icon(
                Icons.error_outline,
                size: 16,
                color: LexiColors.error,
              ),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  'فشل تحميل المدن',
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: LexiColors.error),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              InkWell(
                onTap: () => ref.refresh(citiesProvider),
                child: Text(
                  'إعادة المحاولة',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: LexiColors.primary,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
            ],
          ),
          data: (cities) {
            if (cities.isEmpty) {
              return const Text('لا توجد مدن متاحة');
            }
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: LexiSpacing.sm),
              decoration: BoxDecoration(
                color: LexiColors.lightGray,
                borderRadius: BorderRadius.circular(LexiRadius.sm),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<City>(
                  value: selectedCity,
                  hint: const Text('اختر المدينة'),
                  isExpanded: true,
                  icon: const Icon(Icons.keyboard_arrow_down),
                  items: cities.map((city) {
                    return DropdownMenuItem<City>(
                      value: city,
                      child: Text(city.name),
                    );
                  }).toList(),
                  onChanged: (City? newCity) {
                    ref.read(selectedCityProvider.notifier).state = newCity;
                  },
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}
