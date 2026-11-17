import 'package:meta/meta.dart';

import 'package:btc_map/src/domain/entities/geo_point.dart';

/// The part of the world the map shows. [west] is greater than [east] when the
/// area crosses the antimeridian.
@immutable
final class GeoBounds {
  final double south;
  final double west;
  final double north;
  final double east;

  const GeoBounds._(this.south, this.west, this.north, this.east);

  /// Takes the corners as the map reports them: zoomed far out, longitudes can
  /// run past ±180 and latitudes past the poles. Those are folded back into
  /// range, and an area wider than the world covers every longitude.
  factory GeoBounds({
    required double south,
    required double west,
    required double north,
    required double east,
  }) {
    if (![south, west, north, east].every((value) => value.isFinite)) {
      throw ArgumentError('Bounds must be finite');
    }
    if (south > north) throw ArgumentError('south is above north');
    final clampedSouth = south.clamp(-90.0, 90.0);
    final clampedNorth = north.clamp(-90.0, 90.0);
    if (east - west >= 360) {
      return GeoBounds._(clampedSouth, -180, clampedNorth, 180);
    }
    return GeoBounds._(
      clampedSouth,
      _wrapLongitude(west),
      clampedNorth,
      _wrapLongitude(east),
    );
  }

  bool get crossesAntimeridian => west > east;

  bool contains(GeoPoint point) {
    if (point.latitude < south || point.latitude > north) return false;
    return crossesAntimeridian
        ? point.longitude >= west || point.longitude <= east
        : point.longitude >= west && point.longitude <= east;
  }

  GeoPoint get center {
    final width = crossesAntimeridian ? east + 360 - west : east - west;
    return GeoPoint(
      latitude: (south + north) / 2,
      longitude: _wrapLongitude(west + width / 2),
    );
  }

  /// From the centre to the farthest corner: how large an area the map shows.
  double get radiusMetres {
    final middle = center;
    return [
      GeoPoint(latitude: north, longitude: west),
      GeoPoint(latitude: north, longitude: east),
      GeoPoint(latitude: south, longitude: west),
      GeoPoint(latitude: south, longitude: east),
    ].map(middle.distanceTo).reduce((a, b) => a > b ? a : b);
  }

  static double _wrapLongitude(double longitude) {
    final wrapped = (longitude + 180) % 360 - 180;
    // 180 and -180 are the same meridian; keep 180 for an east edge on it.
    return wrapped == -180 && longitude > 0 ? 180 : wrapped;
  }

  @override
  bool operator ==(Object other) =>
      other is GeoBounds &&
      other.south == south &&
      other.west == west &&
      other.north == north &&
      other.east == east;

  @override
  int get hashCode => Object.hash(south, west, north, east);
}
