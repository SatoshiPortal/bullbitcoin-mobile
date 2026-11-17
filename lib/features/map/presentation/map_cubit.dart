import 'package:bull_map/bull_map.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:primitives/primitives.dart';

import 'package:bb_mobile/features/map/domain/usecases/load_cached_merchants_usecase.dart';
import 'package:bb_mobile/features/map/domain/usecases/sync_merchants_usecase.dart';
import 'package:bb_mobile/features/map/presentation/map_state.dart';

class MapCubit extends Cubit<MapState> {
  final LoadCachedMerchantsUsecase _loadCached;
  final SyncMerchantsUsecase _sync;

  MapCubit(this._loadCached, this._sync) : super(const MapState());

  /// Shows the device copy at once, then brings it up to date.
  Future<void> start() async {
    if (await _loadCached.execute() case Ok(value: final merchants)) {
      if (isClosed) return;
      _emitMerchants(merchants);
    }
    await refresh();
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
    _emitListing(
      state.copyWith(
        category: category,
        mapMerchants: state.merchants.inCategory(category),
      ),
    );
  }

  void _emitMerchants(
    List<Merchant> merchants, {
    bool? isSyncing,
    bool clearFailure = false,
  }) => _emitListing(
    state.copyWith(
      merchants: merchants,
      // The same list back (a sync with no change) keeps the same pins, so
      // the map does not upload them again.
      mapMerchants: identical(merchants, state.merchants)
          ? state.mapMerchants
          : merchants.inCategory(state.category),
      isSyncing: isSyncing ?? state.isSyncing,
      failure: clearFailure ? null : state.failure,
    ),
  );

  void _emitListing(MapState next) => emit(
    next.copyWith(
      listing: MerchantListing.of(
        next.merchants,
        viewport: next.viewport,
        query: next.query,
        category: next.category,
      ),
    ),
  );
}
