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
    this.isSelected = false,
    this.onTap,
    this.onLongPress,
  });

  final bool isSpendable;
  final String txId;
  final int index;
  final int valueSat;
  final List<String> labels;
  final bool isSelected;
  final Function()? onTap;
  final Function()? onLongPress;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Card(
        elevation: isSelected ? 4 : 1,
        color:
            isSelected ? context.colour.primary.withValues(alpha: 0.1) : null,
        shape:
            isSelected
                ? RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: context.colour.primary, width: 2),
                )
                : null,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    isSpendable ? 'Spendable' : 'Unspendable',
                    style: context.font.bodyMedium?.copyWith(
                      color: context.colour.secondary,
                    ),
                  ),
                  if (isSelected)
                    Icon(
                      Icons.check_circle,
                      color: context.colour.primary,
                      size: 24,
                    ),
                ],
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
                const Gap(24),
                Wrap(
                  spacing: 8.0,
                  children:
                      labels
                          .map(
                            (label) => Chip(
                              label: Text(label),
                              backgroundColor: Colors.transparent,
                            ),
                          )
                          .toList(),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
