import 'package:transactions/src/presentation/transactions_localizations_x.dart';
import 'package:bull_ui/bull_ui.dart' show BullTransactionsByDayList;
import 'package:transactions/src/domain/entities/transaction.dart';
import 'package:transactions/src/domain/transaction_failure.dart';
import 'package:transactions/src/presentation/blocs/transactions_cubit.dart';
import 'package:transactions/src/presentation/transaction_failure_l10n.dart';
import 'package:transactions/src/domain/entities/transaction_history.dart';
import 'package:transactions/src/ui/widgets/exchange_orders_notice.dart';
import 'package:transactions/src/ui/widgets/ongoing_swaps.dart';
import 'package:transactions/src/ui/widgets/tx_list_item.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class WalletDetailTxsList extends StatelessWidget {
  const WalletDetailTxsList({super.key, this.sliver = false});

  final bool sliver;

  @override
  Widget build(BuildContext context) {
    return BlocSelector<
      TransactionsCubit,
      TransactionsState,
      ({
        Map<int, List<Transaction>>? txsByDay,
        List<Transaction>? ongoingSwaps,
        TransactionFailure? failure,
        ExchangeOrdersInHistory? exchangeOrders,
      })
    >(
      selector: (state) => (
        txsByDay: state.filteredTransactionsByDay,
        ongoingSwaps: state.ongoingSwaps,
        failure: state.failure,
        exchangeOrders: state.exchangeOrders,
      ),
      builder: (context, selected) {
        final refreshLabels = context.read<TransactionsCubit>().refreshLabels;
        final ongoingSwaps = selected.ongoingSwaps;
        final hasOngoingSwaps = ongoingSwaps != null && ongoingSwaps.isNotEmpty;
        final showsNotice = ExchangeOrdersNotice.shows(selected.exchangeOrders);

        return BullTransactionsByDayList<Transaction>(
          itemsByDay: selected.txsByDay,
          itemBuilder: (context, tx) => TransactionListItem.transaction(
            tx,
            onDetailsClosed: refreshLabels,
          ),
          loadingMessage: context.loc.transactionListLoadingTransactions,
          pendingLabel: context.loc.transactionListPending,
          todayLabel: context.loc.transactionListToday,
          yesterdayLabel: context.loc.transactionListYesterday,
          emptyMessage: context.loc.transactionListNoTransactions,
          header: hasOngoingSwaps || showsNotice
              ? Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (showsNotice) const ExchangeOrdersNotice(),
                    if (hasOngoingSwaps)
                      OngoingSwapsWidget(
                        ongoingSwaps: ongoingSwaps,
                        onDetailsClosed: refreshLabels,
                      ),
                  ],
                )
              : null,
          errorMessage: selected.failure?.toTranslated(context),
          sliver: sliver,
        );
      },
    );
  }
}
