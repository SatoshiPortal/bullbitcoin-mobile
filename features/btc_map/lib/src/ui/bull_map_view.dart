import 'dart:async';
import 'dart:math' show Point;

import 'package:bull_logger/bull_logger.dart';
import 'package:btc_map/src/domain/entities/geo_bounds.dart';
import 'package:btc_map/src/domain/entities/geo_point.dart';
import 'package:btc_map/src/domain/entities/merchant.dart';
import 'package:bull_ui/bull_ui.dart';
import 'package:flutter/services.dart' show PlatformException;
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:material_ui/material_ui.dart';

class BullMapController {
  _BullMapViewState? _view;

  Future<void> focus(GeoPoint location) async => _view?._focus(location);
}

class BullMapView extends StatefulWidget {
  const BullMapView({
    super.key,
    required this.merchants,
    required this.controller,
    required this.onMerchantTap,
    required this.onViewportChanged,
    this.initialCenter,
  });

  final List<Merchant> merchants;
  final BullMapController controller;

  /// Used once, unless the user has already touched the map or picked a place.
  final GeoPoint? initialCenter;

  final ValueChanged<Merchant> onMerchantTap;

  /// Called with what the map shows each time the camera comes to rest.
  final ValueChanged<GeoBounds> onViewportChanged;

  @override
  State<BullMapView> createState() => _BullMapViewState();
}

class _BullMapViewState extends State<BullMapView> {
  /// OpenFreeMap vector styles, the ones btcmap.org itself uses, so the map
  /// looks the way users already know it. OpenFreeMap serves the tiles and
  /// sees which areas are loaded; BTC Map only sees the bulk merchant sync.
  static const _lightStyleUrl = 'https://tiles.openfreemap.org/styles/liberty';
  static const _darkStyleUrl = 'https://tiles.openfreemap.org/styles/dark';

  static const _sourceId = 'merchants';
  static const _clusterLayerId = 'merchant-clusters';
  static const _clusterCountLayerId = 'merchant-cluster-counts';
  static const _merchantLayerId = 'merchant-points';
  static const _merchantIdProperty = 'merchantId';

  /// Fonts the OpenFreeMap styles' glyph server provides.
  static const _labelFont = ['Noto Sans Regular'];

  /// Taps are this many logical pixels wide, so a 7 px dot is easy to hit.
  static const _tapTolerance = 32.0;
  static const _merchantZoom = 17.0;
  // IP geolocation identifies an approximate region, not a precise position.
  static const _regionZoom = 10.0;

  static const _initialCamera = CameraPosition(
    target: LatLng(20, 0),
    zoom: 1.5,
  );

  MapLibreMapController? _map;

  /// [BullMapView.merchants] by id, for resolving a tapped pin. Rebuilt only
  /// when the list itself changes.
  late Map<int, Merchant> _byId = _index(widget.merchants);

  /// The style the merchant layers were added to. A theme change swaps the
  /// style, which drops every runtime layer, so they are added again once the
  /// new style has loaded.
  bool _layersReady = false;

  /// The style the map was last given, to notice a theme change.
  String? _styleUrl;
  bool _initialCenterConsumed = false;

  @override
  void initState() {
    super.initState();
    widget.controller._view = this;
  }

