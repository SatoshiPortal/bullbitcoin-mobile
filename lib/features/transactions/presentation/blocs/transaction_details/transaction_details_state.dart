part of 'transaction_details_cubit.dart';

@freezed
sealed class TransactionDetailsState with _$TransactionDetailsState {
  const factory TransactionDetailsState({
    Transaction? transaction,
    Wallet? wallet,
    Wallet? counterpartWallet,
    String? swapCounterpartTxId,
    String? note,
    @Default(false) bool isBroadcastingPayjoinOriginalTx,
    @Default(false) bool retryingSwap,
    TransactionNotFoundError? notFoundError,
    Object? err,
  }) = _TransactionDetailsState;
  const TransactionDetailsState._();

  bool get isLoading => transaction == null;

  WalletTransaction? get walletTransaction => transaction?.walletTransaction;
  Swap? get swap => transaction?.swap;
  Payjoin? get payjoin => transaction?.payjoin;

  bool get isOngoingSwap => transaction?.isOngoingSwap == true;

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
