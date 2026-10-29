import 'package:bb_mobile/core/blockchain/domain/usecases/broadcast_bitcoin_transaction_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/bitcoin_sync_operation_exception.dart';
import 'package:primitives/primitives.dart';
import 'package:transaction_sync/transaction_sync.dart';
import 'package:meta/meta.dart';
import '../broadcast_signed_tx_failure.dart';

class BroadcastImportedTransactionUsecase {
  final BroadcastBitcoinTransactionUsecase _broadcast;
  BroadcastImportedTransactionUsecase({required this._broadcast});
  @useResult
  Future<Result<String, BroadcastSignedTxFailure>> execute(
    String transaction, {
    required bool isPsbt,
    required String walletId,
  }) async {
    try {
      return Ok(
        await _broadcast.execute(
          transaction,
          isPsbt: isPsbt,
          walletId: walletId,
        ),
      );
    } on BitcoinSyncOperationException catch (error) {
      return Err(switch (error.failure) {
        CbfBroadcastNotRelayedFailure() =>
          const PrivateBroadcastFailedFailure(),
        CbfTorUnavailableFailure() => const PrivateBroadcastTorFailure(),
        _ => const BroadcastFailedFailure(),
      });
    } on Exception {
      return const Err(BroadcastFailedFailure());
    }
  }
}
