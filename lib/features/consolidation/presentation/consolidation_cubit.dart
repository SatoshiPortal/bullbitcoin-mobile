import 'package:bb_mobile/core/utils/logger.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/check_liquid_consolidation_usecase.dart';
import 'package:bb_mobile/features/consolidation/domain/usecases/consolidate_liquid_wallet_usecase.dart';
import 'package:bb_mobile/features/consolidation/presentation/consolidation_state.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Presentation layer for the consolidation screen. Loads the UTXO count and a
/// fee preview, then drives the review → broadcasting → success/failed flow.
/// No business decisions live here — it delegates to
/// [ConsolidateLiquidWalletUsecase].
class ConsolidationCubit extends Cubit<ConsolidationState> {
  final ConsolidateLiquidWalletUsecase _consolidate;
  final CheckLiquidConsolidationUsecase _check;

  ConsolidationCubit({
    required String walletId,
    required ConsolidateLiquidWalletUsecase consolidateLiquidWalletUsecase,
    required CheckLiquidConsolidationUsecase checkLiquidConsolidationUsecase,
  }) : _consolidate = consolidateLiquidWalletUsecase,
       _check = checkLiquidConsolidationUsecase,
       super(ConsolidationState(walletId: walletId));

  Future<void> load() async {
    // L-BTC UTXO count (asset-accurate) for the "outputs before" display.
    final utxoCount = await _check.count(walletId: state.walletId);
    if (!isClosed && utxoCount != null) {
      emit(state.copyWith(utxoCount: utxoCount));
    }
    // Build the PSETs up front so the real network fee can be shown before
    // the user confirms.
    try {
      final preview = await _consolidate.prepare(walletId: state.walletId);
      if (!isClosed) emit(state.copyWith(preview: preview));
    } catch (e) {
      // Leave the preview/fee unavailable (shown as "—"), but still log the
      // cause — previously this was silently discarded, making a real build
      // failure indistinguishable from "still loading" with no way to
      // diagnose why the fee never appeared.
      log.warning('Consolidation prepare failed: $e');
    }
  }

  Future<void> consolidate() async {
    // Re-entrancy guard: a second call (e.g. a fast double-tap landing before
    // the UI's own `disabled` rebuild takes effect) must be a no-op rather
    // than running the whole build→sign→broadcast pipeline concurrently a
    // second time against the same, still-unbroadcast PSETs.
    if (state.status == ConsolidationStatus.broadcasting) return;

    emit(state.copyWith(status: ConsolidationStatus.broadcasting));
    try {
      // consolidate (build) → sign → broadcast. batchBroadcast loops the same
      // broadcastLiquidTransaction usecase a normal send uses.
      final preview =
          state.preview ?? await _consolidate.prepare(walletId: state.walletId);
      await _consolidate.broadcast(
        walletId: state.walletId,
        unsignedPsets: preview.unsignedPsets,
      );
      if (!isClosed) {
        emit(state.copyWith(status: ConsolidationStatus.success));
      }
    } catch (e) {
      // No funds are ever double-spent (an already-broadcast PSET's inputs
      // are already spent, so the network simply rejects a resubmission),
      // but a stale `preview` left in state would still repeatedly retry
      // the very same (partially already-spent) PSET list on every tap —
      // never reaching whichever batches never got a chance to broadcast,
      // and never surfacing that some of them actually did succeed. Clear
      // it so the next attempt always calls `prepare()` again, rebuilding
      // fresh PSETs.
      final succeededTxids = e is ConsolidationException
          ? e.succeededTxids
          : const <String>[];
      log.warning(
        'Consolidation broadcast failed: $e '
        '(${succeededTxids.length} batch(es) already succeeded)',
      );
      if (!isClosed) {
        emit(state.copyWith(status: ConsolidationStatus.failed, preview: null));
      }
    }
  }
}
