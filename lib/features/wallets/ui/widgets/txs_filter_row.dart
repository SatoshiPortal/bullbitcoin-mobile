import 'package:bb_mobile/features/transactions/presentation/blocs/transactions_cubit.dart';
import 'package:bb_mobile/features/transactions/ui/widgets/txs_filter_item.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class TxsFilterRow extends StatefulWidget {
  const TxsFilterRow({super.key});

  @override
  State<TxsFilterRow> createState() => _TxsFilterRowState();
}

class _TxsFilterRowState extends State<TxsFilterRow> {
  @override
  Widget build(BuildContext context) {
    final selectedFilter = context.select(
      (TransactionsCubit cubit) => cubit.state.filter,
    );
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Row(
        children:
            TransactionsFilter.values.map((filter) {
              return Padding(
                padding: const EdgeInsets.only(right: 8.0),
                child: TxsFilterItem(
                  title: switch (filter) {
                    TransactionsFilter.all => 'All',
                    TransactionsFilter.send => 'Send',
                    TransactionsFilter.receive => 'Receive',
                    TransactionsFilter.swap => 'Transfer',
                    TransactionsFilter.payjoin => 'Payjoin',
                    TransactionsFilter.sell => 'Sell',
                    TransactionsFilter.buy => 'Buy',
                  },
                  isSelected: selectedFilter == filter,
                  onTap: () {
                    context.read<TransactionsCubit>().setFilter(filter);
                  },
                ),
              );
            }).toList(),
      ),
    );
  }
}
