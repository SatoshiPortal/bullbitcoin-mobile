import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/widgets/hidden_amount_icon.dart';
import 'package:bb_mobile/core/widgets/loading/fading_linear_progress.dart';
import 'package:bb_mobile/core/widgets/text/text.dart';
import 'package:bb_mobile/features/bitcoin_price/ui/currency_text.dart';
import 'package:bb_mobile/features/settings/presentation/bloc/settings_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
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
    final hideAmounts = context.select(
      (SettingsCubit cubit) => cubit.state.hideAmounts ?? false,
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(2),
        child: Material(
          elevation: 1,
          shadowColor: context.appColors.onSurface.withValues(alpha: 0.3),
          color: context.appColors.background,
          borderRadius: BorderRadius.circular(2),
          child: Container(
            height: 68,
            decoration: BoxDecoration(
              color: context.appColors.background,
              border: Border(left: BorderSide(color: tagColor, width: 3)),
              borderRadius: BorderRadius.circular(2),
            ),
            child: Stack(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            BBText(
                              title,
                              style: context.font.bodyMedium,
                              color: context.appColors.text,
                            ),
                            const Gap(2),
                            BBText(
                              description,
                              style: context.font.labelSmall,
                              color: context.appColors.textMuted,
                            ),
                          ],
                        ),
                      ),
                      const Gap(4),
                      if (hideAmounts)
                        HiddenAmountIcon(
                          size: 18,
                          color: context.appColors.textMuted,
                        )
                      else
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            CurrencyText(
                              balanceSat,
                              showFiat: false,
                              style: context.font.bodyMedium,
                              color: context.appColors.text,
                            ),
                            const Gap(2),
                            CurrencyText(
                              balanceSat,
                              showFiat: true,
                              fiatCurrency: fiatCurrency,
                              style: context.font.labelSmall,
                              color: context.appColors.textMuted,
                            ),
                          ],
                        ),
                      const Gap(4),
                      Icon(
                        Icons.chevron_right,
                        color: context.appColors.textMuted,
                        size: 20,
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
