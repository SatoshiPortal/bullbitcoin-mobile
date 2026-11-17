import 'dart:convert';

import 'package:btc_map/src/domain/entities/geo_point.dart';
import 'package:btc_map/src/domain/entities/merchant.dart';
import 'package:btc_map/src/ui/bull_map_view.dart';
import 'package:bull_ui/testing.dart';
import 'package:flutter/foundation.dart' show Factory;
import 'package:flutter/gestures.dart' show OneSequenceGestureRecognizer;
import 'package:flutter_test/flutter_test.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:material_ui/material_ui.dart';

class _MapPlatform extends MapLibrePlatform {
  final moves = <Object>[];
  final focuses = <Object>[];
  final sources = <SourceProperties>[];
  final jsonUpdates = <String>[];
  OnPlatformViewCreatedCallback? created;

  @override
  Future<void> initPlatform(int id) async {}

  @override
  Widget buildView(
    Map<String, dynamic> creationParams,
    OnPlatformViewCreatedCallback onPlatformViewCreated,
    Set<Factory<OneSequenceGestureRecognizer>>? gestureRecognizers,
  ) {
    created = onPlatformViewCreated;
    return const SizedBox.expand();
  }

  @override
  Future<CameraPosition?> updateMapOptions(
    Map<String, dynamic> optionsUpdate,
  ) async => null;

  @override
  Future<bool?> moveCamera(CameraUpdate cameraUpdate) async {
    moves.add(cameraUpdate.toJson());
    return true;
  }

  @override
  Future<bool?> animateCamera(
    CameraUpdate cameraUpdate, {
    Duration? duration,
  }) async {
    focuses.add(cameraUpdate.toJson());
    return true;
  }

  @override
  Future<void> addSource(String id, SourceProperties properties) async {
    sources.add(properties);
  }

  @override
  Future<bool> editGeoJsonSource(String id, String data) async {
    jsonUpdates.add(data);
    return true;
  }

  @override
  Future<LatLngBounds> getVisibleRegion() async => LatLngBounds(
    southwest: const LatLng(-1, -1),
    northeast: const LatLng(1, 1),
  );

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      invocation.memberName == #addCircleLayer ||
          invocation.memberName == #addSymbolLayer
      ? Future<void>.value()
      : throw UnimplementedError('${invocation.memberName}');
}

void main() {
  late _MapPlatform platform;
  late BullMapController controller;
  final region = GeoPoint(latitude: 45.5, longitude: -73.6);

  setUp(() {
    platform = _MapPlatform();
    controller = BullMapController();
    final previous = MapLibrePlatform.createInstance;
    MapLibrePlatform.createInstance = () => platform;
    addTearDown(() => MapLibrePlatform.createInstance = previous);
  });

  Future<void> pump(WidgetTester tester, GeoPoint? center) => tester.pumpWidget(
    wrapWithTheme(
      BullMapView(
        merchants: const [],
        controller: controller,
        initialCenter: center,
        onMerchantTap: (_) {},
        onViewportChanged: (_) {},
      ),
    ),
  );

  testWidgets('loads merchant data through the native JSON path', (
    tester,
  ) async {
    final merchants = [Merchant(id: 7, location: region, name: 'Shop')];
    Future<void> show(List<Merchant> places) => tester.pumpWidget(
      wrapWithTheme(
        BullMapView(
          merchants: places,
          controller: controller,
          onMerchantTap: (_) {},
          onViewportChanged: (_) {},
        ),
      ),
    );
    await show(merchants);
    platform.created?.call(0);
    await tester.pump();
    tester
        .widget<MapLibreMap>(find.byType(MapLibreMap))
        .onStyleLoadedCallback
        ?.call();
    await tester.pump();
    final source = platform.sources.single as GeojsonSourceProperties;
    expect((source.data as Map)['features'], isEmpty);
    expect(source.cluster, isTrue);
    expect(jsonDecode(platform.jsonUpdates.single)['features'], [
      {
        'type': 'Feature',
        'id': 7,
        'properties': {'merchantId': 7},
        'geometry': {
          'type': 'Point',
          'coordinates': [-73.6, 45.5],
        },
      },
    ]);
    await show(const []);
    await tester.pump();
    expect(jsonDecode(platform.jsonUpdates.last)['features'], isEmpty);
    expect(platform.jsonUpdates, hasLength(2));
  });

  testWidgets('centers once when the location arrives after the native map', (
    tester,
  ) async {
    await pump(tester, null);
    platform.created?.call(0);
    await tester.pump();
    expect(platform.moves, isEmpty);
    await pump(tester, region);
    await pump(tester, region);
    expect(platform.moves, [
      [
        'newLatLngZoom',
        [45.5, -73.6],
        10.0,
      ],
    ]);
  });

  testWidgets('also centers when the location arrives before the native map', (
    tester,
  ) async {
    await pump(tester, region);
    expect(platform.moves, isEmpty);
    platform.created?.call(0);
    await tester.pump();
    expect(platform.moves, hasLength(1));
  });

  testWidgets('a touch prevents a late location from changing the camera', (
    tester,
  ) async {
    await pump(tester, null);
    platform.created?.call(0);
    await tester.pump();
    await tester.tap(find.byType(BullMapView));
    await pump(tester, region);
    expect(platform.moves, isEmpty);
  });

  testWidgets('selecting a merchant takes precedence over a late location', (
    tester,
  ) async {
    await pump(tester, null);
    platform.created?.call(0);
    await tester.pump();
    await controller.focus(GeoPoint(latitude: 1, longitude: 2));
    await pump(tester, region);
    expect(platform.focuses, hasLength(1));
    expect(platform.moves, isEmpty);
  });
}
