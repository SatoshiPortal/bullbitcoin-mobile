part of 'transaction_details_cubit.dart';

@freezed
sealed class TransactionDetailsState with _$TransactionDetailsState {
  const factory TransactionDetailsState({
    WalletTransaction? transaction,
    Wallet? wallet,
    Payjoin? payjoin,
    Swap? swap,
    Object? err,
    bool? isBroadcastingPayjoinOriginalTx,
  }) = _TransactionDetailsState;
  const TransactionDetailsState._();

  bool get isOngoingPayjoin =>
      payjoin != null &&
      payjoin!.isOngoing &&
      // Todo: remove the following line once we put a payjoin to complete or failed
      // depending on watched transactions
      transaction?.txId == payjoin!.originalTxId;
}
