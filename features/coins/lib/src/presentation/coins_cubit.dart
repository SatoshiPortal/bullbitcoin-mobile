import 'package:preferences/preferences.dart' show AmountDisplayPreferences;
import 'package:coins/src/domain/usecases/watch_coins_amount_display_usecase.dart';
import 'package:coins/src/domain/usecases/watch_wallet_revisions_usecase.dart';

import 'dart:async';

import 'package:primitives/primitives.dart';
import 'package:coins/src/domain/usecases/freeze_utxos_usecase.dart';
import 'package:coins/src/domain/usecases/get_utxos_usecase.dart';
import 'package:coins/src/domain/usecases/refresh_coins_usecase.dart';
import 'package:coins/src/domain/usecases/unfreeze_utxos_usecase.dart';
import 'package:coins/src/domain/utxo_sort_filter.dart';
import 'package:coins/src/presentation/coins_state.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:coins/src/domain/usecases/load_coin_label_filters_usecase.dart';

/// Debounce applied before reloading after a wallet sync finishes — a real
/// wait that keeps multiple finish events from each triggering a reload.
const _syncReloadDebounce = Duration(seconds: 3);

/// Thin presentation layer for the Coins view: calls the feature usecases,
/// holds UI state, derives the visible list via the pure sort/filter function,
/// and reacts to wallet syncs. No business decisions live here.
class CoinsCubit extends Cubit<CoinsState> {
  CoinsCubit({
    WatchWalletRevisionsUsecase? watchWalletRevisionsUsecase,
    WatchCoinsAmountDisplayUsecase? watchAmountDisplayUsecase,
    required String walletId,
    required this._getUtxosUsecase,
    required this._freezeUtxosUsecase,
    required this._unfreezeUtxosUsecase,
    required this._refreshCoinsUsecase,
    required this._loadCoinLabelFilters,
    required Stream<String> startedSyncs,
    required Stream<String> finishedSyncs,
  }) : super(CoinsState(walletId: walletId)) {
    _amountDisplaySubscription = watchAmountDisplayUsecase?.execute().listen((
      preferences,
    ) {
      if (!isClosed) emit(state.copyWith(amountDisplay: preferences));
    });
    _startedSub = startedSyncs.listen((_) {
      if (!isClosed) emit(state.copyWith(syncing: true));
    });
    _revisionsSubscription = watchWalletRevisionsUsecase
        ?.execute(walletId: walletId)
        .listen((_) => _scheduleReload());
    _finishedSub = finishedSyncs.listen((_) => _scheduleReload());
  }

  final GetUtxosUsecase _getUtxosUsecase;
  final FreezeUtxosUsecase _freezeUtxosUsecase;
  final UnfreezeUtxosUsecase _unfreezeUtxosUsecase;
  final RefreshCoinsUsecase _refreshCoinsUsecase;
  final LoadCoinLabelFiltersUsecase _loadCoinLabelFilters;

  late final StreamSubscription<AmountDisplayPreferences?>?
  _amountDisplaySubscription;
  StreamSubscription? _startedSub;
  StreamSubscription? _finishedSub;
  StreamSubscription? _revisionsSubscription;
  Timer? _debounceTimer;

  @override
  Future<void> close() async {
    _debounceTimer?.cancel();
    await _amountDisplaySubscription?.cancel();
    await _revisionsSubscription?.cancel();
    await _startedSub?.cancel();
    await _finishedSub?.cancel();
    return super.close();
  }

  // ── Loading ───────────────────────────────────────────────────────────────

  Future<void> load() async {
    if (state.status == CoinsStatus.error) {
      emit(state.copyWith(status: CoinsStatus.loading, failure: null));
    }
    final result = await _getUtxosUsecase.execute(walletId: state.walletId);
    switch (result) {
      case Err(:final failure):
        if (!isClosed) {
          emit(
            state.copyWith(
              status: CoinsStatus.error,
              failure: failure,
              syncing: false,
            ),
          );
        }
      case Ok(:final value):
        final labels = await _loadCoinLabelFilters.execute();
        if (isClosed) return;

        final stillPresent = value.map(utxoOutpointKey).toSet();
        final prunedSelection = state.selectedOutpoints
            .where(stillPresent.contains)
            .toSet();

        emit(
          state.copyWith(
            utxos: value,
            allLabels: labels,
            selectedOutpoints: prunedSelection,
            status: value.isEmpty ? CoinsStatus.empty : CoinsStatus.ready,
            syncing: false,
            failure: null,
          ),
        );
    }
  }

  Future<void> refresh() async {
    await _refreshCoinsUsecase.execute(walletId: state.walletId);
    await load();
  }

  Future<void> _scheduleReload() async {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(_syncReloadDebounce, load);
  }

  // ── Selection ───────────────────────────────────────────────────────────────

  void enterSelect({String? seedOutpoint}) {
    emit(
      state.copyWith(
        selecting: true,
        selectedOutpoints: seedOutpoint != null ? {seedOutpoint} : {},
      ),
    );
  }

  void exitSelect() {
    emit(state.copyWith(selecting: false, selectedOutpoints: {}));
  }

  void toggle(String outpoint) {
    final next = Set<String>.from(state.selectedOutpoints);
    if (!next.remove(outpoint)) next.add(outpoint);
    emit(state.copyWith(selectedOutpoints: next));
  }

  /// Selects every unfrozen coin in the currently visible list.
  void selectAllUnfrozen() {
    final unfrozen = state.visible
        .where((u) => !u.isFrozen)
        .map(utxoOutpointKey)
        .toSet();
    emit(state.copyWith(selectedOutpoints: unfrozen));
  }

  // ── Filtering ───────────────────────────────────────────────────────────────

  void applyFilter(CoinsFilter filter) {
    emit(state.copyWith(filter: filter));
  }

  void clearFilters() {
    emit(state.copyWith(filter: CoinsFilter(sort: state.filter.sort)));
  }

  // ── Freeze / Unfreeze ─────────────────────────────────────────────────────

  /// Returns `true` on success, `false` if the freeze failed.
  /// Callers must gate any success UI on the return value rather than
  /// re-reading [state] — the UI listener clears [CoinsState.failure]
  /// before an awaiting caller's continuation runs.
  Future<bool> freeze(List<String> outpointKeys) async {
    final result = await _freezeUtxosUsecase.execute(
      walletId: state.walletId,
      outpoints: _toOutpoints(outpointKeys),
    );
    switch (result) {
      case Err(:final failure):
        if (!isClosed) emit(state.copyWith(failure: failure));
        return false;
      case Ok():
        await load();
        if (!isClosed) exitSelect();
        return true;
    }
  }

  /// Returns `true` on success, `false` if the unfreeze failed (error emitted).
  /// See [freeze] for why callers must use the return value, not [state].
  Future<bool> unfreeze(List<String> outpointKeys) async {
    final result = await _unfreezeUtxosUsecase.execute(
      walletId: state.walletId,
      outpoints: _toOutpoints(outpointKeys),
    );
    switch (result) {
      case Err(:final failure):
        if (!isClosed) emit(state.copyWith(failure: failure));
        return false;
      case Ok():
        await load();
        if (!isClosed) exitSelect();
        return true;
    }
  }

  /// Clears a transient failure after the UI has shown it.
  void clearFailure() {
    if (state.failure != null) emit(state.copyWith(failure: null));
  }

  List<Outpoint> _toOutpoints(List<String> keys) {
    return keys.map((k) {
      final i = k.lastIndexOf(':');
      final txId = k.substring(0, i);
      final vout = int.parse(k.substring(i + 1));
      return (txId: txId, vout: vout);
    }).toList();
  }
}
