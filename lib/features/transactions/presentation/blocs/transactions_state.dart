part of 'transactions_cubit.dart';

enum TransactionsFilter { all, send, receive, swap, payjoin, sell, buy }

@freezed
abstract class TransactionsState with _$TransactionsState {
  const factory TransactionsState({
    String? walletId,
    List<Transaction>? transactions,
    @Default(false) bool isSyncing,
    @Default(TransactionsFilter.all) TransactionsFilter filter,
    Object? err,
  }) = _TransactionsState;
  const TransactionsState._();

  Map<int, List<Transaction>>? get transactionsByDay {
    if (transactions == null) {
      return null;
    }

    final Map<int, List<Transaction>> grouped = {};

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
    final sorted = SplayTreeMap<int, List<Transaction>>.from(
      grouped,
      (a, b) => b.compareTo(a), // descending key sort
    );

    return LinkedHashMap<int, List<Transaction>>.from(sorted);
  }

  Map<int, List<Transaction>>? get filteredTransactionsByDay {
    if (transactionsByDay == null) {
      return null;
    }

    final filtered = {
      for (final key in transactionsByDay!.keys)
        key:
            transactionsByDay![key]!.where((tx) {
              // We don't want to show:
              // - receive payjoin transactions that didn't get a request from the sender yet.
              // - expired or failed swaps.
              final isReceivePayjoinWithoutRequest =
                  tx.isOngoingPayjoinReceiver &&
                  tx.payjoin!.status == PayjoinStatus.started;
              final isExpiredOrFailedSwap =
                  tx.isSwap &&
                  [
                    SwapStatus.pending,
                    SwapStatus.expired,
                    SwapStatus.failed,
                  ].contains(tx.swap!.status);
              // We also only want to show the incoming side of a chain swap,
              //  unless in specific sending wallet overview or with the 'send'
              //  filter selected.
              final isOutgoingChainSwap =
                  tx.isChainSwap &&
                  tx.walletTransaction?.isOutgoing == true &&
                  tx.swap!.receiveTxId != null;

              return !isReceivePayjoinWithoutRequest &&
                  !isExpiredOrFailedSwap &&
                  switch (filter) {
                    TransactionsFilter.all =>
                      (!isOutgoingChainSwap ||
                          walletId == tx.walletTransaction?.walletId),
                    TransactionsFilter.send => tx.isOutgoing,
                    TransactionsFilter.receive => tx.isIncoming,
                    TransactionsFilter.swap =>
                      tx.isSwap &&
                          (!isOutgoingChainSwap ||
                              walletId == tx.walletTransaction?.walletId),
                    TransactionsFilter.payjoin =>
                      tx.isPayjoin &&
                          (!isOutgoingChainSwap ||
                              walletId == tx.walletTransaction?.walletId),
                    TransactionsFilter.sell => tx.isSellOrder,
                    TransactionsFilter.buy => tx.isBuyOrder,
                  };
            }).toList(),
    };

    filtered.removeWhere((key, value) => value.isEmpty);

    return filtered;
  }

  bool get hasNoTransactions {
    return transactions != null || transactions!.isEmpty;
  }
}

/*
  Payjoin? payjoin;
            try {
              final payjoinModel = payjoins.firstWhere(
                (payjoin) => payjoin.txId == walletTransactionModel.txId,
              );
              payjoin = payjoinModel.toEntity();
            } catch (_) {
              // Transaction is not a payjoin
              payjoin = null;
            }

            Swap? swap;
            try {
              final swapModel = swaps.firstWhere((swap) {
                switch (swap) {
                  case LnReceiveSwapModel _:
                    return swap.receiveTxid == walletTransactionModel.txId;
                  case LnSendSwapModel _:
                    return swap.sendTxid == walletTransactionModel.txId;
                  case ChainSwapModel _:
                    if (walletTransactionModel.isIncoming) {
                      return swap.receiveTxid == walletTransactionModel.txId;
                    } else {
                      return swap.sendTxid == walletTransactionModel.txId;
                    }
                }
              });
              swap = swapModel.toEntity();
            } catch (_) {
              // Transaction is not a swap
              swap = null;
            }
*/

/*
final broadcastedBitcoinTxIds = broadcastedTransactions
          .whereType<BitcoinWalletTransaction>()
          .map((tx) => tx.txId);

      final walletTransactions = [
        ...broadcastedTransactions,
        ...ongoingPayjoinTransactions.where(
          (tx) =>
              !broadcastedBitcoinTxIds.contains(tx.payjoin!.txId) &&
              !broadcastedBitcoinTxIds.contains(tx.payjoin!.originalTxId),
        ),
      ];*/
