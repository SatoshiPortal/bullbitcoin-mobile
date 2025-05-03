import 'package:bb_mobile/core/wallet/domain/entities/wallet_transaction.dart';
import 'package:bb_mobile/features/bitcoin_price/ui/currency_text.dart';
import 'package:bb_mobile/features/transactions/ui/transactions_router.dart';
import 'package:bb_mobile/ui/components/text/text.dart';
import 'package:bb_mobile/ui/themes/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:timeago/timeago.dart' as timeago;

class TxListItem extends StatelessWidget {
  const TxListItem({super.key, required this.tx});

  final WalletTransaction tx;

  @override
  Widget build(BuildContext context) {
    final icon =
        tx.direction == WalletTransactionDirection.outgoing
            ? Icons.arrow_upward
            : Icons.arrow_downward;
    final walletColor =
        tx is BitcoinWalletTransaction
            ? context.colour.onTertiary
            : context.colour.tertiary;
    final walletType = tx is BitcoinWalletTransaction ? 'Bitcoin' : 'Liquid';
    final label = tx.labels.isNotEmpty ? tx.labels.first : null;
    final date =
        tx.confirmationTime != null
            ? timeago.format(tx.confirmationTime!)
            : null;

    return InkWell(
      onTap: () {
        context.pushNamed(TransactionsRoute.transactionDetails.name, extra: tx);
      },
      child: Container(
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
                border: Border.all(color: context.colour.surface),
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
                    tx.amountSat,
                    showFiat: false,
                    style: context.font.bodyLarge,
                  ),
                  if (label != null)
                    BBText(
                      label,
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
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4.0,
                    vertical: 2.0,
                  ),
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
                        date,
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
      ),
    );
  }
}
