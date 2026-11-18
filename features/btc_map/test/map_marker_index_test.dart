import 'dart:convert';

import 'package:btc_map/src/domain/entities/geo_bounds.dart';
import 'package:btc_map/src/domain/entities/geo_point.dart';
import 'package:btc_map/src/domain/entities/merchant.dart';
import 'package:btc_map/src/ui/map_marker_index.dart';
import 'package:flutter_test/flutter_test.dart';

Merchant point(int id, double latitude, double longitude) => Merchant(
  id: id,
  location: GeoPoint(latitude: latitude, longitude: longitude),
);

void main() {
  test(
    'renders only the viewport and its margin, preserving pin ids',
    () async {
      final index = await MapMarkerIndex.forMerchants([
        point(1, 10, 20),
        point(2, 11.5, 20),
        point(3, 40, 20),
      ]);
      final rendered = await index.render(
        GeoBounds(south: 9, west: 19, north: 11, east: 21),
      );
      final features = jsonDecode(rendered.json)['features'] as List;
      expect(features.map((dynamic f) => f['id']), [1, 2]);
      expect(index.positions, {1: 0, 2: 1, 3: 2});
      expect(features.first['geometry']['coordinates'], [20, 10]);
      expect(
        MapMarkerIndex.covers(
          rendered.bounds,
          GeoBounds(south: 9.1, west: 19.1, north: 11.1, east: 21.1),
        ),
        isTrue,
      );
      expect(
        MapMarkerIndex.covers(
          rendered.bounds,
          GeoBounds(south: 9, west: 30, north: 11, east: 32),
        ),
        isFalse,
      );
    },
  );

  test(
    'retains both sides of the antimeridian and excludes the middle',
    () async {
      final index = await MapMarkerIndex.forMerchants([
        point(1, 0, 179),
        point(2, 0, -179),
        point(3, 0, 0),
      ]);
      final rendered = await index.render(
        GeoBounds(south: -1, west: 178, north: 1, east: -178),
      );
      final features = jsonDecode(rendered.json)['features'] as List;
      expect(features.map((dynamic f) => f['id']), [1, 2]);
      expect(
        MapMarkerIndex.covers(
          rendered.bounds,
          GeoBounds(south: -1, west: 179, north: 1, east: -177),
        ),
        isTrue,
      );
      expect(
        MapMarkerIndex.covers(
          rendered.bounds,
          GeoBounds(south: -1, west: -170, north: 1, east: 170),
        ),
        isFalse,
      );
    },
  );

  test('world bounds include the poles and every longitude', () async {
    final index = await MapMarkerIndex.forMerchants([
      point(1, 90, 180),
      point(2, -90, -180),
      point(3, 0, 0),
    ]);
    final world = GeoBounds(south: -90, west: -180, north: 90, east: 180);
    final rendered = await index.render(world);
    expect(jsonDecode(rendered.json)['features'], hasLength(3));
    expect(MapMarkerIndex.covers(rendered.bounds, world), isTrue);
    expect(
      MapMarkerIndex.canReuse(
        rendered.bounds,
        GeoBounds(south: -1, west: -1, north: 1, east: 1),
      ),
      isFalse,
    );
  });

  test('reuses one preparation until the merchant list changes', () async {
    final merchants = [point(1, 10, 20)];
    final first = MapMarkerIndex.forMerchants(merchants);
    expect(identical(first, MapMarkerIndex.forMerchants(merchants)), isTrue);
    expect(
      identical(
        await first,
        await MapMarkerIndex.forMerchants([point(2, 10, 20)]),
      ),
      isFalse,
    );
  });
}
