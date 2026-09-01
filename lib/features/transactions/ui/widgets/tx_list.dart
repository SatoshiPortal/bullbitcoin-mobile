import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/widgets/lists/transactions_by_day_list.dart';
import 'package:bb_mobile/features/transactions/domain/entities/transaction.dart';
import 'package:bb_mobile/features/transactions/presentation/blocs/transactions_cubit.dart';
import 'package:bb_mobile/features/transactions/ui/widgets/ongoing_swaps.dart';
import 'package:bb_mobile/features/transactions/ui/widgets/tx_list_item.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class TxList extends StatelessWidget {
  const TxList({super.key, this.sliver = false});

  final bool sliver;

  @override
  Widget build(BuildContext context) {
    final txsByDay = context.select(
      (TransactionsCubit cubit) => cubit.state.filteredTransactionsByDay,
    );

    final ongoingSwaps = context.select(
      (TransactionsCubit cubit) => cubit.state.ongoingSwaps,
    );

    final err = context.select((TransactionsCubit cubit) => cubit.state.err);

    final refreshLabels = context.read<TransactionsCubit>().refreshLabels;

    if (err != null) {
      return TransactionsByDayList<Transaction>(
        itemsByDay: const {},
        itemBuilder: (context, tx) =>
            TransactionListItem.transaction(tx, onDetailsClosed: refreshLabels),
        loadingMessage: context.loc.transactionListLoadingTransactions,
        emptyMessage: context.loc.transactionListNoTransactions,
        errorMessage: context.loc.transactionListLoadingFailed,
        sliver: sliver,
      );
    }

    final filter = context.select(
      (TransactionsCubit cubit) => cubit.state.filter,
    );

    // Ongoing swaps are only relevant when browsing all transactions or
    // filtering by swap, so hide them under unrelated filters (payjoin, send,
    // receive, sell, buy, …) and they don't bleed into the wrong category.
    final showOngoingSwaps =
        filter == TransactionsFilter.all || filter == TransactionsFilter.swap;

    return TransactionsByDayList<Transaction>(
      itemsByDay: txsByDay,
      itemBuilder: (context, tx) =>
          TransactionListItem.transaction(tx, onDetailsClosed: refreshLabels),
      loadingMessage: context.loc.transactionListLoadingTransactions,
      emptyMessage: context.loc.transactionListNoTransactions,
      header:
          showOngoingSwaps && ongoingSwaps != null && ongoingSwaps.isNotEmpty
          ? OngoingSwapsWidget(
              ongoingSwaps: ongoingSwaps,
              onDetailsClosed: refreshLabels,
            )
          : null,
      sliver: sliver,
    );
  }
}
