import 'package:ark_wallet/ark_wallet.dart' as ark_wallet;
import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/themes/fonts.dart';
import 'package:bb_mobile/features/ark/ui/ark_tx_widget.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:intl/intl.dart';

class TransactionHistoryWidget extends StatelessWidget {
  const TransactionHistoryWidget({super.key, required this.transactions});

  final List<ark_wallet.Transaction> transactions;

  DateTime? _getTransactionDate(ark_wallet.Transaction tx) {
    return switch (tx) {
      ark_wallet.Transaction_Boarding(confirmedAt: final confirmedAt?) =>
        DateTime.fromMillisecondsSinceEpoch(confirmedAt * 1000),
      ark_wallet.Transaction_Commitment(createdAt: final createdAt) =>
        DateTime.fromMillisecondsSinceEpoch(createdAt * 1000),
      ark_wallet.Transaction_Redeem(createdAt: final createdAt) =>
        DateTime.fromMillisecondsSinceEpoch(createdAt * 1000),
      _ => null,
    };
  }

  Map<int, List<ark_wallet.Transaction>> _groupTransactionsByDay() {
    final Map<int, List<ark_wallet.Transaction>> grouped = {};

    for (final tx in transactions) {
      final date = _getTransactionDate(tx);
      if (date != null) {
        final dayStart = DateTime(date.year, date.month, date.day);
        final timestamp = dayStart.millisecondsSinceEpoch;

        if (!grouped.containsKey(timestamp)) {
          grouped[timestamp] = [];
        }
        grouped[timestamp]!.add(tx);
      }
    }

    final sortedEntries =
        grouped.entries.toList()..sort((a, b) => b.key.compareTo(a.key));

    return Map.fromEntries(sortedEntries);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (transactions.isEmpty) {
      return Center(
        child: Column(
          children: [
            const Gap(16),
            Text(
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
    }

    final transactionsByDay = _groupTransactionsByDay();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children:
            transactionsByDay.entries.map((entry) {
              final date = DateTime.fromMillisecondsSinceEpoch(entry.key);
              final txs = entry.value;
              final now = DateTime.now();
              final today = DateTime(now.year, now.month, now.day);
              final yesterday = DateTime(now.year, now.month, now.day - 1);

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    date.isAtSameMomentAs(today)
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
                  ...txs.map((tx) => ArkTxWidget(tx: tx)),
                  const Gap(16),
                ],
              );
            }).toList(),
      ),
    );
  }
}
