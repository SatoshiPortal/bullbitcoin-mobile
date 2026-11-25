part of 'transaction_status_cubit.dart';

@freezed
sealed class TransactionStatusState with _$TransactionStatusState {
  const factory TransactionStatusState({
    /// Null until the preference is read.
    bool? animationsEnabled,
    TransactionSettlementTarget? settlementTarget,
    WalletTransaction? settlement,
  }) = _TransactionStatusState;
  const TransactionStatusState._();

  /// The observed transaction is the settlement one and it is confirmed.
  bool get settlementConfirmed {
    final target = settlementTarget;
    final observed = settlement;
    return target != null &&
        observed != null &&
        observed.txId == target.txId &&
        observed.walletId == target.walletId &&
        observed.isConfirmed;
  }

  /// A settlement transaction is known and not confirmed yet.
  bool get settlementPending =>
      settlementTarget != null && !settlementConfirmed;
}
