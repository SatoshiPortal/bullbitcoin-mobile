import '../../domain/entities/geo_point.dart';

class IpLocationModel {
  final bool success;
  final double? latitude;
  final double? longitude;

  const IpLocationModel(this.success, this.latitude, this.longitude);

  factory IpLocationModel.fromJson(Object? json) => switch (json) {
    {'success': true, 'latitude': num lat, 'longitude': num lon} =>
      IpLocationModel(true, lat.toDouble(), lon.toDouble()),
    _ => const IpLocationModel(false, null, null),
  };
}

extension IpLocationMapper on IpLocationModel {
  GeoPoint? toDomain() {
    final lat = latitude;
    final lon = longitude;
    if (!success ||
        lat == null ||
        lon == null ||
        !GeoPoint.isValid(latitude: lat, longitude: lon)) {
      return null;
    }
    return GeoPoint(latitude: lat, longitude: lon);
  }
}
