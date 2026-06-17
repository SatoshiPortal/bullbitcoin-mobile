import 'dart:async';

import 'package:bb_mobile/core/wallet/domain/entities/outpoint.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/watch_finished_wallet_syncs_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/watch_started_wallet_syncs_usecase.dart';
import 'package:bb_mobile/features/coins/domain/coins_error.dart';
import 'package:bb_mobile/features/coins/domain/usecases/freeze_utxos_usecase.dart';
import 'package:bb_mobile/features/coins/domain/usecases/get_utxos_usecase.dart';
import 'package:bb_mobile/features/coins/domain/usecases/unfreeze_utxos_usecase.dart';
import 'package:bb_mobile/features/coins/domain/utxo_sort_filter.dart';
import 'package:bb_mobile/features/coins/presentation/coins_state.dart';
import 'package:bb_mobile/features/labels/labels_facade.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Debounce applied before reloading after a wallet sync finishes — a real
/// wait that keeps multiple finish events from each triggering a reload.
const _syncReloadDebounce = Duration(seconds: 3);

/// Thin presentation layer for the Coins view: calls the feature usecases,
/// holds UI state, derives the visible list via the pure sort/filter function,
/// and reacts to wallet syncs. No business decisions live here.
class CoinsCubit extends Cubit<CoinsState> {
  CoinsCubit({
    required String walletId,
    required this._getUtxosUsecase,
    required this._freezeUtxosUsecase,
    required this._unfreezeUtxosUsecase,
    required this._labelsFacade,
    required WatchStartedWalletSyncsUsecase watchStartedWalletSyncsUsecase,
    required WatchFinishedWalletSyncsUsecase watchFinishedWalletSyncsUsecase,
  }) : super(CoinsState(walletId: walletId)) {
    _startedSub = watchStartedWalletSyncsUsecase
        .execute(walletId: walletId)
        .listen((_) {
          if (!isClosed) emit(state.copyWith(syncing: true));
        });
    _finishedSub = watchFinishedWalletSyncsUsecase
        .execute(walletId: walletId)
        .listen((_) => _onSyncFinished());
  }

  final GetUtxosUsecase _getUtxosUsecase;
  final FreezeUtxosUsecase _freezeUtxosUsecase;
  final UnfreezeUtxosUsecase _unfreezeUtxosUsecase;
  final LabelsFacade _labelsFacade;

  StreamSubscription? _startedSub;
  StreamSubscription? _finishedSub;
  Timer? _debounceTimer;

  @override
  Future<void> close() async {
    _debounceTimer?.cancel();
    await _startedSub?.cancel();
    await _finishedSub?.cancel();
    return super.close();
  }

  // ── Loading ───────────────────────────────────────────────────────────────

  Future<void> load() async {
    try {
      if (state.status == CoinsStatus.error) {
        emit(state.copyWith(status: CoinsStatus.loading, error: null));
      }
      final utxos = await _getUtxosUsecase.execute(walletId: state.walletId);
      final labels = await _labelsFacade.fetchDistinctLabels();

      final stillPresent = utxos.map(utxoOutpointKey).toSet();
      final prunedSelection = state.selectedOutpoints
          .where(stillPresent.contains)
          .toSet();

      emit(
        state.copyWith(
          utxos: utxos,
          allLabels: labels,
          selectedOutpoints: prunedSelection,
          status: utxos.isEmpty ? CoinsStatus.empty : CoinsStatus.ready,
          syncing: false,
          error: null,
        ),
      );
    } on CoinsError catch (e) {
      if (!isClosed) {
        emit(state.copyWith(status: CoinsStatus.error, error: e, syncing: false));
      }
    } catch (e) {
      if (!isClosed) {
        emit(
          state.copyWith(
            status: CoinsStatus.error,
            error: CoinsError.unexpected(message: e.toString()),
            syncing: false,
          ),
        );
      }
    }
  }

  Future<void> refresh() => load();

  Future<void> _onSyncFinished() async {
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

  Future<void> freeze(List<String> outpointKeys) async {
    try {
      await _freezeUtxosUsecase.execute(
        walletId: state.walletId,
        outpoints: _toOutpoints(outpointKeys),
      );
      await load();
      if (!isClosed) exitSelect();
    } on CoinsError catch (e) {
      // Preserve selection; surface the error.
      if (!isClosed) emit(state.copyWith(error: e));
    }
  }

  Future<void> unfreeze(List<String> outpointKeys) async {
    try {
      await _unfreezeUtxosUsecase.execute(
        walletId: state.walletId,
        outpoints: _toOutpoints(outpointKeys),
      );
      await load();
      if (!isClosed) exitSelect();
    } on CoinsError catch (e) {
      if (!isClosed) emit(state.copyWith(error: e));
    }
  }

  /// Clears a transient error after the UI has shown it.
  void clearError() {
    if (state.error != null) emit(state.copyWith(error: null));
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
