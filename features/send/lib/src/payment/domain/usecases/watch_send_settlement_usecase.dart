import 'package:transactions/transactions.dart'
    show Transactions, WalletTransaction;

/// Observes the settlement transaction in its wallet. Scheduling of the
/// wallet refresh belongs to the screen (`SettlementSyncPoller`).
class WatchSendSettlementUsecase {
  const WatchSendSettlementUsecase(this._transactions);

  final Transactions _transactions;

  Stream<WalletTransaction> execute({
    required String walletId,
    required String txId,
  }) => _transactions.watchWalletTransactionByTxId(
    walletId: walletId,
    txId: txId,
  );
}
