part of 'transaction_details_cubit.dart';

@freezed
sealed class TransactionDetailsState with _$TransactionDetailsState {
  const factory TransactionDetailsState({
    TransactionViewModel? transaction,
    Object? err,
    bool? isBroadcastingPayjoinOriginalTx,
  }) = _TransactionDetailsState;
  const TransactionDetailsState._();

  bool
  get isOngoingPayjoin =>
      transaction?.payjoin != null &&
      transaction!.payjoin!.isOngoing &&
      // Todo: remove the following line once we put a payjoin to complete or failed
      // depending on watched transactions
      transaction?.walletTransaction?.txId ==
          transaction?.payjoin!.originalTxId;
}
