import 'package:ark_wallet/ark_wallet.dart' as ark_wallet;
import 'package:bb_mobile/core/themes/fonts.dart';
import 'package:bb_mobile/core/widgets/text/text.dart';
import 'package:bb_mobile/features/ark/ui/ark_tx_widget.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

class TransactionHistoryWidget extends StatelessWidget {
  const TransactionHistoryWidget({super.key, required this.transactions});

  final List<ark_wallet.Transaction> transactions;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (transactions.isEmpty) {
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
        itemCount: transactions.length,
        itemBuilder: (context, index) {
          final tx = transactions[index];
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [const Gap(16), ArkTxWidget(tx: tx), const Gap(16)],
          );
        },
      );
    }
  }
}
