import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/widgets/bottom_sheet/x.dart';
import 'package:bb_mobile/features/bitcoin_price/ui/currency_text.dart';
import 'package:bb_mobile/features/wallet/ui/widgets/eye_toggle.dart';
import 'package:bb_mobile/features/wallet/ui/widgets/home_fiat_balance.dart';
import 'package:bb_mobile/generated/flutter_gen/assets.gen.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

class ArkBalanceDetailWidget extends StatelessWidget {
  const ArkBalanceDetailWidget({
    super.key,
    required this.confirmedBalance,
    required this.pendingBalance,
  });

  final int confirmedBalance;
  final int pendingBalance;
  int get totalBalance => confirmedBalance + pendingBalance;

  void _showBalanceBreakdown(BuildContext context) {
    BlurredBottomSheet.show(
      context: context,
      child: Container(
        decoration: BoxDecoration(
          color: context.colour.onPrimary,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Balance Breakdown', style: context.font.headlineMedium),
                const Gap(24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.check_circle,
                          color: context.colour.inverseSurface,
                        ),
                        const Gap(8),
                        Text('Confirmed', style: context.font.bodyLarge),
                      ],
                    ),
                    CurrencyText(
                      confirmedBalance,
                      style: context.font.bodyLarge,
                      showFiat: false,
                    ),
                  ],
                ),
                const Gap(16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.pending_actions,
                          color: context.colour.inversePrimary,
                        ),
                        const Gap(8),
                        Text('Pending', style: context.font.bodyLarge),
                      ],
                    ),
                    CurrencyText(
                      pendingBalance,
                      style: context.font.bodyLarge,
                      showFiat: false,
                    ),
                  ],
                ),
                const Gap(16),
                Divider(color: context.colour.outline),
                const Gap(16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Total', style: context.font.titleLarge),
                    CurrencyText(
                      totalBalance,
                      style: context.font.titleLarge,
                      showFiat: false,
                    ),
                  ],
                ),
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
          fit: BoxFit.cover,
          colorFilter: null,
        ),
        border: Border(
          bottom: BorderSide(color: theme.colorScheme.secondary, width: 9),
        ),
        borderRadius: BorderRadius.circular(2),
      ),
      child: Stack(
        children: [
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Gap(16),
                    CurrencyText(
                      totalBalance,
                      style: theme.textTheme.displaySmall?.copyWith(
                        color: theme.colorScheme.onPrimary,
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
                color: theme.colorScheme.onPrimary,
              ),
              tooltip: 'Balance breakdown',
            ),
          ),
        ],
      ),
    );
  }
}
