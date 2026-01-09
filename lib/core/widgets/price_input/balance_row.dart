import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/widgets/switch/bb_switch.dart';
import 'package:bb_mobile/core/widgets/text/text.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

class BalanceRow extends StatelessWidget {
  final String title;
  final String balance;
  final String currencyCode;
  final void Function(bool)? onMaxToggled;
  final bool isMax;
  final String? walletLabel;

  const BalanceRow({
    super.key,
    this.title = 'Balance',
    required this.balance,
    required this.currencyCode,
    this.onMaxToggled,
    this.isMax = false,
    this.walletLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: .spaceBetween,
      children: [
        Expanded(
          child: Column(
            mainAxisAlignment: .center,
            crossAxisAlignment: .start,
            children: [
              if (walletLabel != null) ...[
                RichText(
                  text: TextSpan(
                    text: 'Wallet: ',
                    style: context.font.labelLarge?.copyWith(
                      color: context.appColors.onSurfaceVariant,
                    ),
                    children: [
                      TextSpan(
                        text: walletLabel,
                        style: context.font.labelMedium?.copyWith(
                          color: context.appColors.secondary,
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
                    color: context.appColors.onSurfaceVariant,
                  ),
                  children: [
                    TextSpan(
                      text: '$balance $currencyCode',
                      style: context.font.labelMedium?.copyWith(
                        color: context.appColors.secondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (onMaxToggled != null)
          Row(
            children: [
              BBText(
                'MAX',
                style: context.font.labelLarge,
                color: context.appColors.secondary,
              ),
              const Gap(8),
              BBSwitch(value: isMax, onChanged: onMaxToggled!),
            ],
          ),
      ],
    );
  }
}
