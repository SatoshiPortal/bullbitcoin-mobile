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
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                CurrencyText(
                  confirmedBalance,
                  style: theme.textTheme.displaySmall?.copyWith(
                    color: theme.colorScheme.onPrimary,
                  ),
                  showFiat: false,
                ),
                Icon(Icons.check_circle, color: theme.colorScheme.onPrimary),
              ],
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                CurrencyText(
                  pendingBalance,
                  style: theme.textTheme.displaySmall?.copyWith(
                    color: theme.colorScheme.onPrimary,
                  ),
                  showFiat: false,
                ),
                Icon(Icons.pending_actions, color: theme.colorScheme.onPrimary),
              ],
            ),
            const Gap(12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const EyeToggle(),
                HomeFiatBalance(balanceSat: totalBalance),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
