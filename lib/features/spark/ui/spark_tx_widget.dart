import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/string_formatting.dart';
import 'package:bb_mobile/core/widgets/text/text.dart';
import 'package:bb_mobile/features/bitcoin_price/ui/currency_text.dart';
import 'package:breez_sdk_spark_flutter/breez_sdk_spark.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:timeago/timeago.dart' as timeago;

class SparkTxWidget extends StatelessWidget {
  const SparkTxWidget({super.key, required this.payment, this.onTap});

  final Payment payment;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final date = DateTime.fromMillisecondsSinceEpoch(payment.timestamp.toInt() * 1000);

    final icon = switch (payment.paymentType) {
      PaymentType.send => Icons.arrow_upward,
      PaymentType.receive => Icons.arrow_downward,
    };

    final isSent = payment.paymentType == PaymentType.send;
    final amount =
        isSent
            ? -(payment.amount.toInt() + payment.fees.toInt())
            : payment.amount.toInt();

    final statusIcon = switch (payment.status) {
      PaymentStatus.pending => Icons.schedule,
      PaymentStatus.completed => Icons.check_circle,
      PaymentStatus.failed => Icons.error,
    };

    final statusColor = switch (payment.status) {
      PaymentStatus.pending => context.colour.primary,
      PaymentStatus.completed => context.colour.inverseSurface,
      PaymentStatus.failed => context.colour.error,
    };

    final description = payment.details?.whenOrNull(
      spark: () => null,
      token: (metadata, txHash) => metadata.name,
    );

    return InkWell(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8.0),
        padding: const EdgeInsets.all(16.0),
        decoration: BoxDecoration(
          color: context.colour.onPrimary,
          borderRadius: BorderRadius.circular(2.0),
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
                    amount.abs(),
                    showFiat: false,
                    style: context.font.bodyLarge,
                  ),
                  if (description != null && description.isNotEmpty)
                    Text(
                      StringFormatting.truncateMiddle(description),
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
                    color: context.colour.secondary,
                    borderRadius: BorderRadius.circular(2.0),
                  ),
                  child: BBText(
                    isSent ? 'Sent' : 'Received',
                    style: context.font.labelSmall?.copyWith(
                      color: context.colour.onSecondary,
                    ),
                  ),
                ),
                const Gap(4.0),
                Row(
                  children: [
                    BBText(
                      timeago.format(date),
                      style: context.font.labelSmall?.copyWith(
                        color: statusColor,
                      ),
                    ),
                    const Gap(4.0),
                    Icon(statusIcon, size: 12.0, color: statusColor),
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
