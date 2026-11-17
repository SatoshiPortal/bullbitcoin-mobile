import 'package:bull_map/bull_map.dart';
import 'package:bull_ui/bull_ui.dart';
import 'package:material_ui/material_ui.dart';

import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/features/map/presentation/map_state.dart';
import 'package:bb_mobile/features/map/ui/widgets/merchant_list_tile.dart';

/// The places under the list sheet's header, as slivers: the rows, or why
/// there are none, and a note when the list is capped.
class MerchantListPlaces extends StatelessWidget {
  const MerchantListPlaces({
    super.key,
    required this.state,
    required this.onSelected,
  });

  final MapState state;
  final ValueChanged<Merchant> onSelected;

  @override
  Widget build(BuildContext context) {
    final listing = state.listing;
    final textTheme = Theme.of(context).textTheme;
    final colors = context.bull;
    // The count line already asks the user to zoom in.
    if (listing.isZoomedOut) return const SliverToBoxAdapter();
    if (listing.places.isEmpty) {
      return SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: BullText(
            state.isSearching
                ? context.loc.merchantMapNoResults
                : context.loc.merchantMapNoPlacesInView,
            style: textTheme.bodyMedium,
            color: colors.textMuted,
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    final now = DateTime.now();
    return SliverMainAxisGroup(
      slivers: [
        SliverList.builder(
          itemCount: listing.places.length,
          itemBuilder: (context, index) {
            final merchant = listing.places[index];
            return MerchantListTile(
              key: ValueKey('merchant-result-${merchant.id}'),
              merchant: merchant,
              now: now,
              onTap: () => onSelected(merchant),
            );
          },
        ),
        if (listing.isTruncated)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: BullText(
                state.isSearching
                    ? context.loc.merchantMapListTruncated(
                        listing.places.length,
                        listing.total,
                      )
                    : context.loc.merchantMapZoomInForMore(
                        listing.places.length,
                        listing.total,
                      ),
                style: textTheme.bodySmall,
                color: colors.textMuted,
                textAlign: TextAlign.center,
              ),
            ),
          ),
      ],
    );
  }
}
