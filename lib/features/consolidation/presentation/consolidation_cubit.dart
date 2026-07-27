import 'package:bb_mobile/core/utils/logger.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/get_wallet_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/sync_wallet_usecase.dart';
import 'package:bb_mobile/features/consolidation/domain/consolidation_failure.dart';
import 'package:bb_mobile/features/consolidation/domain/usecases/check_liquid_consolidation_usecase.dart';
import 'package:bb_mobile/features/consolidation/domain/usecases/consolidate_liquid_wallet_usecase.dart';
import 'package:bb_mobile/features/consolidation/presentation/consolidation_state.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class ConsolidationCubit extends Cubit<ConsolidationState> {
  final ConsolidateLiquidWalletUsecase _consolidate;
  final CheckLiquidConsolidationUsecase _check;
  final GetWalletUsecase _getWallet;
  final SyncWalletUsecase _sync;

  ConsolidationCubit({
    required String walletId,
    required ConsolidateLiquidWalletUsecase consolidateLiquidWalletUsecase,
    required CheckLiquidConsolidationUsecase checkLiquidConsolidationUsecase,
    required GetWalletUsecase getWalletUsecase,
    required SyncWalletUsecase syncWalletUsecase,
  }) : _consolidate = consolidateLiquidWalletUsecase,
       _check = checkLiquidConsolidationUsecase,
       _getWallet = getWalletUsecase,
       _sync = syncWalletUsecase,
       super(ConsolidationState(walletId: walletId));

  Future<void> load() async {
    try {
      final wallet = await _getWallet.execute(state.walletId);
      if (!isClosed && wallet != null) {
        emit(state.copyWith(balanceSat: wallet.balanceSat.toInt()));
      }
    } catch (_) {
      // Best-effort: the balance row just stays at 0.
    }

    // L-BTC UTXO count (asset-accurate) for the "outputs before" display.
    final status = await _check.execute(walletId: state.walletId);
    if (!isClosed && status.utxoCount != null) {
      emit(state.copyWith(utxoCount: status.utxoCount!));
    }

    final previewResult = await _consolidate.prepare(walletId: state.walletId);
    if (!isClosed) {
      switch (previewResult) {
        case Ok(:final value):
          emit(state.copyWith(preview: value, utxoCount: value.utxoCount));
        case Err(:final failure):
          log.warning('Consolidation prepare failed: ${failure.logMessage}');
          emit(
            state.copyWith(
              status: ConsolidationStatus.failed,
              failure: failure,
            ),
          );
      }
    }
  }

  Future<void> consolidate() async {
    if (state.status == ConsolidationStatus.broadcasting) return;

    emit(state.copyWith(status: ConsolidationStatus.broadcasting));

    var preview = state.preview;
    if (preview == null) {
      try {
        final wallet = await _getWallet.execute(state.walletId);
        if (wallet != null) await _sync.execute(wallet);
      } catch (e) {
        log.warning('Consolidation pre-retry sync failed: $e');
        if (!isClosed) {
          emit(
            state.copyWith(
              status: ConsolidationStatus.failed,
              failure: ConsolidationSyncFailure(e.toString()),
            ),
          );
        }
        return;
      }

      final previewResult = await _consolidate.prepare(
        walletId: state.walletId,
      );
      switch (previewResult) {
        case Ok(:final value):
          preview = value;
        case Err(:final failure):
          if (!isClosed) {
            emit(
              state.copyWith(
                status: ConsolidationStatus.failed,
                failure: failure,
              ),
            );
          }
          return;
      }
    }

    final broadcastResult = await _consolidate.broadcast(
      walletId: state.walletId,
      batches: preview.batches,
    );
    if (isClosed) return;
    switch (broadcastResult) {
      case Ok(:final value):
        emit(
          state.copyWith(
            status: ConsolidationStatus.success,
            unfrozenDecoyCount: value.unfrozenDecoyCount,
          ),
        );
      case Err(:final failure):
        emit(
          state.copyWith(
            status: ConsolidationStatus.failed,
            failure: failure,
            preview: null,
          ),
        );
    }
  }
}
