import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/widgets/lists/transactions_by_day_list.dart';
import 'package:bb_mobile/features/transactions/domain/entities/transaction.dart';
import 'package:bb_mobile/features/transactions/presentation/blocs/transactions_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class WalletDetailTxsList extends StatelessWidget {
  const WalletDetailTxsList({super.key});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        mainAxisSize: .min,
        children: [
          Expanded(
            child:
                BlocSelector<
                  TransactionsCubit,
                  TransactionsState,
                  ({Map<int, List<Transaction>>? txsByDay, Object? err})
                >(
                  selector: (state) => (
                    txsByDay: state.filteredTransactionsByDay,
                    err: state.err,
                  ),
                  builder: (context, selected) => TransactionsByDayList(
                    transactionsByDay: selected.txsByDay,
                    errorMessage: selected.err != null
                        ? context.loc.transactionListLoadingFailed
                        : null,
                  ),
                ),
          ),
        ],
      ),
    );
  }
}
