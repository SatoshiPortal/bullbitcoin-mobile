import 'package:btc_map/src/domain/entities/geo_point.dart';
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
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
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
