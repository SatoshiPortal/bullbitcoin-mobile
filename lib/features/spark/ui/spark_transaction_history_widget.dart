import 'package:bb_mobile/core/themes/fonts.dart';
import 'package:bb_mobile/features/spark/router.dart';
import 'package:bb_mobile/features/spark/ui/spark_tx_widget.dart';
import 'package:breez_sdk_spark_flutter/breez_sdk_spark.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

class SparkTransactionHistoryWidget extends StatelessWidget {
  const SparkTransactionHistoryWidget({
    super.key,
    required this.payments,
    this.isLoading = false,
  });

  final List<Payment> payments;
  final bool isLoading;

  DateTime _getPaymentDate(Payment payment) {
    return DateTime.fromMillisecondsSinceEpoch(payment.timestamp.toInt() * 1000);
  }

  Map<int, List<Payment>> _groupPaymentsByDay() {
    final Map<int, List<Payment>> grouped = {};

    for (final payment in payments) {
      final date = _getPaymentDate(payment);
      final dayStart = DateTime(date.year, date.month, date.day);
      final timestamp = dayStart.millisecondsSinceEpoch;

      if (!grouped.containsKey(timestamp)) {
        grouped[timestamp] = [];
      }
      grouped[timestamp]!.add(payment);
    }

    final sortedEntries =
        grouped.entries.toList()..sort((a, b) => b.key.compareTo(a.key));

    return Map.fromEntries(sortedEntries);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (!isLoading && payments.isEmpty) {
      return Center(
        child: Column(
          children: [
            const Gap(16),
            Text(
              'No payments yet.',
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

    final paymentsByDay = _groupPaymentsByDay();

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      itemCount: paymentsByDay.entries.length,
      itemBuilder: (context, index) {
        final entry = paymentsByDay.entries.elementAt(index);
        final date = DateTime.fromMillisecondsSinceEpoch(entry.key);
        final payments = entry.value;
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
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.outline,
              ),
            ),
            const Gap(8),
            ...payments.map(
              (payment) => SparkTxWidget(
                payment: payment,
                onTap: () {
                  context.pushNamed(
                    SparkRoute.sparkPaymentDetails.name,
                    extra: payment,
                  );
                },
              ),
            ),
            const Gap(16),
          ],
        );
      },
    );
  }
}
