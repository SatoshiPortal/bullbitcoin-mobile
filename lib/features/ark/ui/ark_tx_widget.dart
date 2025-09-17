import 'package:ark_wallet/ark_wallet.dart' as ark_wallet;
import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/mempool_url.dart';
import 'package:bb_mobile/core/utils/string_formatting.dart';
import 'package:bb_mobile/core/widgets/tables/details_table_item.dart';
import 'package:bb_mobile/core/widgets/text/text.dart';
import 'package:bb_mobile/features/bitcoin_price/ui/currency_text.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
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

    return Container(
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
              Row(
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
                  const Gap(8.0),
                  CurrencyText(
                    sats,
                    showFiat: false,
                    style: context.font.bodyLarge,
                    fiatAmount: null,
                    fiatCurrency: null,
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.all(8.0),
                decoration: BoxDecoration(
                  color: context.colour.secondary,
                  borderRadius: BorderRadius.circular(2.0),
                ),
                child: BBText(
                  transactionType.name,
                  style: context.font.labelMedium?.copyWith(
                    color: context.colour.onSecondary,
                  ),
                ),
              ),
            ],
          ),

          // Container(
          //   padding: const EdgeInsets.all(5.0),
          //   decoration: BoxDecoration(
          //     color: context.colour.secondary,
          //     borderRadius: BorderRadius.circular(2.0),
          //   ),
          //   child:
          // ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              const Gap(4.0),
              if (date != null)
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    BBText(
                      timeago.format(date),
                      style: context.font.labelSmall?.copyWith(
                        color: context.colour.outline,
                      ),
                    ),
                  ],
                ),

              if (tx is ark_wallet.Transaction_Boarding)
                DetailsTableItem(
                  label: 'Transaction ID',
                  displayValue: StringFormatting.truncateMiddle(txid),
                  copyValue: txid,
                  displayWidget: GestureDetector(
                    onTap: () async {
                      await launchUrl(
                        Uri.parse(
                          MempoolUrl.bitcoinTxidUrl(txid, isTestnet: false),
                        ),
                      );
                    },
                    child: Text(
                      StringFormatting.truncateMiddle(txid),
                      style: TextStyle(color: context.colour.primary),
                      textAlign: TextAlign.end,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
