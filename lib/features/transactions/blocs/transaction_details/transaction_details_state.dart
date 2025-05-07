part of 'transaction_details_cubit.dart';

@freezed
sealed class TransactionDetailsState with _$TransactionDetailsState {
  const factory TransactionDetailsState({
    WalletTransaction? transaction,
    Wallet? wallet,
    Payjoin? payjoin,
    Swap? swap,
    Object? err,
  }) = _TransactionDetailsState;
  const TransactionDetailsState._();

  bool get isOngoingPayjoin => payjoin != null && payjoin!.isOngoing;
}
