import 'package:btc_map/src/map_types.dart';
import 'package:flutter_test/flutter_test.dart';

GeoPoint _point(double latitude, double longitude) =>
    GeoPoint(latitude: latitude, longitude: longitude);

void main() {
  test('contains points inside, edges included', () {
    final bounds = GeoBounds(south: 10, west: 20, north: 30, east: 40);
    expect(bounds.contains(_point(20, 30)), isTrue);
    expect(bounds.contains(_point(10, 20)), isTrue);
    expect(bounds.contains(_point(9.9, 30)), isFalse);
    expect(bounds.contains(_point(20, 41)), isFalse);
    expect(bounds.center, _point(20, 30));
  });

  test('handles an area across the antimeridian', () {
    // What the map reports when panned over the Pacific: east past 180.
    final bounds = GeoBounds(south: -10, west: 170, north: 10, east: 190);
    expect(bounds.crossesAntimeridian, isTrue);
    expect(bounds.contains(_point(0, 175)), isTrue);
    expect(bounds.contains(_point(0, -175)), isTrue);
    expect(bounds.contains(_point(0, 0)), isFalse);
    expect(bounds.center, _point(0, 180));
  });

  test('a view wider than the world covers every longitude', () {
    final bounds = GeoBounds(south: -95, west: -400, north: 95, east: 400);
    expect(bounds.contains(_point(0, 0)), isTrue);
    expect(bounds.contains(_point(89, 179)), isTrue);
    expect(bounds.contains(_point(-89, -179)), isTrue);
  });

  test('rejects an inverted or non-finite area', () {
    expect(
      () => GeoBounds(south: 10, west: 0, north: 0, east: 1),
      throwsArgumentError,
    );
    expect(
      () => GeoBounds(south: 0, west: double.nan, north: 1, east: 1),
      throwsArgumentError,
    );
  });

  test('distance between points is the great-circle one', () {
    // One degree of latitude is about 111.2 km.
    expect(_point(0, 0).distanceTo(_point(1, 0)), closeTo(111195, 10));
    expect(_point(45, 10).distanceTo(_point(45, 10)), 0);
  });
}
