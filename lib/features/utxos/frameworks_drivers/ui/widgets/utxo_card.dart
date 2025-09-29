import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/features/bitcoin_price/ui/currency_text.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

class UtxoCard extends StatelessWidget {
  const UtxoCard({
    super.key,
    required this.isSpendable,
    required this.txId,
    required this.index,
    required this.valueSat,
    required this.labels,
    this.onTap,
  });

  final bool isSpendable;
  final String txId;
  final int index;
  final int valueSat;
  final List<String> labels;
  final Function()? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                isSpendable ? 'Spendable' : 'Unspendable',
                style: context.font.bodyMedium?.copyWith(
                  color: context.colour.secondary,
                ),
              ),
              const Gap(8),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '$txId:$index',
                      style: context.font.headlineMedium?.copyWith(
                        color: context.colour.primary,
                      ),
                    ),
                  ),
                ],
              ),

              const Gap(8),
              Row(
                children: [
                  Text(
                    'Value: ',
                    style: context.font.bodyMedium?.copyWith(
                      color: context.colour.secondary,
                    ),
                  ),
                  CurrencyText(
                    valueSat,
                    style: context.font.bodyMedium?.copyWith(
                      color: context.colour.secondary,
                    ),
                    showFiat: false,
                  ),
                ],
              ),
              if (labels.isNotEmpty) ...[
                const Gap(8),
                Text(
                  'Labels: ${labels.join(', ')}',
                  style: context.font.bodyMedium?.copyWith(
                    color: context.colour.secondary,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
