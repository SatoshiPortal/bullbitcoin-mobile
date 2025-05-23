import 'package:bb_mobile/ui/components/buttons/button.dart';
import 'package:bb_mobile/ui/themes/app_theme.dart';
import 'package:flutter/material.dart';

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
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title:
          walletLabel != null
              ? RichText(
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
              )
              : null,
      subtitle: RichText(
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
      trailing:
          showMax
              ? BBButton.small(
                label: 'MAX',
                height: 30,
                width: 51,
                bgColor: context.colour.secondaryFixedDim,
                textColor: context.colour.secondary,
                textStyle: context.font.labelLarge,
                onPressed: onMaxPressed,
              )
              : null,
    );
  }
}
