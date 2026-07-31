import 'package:bb_mobile/core/blockchain/domain/usecases/broadcast_bitcoin_transaction_usecase.dart';
import 'package:bb_mobile/core/utils/logger.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/sweep/domain/sweep_failure.dart';
import 'package:meta/meta.dart';

/// Broadcasts the signed sweep and returns its txid.
class BroadcastSweepPsbtUsecase {
  final BroadcastBitcoinTransactionUsecase _broadcast;

  BroadcastSweepPsbtUsecase({
    required BroadcastBitcoinTransactionUsecase
    broadcastBitcoinTransactionUsecase,
  }) : _broadcast = broadcastBitcoinTransactionUsecase;

  @useResult
  Future<Result<String, SweepFailure>> execute({
    required String signedPsbt,
  }) async {
    try {
      final txId = await _broadcast.execute(signedPsbt, isPsbt: true);
      return Ok(txId);
    } on Exception catch (e, st) {
      log.severe(message: 'Failed to broadcast sweep', error: e, trace: st);
      return Err(SweepBroadcastFailure(e.toString()));
    }
  }
}
