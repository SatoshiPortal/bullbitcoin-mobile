import 'package:ark_wallet/ark_wallet.dart' as ark_wallet;
import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/widgets/text/text.dart';
import 'package:bb_mobile/features/bitcoin_price/ui/currency_text.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

enum ArkTransactionType { boarding, commitment, redeem }

class ArkTxWidget extends StatelessWidget {
  const ArkTxWidget({super.key, required this.tx});

  final ark_wallet.Transaction tx;

  @override
  Widget build(BuildContext context) {
    DateTime? date;
    ArkTransactionType transactionType;
    String txid;
    int sats;
    switch (tx) {
      case final ark_wallet.Transaction_Boarding tx:
        if (tx.confirmedAt != null) {
          date = DateTime.fromMillisecondsSinceEpoch(tx.confirmedAt! * 1000);
        }
        transactionType = ArkTransactionType.boarding;
        sats = tx.sats;
        txid = tx.txid;
      case final ark_wallet.Transaction_Commitment tx:
        date = DateTime.fromMillisecondsSinceEpoch(tx.createdAt * 1000);
        transactionType = ArkTransactionType.commitment;
        sats = tx.sats;
        txid = tx.txid;
      case final ark_wallet.Transaction_Redeem tx:
        date = DateTime.fromMillisecondsSinceEpoch(tx.createdAt * 1000);
        transactionType = ArkTransactionType.redeem;
        sats = tx.sats;
        txid = tx.txid;
    }

    final icon = switch (transactionType) {
      ArkTransactionType.boarding => Icons.upcoming,
      ArkTransactionType.commitment => Icons.commit,
      ArkTransactionType.redeem => Icons.redeem,
    };
    final walletColor = context.colour.primary;

    return InkWell(
      onTap: () {
        // if (tx.walletTransaction != null) {
        //   context.pushNamed(
        //     TransactionsRoute.transactionDetails.name,
        //     pathParameters: {'txId': tx.walletTransaction!.txId},
        //     queryParameters: {'walletId': tx.walletTransaction!.walletId},
        //   );
        //   return;
        // }
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 8.0),
        padding: const EdgeInsets.all(16.0),
        decoration: BoxDecoration(
          color: context.colour.onPrimary,
          borderRadius: BorderRadius.circular(2.0),
          boxShadow: const [],
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
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

                CurrencyText(
                  sats,
                  showFiat: false,
                  style: context.font.bodyLarge,
                  fiatAmount: null,
                  fiatCurrency: null,
                ),

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
                    transactionType.name,
                    style: context.font.labelSmall?.copyWith(
                      color: context.colour.secondary,
                    ),
                  ),
                ),
              ],
            ),

            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                const Gap(4.0),
                if (date != null)
                  Row(
                    children: [
                      BBText(
                        date.toIso8601String(),
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
                  ),
                BBText(
                  txid,
                  style: context.font.labelSmall?.copyWith(
                    color: context.colour.outline,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
