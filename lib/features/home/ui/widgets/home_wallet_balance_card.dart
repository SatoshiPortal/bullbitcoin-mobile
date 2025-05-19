import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/features/bitcoin_price/ui/currency_text.dart';
import 'package:bb_mobile/features/home/ui/widgets/eye_toggle.dart';
import 'package:bb_mobile/features/home/ui/widgets/home_fiat_balance.dart';
import 'package:bb_mobile/features/transactions/ui/widgets/txs_syncing_indicator.dart';
import 'package:bb_mobile/generated/flutter_gen/assets.gen.dart';
import 'package:bb_mobile/ui/themes/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

class HomeWalletBalanceCard extends StatelessWidget {
  const HomeWalletBalanceCard({
    super.key,
    required this.balanceSat,
    required this.isLiquid,
    required this.walletSource,
  });

  final int balanceSat;
  final bool isLiquid;
  final WalletSource walletSource;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      height: 185,
      decoration: BoxDecoration(
        image: DecorationImage(
          image: AssetImage(
            isLiquid
                ? Assets.images2.bgInstantWallet.path
                : Assets.images2.bgSecureWallet.path,
          ),
          fit: BoxFit.cover,
          colorFilter:
              walletSource == WalletSource.xpub ||
                      walletSource == WalletSource.coldcard
                  ? ColorFilter.mode(
                    context.theme.secondaryHeaderColor,
                    BlendMode.color,
                  )
                  : null,
        ),
        border: Border(
          bottom: BorderSide(
            color:
                isLiquid && walletSource == WalletSource.mnemonic
                    ? theme.colorScheme.tertiary
                    : !isLiquid && walletSource == WalletSource.mnemonic
                    ? theme.colorScheme.onTertiary
                    : theme.colorScheme.secondary,
            width: 9,
          ),
        ),
        borderRadius: BorderRadius.circular(2),
      ),
      child: Stack(
        children: [
          const TxsSyncingIndicator(),
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
                      balanceSat,
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
                HomeFiatBalance(balanceSat: balanceSat),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
