import 'package:ark_wallet/ark_wallet.dart' as ark_wallet;
import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/mempool_url.dart';
import 'package:bb_mobile/core/utils/string_formatting.dart';
import 'package:bb_mobile/core/widgets/text/text.dart';
import 'package:bb_mobile/features/ark/router.dart';
import 'package:bb_mobile/features/bitcoin_price/ui/currency_text.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:url_launcher/url_launcher.dart';

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
      ArkTransactionType.boarding => Icons.flight_takeoff,
      ArkTransactionType.commitment => Icons.commit,
      ArkTransactionType.redeem => Icons.redeem,
    };

    return InkWell(
      onTap: () {
        context.pushNamed(ArkRoute.arkTransactionDetails.name, extra: tx);
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
                borderRadius: BorderRadius.circular(2.0),
                border: Border.all(color: context.colour.surface),
              ),
              child: Icon(icon, color: context.colour.secondary),
            ),
            const Gap(16.0),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CurrencyText(
                    sats,
                    showFiat: false,
                    style: context.font.bodyLarge,
                    fiatAmount: null,
                    fiatCurrency: null,
                  ),
                  if (tx is ark_wallet.Transaction_Boarding)
                    GestureDetector(
                      onTap: () async {
                        await launchUrl(
                          Uri.parse(
                            MempoolUrl.bitcoinTxidUrl(txid, isTestnet: false),
                          ),
                        );
                      },
                      child: Text(
                        StringFormatting.truncateMiddle(txid),
                        style: context.font.labelSmall?.copyWith(
                          color: context.colour.primary,
                        ),
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
                    color: context.colour.secondary,
                    borderRadius: BorderRadius.circular(2.0),
                  ),
                  child: BBText(
                    StringFormatting.capitalize(transactionType.name),
                    style: context.font.labelSmall?.copyWith(
                      color: context.colour.onSecondary,
                    ),
                  ),
                ),
                const Gap(4.0),
                if (date != null)
                  Row(
                    children: [
                      BBText(
                        timeago.format(date),
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
                else if (tx is ark_wallet.Transaction_Boarding)
                  Row(
                    children: [
                      BBText(
                        'Pending',
                        style: context.font.labelSmall?.copyWith(
                          color: context.colour.primary,
                        ),
                      ),
                      const Gap(4.0),
                      Icon(
                        Icons.schedule,
                        size: 12.0,
                        color: context.colour.primary,
                      ),
                    ],
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
