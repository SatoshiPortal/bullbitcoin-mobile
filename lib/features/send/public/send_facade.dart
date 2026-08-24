import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/send/domain/pending_bitcoin_transaction.dart';
import 'package:bb_mobile/features/send/domain/send_failure.dart';
import 'package:bb_mobile/features/send/domain/usecases/watch_pending_bitcoin_transactions_usecase.dart';

export '../domain/pending_bitcoin_transaction.dart';
export '../domain/send_failure.dart';
export '../ui/send_router.dart' show SendRoute, SendRouteArgs;

class SendFacade {
  final WatchPendingBitcoinTransactionsUsecase
  _watchPendingBitcoinTransactionsUsecase;

  const SendFacade(this._watchPendingBitcoinTransactionsUsecase);

  Stream<Result<PendingBitcoinTransactionSnapshot, SendFailure>> watchPending(
    String walletId,
  ) => _watchPendingBitcoinTransactionsUsecase.execute(walletId);
}
