import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/widgets/lists/transactions_by_day_list.dart';
import 'package:bb_mobile/features/transactions/domain/entities/transaction.dart';
import 'package:bb_mobile/features/transactions/presentation/blocs/transactions_cubit.dart';
import 'package:bb_mobile/features/transactions/presentation/transaction_failure_l10n.dart';
import 'package:bb_mobile/features/transactions/ui/transactions_router.dart';
import 'package:bb_mobile/features/transactions/ui/widgets/ongoing_swaps.dart';
import 'package:bb_mobile/features/transactions/ui/widgets/tx_list_item.dart';
import 'package:bull_ui/bull_ui.dart' show BullPanel;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

class RecentTransactionsPanel extends StatelessWidget {
  const RecentTransactionsPanel({super.key, this.maxItems = 8});

  final int maxItems;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => GetIt.I<TransactionsCubit>()..loadTxs(),
      child: _Panel(maxItems: maxItems),
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({required this.maxItems});

  final int maxItems;

  Map<int, List<Transaction>>? _mostRecent(
    Map<int, List<Transaction>>? txsByDay,
  ) {
    if (txsByDay == null) return null;
    final recent = <int, List<Transaction>>{};
    var remaining = maxItems;
    for (final entry in txsByDay.entries) {
      if (remaining <= 0) break;
      final txs = entry.value.take(remaining).toList();
      recent[entry.key] = txs;
      remaining -= txs.length;
    }
    return recent;
  }

  @override
  Widget build(BuildContext context) {
    final txsByDay = context.select(
      (TransactionsCubit cubit) => cubit.state.filteredTransactionsByDay,
    );
    final ongoingSwaps = context.select(
      (TransactionsCubit cubit) => cubit.state.ongoingSwaps,
    );
    final failure = context.select(
      (TransactionsCubit cubit) => cubit.state.failure,
    );
    final refreshLabels = context.read<TransactionsCubit>().refreshLabels;

    return BullPanel(
      title: context.loc.transactionRecentTitle,
      actionLabel: context.loc.transactionRecentViewAll,
      onAction: () => context.pushNamed(TransactionsRoute.transactions.name),
      child: TransactionsByDayList<Transaction>(
        itemsByDay: _mostRecent(txsByDay),
        itemBuilder: (context, tx) => TransactionListItem.transaction(
          tx,
          onDetailsClosed: refreshLabels,
          dense: true,
        ),
        loadingMessage: context.loc.transactionListLoadingTransactions,
        emptyMessage: context.loc.transactionListNoTransactions,
        errorMessage: failure?.toTranslated(context),
        embedded: true,
        header: ongoingSwaps != null && ongoingSwaps.isNotEmpty
            ? OngoingSwapsWidget(
                ongoingSwaps: ongoingSwaps,
                onDetailsClosed: refreshLabels,
              )
            : null,
      ),
    );
  }
}
