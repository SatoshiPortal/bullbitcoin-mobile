part of 'transaction_details_cubit.dart';

@freezed
sealed class TransactionDetailsState with _$TransactionDetailsState {
  const factory TransactionDetailsState.loading({
    @Default(false) bool isBroadcastingPayjoinOriginalTx,
    Object? err,
  }) = _LoadingTransactionDetailsState;
  const factory TransactionDetailsState.incoming({
    required Transaction transaction,
    required Wallet wallet,
    Object? err,
    bool? isBroadcastingPayjoinOriginalTx,
  }) = _IncomingTransactionDetailsState;
  const factory TransactionDetailsState.outgoing({
    required Transaction transaction,
    required Wallet wallet,
    Object? err,
    bool? isBroadcastingPayjoinOriginalTx,
  }) = _OutgoingTransactionDetailsState;
  const factory TransactionDetailsState.betweenWallets({
    required Transaction transaction,
    required Wallet wallet,
    required Wallet otherWallet,
    Object? err,
    bool? isBroadcastingPayjoinOriginalTx,
  }) = _BetweenWalletsTransactionDetailsState;
  const factory TransactionDetailsState.betweenWalletsWithSwap({
    required Transaction transaction,
    required Wallet wallet,
    required Transaction otherTransaction,
    required Wallet otherWallet,
    bool? isBroadcastingPayjoinOriginalTx,
    Object? err,
  }) = _BetweenWalletsWithSwapTransactionDetailsState;
  const TransactionDetailsState._();

  bool get isOngoingSwap => switch (this) {
    _IncomingTransactionDetailsState(transaction: final tx) => tx.isOngoingSwap,
    _OutgoingTransactionDetailsState(transaction: final tx) => tx.isOngoingSwap,
    _BetweenWalletsTransactionDetailsState(transaction: final tx) =>
      tx.isOngoingSwap,
    _BetweenWalletsWithSwapTransactionDetailsState(
      transaction: final transaction,
    ) =>
      transaction.isOngoingSwap,
    _LoadingTransactionDetailsState() => false,
  };
  bool get isOngoingPayjoin => switch (this) {
    _IncomingTransactionDetailsState(transaction: final tx) =>
      tx.isOngoingPayjoin,
    _OutgoingTransactionDetailsState(transaction: final tx) =>
      tx.isOngoingPayjoin,
    _BetweenWalletsTransactionDetailsState(transaction: final tx) =>
      tx.isOngoingPayjoin,
    _BetweenWalletsWithSwapTransactionDetailsState(
      transaction: final transaction,
    ) =>
      transaction.isOngoingPayjoin,
    _LoadingTransactionDetailsState() => false,
  };

  Payjoin? get payjoin => switch (this) {
    _IncomingTransactionDetailsState(transaction: final tx) => tx.payjoin,
    _OutgoingTransactionDetailsState(transaction: final tx) => tx.payjoin,
    _BetweenWalletsTransactionDetailsState(transaction: final tx) => tx.payjoin,
    _BetweenWalletsWithSwapTransactionDetailsState(
      transaction: final transaction,
    ) =>
      transaction.payjoin,
    _LoadingTransactionDetailsState() => null,
  };

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
