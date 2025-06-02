import 'package:bb_mobile/features/transactions/domain/entities/transaction.dart';
import 'package:bb_mobile/features/transactions/ui/widgets/tx_list_item.dart';
import 'package:bb_mobile/ui/components/text/text.dart';
import 'package:bb_mobile/ui/themes/fonts.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:intl/intl.dart';

class TransactionsByDayList extends StatelessWidget {
  const TransactionsByDayList({super.key, required this.transactionsByDay});

  final Map<int, List<Transaction>>? transactionsByDay;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (transactionsByDay == null) {
      return Center(
        child: Column(
          children: [
            const Gap(16),
            BBText(
              'Loading transactions...',
              maxLines: 2,
              textAlign: TextAlign.center,
              style: AppFonts.textTheme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface,
              ),
            ),
          ],
        ),
      );
    } else if (transactionsByDay!.isEmpty) {
      return Center(
        child: Column(
          children: [
            const Gap(16),
            BBText(
              'No transactions yet.',
              maxLines: 2,
              textAlign: TextAlign.center,
              style: AppFonts.textTheme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface,
              ),
            ),
          ],
        ),
      );
    } else {
      return ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
        itemCount: transactionsByDay!.entries.length,
        itemBuilder: (context, index) {
          final entry = transactionsByDay!.entries.elementAt(index);
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
}
