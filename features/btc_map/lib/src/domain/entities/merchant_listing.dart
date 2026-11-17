import 'package:meta/meta.dart';

import 'package:btc_map/src/domain/entities/geo_bounds.dart';
import 'package:btc_map/src/domain/entities/merchant.dart';

/// What the list under the map shows: the first places, how many matched in
/// all, and which categories they cover.
@immutable
final class MerchantListing {
  /// btcmap.org's own cap; the count still says how many matched in all.
  static const maxPlaces = 250;

  /// Places are "nearby" only while the map shows about a city or region:
  /// roughly btcmap.org's zoom 10 on a phone. Further out the count would be
  /// most of the world.
  static const maxNearbyRadiusMetres = 50000.0;

  /// A single letter matches most places; search starts from two.
  static const minSearchLength = 2;

  /// Whether [query] is long enough to search every place.
  static bool isSearch(String query) => query.trim().length >= minSearchLength;

  /// At most [maxPlaces], the best match first.
  final List<Merchant> places;

  /// Every match, of which [places] is the start.
  final int total;

  /// The categories of the matches before the category filter, so only chips
  /// that would show something are offered.
  final Set<MerchantCategory> categories;

  /// The map shows too large an area for a nearby list: the user has to
  /// zoom in first.
  final bool isZoomedOut;

  const MerchantListing({
    this.places = const [],
    this.total = 0,
    this.categories = const {},
    this.isZoomedOut = false,
  });

  static const empty = MerchantListing();
  static const zoomedOut = MerchantListing(isZoomedOut: true);

  /// What the list shows: with a [query], a search of every place; without
  /// one, the places in [viewport], or nothing before the map has reported
  /// it. Never touches the network, so neither what a user types nor where
  /// they look is disclosed to anyone.
  factory MerchantListing.of(
    Iterable<Merchant> merchants, {
    required GeoBounds? viewport,
    String query = '',
    MerchantCategory? category,
  }) {
    if (isSearch(query)) {
      return MerchantListing.search(
        merchants,
        query: query,
        category: category,
      );
    }
    if (viewport == null) return empty;
    return MerchantListing.nearby(
      merchants,
      viewport: viewport,
      category: category,
    );
  }

  /// The places in [viewport], nearest to its centre first, or [zoomedOut]
  /// when it covers more than a region.
  factory MerchantListing.nearby(
    Iterable<Merchant> merchants, {
    required GeoBounds viewport,
    MerchantCategory? category,
  }) {
    if (viewport.radiusMetres > maxNearbyRadiusMetres) return zoomedOut;
    final center = viewport.center;
    final distances = <int, double>{};
    double distanceOf(Merchant merchant) => distances.putIfAbsent(
      merchant.id,
      () => merchant.location.distanceTo(center),
    );
    return MerchantListing._ranked(
      merchants.where((m) => viewport.contains(m.location)).toList(),
      category: category,
      compare: (a, b) => distanceOf(a).compareTo(distanceOf(b)),
    );
  }

  /// Every place whose name or address matches [query], names starting with
  /// it first, then alphabetical.
  factory MerchantListing.search(
    Iterable<Merchant> merchants, {
    required String query,
    MerchantCategory? category,
  }) {
    final needle = query.trim().toLowerCase();
    return MerchantListing._ranked(
      merchants.where((m) => m.matchesLowercase(needle)).toList(),
      category: category,
      compare: (a, b) {
        final aPrefix = a.searchName.startsWith(needle);
        final bPrefix = b.searchName.startsWith(needle);
        if (aPrefix != bPrefix) return aPrefix ? -1 : 1;
        return a.searchName.compareTo(b.searchName);
      },
    );
  }

  /// Keeps [category]'s [matches], orders them by [compare] and caps them at
  /// [maxPlaces].
  factory MerchantListing._ranked(
    List<Merchant> matches, {
    required MerchantCategory? category,
    required Comparator<Merchant> compare,
  }) {
    final shown = matches.inCategory(category).toList()..sort(compare);
    return MerchantListing(
      places: List.unmodifiable(shown.take(maxPlaces)),
      total: shown.length,
      categories: Set.unmodifiable({
        ...matches.map((m) => m.category).nonNulls,
      }),
    );
  }

  bool get isTruncated => total > places.length;
}
