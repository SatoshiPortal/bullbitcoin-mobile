import 'package:ark_wallet/ark_wallet.dart' as ark_wallet;
import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/utils/mempool_url.dart';
import 'package:bb_mobile/core/utils/string_formatting.dart';
import 'package:bb_mobile/core/widgets/badges/transaction_direction_badge.dart';
import 'package:bb_mobile/core/widgets/navbar/top_bar.dart';
import 'package:bb_mobile/core/widgets/tables/details_table.dart';
import 'package:bb_mobile/core/widgets/tables/details_table_item.dart';
import 'package:bb_mobile/core/widgets/text/text.dart';
import 'package:bb_mobile/features/bitcoin_price/ui/currency_text.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

class ArkTransactionDetailsPage extends StatelessWidget {
  const ArkTransactionDetailsPage({super.key, required this.transaction});

  final ark_wallet.Transaction transaction;

  @override
  Widget build(BuildContext context) {
    String txid;
    int sats;
    DateTime? date;
    String type;
    String statusLabel;
    bool isIncoming = true;
    bool isSwap = false;

    switch (transaction) {
      case final ark_wallet.Transaction_Boarding tx:
        txid = tx.txid;
        sats = tx.sats;
        if (tx.confirmedAt != null) {
          date = DateTime.fromMillisecondsSinceEpoch(tx.confirmedAt! * 1000);
        }
        type = context.loc.arkTxBoarding;
        statusLabel = date != null ? context.loc.arkStatusConfirmed : context.loc.arkTxPending;
      case final ark_wallet.Transaction_Commitment tx:
        txid = tx.txid;
        sats = tx.sats;
        date = DateTime.fromMillisecondsSinceEpoch(tx.createdAt * 1000);
        type = context.loc.arkTxSettlement;
        statusLabel = context.loc.arkStatusConfirmed;
        isIncoming = false;
        isSwap = true;
      case final ark_wallet.Transaction_Redeem tx:
        txid = tx.txid;
        sats = tx.sats;
        date = DateTime.fromMillisecondsSinceEpoch(tx.createdAt * 1000);
        type = context.loc.arkTxPayment;
        statusLabel = tx.isSettled ? context.loc.arkStatusSettled : context.loc.arkTxPending;
        isIncoming = false;
    }

    final isBoarding = transaction is ark_wallet.Transaction_Boarding;
    final mempoolUrl =
        isBoarding ? MempoolUrl.bitcoinTxidUrl(txid, isTestnet: false) : null;

    return Scaffold(
      appBar: AppBar(
        forceMaterialTransparency: true,
        automaticallyImplyLeading: false,
        flexibleSpace: TopBar(
          title: context.loc.arkTransactionDetails,
          actionIcon: Icons.close,
          onAction: () => context.pop(),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Center(
            child: Column(
              children: [
                TransactionDirectionBadge(
                  isIncoming: isIncoming,
                  isSwap: isSwap,
                ),
                const Gap(24),
                BBText(
                  statusLabel,
                  style: context.font.titleMedium?.copyWith(
                    color: context.appColors.textMuted,
                  ),
                ),
                const Gap(8),
                CurrencyText(
                  sats,
                  showFiat: false,
                  style: context.font.displaySmall?.copyWith(
                    color: context.appColors.onSurface,
                    fontWeight: .w500,
                  ),
                  fiatAmount: null,
                  fiatCurrency: null,
                ),
                const Gap(16),
                DetailsTable(
                  items: [
                    DetailsTableItem(
                      label: context.loc.arkTransactionId,
                      displayValue: StringFormatting.truncateMiddle(txid),
                      copyValue: txid,
                      displayWidget:
                          mempoolUrl != null
                              ? GestureDetector(
                                onTap: () async {
                                  await launchUrl(Uri.parse(mempoolUrl));
                                },
                                child: Text(
                                  StringFormatting.truncateMiddle(txid),
                                  style: TextStyle(
                                    color: context.appColors.primary,
                                  ),
                                  textAlign: .end,
                                ),
                              )
                              : null,
                    ),
                    DetailsTableItem(label: context.loc.arkType, displayValue: type),
                    DetailsTableItem(
                      label: context.loc.arkStatus,
                      displayValue: statusLabel,
                    ),
                    DetailsTableItem(
                      label: context.loc.arkAmount,
                      displayValue: '$sats ${context.loc.arkSatsUnit}',
                    ),
                    // Note: Network fee is not currently available from the ark_wallet library
                    // When the library exposes fee information, it can be added here like:
                    // if (fee != null)
                    //   DetailsTableItem(
                    //     label: 'Network Fee',
                    //     displayValue: '$fee sats',
                    //   ),
                    if (date != null)
                      DetailsTableItem(
                        label: context.loc.arkDate,
                        displayValue: DateFormat(
                          'MMM d, y, h:mm a',
                        ).format(date),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
