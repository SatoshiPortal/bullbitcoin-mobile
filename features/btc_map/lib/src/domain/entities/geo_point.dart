import 'dart:math' as math;

import 'package:meta/meta.dart';

/// A WGS84 coordinate. Rejects anything a map camera cannot take: a
/// non-finite or out-of-range value poisons the native camera.
@immutable
final class GeoPoint {
  final double latitude;
  final double longitude;

  GeoPoint({required this.latitude, required this.longitude}) {
    if (!isValid(latitude: latitude, longitude: longitude)) {
      throw ArgumentError('Invalid coordinate ($latitude, $longitude)');
    }
  }

  static bool isValid({required double latitude, required double longitude}) =>
      latitude.isFinite &&
      longitude.isFinite &&
      latitude >= -90 &&
      latitude <= 90 &&
      longitude >= -180 &&
      longitude <= 180;

  /// Great-circle distance to [other] in metres (haversine, spherical Earth).
  double distanceTo(GeoPoint other) {
    const earthRadiusMetres = 6371008.8;
    double radians(double degrees) => degrees * math.pi / 180;
    final dLatitude = radians(other.latitude - latitude);
    final dLongitude = radians(other.longitude - longitude);
    final a =
        math.pow(math.sin(dLatitude / 2), 2) +
        math.cos(radians(latitude)) *
            math.cos(radians(other.latitude)) *
            math.pow(math.sin(dLongitude / 2), 2);
    return 2 * earthRadiusMetres * math.asin(math.min(1, math.sqrt(a)));
  }

  @override
  bool operator ==(Object other) =>
      other is GeoPoint &&
      other.latitude == latitude &&
      other.longitude == longitude;

  @override
  int get hashCode => Object.hash(latitude, longitude);
}
