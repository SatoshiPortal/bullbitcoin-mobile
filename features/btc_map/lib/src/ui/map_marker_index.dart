import 'dart:convert';
import 'dart:isolate';

import '../domain/entities/geo_bounds.dart';
import '../domain/entities/geo_point.dart';
import '../domain/entities/merchant.dart';

/// Compact rendering data: moving the map never copies the merchant catalogue
/// into a worker. Only ids and coordinates are needed to prepare native pins.
final class MapMarkerIndex {
  static List<Merchant>? _lastMerchants;
  static Future<MapMarkerIndex>? _lastIndex;

  final List<({int id, double latitude, double longitude})> _points;
  final Map<int, int> positions;

  MapMarkerIndex._(this._points, this.positions);

  /// One retained preparation, reused when a cached map is reopened. A new
  /// dataset or category replaces it rather than growing a cache per filter.
  static Future<MapMarkerIndex> forMerchants(List<Merchant> merchants) {
    final previous = _lastIndex;
    if (identical(merchants, _lastMerchants) && previous != null) {
      return previous;
    }
    _lastMerchants = merchants;
    return _lastIndex = Isolate.run(() => _build(merchants));
  }

  static MapMarkerIndex _build(List<Merchant> merchants) => MapMarkerIndex._(
    [
      for (final merchant in merchants)
        (
          id: merchant.id,
          latitude: merchant.location.latitude,
          longitude: merchant.location.longitude,
        ),
    ],
    {for (var i = 0; i < merchants.length; i++) merchants[i].id: i},
  );

  /// Prepare a margin around the viewport, so small pans reuse native pins.
  Future<({GeoBounds bounds, String json})> render(GeoBounds viewport) {
    final width = _width(viewport);
    final height = viewport.north - viewport.south;
    final bounds = GeoBounds(
      south: viewport.south - height / 2,
      north: viewport.north + height / 2,
      west: viewport.west - width / 2,
      east: viewport.west + width * 1.5,
    );
    final points = _points;
    return Isolate.run(
      () => (
        bounds: bounds,
        json: jsonEncode({
          'type': 'FeatureCollection',
          'features': [
            for (final point in points)
              if (bounds.contains(
                GeoPoint(latitude: point.latitude, longitude: point.longitude),
              ))
                {
                  'type': 'Feature',
                  'id': point.id,
                  'properties': {'merchantId': point.id},
                  'geometry': {
                    'type': 'Point',
                    'coordinates': [point.longitude, point.latitude],
                  },
                },
          ],
        }),
      ),
    );
  }

  /// A zoom into a much smaller area must drop the old world's pins, even
  /// though those old bounds contain the new view. Reuse is for small pans.
  static bool canReuse(GeoBounds loaded, GeoBounds viewport) =>
      covers(loaded, viewport) &&
      _width(loaded) <= _width(viewport) * 4 &&
      loaded.north - loaded.south <= (viewport.north - viewport.south) * 4;

  static bool covers(GeoBounds loaded, GeoBounds viewport) {
    if (loaded.south > viewport.south || loaded.north < viewport.north) {
      return false;
    }
    final width = _width(loaded);
    if (width >= 360) return true;
    final offset = (viewport.west - loaded.west + 360) % 360;
    return offset + _width(viewport) <= width;
  }

  static double _width(GeoBounds bounds) => bounds.crossesAntimeridian
      ? bounds.east + 360 - bounds.west
      : bounds.east - bounds.west;
}
