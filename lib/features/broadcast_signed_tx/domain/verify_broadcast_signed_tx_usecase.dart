import 'package:primitives/primitives.dart';
import 'package:spend/spend.dart';
import 'package:bb_mobile/features/broadcast_signed_tx/domain/broadcast_signed_tx_failure.dart';
import 'package:meta/meta.dart';

class VerifyBroadcastSignedTxUsecase {
  final Spend _spend;

  VerifyBroadcastSignedTxUsecase(this._spend);

  @useResult
  Future<Result<void, BroadcastSignedTxFailure>> verifyPrepared({
    required PreparedBitcoinSpend prepared,
    required String signedTransaction,
  }) async => (await _spend.verifySignedBitcoin(
    prepared: prepared,
    signedTransaction: signedTransaction,
    isPsbt: false,
  )).map((_) {}).mapErr((_) => const InvalidTransactionFailure());

  @useResult
  Future<Result<void, BroadcastSignedTxFailure>> execute({
    required String unsignedPsbt,
    required String signedTransaction,
    bool isPsbt = false,
  }) async {
    final result = _spend.verifyExternalBitcoin(
      unsignedPsbt: unsignedPsbt,
      signedTransaction: signedTransaction,
      isPsbt: isPsbt,
    );
    return result.mapErr((_) => const InvalidTransactionFailure());
  }
}
