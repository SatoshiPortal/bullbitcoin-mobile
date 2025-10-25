import 'package:bb_mobile/core/spark/entities/spark_balance.dart';
import 'package:bb_mobile/features/bitcoin_price/ui/currency_text.dart';
import 'package:bb_mobile/features/wallet/ui/widgets/eye_toggle.dart';
import 'package:bb_mobile/features/wallet/ui/widgets/home_fiat_balance.dart';
import 'package:bb_mobile/generated/flutter_gen/assets.gen.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

class SparkBalanceDetailWidget extends StatelessWidget {
  const SparkBalanceDetailWidget({super.key, required this.sparkBalance});

  final SparkBalance? sparkBalance;

  int get totalBalance => sparkBalance?.balanceSats ?? 0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      height: 185,
      decoration: BoxDecoration(
        image: DecorationImage(
          image: AssetImage(Assets.backgrounds.bgInstantWallet.path),
          fit: BoxFit.cover,
        ),
        border: Border(
          bottom: BorderSide(color: theme.colorScheme.primary, width: 9),
        ),
        borderRadius: BorderRadius.circular(2),
      ),
      child: Center(
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
    );
  }
}
