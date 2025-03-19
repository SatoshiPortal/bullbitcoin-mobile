import 'package:bb_mobile/_ui/components/buttons/button.dart';
import 'package:bb_mobile/_ui/components/text/text.dart';
import 'package:bb_mobile/_ui/themes/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

class BalanceRow extends StatelessWidget {
  const BalanceRow({super.key});

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
                '53.34 CAD',
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
                onPressed: () {},
              ),
              const Gap(8),
            ],
          ),
        ],
      ),
    );
  }
}