  @override
  void didUpdateWidget(BullMapView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller._view = null;
      widget.controller._view = this;
    }
    if (!identical(oldWidget.merchants, widget.merchants)) {
      _byId = _index(widget.merchants);
      if (_layersReady) unawaited(_updateMerchants());
    }
    unawaited(_centerInitially());
  }

  @override
  void dispose() {
    if (widget.controller._view == this) widget.controller._view = null;
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final styleUrl = _styleUrlFor(context);
    // A theme change swaps the style, dropping every runtime layer: until
    // _onStyleLoaded adds them again, merchant updates must wait.
    if (_styleUrl != null && _styleUrl != styleUrl) _layersReady = false;
    _styleUrl = styleUrl;
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.opaque,
      onPointerDown: (_) => _initialCenterConsumed = true,
      child: MapLibreMap(
        // A theme change swaps the style in place; _onStyleLoaded then adds the
        // merchant layers again, in the new theme's colours.
        styleString: _styleUrlFor(context),
        initialCameraPosition: _initialCamera,
        onMapCreated: (controller) {
          _map = controller;
          unawaited(_centerInitially());
        },
        onStyleLoadedCallback: _onStyleLoaded,
        onMapClick: _onMapClick,
        onCameraIdle: _onCameraIdle,
        // No device location or GPS is requested, even when IP centering succeeds.
        myLocationEnabled: false,
        tiltGesturesEnabled: false,
        // OpenStreetMap's licence requires the attribution to stay visible. Both
        // native SDKs show it by default; it moves to the top because the bottom
        // of the map is under the merchant list.
        attributionButtonPosition: AttributionButtonPosition.topRight,
        attributionButtonColor: context.bull.onSurface,
      ),
    );
  }

  Future<void> _centerInitially() async {
    final map = _map;
    final center = widget.initialCenter;
    if (!mounted || _initialCenterConsumed || map == null || center == null) {
      return;
    }
    _initialCenterConsumed = true;
    try {
      await map.moveCamera(
        CameraUpdate.newLatLngZoom(
          LatLng(center.latitude, center.longitude),
          _regionZoom,
        ),
      );
    } on PlatformException {
      // Best effort, like the IP lookup itself: leave the current view alone.
    }
  }

  Future<void> _onStyleLoaded() async {
    final map = _map;
    if (map == null || !mounted) return;
    _layersReady = false;
    final colors = context.bull;
    final shown = widget.merchants;
    try {
      await map.addSource(
        _sourceId,
        GeojsonSourceProperties(
          data: _featureCollection(shown),
          cluster: true,
          clusterRadius: 50,
          clusterMaxZoom: 14,
        ),
      );
      await map.addCircleLayer(
        _sourceId,
        _clusterLayerId,
        CircleLayerProperties(
          circleColor: _hex(colors.primary),
          circleRadius: const [
            'step',
            ['get', 'point_count'],
            16,
            100,
            20,
            1000,
            26,
          ],
          circleStrokeWidth: 2,
          circleStrokeColor: _hex(colors.background),
        ),
        filter: const ['has', 'point_count'],
        enableInteraction: false,
      );
      await map.addSymbolLayer(
        _sourceId,
        _clusterCountLayerId,
        SymbolLayerProperties(
          textField: const ['get', 'point_count_abbreviated'],
          textFont: _labelFont,
          textSize: 12,
          textColor: _hex(colors.onPrimary),
          textAllowOverlap: true,
          textIgnorePlacement: true,
        ),
        filter: const ['has', 'point_count'],
        enableInteraction: false,
      );
      await map.addCircleLayer(
        _sourceId,
        _merchantLayerId,
        CircleLayerProperties(
          circleColor: _hex(colors.primary),
          circleRadius: 7,
          circleStrokeWidth: 2,
          circleStrokeColor: _hex(colors.background),
        ),
        filter: const [
          '!',
          ['has', 'point_count'],
        ],
        enableInteraction: false,
      );
      if (!mounted) return;
      _layersReady = true;
      // The list needs the first viewport even if the camera never moves.
      unawaited(_onCameraIdle());
      // Merchants that arrived while the layers were being added.
      if (mounted && !identical(shown, widget.merchants)) {
        await _updateMerchants();
      }
    } on PlatformException catch (error) {
      log.warning('Merchant map layers not added: ${error.code}');
    }
  }

  Future<void> _onCameraIdle() async {
    final map = _map;
    if (map == null) return;
    final LatLngBounds region;
    try {
      region = await map.getVisibleRegion();
    } on PlatformException catch (error) {
      log.info('Merchant map region not read: ${error.code}');
      return;
    }
    if (!mounted) return;
    final GeoBounds bounds;
    try {
      bounds = GeoBounds(
        south: region.southwest.latitude,
        west: region.southwest.longitude,
        north: region.northeast.latitude,
        east: region.northeast.longitude,
      );
    } on ArgumentError {
      // A degenerate region while the view is still being laid out.
      return;
    }
    widget.onViewportChanged(bounds);
  }

  Future<void> _updateMerchants() async {
    final map = _map;
    if (map == null) return;
    try {
      await map.setGeoJsonSource(
        _sourceId,
        _featureCollection(widget.merchants),
      );
    } on PlatformException catch (error) {
      log.warning('Merchant map source not updated: ${error.code}');
    }
  }

  Future<void> _onMapClick(Point<double> point, LatLng _) async {
    final map = _map;
    if (map == null || !_layersReady) return;
    // MapLibre on Android reports the tap, and reads the query rectangle, in
    // physical pixels; iOS uses points. The tolerance is in logical pixels.
    final tolerance = Theme.of(context).platform == TargetPlatform.android
        ? _tapTolerance * MediaQuery.devicePixelRatioOf(context)
        : _tapTolerance;
    final List<Object?> features;
    try {
      features = await map.queryRenderedFeaturesInRect(
        Rect.fromCenter(
          center: Offset(point.x, point.y),
          width: tolerance,
          height: tolerance,
        ),
        const [_clusterLayerId, _merchantLayerId],
        null,
      );
    } on PlatformException catch (error) {
      log.warning('Merchant map tap query failed: ${error.code}');
      return;
    }

    for (final feature in features) {
      if (feature is! Map) continue;
      final properties = feature['properties'];
      if (properties is! Map) continue;
      final clusterId = properties['cluster_id'];
      if (clusterId is num) {
        await _expandCluster(clusterId.toInt(), _coordinatesOf(feature));
        return;
      }
      final merchantId = properties[_merchantIdProperty];
      if (merchantId is! num) continue;
      if (_byId[merchantId.toInt()] case final merchant?) {
        widget.onMerchantTap(merchant);
      }
      return;
    }
  }

  Future<void> _expandCluster(int clusterId, LatLng? centre) async {
    final map = _map;
    if (map == null || centre == null) return;
    try {
      final zoom = await map.getClusterExpansionZoom(_sourceId, clusterId);
      await map.animateCamera(
        CameraUpdate.newLatLngZoom(centre, zoom.toDouble() + 0.5),
      );
    } on PlatformException catch (error) {
      // Cluster ids change with the viewport; a stale one just does nothing.
      log.info('Merchant cluster not expanded: ${error.code}');
    }
  }

  Future<void> _focus(GeoPoint location) async {
    _initialCenterConsumed = true;
    try {
      await _map?.animateCamera(
        CameraUpdate.newLatLngZoom(
          LatLng(location.latitude, location.longitude),
          _merchantZoom,
        ),
      );
    } on PlatformException catch (error) {
      // The caller goes on (opening the place's details) either way.
      log.warning('Merchant map camera not moved: ${error.code}');
    }
  }

  static String _styleUrlFor(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
      ? _darkStyleUrl
      : _lightStyleUrl;

  static Map<int, Merchant> _index(List<Merchant> merchants) => {
    for (final merchant in merchants) merchant.id: merchant,
  };

  static LatLng? _coordinatesOf(Map<Object?, Object?> feature) {
    final geometry = feature['geometry'];
    if (geometry is! Map) return null;
    final coordinates = geometry['coordinates'];
    if (coordinates is! List || coordinates.length < 2) return null;
    final [longitude, latitude, ...] = coordinates;
    if (latitude is! num || longitude is! num) return null;
    return LatLng(latitude.toDouble(), longitude.toDouble());
  }

  static Map<String, Object> _featureCollection(List<Merchant> merchants) => {
    'type': 'FeatureCollection',
    'features': [
      for (final merchant in merchants)
        {
          'type': 'Feature',
          'id': merchant.id,
          'properties': {_merchantIdProperty: merchant.id},
          'geometry': {
            'type': 'Point',
            'coordinates': [
              merchant.location.longitude,
              merchant.location.latitude,
            ],
          },
        },
    ],
  };

  /// MapLibre style colours are CSS strings; these come from the theme.
  static String _hex(Color color) =>
      '#${(color.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}';
}
