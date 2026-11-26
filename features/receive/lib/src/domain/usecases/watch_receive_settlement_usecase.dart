import 'package:transactions/transactions.dart'
    show Transactions, WalletTransaction;

class WatchReceiveSettlementUsecase {
  const WatchReceiveSettlementUsecase(this._transactions);

  final Transactions _transactions;

  /// Observes the transaction [txId] in [walletId]. Wallet syncing is
  /// scheduled by the receive screens, not here.
  Stream<WalletTransaction> execute({
    required String walletId,
    required String txId,
  }) => _transactions.watchWalletTransactionByTxId(
    walletId: walletId,
    txId: txId,
  );
}
