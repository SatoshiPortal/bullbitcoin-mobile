import 'package:bb_mobile/core/utils/build_context_x.dart';
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
    final state = context.select((TransactionsCubit cubit) => cubit.state);
    final selectedFilter = state.filter;
    final availableFilters = state.availableFilters;
    return SingleChildScrollView(
      scrollDirection: .horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Row(
        children:
            availableFilters.map((filter) {
              return Padding(
                padding: const EdgeInsets.only(right: 8.0),
                child: TxsFilterItem(
                  title: switch (filter) {
                    TransactionsFilter.all => context.loc.transactionFilterAll,
                    TransactionsFilter.send => context.loc.transactionFilterSend,
                    TransactionsFilter.receive =>
                      context.loc.transactionFilterReceive,
                    TransactionsFilter.swap =>
                      context.loc.transactionFilterTransfer,
                    TransactionsFilter.payjoin =>
                      context.loc.transactionFilterPayjoin,
                    TransactionsFilter.sell => context.loc.transactionFilterSell,
                    TransactionsFilter.buy => context.loc.transactionFilterBuy,
                    TransactionsFilter.withdraw =>
                      context.loc.transactionFilterWithdraw,
                    TransactionsFilter.pay => context.loc.transactionFilterPay,
                    TransactionsFilter.funding =>
                      context.loc.transactionFilterFunding,
                    TransactionsFilter.reward =>
                      context.loc.transactionFilterReward,
                    TransactionsFilter.refund =>
                      context.loc.transactionFilterRefund,
                    TransactionsFilter.balanceAdjustment =>
                      context.loc.transactionFilterBalanceAdjustment,
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
