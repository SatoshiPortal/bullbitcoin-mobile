import 'package:bb_mobile/core/wallet/domain/entity/wallet_transaction.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'transactions_state.freezed.dart';

@freezed
class TransactionsState with _$TransactionsState {
  const factory TransactionsState({
    List<Transaction>? transactions,
    @Default(false) bool isSyncing,
    Object? err,
  }) = _TransactionsState;
  const TransactionsState._();

  List<Transaction> get sortedTransactions {
    if (transactions == null) return [];

    final txList = List<Transaction>.from(transactions!);
    txList.sort((a, b) {
      // If both transactions have confirmationTime, sort by time (newest first)
      if (a.confirmationTime != null && b.confirmationTime != null) {
        return b.confirmationTime!.compareTo(a.confirmationTime!);
      }

      // Null confirmationTime transactions are considered pending and should be at the top
      if (a.confirmationTime == null) return -1;
      if (b.confirmationTime == null) return 1;

      // This line should never be reached but is required for completeness
      return 0;
    });

    return txList;
  }
}
