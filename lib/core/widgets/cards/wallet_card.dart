import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/widgets/loading/fading_linear_progress.dart';
import 'package:bb_mobile/core/widgets/text/text.dart';
import 'package:bb_mobile/features/bitcoin_price/ui/currency_text.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

class WalletCard extends StatelessWidget {
  const WalletCard({
    super.key,
    required this.tagColor,
    required this.title,
    required this.description,
    required this.balanceSat,
    this.onTap,
    this.isSyncing = false,
    this.fiatCurrency,
  });

  final Color tagColor;
  final String title;
  final String description;
  final int balanceSat;
  final bool isSyncing;
  final void Function()? onTap;
  final String? fiatCurrency;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(2),
        child: Material(
          elevation: 2,
          shadowColor: context.appColors.onSurface.withValues(alpha: 0.5),
          color: context.appColors.background,
          borderRadius: BorderRadius.circular(2),
          child: Container(
            height: 90,
            decoration: BoxDecoration(
              color: context.appColors.background,
              border: Border(left: BorderSide(color: tagColor, width: 4)),
              borderRadius: BorderRadius.circular(2),
            ),
            child: Stack(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  child: Row(
                    mainAxisAlignment: .spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: .start,
                          mainAxisAlignment: .center,
                          children: [
                            Row(
                              mainAxisAlignment: .spaceBetween,
                              children: [
                                BBText(
                                  title,
                                  style: context.font.bodyLarge,
                                  color: context.appColors.secondary,
                                ),
                                const Gap(4),
                                CurrencyText(
                                  balanceSat,
                                  showFiat: false,
                                  style: context.font.bodyLarge,
                                  color: context.appColors.secondary,
                                ),
                              ],
                            ),
                            const Gap(4),
                            Row(
                              mainAxisAlignment: .spaceBetween,
                              children: [
                                BBText(
                                  description,
                                  style: context.font.labelMedium,
                                  color: context.appColors.onSurfaceVariant,
                                ),
                                const Gap(4),
                                CurrencyText(
                                  balanceSat,
                                  showFiat: true,
                                  fiatCurrency: fiatCurrency,
                                  style: context.font.labelMedium,
                                  color: context.appColors.onSurfaceVariant,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const Gap(8),
                      Icon(
                        Icons.chevron_right,
                        color: context.appColors.onSurfaceVariant,
                        size: 24,
                      ),
                    ],
                  ),
                ),
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: FadingLinearProgress(
                    trigger: isSyncing,
                    backgroundColor: context.appColors.transparent,
                    foregroundColor: context.appColors.onSecondaryFixed,
                    height: 3.0,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
