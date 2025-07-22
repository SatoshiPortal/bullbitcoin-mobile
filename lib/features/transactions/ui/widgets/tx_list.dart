import 'package:bb_mobile/core/widgets/lists/transactions_by_day_list.dart';
import 'package:bb_mobile/features/transactions/presentation/blocs/transactions_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class TxList extends StatelessWidget {
  const TxList({super.key});

  @override
  Widget build(BuildContext context) {
    final txsByDay = context.select(
      (TransactionsCubit cubit) => cubit.state.filteredTransactionsByDay,
    );

    final ongoingSwaps = context.select(
      (TransactionsCubit cubit) => cubit.state.ongoingSwaps,
    );

    return TransactionsByDayList(
      transactionsByDay: txsByDay,
      ongoingSwaps: ongoingSwaps,
    );
  }
}
