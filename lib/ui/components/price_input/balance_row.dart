import 'package:bb_mobile/ui/components/buttons/button.dart';
import 'package:bb_mobile/ui/components/text/text.dart';
import 'package:bb_mobile/ui/themes/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

class BalanceRow extends StatelessWidget {
  final String balance;
  final String currencyCode;
  final void Function() onMaxPressed;

  const BalanceRow({
    super.key,
    required this.balance,
    required this.currencyCode,
    required this.onMaxPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          Container(
            height: 1,
            color: context.colour.secondaryFixedDim,
          ),
          const Gap(14),
          Row(
            children: [
              const Gap(8),
              BBText(
                'Wallet Balance',
                style: context.font.labelLarge,
                color: context.colour.surface,
              ),
              const Gap(4),
              BBText(
                '$balance $currencyCode',
                style: context.font.labelMedium,
                color: context.colour.secondary,
              ),
              const Spacer(),
              BBButton.small(
                label: 'MAX',
                height: 30,
                width: 51,
                bgColor: context.colour.secondaryFixedDim,
                textColor: context.colour.secondary,
                textStyle: context.font.labelLarge,
                onPressed: () => onMaxPressed(),
              ),
              const Gap(8),
            ],
          ),
        ],
      ),
    );
  }
}
