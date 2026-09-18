import 'package:bb_mobile/core/widgets/lists/transactions_by_day_list.dart';
import 'package:bb_mobile/features/transactions/domain/entities/transaction.dart';
import 'package:bb_mobile/features/transactions/domain/transaction_failure.dart';
import 'package:bb_mobile/features/transactions/presentation/blocs/transactions_cubit.dart';
import 'package:bb_mobile/features/transactions/presentation/transaction_failure_l10n.dart';
import 'package:flutter/material.dart';
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
      })
    >(
      selector: (state) => (
        txsByDay: state.filteredTransactionsByDay,
        ongoingSwaps: state.ongoingSwaps,
        failure: state.failure,
      ),
      builder: (context, selected) => TransactionsByDayList(
        transactionsByDay: selected.txsByDay,
        ongoingSwaps: selected.ongoingSwaps,
        errorMessage: selected.failure?.toTranslated(context),
        sliver: sliver,
        onDetailsClosed: context.read<TransactionsCubit>().refreshLabels,
      ),
    );
  }
}
