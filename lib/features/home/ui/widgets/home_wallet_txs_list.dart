import 'package:bb_mobile/features/transactions/blocs/transactions_cubit.dart';
import 'package:bb_mobile/ui/components/lists/transactions_by_day_list.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class HomeWalletTxsList extends StatelessWidget {
  const HomeWalletTxsList({super.key});

  @override
  Widget build(BuildContext context) {
    final txsByDay = context.select(
      (TransactionsCubit cubit) => cubit.state.transactionsByDay,
    );

    return Expanded(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Expanded(child: TransactionsByDayList(transactionsByDay: txsByDay)),
        ],
      ),
    );
  }
}
