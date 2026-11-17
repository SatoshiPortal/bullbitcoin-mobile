import '../../domain/entities/geo_point.dart';

class IpLocationModel {
  final double? latitude;
  final double? longitude;

  const IpLocationModel(this.latitude, this.longitude);

  /// BTC Map's map page exposes Netlify's approximate connection location in
  /// Svelte's data table. This optional website response is not a stable API:
  /// an unsupported shape deliberately leaves the map at its default view.
  factory IpLocationModel.fromJson(Object? json) {
    if (json case {'type': 'data', 'nodes': final List nodes}) {
      for (final node in nodes) {
        if (node case {'type': 'data', 'data': final List table}
            when table.isNotEmpty) {
          final root = table.first;
          if (root is! Map) continue;
          final geo = _at(table, root['geo']);
          if (geo is! Map) continue;
          final latitude = _at(table, geo['lat']);
          final longitude = _at(table, geo['lng']);
          if (latitude is num && longitude is num) {
            return IpLocationModel(latitude.toDouble(), longitude.toDouble());
          }
        }
      }
    }
    return const IpLocationModel(null, null);
  }

  static Object? _at(List<Object?> table, Object? reference) =>
      reference is int && reference >= 0 && reference < table.length
      ? table[reference]
      : null;
}

extension IpLocationMapper on IpLocationModel {
  GeoPoint? toDomain() {
    final lat = latitude;
    final lon = longitude;
    if (lat == null ||
        lon == null ||
        !GeoPoint.isValid(latitude: lat, longitude: lon)) {
      return null;
    }
    return GeoPoint(latitude: lat, longitude: lon);
  }
}
