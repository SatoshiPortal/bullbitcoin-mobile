import 'dart:async';

import 'package:btc_map/src/domain/usecases/load_cached_merchants_usecase.dart';
import 'package:btc_map/src/domain/usecases/sync_merchants_usecase.dart';
import 'package:btc_map/src/presentation/map_state.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:primitives/primitives.dart';

import '../domain/entities/geo_bounds.dart';
import '../domain/entities/merchant.dart';
import '../domain/usecases/get_initial_map_center_usecase.dart';
import '../domain/usecases/select_merchants_usecase.dart';

class MapCubit extends Cubit<MapState> {
  final LoadCachedMerchantsUsecase _loadCached;
  final SyncMerchantsUsecase _sync;
  final SelectMerchantsUsecase _select;
  final GetInitialMapCenterUsecase? _initialCenter;
  bool _didLocate = false;

  MapCubit(
    this._loadCached,
    this._sync, [
    this._select = const SelectMerchantsUsecase(),
    this._initialCenter,
  ]) : super(const MapState());

  /// Shows the device copy at once, then brings it up to date.
  Future<void> start() async {
    final initialCenter = _initialCenter;
    if (!_didLocate && initialCenter != null) {
      _didLocate = true;
      unawaited(_locate(initialCenter));
    }
    if (await _loadCached.execute() case Ok(value: final merchants)) {
      if (isClosed) return;
      _emitMerchants(merchants);
    }
    await refresh();
  }

  Future<void> _locate(GetInitialMapCenterUsecase initialCenter) async {
    final result = await initialCenter.execute();
    if (isClosed) return;
    if (result case Ok(value: final point)) {
      emit(state.copyWith(initialCenter: point));
    }
    // An unavailable location never changes merchant loading or error state.
  }

  Future<void> refresh() async {
    if (state.isSyncing || isClosed) return;
    emit(state.copyWith(isSyncing: true));
    final result = await _sync.execute();
    if (isClosed) return;
    switch (result) {
      case Ok(value: final merchants):
        _emitMerchants(merchants, isSyncing: false, clearFailure: true);
      case Err(failure: final failure):
        emit(state.copyWith(isSyncing: false, failure: failure));
    }
  }

  /// The map stopped moving and now shows [viewport].
  void viewportChanged(GeoBounds viewport) {
    if (viewport == state.viewport) return;
    _emitListing(state.copyWith(viewport: viewport));
  }

  void search(String query) {
    if (query == state.query) return;
    _emitListing(state.copyWith(query: query));
  }

  /// Null shows every category again.
  void selectCategory(MerchantCategory? category) {
    if (category == state.category) return;
    _emitListing(state.copyWith(category: category), rebuildPins: true);
  }

  void _emitMerchants(
    List<Merchant> merchants, {
    bool? isSyncing,
    bool clearFailure = false,
  }) => _emitListing(
    state.copyWith(
      merchants: merchants,
      isSyncing: isSyncing ?? state.isSyncing,
      failure: clearFailure ? null : state.failure,
    ),
    rebuildPins: !identical(merchants, state.merchants),
  );

  void _emitListing(MapState next, {bool rebuildPins = false}) {
    final selection = _select.execute(
      next.merchants,
      viewport: next.viewport,
      query: next.query,
      category: next.category,
      unchangedPins: rebuildPins ? null : next.mapMerchants,
    );
    emit(
      next.copyWith(mapMerchants: selection.pins, listing: selection.listing),
    );
  }
}
