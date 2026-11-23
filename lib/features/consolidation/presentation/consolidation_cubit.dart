import 'package:bull_logger/bull_logger.dart';
import 'package:bb_mobile/features/consolidation/domain/usecases/check_liquid_consolidation_usecase.dart';
import 'package:bb_mobile/features/consolidation/domain/usecases/consolidate_liquid_wallet_usecase.dart';
import 'package:bb_mobile/features/consolidation/presentation/consolidation_state.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:primitives/primitives.dart';

/// Presentation layer for the consolidation screen. Loads the UTXO count and a
/// fee preview, then drives the review → broadcasting → success/failed flow.
/// No business decisions live here — it delegates to
/// [ConsolidateLiquidWalletUsecase].
class ConsolidationCubit extends Cubit<ConsolidationState> {
  final ConsolidateLiquidWalletUsecase _consolidate;
  final CheckLiquidConsolidationUsecase _check;
  ConsolidationSubmissionFailure? _lastSubmissionFailure;
  var _loading = false;

  ConsolidationCubit({
    required String walletId,
    required ConsolidateLiquidWalletUsecase consolidateLiquidWalletUsecase,
    required CheckLiquidConsolidationUsecase checkLiquidConsolidationUsecase,
  }) : _consolidate = consolidateLiquidWalletUsecase,
       _check = checkLiquidConsolidationUsecase,
       super(ConsolidationState(walletId: walletId));

  bool get canSubmit => _lastSubmissionFailure?.outcomeUnknown != true;

  List<String> get acceptedBeforeFailure =>
      _lastSubmissionFailure?.acceptedTxids ?? const [];

  Future<void> load() async {
    if (_loading ||
        !canSubmit ||
        state.status == ConsolidationStatus.broadcasting ||
        state.status == ConsolidationStatus.success) {
      return;
    }
    _loading = true;
    // L-BTC UTXO count (asset-accurate) for the "outputs before" display.
    try {
      final utxoCount = await _check.count(walletId: state.walletId);
      if (isClosed) return;
      if (utxoCount != null) emit(state.copyWith(utxoCount: utxoCount));
      // Build the PSETs up front so the real network fee can be shown before
      // the user confirms.
      final result = await _consolidate.prepare(walletId: state.walletId);
      if (isClosed) return;
      switch (result) {
        case Ok(:final value):
          emit(state.copyWith(preview: value));
        case Err(:final failure):
          log.warning(
            'Consolidation preparation failed category=${failure.runtimeType}',
          );
      }
    } finally {
      _loading = false;
    }
  }

  Future<void> consolidate() async {
    // Re-entrancy guard: a second call (e.g. a fast double-tap landing before
    // the UI's own `disabled` rebuild takes effect) must be a no-op rather
    // than running the whole build→sign→broadcast pipeline concurrently a
    // second time against the same, still-unbroadcast PSETs.
    if (_loading ||
        !canSubmit ||
        state.status == ConsolidationStatus.broadcasting ||
        state.status == ConsolidationStatus.success) {
      return;
    }

    final preview = state.preview;
    if (preview == null || !state.hasPreview) {
      await load();
      return;
    }
    emit(state.copyWith(status: ConsolidationStatus.broadcasting));
    final submission = await _consolidate.broadcast(preview);
    if (isClosed) return;
    switch (submission) {
      case Ok():
        emit(state.copyWith(status: ConsolidationStatus.success));
      case Err(:final failure):
        if (failure is ConsolidationSubmissionFailure) {
          _lastSubmissionFailure = failure;
          log.warning(
            'Consolidation submission interrupted accepted=${failure.acceptedTxids.length} outcomeUnknown=${failure.outcomeUnknown}',
          );
        }
        emit(state.copyWith(status: ConsolidationStatus.failed, preview: null));
    }
  }
}
