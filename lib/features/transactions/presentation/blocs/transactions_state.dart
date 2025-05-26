part of 'transactions_cubit.dart';

enum TransactionsFilter { all, send, receive, swap, payjoin, sell, buy }

@freezed
abstract class TransactionsState with _$TransactionsState {
  const factory TransactionsState({
    List<TransactionViewModel>? transactions,
    @Default(false) bool isSyncing,
    @Default(TransactionsFilter.all) TransactionsFilter filter,
    Object? err,
  }) = _TransactionsState;
  const TransactionsState._();

  Map<int, List<TransactionViewModel>>? get transactionsByDay {
    if (transactions == null) {
      return null;
    }

    final Map<int, List<TransactionViewModel>> grouped = {};

    for (final tx in transactions!) {
      int day;
      if (tx.timestamp == null) {
        // Pending transactions can't be assigned to a specific day yet, since
        //  they are in the future we assign them to a day that is always
        //  greater than any other day. This way they will always be at the top
        //  of the list when sorted by date.
        day = 8640000000000000; // Max milliseconds value for DateTime
      } else {
        final date = tx.timestamp!;
        day = DateTime(date.year, date.month, date.day).millisecondsSinceEpoch;
      }

      grouped.putIfAbsent(day, () => []).add(tx);
    }

    // Sort transactions inside each day
    grouped.forEach((_, txs) {
      txs.sort((a, b) {
        final aTime = a.timestamp ?? DateTime.fromMillisecondsSinceEpoch(0);
        final bTime = b.timestamp ?? DateTime.fromMillisecondsSinceEpoch(0);
        return bTime.compareTo(aTime); // descending
      });
    });

    // Sort days in descending order and preserve order with LinkedHashMap
    final sorted = SplayTreeMap<int, List<WalletTransaction>>.from(
      grouped,
      (a, b) => b.compareTo(a), // descending key sort
    );

    return LinkedHashMap<int, List<TransactionViewModel>>.from(sorted);
  }

  Map<int, List<TransactionViewModel>>? get filteredTransactionsByDay {
    if (transactionsByDay == null) {
      return null;
    }

    final filtered = {
      for (final key in transactionsByDay!.keys)
        key:
            transactionsByDay![key]!
                .where(
                  (tx) => switch (filter) {
                    TransactionsFilter.all => true,
                    TransactionsFilter.send => tx.isOutgoing,
                    TransactionsFilter.receive => tx.isIncoming,
                    TransactionsFilter.swap => tx.isSwap,
                    TransactionsFilter.payjoin => tx.isPayjoin,
                    TransactionsFilter.sell => false,
                    TransactionsFilter.buy => false,
                  },
                )
                .toList(),
    };

    return filtered;
  }

  bool get hasNoTransactions {
    return transactions != null || transactions!.isEmpty;
  }
}
