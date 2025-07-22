import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/widgets/buttons/button.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

class BalanceRow extends StatelessWidget {
  final String balance;
  final String currencyCode;
  final bool showMax;
  final void Function() onMaxPressed;
  final String? walletLabel;

  const BalanceRow({
    super.key,
    required this.balance,
    required this.currencyCode,
    required this.showMax,
    required this.onMaxPressed,
    this.walletLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (walletLabel != null) ...[
                  RichText(
                    text: TextSpan(
                      text: 'Wallet: ',
                      style: context.font.labelSmall?.copyWith(
                        color: context.colour.surface,
                      ),
                      children: [
                        TextSpan(
                          text: walletLabel,
                          style: context.font.labelMedium?.copyWith(
                            color: context.colour.secondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Gap(4),
                ],
                RichText(
                  text: TextSpan(
                    text: 'Balance: ',
                    style: context.font.labelLarge?.copyWith(
                      color: context.colour.surface,
                    ),
                    children: [
                      TextSpan(
                        text: '$balance $currencyCode',
                        style: context.font.labelMedium?.copyWith(
                          color: context.colour.secondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (showMax)
            BBButton.small(
              label: 'MAX',
              height: 30,
              width: 51,
              bgColor: context.colour.secondaryFixedDim,
              textColor: context.colour.secondary,
              textStyle: context.font.labelLarge,
              onPressed: onMaxPressed,
            ),
        ],
      ),
    );
  }
}
