import '../domain/bull_map_failure.dart';
import '../domain/entities/geo_bounds.dart';
import '../domain/entities/geo_point.dart';
import '../domain/entities/merchant.dart';
import '../domain/entities/merchant_listing.dart';

import 'package:freezed_annotation/freezed_annotation.dart';

part 'map_state.freezed.dart';

/// Lists are kept as given rather than wrapped: the map re-uploads every pin
/// whenever it gets a different list instance.
@Freezed(makeCollectionsUnmodifiable: false)
sealed class MapState with _$MapState {
  const factory MapState({
    @Default([]) List<Merchant> merchants,

    /// The merchants drawn on the map: all of them, or the picked category's.
    @Default([]) List<Merchant> mapMerchants,
    @Default(false) bool isSyncing,

    /// Why the last sync failed, cleared by the next successful one. With
    /// merchants still on screen (from the cache) it is not blocking.
    BullMapFailure? failure,

    /// What the map shows, once it has reported it.
    GeoBounds? viewport,

    /// A transient IP-derived suggestion for this map opening, never GPS data.
    GeoPoint? initialCenter,
    @Default('') String query,

    /// Null for every category.
    MerchantCategory? category,
    @Default(MerchantListing.empty) MerchantListing listing,
  }) = _MapState;

  const MapState._();

  /// Nothing to show yet: no cached merchants and the first sync is running.
  bool get isFirstLoad => merchants.isEmpty && isSyncing;

  /// Nothing to show and the last sync failed: the screen offers a retry.
  bool get isBlockingFailure =>
      merchants.isEmpty && !isSyncing && failure != null;

  bool get isSearching => MerchantListing.isSearch(query);
}
