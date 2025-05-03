import 'package:bb_mobile/features/transactions/bloc/transactions_cubit.dart';
import 'package:bb_mobile/features/transactions/ui/widgets/tx_list_item.dart';
import 'package:bb_mobile/ui/themes/fonts.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';
import 'package:intl/intl.dart';

class TxList extends StatelessWidget {
  const TxList({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final txsByDay = context.select(
      (TransactionsCubit cubit) => cubit.state.transactionsByDay,
    );

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      itemCount: txsByDay.entries.length,
      itemBuilder: (context, index) {
        final entry = txsByDay.entries.elementAt(index);
        final date = DateTime.fromMillisecondsSinceEpoch(entry.key);
        final txs = entry.value;
        final now = DateTime.now();
        final today = DateTime(now.year, now.month, now.day);
        final yesterday = DateTime(now.year, now.month, now.day - 1);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              date.compareTo(today) > 0
                  ? 'Pending'
                  : date == today
                  ? 'Today'
                  : date == yesterday
                  ? 'Yesterday'
                  : date.year == DateTime.now().year
                  ? DateFormat.MMMMd().format(date)
                  : DateFormat.yMMMMd().format(date),
              style: AppFonts.textTheme.textTheme.titleSmall?.copyWith(
                color: theme.colorScheme.onSurface,
              ),
            ),
            const Gap(16),
            ...txs.map((tx) => TxListItem(tx: tx)),
            const Gap(16),
          ],
        );
      },
    );
  }
}
