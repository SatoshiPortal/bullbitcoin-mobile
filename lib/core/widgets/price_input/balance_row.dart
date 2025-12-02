import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/widgets/buttons/button.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

class BalanceRow extends StatelessWidget {
  final String title;
  final String balance;
  final String currencyCode;
  final void Function()? onMaxPressed;
  final String? walletLabel;

  const BalanceRow({
    super.key,
    this.title = 'Balance',
    required this.balance,
    required this.currencyCode,
    required this.onMaxPressed,
    this.walletLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
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
                      color: context.colorScheme.surface,
                    ),
                    children: [
                      TextSpan(
                        text: walletLabel,
                        style: context.font.labelMedium?.copyWith(
                          color: context.colorScheme.secondary,
                        ),
                      ),
                    ],
                  ),
                ),
                const Gap(4),
              ],
              RichText(
                text: TextSpan(
                  text: '$title: ',
                  style: context.font.labelLarge?.copyWith(
                    color: context.colorScheme.surface,
                  ),
                  children: [
                    TextSpan(
                      text: '$balance $currencyCode',
                      style: context.font.labelMedium?.copyWith(
                        color: context.colorScheme.secondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (onMaxPressed != null)
          BBButton.small(
            label: 'MAX',
            height: 30,
            width: 51,
            bgColor: context.colorScheme.secondaryFixedDim,
            textColor: context.colorScheme.secondary,
            textStyle: context.font.labelLarge,
            onPressed: onMaxPressed!,
          ),
      ],
    );
  }
}
