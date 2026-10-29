import 'package:bb_mobile/core/blockchain/domain/usecases/broadcast_bitcoin_transaction_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/bitcoin_sync_operation_exception.dart';
import 'package:primitives/primitives.dart';
import 'package:transaction_sync/transaction_sync.dart';
import 'package:meta/meta.dart';
import '../send_failure.dart';

class BroadcastSendTransactionUsecase {
  final BroadcastBitcoinTransactionUsecase _broadcast;
  BroadcastSendTransactionUsecase({required this._broadcast});
  @useResult
  Future<Result<String, SendFailure>> execute(
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
        CbfBroadcastNotRelayedFailure() => const SendPrivateBroadcastFailure(),
        CbfTorUnavailableFailure() => const SendPrivateTorFailure(),
        _ => const SendTransactionConfirmationFailure(isBroadcastFailure: true),
      });
    } on Exception {
      return const Err(
        SendTransactionConfirmationFailure(isBroadcastFailure: true),
      );
    }
  }
}
