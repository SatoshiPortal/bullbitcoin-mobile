import 'package:bb_mobile/features/send/domain/usecases/verify_signed_tx_usecase.dart';
import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart' show Result;
import 'package:bb_mobile/features/send/domain/pending_bitcoin_transaction.dart';
import 'package:bb_mobile/features/send/domain/send_failure.dart';
import 'package:bb_mobile/features/send/domain/usecases/watch_pending_bitcoin_transactions_usecase.dart';

export '../domain/pending_bitcoin_transaction.dart';
export '../domain/send_failure.dart';
export 'send_route.dart';
export 'send_route_args.dart';

class SendFacade {
  final VerifySignedTxUsecase _verifySignedTxUsecase;
  final WatchPendingBitcoinTransactionsUsecase
  _watchPendingBitcoinTransactionsUsecase;

  const SendFacade(
    this._verifySignedTxUsecase,
    this._watchPendingBitcoinTransactionsUsecase,
  );

  @useResult
  Future<Result<void, SendFailure>> verifySignedTransaction({
    required String unsignedPsbt,
    required String signedTransaction,
    bool isPsbt = false,
  }) => _verifySignedTxUsecase.execute(
    unsignedPsbt: unsignedPsbt,
    signedTransaction: signedTransaction,
    isPsbt: isPsbt,
  );

  Stream<Result<PendingBitcoinTransactionSnapshot, SendFailure>> watchPending(
    String walletId,
  ) => _watchPendingBitcoinTransactionsUsecase.execute(walletId);
}
