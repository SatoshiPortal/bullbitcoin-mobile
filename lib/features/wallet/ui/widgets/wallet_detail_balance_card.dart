import 'package:bb_mobile/core/storage/tables/wallet_metadata_table.dart';
import 'package:bb_mobile/features/bitcoin_price/ui/currency_text.dart';
import 'package:bb_mobile/features/transactions/ui/widgets/txs_syncing_indicator.dart';
import 'package:bb_mobile/features/wallet/ui/widgets/eye_toggle.dart';
import 'package:bb_mobile/features/wallet/ui/widgets/home_fiat_balance.dart';
import 'package:bb_mobile/generated/flutter_gen/assets.gen.dart';
import 'package:bb_mobile/ui/themes/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

class WalletDetailBalanceCard extends StatelessWidget {
  const WalletDetailBalanceCard({
    super.key,
    required this.balanceSat,
    required this.isLiquid,
    required this.signer,
  });

  final int balanceSat;
  final bool isLiquid;
  final Signer signer;

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
              signer == Signer.none
                  ? ColorFilter.mode(
                    context.theme.secondaryHeaderColor,
                    BlendMode.color,
                  )
                  : null,
        ),
        border: Border(
          bottom: BorderSide(
            color:
                isLiquid && signer == Signer.local
                    ? theme.colorScheme.tertiary
                    : !isLiquid && signer == Signer.local
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
