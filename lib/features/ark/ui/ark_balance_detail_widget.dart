import 'package:bb_mobile/core_deprecated/ark/entities/ark_balance.dart';
import 'package:bb_mobile/core_deprecated/themes/app_theme.dart';
import 'package:bb_mobile/core_deprecated/utils/build_context_x.dart';
import 'package:bb_mobile/core_deprecated/widgets/bottom_sheet/x.dart';
import 'package:bb_mobile/features/bitcoin_price/ui/currency_text.dart';
import 'package:bb_mobile/features/wallet/ui/widgets/eye_toggle.dart';
import 'package:bb_mobile/features/wallet/ui/widgets/home_fiat_balance.dart';
import 'package:bb_mobile/generated/flutter_gen/assets.gen.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

class ArkBalanceDetailWidget extends StatelessWidget {
  const ArkBalanceDetailWidget({super.key, required this.arkBalance});

  final ArkBalance? arkBalance;

  int get totalBalance => arkBalance?.completeTotal ?? 0;

  void _showBalanceBreakdown(BuildContext context) {
    BlurredBottomSheet.show(
      context: context,
      child: Container(
        decoration: BoxDecoration(
          color: context.appColors.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: .min,
              children: [
                Text(context.loc.arkBalanceBreakdown, style: context.font.headlineMedium),
                const Gap(24),
                if (arkBalance != null) ...[
                  // Boarding Unconfirmed
                  Row(
                    mainAxisAlignment: .spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.schedule,
                            color: context.appColors.primary,
                          ),
                          const Gap(8),
                          Text(
                            context.loc.arkBoardingUnconfirmed,
                            style: context.font.bodyLarge,
                          ),
                        ],
                      ),
                      CurrencyText(
                        arkBalance!.boarding.unconfirmed,
                        style: context.font.bodyLarge,
                        showFiat: false,
                      ),
                    ],
                  ),
                  const Gap(16),
                  // Boarding Confirmed
                  Row(
                    mainAxisAlignment: .spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.check_circle,
                            color: context.appColors.success,
                          ),
                          const Gap(8),
                          Text(
                            context.loc.arkBoardingConfirmed,
                            style: context.font.bodyLarge,
                          ),
                        ],
                      ),
                      CurrencyText(
                        arkBalance!.boarding.confirmed,
                        style: context.font.bodyLarge,
                        showFiat: false,
                      ),
                    ],
                  ),
                  const Gap(16),
                  // Preconfirmed
                  Row(
                    mainAxisAlignment: .spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.hourglass_empty,
                            color: context.appColors.warning,
                          ),
                          const Gap(8),
                          Text(context.loc.arkPreconfirmed, style: context.font.bodyLarge),
                        ],
                      ),
                      CurrencyText(
                        arkBalance!.preconfirmed,
                        style: context.font.bodyLarge,
                        showFiat: false,
                      ),
                    ],
                  ),
                  const Gap(16),
                  // Settled
                  Row(
                    mainAxisAlignment: .spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.done_all,
                            color: context.appColors.success,
                          ),
                          const Gap(8),
                          Text(context.loc.arkSettled, style: context.font.bodyLarge),
                        ],
                      ),
                      CurrencyText(
                        arkBalance!.settled,
                        style: context.font.bodyLarge,
                        showFiat: false,
                      ),
                    ],
                  ),
                  const Gap(16),
                  // Available
                  Row(
                    mainAxisAlignment: .spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.account_balance_wallet,
                            color: context.appColors.primary,
                          ),
                          const Gap(8),
                          Text(context.loc.arkAvailable, style: context.font.bodyLarge),
                        ],
                      ),
                      CurrencyText(
                        arkBalance!.available,
                        style: context.font.bodyLarge,
                        showFiat: false,
                      ),
                    ],
                  ),
                  const Gap(16),
                  Divider(color: context.appColors.border),
                  const Gap(16),
                  // Total
                  Row(
                    mainAxisAlignment: .spaceBetween,
                    children: [
                      Text(context.loc.arkTotal, style: context.font.titleLarge),
                      CurrencyText(
                        arkBalance!.completeTotal,
                        style: context.font.titleLarge,
                        showFiat: false,
                      ),
                    ],
                  ),
                ] else ...[
                  Text(
                    context.loc.arkNoBalanceData,
                    style: context.font.bodyLarge,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      height: 185,
      decoration: BoxDecoration(
        image: DecorationImage(
          image: AssetImage(Assets.backgrounds.bgInstantWallet.path),
          fit: .cover,
          colorFilter: null,
        ),
        border: Border(
          bottom: BorderSide(color: context.appColors.secondary, width: 9),
        ),
        borderRadius: BorderRadius.circular(2),
      ),
      child: Stack(
        children: [
          Center(
            child: Column(
              mainAxisSize: .min,
              mainAxisAlignment: .center,
              children: [
                Row(
                  mainAxisAlignment: .center,
                  children: [
                    const Gap(16),
                    CurrencyText(
                      totalBalance,
                      style: theme.textTheme.displaySmall?.copyWith(
                        color: context.appColors.onPrimary,
                      ),
                      showFiat: false,
                    ),
                    const Gap(16),
                    const EyeToggle(),
                  ],
                ),
                const Gap(12),
                HomeFiatBalance(balanceSat: totalBalance),
              ],
            ),
          ),
          Positioned(
            top: 16,
            right: 16,
            child: IconButton(
              onPressed: () => _showBalanceBreakdown(context),
              icon: Icon(
                Icons.info_outline,
                color: context.appColors.onPrimary,
              ),
              tooltip: context.loc.arkBalanceBreakdownTooltip,
            ),
          ),
        ],
      ),
    );
  }
}
