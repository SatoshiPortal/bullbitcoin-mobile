import 'package:bb_mobile/core/entities/signer_entity.dart';
import 'package:bb_mobile/features/bitcoin_price/ui/currency_text.dart';
import 'package:bb_mobile/features/transactions/ui/widgets/txs_syncing_indicator.dart';
import 'package:bb_mobile/features/wallet/ui/widgets/eye_toggle.dart';
import 'package:bb_mobile/features/wallet/ui/widgets/home_fiat_balance.dart';
import 'package:bb_mobile/generated/flutter_gen/assets.gen.dart';
import 'package:flutter/material.dart';
import 'package:bull_ui/bull_ui.dart';

class WalletDetailBalanceCard extends StatelessWidget {
  const WalletDetailBalanceCard({
    super.key,
    required this.balanceSat,
    required this.isLiquid,
    required this.signer,
    this.hasSyncingIndicator = true,
  });

  final int balanceSat;
  final bool isLiquid;
  final SignerEntity signer;
  final bool hasSyncingIndicator;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      height: 185,
      decoration: BoxDecoration(
        image: DecorationImage(
          image: AssetImage(
            isLiquid
                ? Assets.backgrounds.bgInstantWallet.path
                : Assets.backgrounds.bgSecureWallet.path,
          ),
          fit: .cover,
          colorFilter: signer == SignerEntity.none
              ? ColorFilter.mode(theme.secondaryHeaderColor, .color)
              : null,
        ),
        border: Border(
          bottom: BorderSide(
            color: isLiquid && signer == SignerEntity.local
                ? context.bull.tertiary
                : !isLiquid && signer == SignerEntity.local
                ? context.bull.onTertiary
                : context.bull.secondary,
            width: 9,
          ),
        ),
        borderRadius: BorderRadius.circular(2),
      ),
      child: Stack(
        children: [
          if (hasSyncingIndicator) const TxsSyncingIndicator(),
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
                      balanceSat,
                      style: theme.textTheme.displaySmall?.copyWith(
                        color: context.bull.onPrimary,
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
