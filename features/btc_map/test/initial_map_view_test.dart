import 'dart:async';
import 'dart:convert';

import 'package:btc_map/src/domain/entities/geo_point.dart';
import 'package:btc_map/src/domain/entities/merchant.dart';
import 'package:btc_map/src/ui/bull_map_view.dart';
import 'package:bull_ui/testing.dart';
import 'package:flutter/foundation.dart' show Factory;
import 'package:flutter/gestures.dart' show OneSequenceGestureRecognizer;
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart' show PlatformException;
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:material_ui/material_ui.dart';

class _MapPlatform extends MapLibrePlatform {
  final moves = <Object>[];
  final focuses = <Object>[];
  final sources = <SourceProperties>[];
  final jsonUpdates = <String>[];
  Completer<void> updated = Completer<void>();
  OnPlatformViewCreatedCallback? created;
  Completer<void>? holdUpdate;
  Completer<void>? holdSource;
  bool failHeldUpdate = false;
  int layers = 0;
  LatLngBounds visible = LatLngBounds(
    southwest: const LatLng(44, -75),
    northeast: const LatLng(47, -72),
  );

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
    final hold = holdSource;
    if (hold != null) await hold.future;
  }

  @override
  Future<bool> editGeoJsonSource(String id, String data) async {
    jsonUpdates.add(data);
    if (!updated.isCompleted) updated.complete();
    final hold = holdUpdate;
    if (hold != null) {
      await hold.future;
      if (failHeldUpdate) throw PlatformException(code: 'old-source');
    }
    return true;
  }

  @override
  Future<LatLngBounds> getVisibleRegion() async => visible;

  @override
  dynamic noSuchMethod(Invocation invocation) {
    if (invocation.memberName == #addCircleLayer ||
        invocation.memberName == #addSymbolLayer) {
      layers++;
      return Future<void>.value();
    }
    throw UnimplementedError('${invocation.memberName}');
  }
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

  Future<void> waitForPins(WidgetTester tester) async {
    final deadline = DateTime.now().add(const Duration(seconds: 5));
    while (!platform.updated.isCompleted && DateTime.now().isBefore(deadline)) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 10)),
      );
      await tester.pump();
    }
    expect(platform.updated.isCompleted, isTrue, reason: 'native pins updated');
  }

  testWidgets('loads merchant data through the native JSON path', (
    tester,
  ) async {
    final merchants = [
      Merchant(id: 7, location: region, name: 'Shop'),
      Merchant(id: 8, location: GeoPoint(latitude: 0, longitude: 0)),
    ];
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
    await waitForPins(tester);
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
    final regional = platform.visible;
    for (final bounds in [
      LatLngBounds(
        southwest: const LatLng(-90, -179),
        northeast: const LatLng(90, 179),
      ),
      regional,
    ]) {
      platform.visible = bounds;
      platform.updated = Completer<void>();
      tester.widget<MapLibreMap>(find.byType(MapLibreMap)).onCameraIdle?.call();
      await waitForPins(tester);
    }
    expect(jsonDecode(platform.jsonUpdates[1])['features'], hasLength(2));
    expect(jsonDecode(platform.jsonUpdates[2])['features'], hasLength(1));
    platform.updated = Completer<void>();
    await show(const []);
    await waitForPins(tester);
    expect(jsonDecode(platform.jsonUpdates.last)['features'], isEmpty);
    expect(platform.jsonUpdates, hasLength(4));
  });

  for (final fails in [false, true]) {
    testWidgets(
      'latest merchants survive an in-flight update (failure: $fails)',
      (tester) async {
        platform.failHeldUpdate = fails;
        final hold = Completer<void>();
        platform.holdUpdate = hold;
        Future<void> show(int id) => tester.pumpWidget(
          wrapWithTheme(
            BullMapView(
              merchants: [Merchant(id: id, location: region)],
              controller: controller,
              onMerchantTap: (_) {},
              onViewportChanged: (_) {},
            ),
          ),
        );
        await show(1);
        platform.created?.call(0);
        await tester.pump();
        tester
            .widget<MapLibreMap>(find.byType(MapLibreMap))
            .onStyleLoadedCallback
            ?.call();
        await waitForPins(tester);
        await show(2);
        platform.updated = Completer<void>();
        platform.holdUpdate = null;
        hold.complete();
        await waitForPins(tester);
        expect(
          jsonDecode(platform.jsonUpdates.last)['features'].single['id'],
          2,
        );
      },
    );
  }

  // Android rebuilds the native MapView when the activity is recreated, keeps the Dart widget, drops every runtime source and layer, and fires the style callback once more for the same style.
  testWidgets('pins are uploaded again when the same style loads again', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrapWithTheme(
        BullMapView(
          merchants: [Merchant(id: 1, location: region)],
          controller: controller,
          onMerchantTap: (_) {},
          onViewportChanged: (_) {},
        ),
      ),
    );
    platform.created?.call(0);
    await tester.pump();
    tester
        .widget<MapLibreMap>(find.byType(MapLibreMap))
        .onStyleLoadedCallback
        ?.call();
    await waitForPins(tester);
    platform.updated = Completer<void>();
    tester
        .widget<MapLibreMap>(find.byType(MapLibreMap))
        .onStyleLoadedCallback
        ?.call();
    await waitForPins(tester);
    expect(platform.sources, hasLength(2));
    expect(platform.jsonUpdates, hasLength(2));
    expect(jsonDecode(platform.jsonUpdates.last)['features'].single['id'], 1);
  });

  testWidgets('an upload outlived by a style reload does not stand in for it', (
    tester,
  ) async {
    final hold = Completer<void>();
    platform.holdUpdate = hold;
    await tester.pumpWidget(
      wrapWithTheme(
        BullMapView(
          merchants: [Merchant(id: 1, location: region)],
          controller: controller,
          onMerchantTap: (_) {},
          onViewportChanged: (_) {},
        ),
      ),
    );
    platform.created?.call(0);
    await tester.pump();
    tester
        .widget<MapLibreMap>(find.byType(MapLibreMap))
        .onStyleLoadedCallback
        ?.call();
    await waitForPins(tester);
    // The style reloads while the first upload is still in flight.
    platform.updated = Completer<void>();
    platform.holdUpdate = null;
    tester
        .widget<MapLibreMap>(find.byType(MapLibreMap))
        .onStyleLoadedCallback
        ?.call();
    await tester.pump();
    expect(platform.sources, hasLength(2));
    expect(platform.layers, 6);
    expect(platform.jsonUpdates, hasLength(1));
    hold.complete();
    await waitForPins(tester);
    expect(platform.jsonUpdates, hasLength(2));
    expect(jsonDecode(platform.jsonUpdates.last)['features'].single['id'], 1);
  });

  testWidgets('an obsolete style cannot add layers after a theme change', (
    tester,
  ) async {
    final hold = Completer<void>();
    platform.holdSource = hold;
    Future<void> show(Brightness brightness) => tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(
          brightness: brightness,
          extensions: testBullExtensions,
        ),
        home: Scaffold(
          body: BullMapView(
            merchants: const [],
            controller: controller,
            onMerchantTap: (_) {},
            onViewportChanged: (_) {},
          ),
        ),
      ),
    );
    await show(Brightness.light);
    platform.created?.call(0);
    await tester.pump();
    tester
        .widget<MapLibreMap>(find.byType(MapLibreMap))
        .onStyleLoadedCallback
        ?.call();
    await tester.pump();
    expect(platform.sources, hasLength(1));
    await show(Brightness.dark);
    await tester.pump(const Duration(milliseconds: 300));
    platform.holdSource = null;
    hold.complete();
    await tester.pump();
    expect(platform.layers, 0);
    tester
        .widget<MapLibreMap>(find.byType(MapLibreMap))
        .onStyleLoadedCallback
        ?.call();
    await waitForPins(tester);
    expect(platform.layers, 3);
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
