part of 'transaction_details_cubit.dart';

@freezed
sealed class TransactionDetailsState with _$TransactionDetailsState {
  const factory TransactionDetailsState({
    @Default(true) bool isLoading,
    required Transaction transaction,
    Wallet? wallet,
    String? note,
    Wallet? counterpartWallet,
    Transaction? swapCounterpartTransaction,
    @Default(false) bool isBroadcastingPayjoinOriginalTx,
    Object? err,
  }) = _TransactionDetailsState;
  const TransactionDetailsState._();

  WalletTransaction? get walletTransaction => transaction.walletTransaction;
  Swap? get swap => transaction.swap;
  Payjoin? get payjoin => transaction.payjoin;

  bool get isOngoingSwap => transaction.isOngoingSwap;
  bool get isOngoingPayjoin => transaction.isOngoingPayjoin;

  /*
  bool
  get isOngoingPayjoin {
    final transaction = incomingTransaction ?? outgoingTransaction!;
  }
      incomingTransaction?.payjoin != null &&
      transaction!.payjoin!.isOngoing &&
      // Todo: remove the following line once we put a payjoin to complete or failed
      // depending on watched transactions
      transaction?.walletTransaction?.txId ==
          transaction?.payjoin!.originalTxId;*/
}
