part of 'transactions_cubit.dart';

enum TransactionsFilter { all, send, receive, swap, payjoin, sell, buy }

@freezed
abstract class TransactionsState with _$TransactionsState {
  const factory TransactionsState({
    List<WalletTransaction>? transactions,
    @Default(false) bool isSyncing,
    @Default(TransactionsFilter.all) TransactionsFilter filter,
    Object? err,
  }) = _TransactionsState;
  const TransactionsState._();

  Map<int, List<WalletTransaction>>? get transactionsByDay {
    if (filteredTransactions == null) {
      return null;
    }

    final Map<int, List<WalletTransaction>> grouped = {};

    for (final tx in filteredTransactions!) {
      int day;
      if (tx.confirmationTime == null) {
        // Pending transactions can't be assigned to a specific day yet, since
        //  they are in the future we assign them to a day that is always
        //  greater than any other day. This way they will always be at the top
        //  of the list when sorted by date.
        day = 8640000000000000; // Max milliseconds value for DateTime
      } else {
        final date = tx.confirmationTime!;
        day = DateTime(date.year, date.month, date.day).millisecondsSinceEpoch;
      }

      grouped.putIfAbsent(day, () => []).add(tx);
    }

    // Sort transactions inside each day
    grouped.forEach((_, txs) {
      txs.sort((a, b) {
        final aTime =
            a.confirmationTime ?? DateTime.fromMillisecondsSinceEpoch(0);
        final bTime =
            b.confirmationTime ?? DateTime.fromMillisecondsSinceEpoch(0);
        return bTime.compareTo(aTime); // descending
      });
    });

    // Sort days in descending order and preserve order with LinkedHashMap
    final sorted = SplayTreeMap<int, List<WalletTransaction>>.from(
      grouped,
      (a, b) => b.compareTo(a), // descending key sort
    );

    return LinkedHashMap<int, List<WalletTransaction>>.from(sorted);
  }

  List<WalletTransaction>? get filteredTransactions {
    return transactions
        ?.where((tx) {
          switch (filter) {
            case TransactionsFilter.all:
              return true;
            case TransactionsFilter.send:
              return tx.isOutgoing;
            case TransactionsFilter.receive:
              return tx.isIncoming;
            case TransactionsFilter.swap:
              return tx.isSwap;
            case TransactionsFilter.payjoin:
              return tx.isPayjoin;
            case TransactionsFilter.sell:
              return false;
            case TransactionsFilter.buy:
              return false;
          }
        })
        .toList(growable: false);
  }

  bool get hasNoTransactions {
    return transactions != null || transactions!.isEmpty;
  }
}
