import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/themes/fonts.dart';
import 'package:bb_mobile/core/widgets/text/text.dart';
import 'package:bb_mobile/features/transactions/domain/entities/transaction.dart';
import 'package:bb_mobile/features/transactions/ui/widgets/ongoing_swaps.dart';
import 'package:bb_mobile/features/transactions/ui/widgets/tx_list_item.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:intl/intl.dart';

class TransactionsByDayList extends StatelessWidget {
  const TransactionsByDayList({
    super.key,
    required this.transactionsByDay,
    this.ongoingSwaps,
  });

  final Map<int, List<Transaction>>? transactionsByDay;
  final List<Transaction>? ongoingSwaps;

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
    } else if (transactionsByDay!.isEmpty &&
        (ongoingSwaps == null || ongoingSwaps!.isEmpty)) {
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
        itemCount:
            transactionsByDay!.entries.length +
            (ongoingSwaps != null && ongoingSwaps!.isNotEmpty ? 1 : 0),
        itemBuilder: (context, index) {
          // Show ongoing swaps section at the top
          if (ongoingSwaps != null && ongoingSwaps!.isNotEmpty && index == 0) {
            return OngoingSwapsWidget(ongoingSwaps: ongoingSwaps!);
          }

          // Adjust index if we have ongoing swaps
          final adjustedIndex =
              ongoingSwaps != null && ongoingSwaps!.isNotEmpty
                  ? index - 1
                  : index;
          final entry = transactionsByDay!.entries.elementAt(adjustedIndex);
          final date = DateTime.fromMillisecondsSinceEpoch(entry.key);
          final txs = entry.value;
          final now = DateTime.now();
          final today = DateTime(now.year, now.month, now.day);
          final yesterday = DateTime(now.year, now.month, now.day - 1);

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              BBText(
                date.compareTo(today) > 0
                    ? 'Pending'
                    : date.isAtSameMomentAs(today)
                    ? 'Today'
                    : date.isAtSameMomentAs(yesterday)
                    ? 'Yesterday'
                    : date.year == DateTime.now().year
                    ? DateFormat.MMMMd().format(date)
                    : DateFormat.yMMMMd().format(date),
                style: context.font.titleSmall?.copyWith(
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
