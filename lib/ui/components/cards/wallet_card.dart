import 'package:bb_mobile/core/wallet/domain/entity/wallet.dart';
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
      child: SizedBox(
        height: 80,
        child: Material(
          clipBehavior: Clip.antiAlias,
          elevation: 2,
          color: context.colour.onPrimary,
          borderRadius: BorderRadius.circular(2),
          child: Row(
            children: [
              Container(
                width: 4,
                height: double.infinity,
                color: tagColor,
              ),
              const Gap(12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Gap(16),
                  BBText(
                    title,
                    style: context.font.bodyLarge,
                    color: context.colour.secondary,
                  ),
                  const Gap(4),
                  BBText(
                    description,
                    style: context.font.labelMedium,
                    color: context.colour.outline,
                  ),
                  const Gap(16),
                ],
              ),
              const Spacer(),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Gap(16),
                  CurrencyText(
                    wallet.balanceSat.toInt(),
                    showFiat: false,
                    style: context.font.bodyLarge,
                    color: context.colour.secondary,
                  ),
                  const Gap(4),
                  CurrencyText(
                    wallet.balanceSat.toInt(),
                    showFiat: true,
                    style: context.font.labelMedium,
                    color: context.colour.outline,
                  ),
                  const Gap(16),
                ],
              ),
              const Gap(8),
              Icon(
                Icons.chevron_right,
                color: context.colour.outline,
                size: 24,
              ),
              const Gap(8),
            ],
          ),
        ),
      ),
    );
  }
}
