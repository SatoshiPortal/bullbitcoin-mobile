import 'package:btc_map/src/map_types.dart';
import 'package:bull_ui/bull_ui.dart';
import 'package:material_ui/material_ui.dart';

import 'package:btc_map/src/presentation/map_localizations_x.dart';
import 'package:btc_map/src/presentation/map_state.dart';
import 'package:btc_map/src/ui/widgets/merchant_list_tile.dart';

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
                ? context.btcMapLoc.merchantMapNoResults
                : context.btcMapLoc.merchantMapNoPlacesInView,
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
                    ? context.btcMapLoc.merchantMapListTruncated(
                        listing.places.length,
                        listing.total,
                      )
                    : context.btcMapLoc.merchantMapZoomInForMore(
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
