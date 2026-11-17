import 'package:btc_map/src/map_types.dart';
import 'package:bull_ui/bull_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';

import 'package:btc_map/src/presentation/map_localizations_x.dart';
import 'package:btc_map/src/presentation/map_cubit.dart';
import 'package:btc_map/src/presentation/map_state.dart';
import 'package:btc_map/src/ui/merchant_display_x.dart';

/// The top of the list sheet: drag handle and search bar, then, once the sheet
/// is pulled up, the category chips and how many places the list holds.
class MerchantListHeader extends StatelessWidget {
  const MerchantListHeader({
    super.key,
    required this.state,
    required this.searchFocus,
    required this.isOpen,
    required this.onCategorySelected,
  });

  final MapState state;
  final FocusNode searchFocus;

  /// Collapsed, only the search field shows; the space under it (above the
  /// home indicator) stays empty.
  final bool isOpen;
  final ValueChanged<MerchantCategory?> onCategorySelected;

  @override
  Widget build(BuildContext context) {
    final colors = context.bull;
    final cubit = context.read<MapCubit>();
    return ColoredBox(
      color: colors.background,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Gap(8),
          Center(
            child: Container(
              key: const ValueKey('merchant-list-handle'),
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: colors.border,
                borderRadius: BorderRadius.circular(context.bullShapes.dot),
              ),
            ),
          ),
          const Gap(12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: BullSearchBar(
              fieldKey: const ValueKey('merchant-search-field'),
              value: state.query,
              // Nothing to search yet on the very first download.
              hint: state.isFirstLoad
                  ? context.btcMapLoc.merchantMapLoading
                  : context.btcMapLoc.merchantMapSearchHint,
              clearTooltip: context.btcMapLoc.merchantMapSearchClear,
              focusNode: searchFocus,
              onChanged: cubit.search,
              onCleared: () {
                cubit.search('');
                searchFocus.unfocus();
              },
            ),
          ),
          AnimatedOpacity(
            opacity: isOpen ? 1 : 0,
            duration: const Duration(milliseconds: 150),
            child: IgnorePointer(
              ignoring: !isOpen,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Gap(16),
                  SizedBox(
                    height: 32,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      children: [
                        for (final category in [
                          null,
                          ...MerchantCategory.values,
                        ])
                          if (_showsChip(category))
                            Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: BullFilterChip.selectable(
                                key: ValueKey(
                                  'merchant-category-${category?.name}',
                                ),
                                label: category.label(context),
                                selected: state.category == category,
                                onSelected: (_) => onCategorySelected(category),
                              ),
                            ),
                      ],
                    ),
                  ),
                  const Gap(12),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: BullText(
                      _countLine(context),
                      key: const ValueKey('merchant-list-count'),
                      style: Theme.of(context).textTheme.labelLarge,
                      color: colors.textMuted,
                    ),
                  ),
                  const Gap(8),
                  Divider(height: 1, color: colors.border),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Zoomed out every category stays offered, since it still filters the
  /// pins; zoomed in, only those with places in view.
  bool _showsChip(MerchantCategory? category) =>
      category == null ||
      category == state.category ||
      state.listing.isZoomedOut ||
      state.listing.categories.contains(category);

  String _countLine(BuildContext context) {
    final listing = state.listing;
    return switch ((state.isSearching, listing.isZoomedOut)) {
      (true, _) => context.btcMapLoc.merchantMapResultsCount(listing.total),
      (false, true) => context.btcMapLoc.merchantMapZoomInToSeeNearby,
      (false, false) => context.btcMapLoc.merchantMapNearbyCount(listing.total),
    };
  }
}
