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

  /// Calculates the actual amount sent (received by recipient)
  /// For swaps: amount - txFee + aggregateSwapFees
  /// For regular transactions: amount - txFee
  int getAmountSent() {
    final swap = this.swap;
    final payjoin = this.payjoin;
    final txFee = walletTransaction?.feeSat ?? 0;
    final amount = walletTransaction?.amountSat;
    if (payjoin != null) {
      return payjoin.amountSat ?? 0;
    }

    if (swap != null) {
      return swap.sendAmount ?? 0;
    }
    return amount ?? 0 + txFee;
  }

  int getAmountReceived() {
    if (payjoin != null) {
      return payjoin?.amountSat ?? 0;
    }
    final amount = walletTransaction?.amountSat ?? 0;
    return amount;
  }

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
