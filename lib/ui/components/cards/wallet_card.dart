import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/features/bitcoin_price/ui/currency_text.dart';
import 'package:bb_mobile/ui/components/text/text.dart';
import 'package:bb_mobile/ui/themes/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

class WalletCard extends StatelessWidget {
  const WalletCard({
    super.key,
    required this.tagColor,
    required this.title,
    required this.description,
    required this.wallet,
    required this.onTap,
  });

  final Color tagColor;
  final String title;
  final String description;
  final Wallet wallet;

  final Function onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => onTap(),
      child: Material(
        elevation: 2,
        color: context.colour.onPrimary,
        borderRadius: BorderRadius.circular(2),
        child: Container(
          height: 80,
          decoration: BoxDecoration(
            color: context.colour.onPrimary,
            border: Border(left: BorderSide(color: tagColor, width: 4)),
            borderRadius: BorderRadius.circular(2),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        BBText(
                          title,
                          style: context.font.bodyLarge,
                          color: context.colour.secondary,
                        ),
                        const Gap(4),
                        CurrencyText(
                          wallet.balanceSat.toInt(),
                          showFiat: false,
                          style: context.font.bodyLarge,
                          color: context.colour.secondary,
                        ),
                      ],
                    ),
                    const Gap(4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        BBText(
                          description,
                          style: context.font.labelMedium,
                          color: context.colour.outline,
                        ),
                        const Gap(4),
                        CurrencyText(
                          wallet.balanceSat.toInt(),
                          showFiat: true,
                          style: context.font.labelMedium,
                          color: context.colour.outline,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const Gap(8),
              Icon(
                Icons.chevron_right,
                color: context.colour.outline,
                size: 24,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
