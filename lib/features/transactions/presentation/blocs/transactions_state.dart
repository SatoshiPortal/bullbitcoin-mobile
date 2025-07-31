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

  /// Extracts ongoing swaps from transactions
  List<Transaction>? get ongoingSwaps {
    final txList = transactions;
    if (txList == null) return null;

    final ongoingList = <Transaction>[];
    for (final tx in txList) {
      // Show swaps where funds are truly in transit/locked up - not yet reached final outcome
      if (tx.isSwap &&
          tx.swap != null &&
          [
            SwapStatus.paid,
            SwapStatus.claimable,
            SwapStatus.refundable,
            SwapStatus.canCoop,
          ].contains(tx.swap?.status)) {
        ongoingList.add(tx);
      }
    }

    // Sort by timestamp, newest first
    ongoingList.sort((a, b) {
      final aTime = a.timestamp ?? DateTime.fromMillisecondsSinceEpoch(0);
      final bTime = b.timestamp ?? DateTime.fromMillisecondsSinceEpoch(0);
      return bTime.compareTo(aTime);
    });

    return ongoingList;
  }

  Map<int, List<Transaction>>? get transactionsByDay {
    final txList = transactions;
    if (txList == null) return null;

    final Map<int, List<Transaction>> grouped = {};

    for (final tx in txList) {
      // Pending transactions can't be assigned to a specific day yet, since
      // they are in the future we assign them to a day that is always
      // greater than any other day. This way they will always be at the top
      // of the list when sorted by date.
      final day =
          tx.timestamp == null
              ? 8640000000000000 // Max milliseconds value for DateTime
              : DateTime(
                tx.timestamp!.year,
                tx.timestamp!.month,
                tx.timestamp!.day,
              ).millisecondsSinceEpoch;
      grouped.putIfAbsent(day, () => []).add(tx);
    }

    // Sort transactions inside each day (newest first)
    for (final txs in grouped.values) {
      txs.sort((a, b) {
        final aTime = a.timestamp ?? DateTime.fromMillisecondsSinceEpoch(0);
        final bTime = b.timestamp ?? DateTime.fromMillisecondsSinceEpoch(0);
        return bTime.compareTo(aTime); // descending
      });
    }

    // Sort days in descending order and preserve order with LinkedHashMap
    final sorted = SplayTreeMap<int, List<Transaction>>.from(
      grouped,
      (a, b) => b.compareTo(a), // descending key sort
    );

    return LinkedHashMap<int, List<Transaction>>.from(sorted);
  }

  Map<int, List<Transaction>>? get filteredTransactionsByDay {
    final txByDay = transactionsByDay;
    if (txByDay == null) return null;

    final filtered = <int, List<Transaction>>{};

    for (final entry in txByDay.entries) {
      final filteredTxs =
          entry.value.where((tx) {
            // Skip ongoing swaps as they will be shown in their own section
            if (tx.isOngoingSwap) {
              return false;
            }

            // We don't want to show:
            // - receive payjoin transactions that didn't get a request from the sender yet.
            // - expired or failed swaps.
            final isReceivePayjoinWithoutRequest =
                tx.isOngoingPayjoinReceiver &&
                tx.payjoin?.status == PayjoinStatus.started;

            final isExpiredOrFailedSwap =
                tx.isSwap &&
                [
                  SwapStatus.expired,
                  SwapStatus.failed,
                ].contains(tx.swap?.status);

            final isExpiredAndNotStartedOrder =
                tx.isOrder &&
                (tx.order?.orderStatus == OrderStatus.expired &&
                    tx.order?.payinStatus == OrderPayinStatus.notStarted);

            if (isReceivePayjoinWithoutRequest ||
                isExpiredOrFailedSwap ||
                isExpiredAndNotStartedOrder) {
              return false;
            }

            // We also only want to show the incoming side of a chain swap,
            // unless in specific sending wallet overview or with the 'send'
            // filter selected.
            final isLockupChainSwap =
                tx.isChainSwap &&
                tx.walletTransaction?.isOutgoing == true &&
                tx.swap?.receiveTxId != null;

            // For swap-only chain swap transactions (no walletTransaction),
            // we need to determine direction based on the current wallet context
            final isSwapOnlyLockupChainSwap =
                tx.isChainSwap &&
                tx.walletTransaction == null &&
                tx.swap?.receiveTxId != null &&
                walletId == (tx.swap as ChainSwap?)?.sendWalletId;

            final shouldFilterOutgoingChainSwap =
                (isLockupChainSwap || isSwapOnlyLockupChainSwap) &&
                walletId != tx.walletTransaction?.walletId &&
                walletId != (tx.swap as ChainSwap?)?.sendWalletId;

            return switch (filter) {
              TransactionsFilter.all => !shouldFilterOutgoingChainSwap,
              TransactionsFilter.send => tx.isOutgoing,
              TransactionsFilter.receive => tx.isIncoming,
              TransactionsFilter.swap =>
                tx.isSwap && !shouldFilterOutgoingChainSwap,
              TransactionsFilter.payjoin =>
                tx.isPayjoin && !shouldFilterOutgoingChainSwap,
              TransactionsFilter.sell => tx.isSellOrder,
              TransactionsFilter.buy => tx.isBuyOrder,
            };
          }).toList();

      if (filteredTxs.isNotEmpty) {
        filtered[entry.key] = filteredTxs;
      }
    }

    return filtered;
  }

  bool get hasNoTransactions {
    return transactions == null || transactions!.isEmpty;
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
