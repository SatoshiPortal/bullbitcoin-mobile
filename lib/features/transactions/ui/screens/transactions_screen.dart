import 'package:bb_mobile/core/transaction/domain/entities/transaction.dart';
import 'package:bb_mobile/core/wallet/domain/entity/wallet.dart';
import 'package:bb_mobile/features/bitcoin_price/ui/currency_text.dart';
import 'package:bb_mobile/features/transactions/bloc/transactions_bloc.dart';
import 'package:bb_mobile/locator.dart';
import 'package:bb_mobile/ui/components/navbar/top_bar.dart';
import 'package:bb_mobile/ui/components/text/text.dart';
import 'package:bb_mobile/ui/themes/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:timeago/timeago.dart' as timeago;

class TransactionsScreen extends StatelessWidget {
  const TransactionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => locator<TransactionsCubit>(),
      child: Scaffold(
        appBar: AppBar(
          forceMaterialTransparency: true,
          automaticallyImplyLeading: false,
          titleSpacing: 0,
          title: TopBar(
            title: 'Transactions',
            onBack: () {
              context.pop();
            },
          ),
          backgroundColor: context.colour.onPrimary,
          elevation: 0,
        ),
        body: const _Screen(),
      ),
    );
  }
}

class _Screen extends StatelessWidget {
  const _Screen();

  @override
  Widget build(BuildContext context) {
    final loading =
        context.select((TransactionsCubit cubit) => cubit.state.loadingTxs);
    final err = context.select((TransactionsCubit cubit) => cubit.state.err);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const FilterRow(),
        if (loading) const LinearProgressIndicator(),
        if (err != null)
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: BBText(
              'Error - $err',
              style: context.font.bodyLarge,
              color: context.colour.error,
            ),
          ),
        const Expanded(
          child: TxsList(),
        ),
      ],
    );
  }
}

class TxsList extends StatelessWidget {
  const TxsList({
    super.key,
  });

  (IconData, Color, String) getTxDetails(
    BuildContext context,
    Transaction tx,
  ) {
    // TODO: define DetailedTransaction entity with all the details
    const network = Network.bitcoinMainnet; //tx.network;

    IconData icon;
    Color color;
    String walletType;

    switch (network) {
      case Network.bitcoinMainnet:
      case Network.bitcoinTestnet:
        color = context.colour.onTertiary;
        walletType = 'Bitcoin';

      case Network.liquidMainnet:
      case Network.liquidTestnet:
        color = context.colour.tertiary;
        walletType = 'Liquid';
    }
    /*
    if (tx.type == TxType.lnSwap) {
      walletType = 'Lightning';
    }*/

    /*
    final type = tx.type;
    switch (type) {
      case TxtType.send:
        icon = Icons.arrow_upward;

      case TxType.receive:
        icon = Icons.arrow_downward;

      case TxType.self:
        icon = Icons.swap_horiz;

      case TxType.lnSwap:
        icon = Icons.arrow_downward;

      case TxType.chainSwap:
        icon = Icons.swap_horiz;
    }*/
    final direction = tx.direction;
    switch (direction) {
      case TransactionDirection.outgoing:
        icon = Icons.arrow_upward;
      case _:
        icon = Icons.arrow_downward;
    }

    return (icon, color, walletType);
  }

  @override
  Widget build(BuildContext context) {
    final txs = context
        .select((TransactionsCubit cubit) => cubit.state.sortedTransactions);

    final List<TxItem> txItems = [];
    if (txs.isNotEmpty) {
      for (final tx in txs) {
        final (icon, color, type) = getTxDetails(context, tx);
        String? formattedDate;
        if (tx.confirmationTime != null) {
          formattedDate = timeago.format(tx.confirmationTime!);
        }

        txItems.add(
          TxItem(
            icon: icon,
            amount: tx.amountSat,
            label: 'Label',
            date: formattedDate,
            walletType: type,
            walletColor: color,
          ),
        );
      }
    }
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      children: [
        const Gap(16.0),
        ...txItems,
      ],
    );
  }
}

class FilterRow extends StatefulWidget {
  const FilterRow({super.key});

  @override
  State<FilterRow> createState() => _FilterRowState();
}

class _FilterRowState extends State<FilterRow> {
  final List<String> filters = const [
    'All',
    'Send',
    'Receive',
    'Swap',
    'Sell',
    'Pay',
  ];
  String selectedFilter = 'All';

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Row(
        children: filters.map((filter) {
          final isSelected = filter == selectedFilter;
          return Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: FilterItem(
              title: filter,
              isSelected: isSelected,
              onTap: () {
                setState(() {
                  selectedFilter = filter;
                });
              },
            ),
          );
        }).toList(),
      ),
    );
  }
}

class FilterItem extends StatelessWidget {
  const FilterItem({
    super.key,
    required this.title,
    required this.isSelected,
    required this.onTap,
  });

  final String title;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
        decoration: BoxDecoration(
          color: isSelected ? context.colour.secondary : Colors.transparent,
          borderRadius: BorderRadius.circular(2.0),
          border: Border.all(
            color: isSelected
                ? context.colour.secondaryFixedDim
                : context.colour.outline,
          ),
        ),
        child: BBText(
          title,
          style: context.font.bodyMedium?.copyWith(
            color: isSelected
                ? context.colour.onSecondary
                : context.colour.secondary,
          ),
        ),
      ),
    );
  }
}

class TxItem extends StatelessWidget {
  const TxItem({
    super.key,
    required this.icon,
    required this.amount,
    this.label,
    required this.date,
    required this.walletType,
    required this.walletColor,
  });

  final IconData icon;
  final int amount;
  final String? label;
  final String? date;
  final String walletType;
  final Color walletColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8.0),
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: context.colour.onPrimary,
        borderRadius: BorderRadius.circular(2.0),
        boxShadow: const [],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8.0),
            decoration: BoxDecoration(
              color: context.colour.onPrimary,
              border: Border.all(
                color: context.colour.surface,
              ),
              borderRadius: BorderRadius.circular(2.0),
            ),
            child: Icon(icon, color: context.colour.secondary),
          ),
          const Gap(16.0),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CurrencyText(
                  amount,
                  showFiat: false,
                  style: context.font.bodyLarge,
                ),
                if (label != null)
                  BBText(
                    label!,
                    style: context.font.labelSmall?.copyWith(
                      color: context.colour.outline,
                    ),
                  ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 4.0, vertical: 2.0),
                decoration: BoxDecoration(
                  color: walletColor,
                  borderRadius: BorderRadius.circular(2.0),
                ),
                child: BBText(
                  walletType,
                  style: context.font.labelSmall?.copyWith(
                    color: context.colour.secondary,
                  ),
                ),
              ),
              const Gap(4.0),
              if (date != null)
                Row(
                  children: [
                    BBText(
                      date!,
                      style: context.font.labelSmall?.copyWith(
                        color: context.colour.outline,
                      ),
                    ),
                    const Gap(4.0),
                    Icon(
                      Icons.check_circle,
                      size: 12.0,
                      color: context.colour.inverseSurface,
                    ),
                  ],
                )
              else ...[
                BBText(
                  'Pending',
                  style: context.font.labelSmall?.copyWith(
                    color: context.colour.outline,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
