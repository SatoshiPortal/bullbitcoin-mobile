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
        mainAxisSize: MainAxisSize.min,
        children: [
          Expanded(
            child: BlocSelector<
              TransactionsCubit,
              TransactionsState,
              Map<int, List<Transaction>>?
            >(
              selector: (state) => state.filteredTransactionsByDay,
              builder:
                  (context, txsByDay) =>
                      TransactionsByDayList(transactionsByDay: txsByDay),
            ),
          ),
        ],
      ),
    );
  }
}
