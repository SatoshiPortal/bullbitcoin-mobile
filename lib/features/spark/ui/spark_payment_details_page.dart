import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/string_formatting.dart';
import 'package:bb_mobile/core/widgets/badges/transaction_direction_badge.dart';
import 'package:bb_mobile/core/widgets/navbar/top_bar.dart';
import 'package:bb_mobile/core/widgets/tables/details_table.dart';
import 'package:bb_mobile/core/widgets/tables/details_table_item.dart';
import 'package:bb_mobile/core/widgets/text/text.dart';
import 'package:bb_mobile/features/bitcoin_price/ui/currency_text.dart';
import 'package:breez_sdk_spark_flutter/breez_sdk_spark.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

class SparkPaymentDetailsPage extends StatelessWidget {
  const SparkPaymentDetailsPage({super.key, required this.payment});

  final Payment payment;

  @override
  Widget build(BuildContext context) {
    final date = DateTime.fromMillisecondsSinceEpoch(
      payment.timestamp.toInt() * 1000,
    );

    final isSent = payment.paymentType == PaymentType.send;
    const isSwap = false; // todo: check this later

    final statusLabel = switch (payment.status) {
      PaymentStatus.pending => 'Pending',
      PaymentStatus.completed => 'Completed',
      PaymentStatus.failed => 'Failed',
    };

    final typeLabel = switch (payment.paymentType) {
      PaymentType.send => 'Sent',
      PaymentType.receive => 'Received',
    };

    final amountSats = payment.amount.toInt();
    final feeSats = payment.fees.toInt();
    final totalSats = isSent ? amountSats + feeSats : amountSats;

    final description = payment.details?.whenOrNull(
      spark: () => null,
      token: (metadata, txHash) => metadata.name,
    );

    return Scaffold(
      appBar: AppBar(
        forceMaterialTransparency: true,
        automaticallyImplyLeading: false,
        flexibleSpace: TopBar(
          title: 'Payment details',
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
                TransactionDirectionBadge(isIncoming: !isSent, isSwap: isSwap),
                const Gap(24),
                BBText(
                  statusLabel,
                  style: context.font.titleMedium?.copyWith(
                    color: context.colour.outline,
                  ),
                ),
                const Gap(8),
                CurrencyText(
                  totalSats,
                  showFiat: false,
                  style: context.font.displaySmall?.copyWith(
                    color: context.colour.outlineVariant,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const Gap(16),
                DetailsTable(
                  items: [
                    DetailsTableItem(
                      label: 'Payment ID',
                      displayValue: StringFormatting.truncateMiddle(payment.id),
                      copyValue: payment.id,
                    ),
                    DetailsTableItem(label: 'Type', displayValue: typeLabel),
                    DetailsTableItem(
                      label: 'Status',
                      displayValue: statusLabel,
                    ),
                    DetailsTableItem(
                      label: 'Amount',
                      displayValue: '$amountSats sats',
                    ),
                    if (feeSats > 0)
                      DetailsTableItem(
                        label: 'Fee',
                        displayValue: '$feeSats sats',
                      ),
                    if (isSent && feeSats > 0)
                      DetailsTableItem(
                        label: 'Total',
                        displayValue: '$totalSats sats',
                      ),
                    if (description != null && description.isNotEmpty)
                      DetailsTableItem(
                        label: 'Description',
                        displayValue: description,
                      ),
                    DetailsTableItem(
                      label: 'Date',
                      displayValue: DateFormat('MMM d, y, h:mm a').format(date),
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
