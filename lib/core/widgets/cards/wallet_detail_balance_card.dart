import 'package:bb_mobile/core/entities/signer_entity.dart';
import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/generated/flutter_gen/assets.gen.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

class WalletDetailBalanceCard extends StatelessWidget {
  const WalletDetailBalanceCard({
    super.key,
    required this.isLiquid,
    required this.signer,
    required this.balanceText,
    required this.fiatBalance,
    this.eyeToggle,
    this.syncingIndicator,
  });

  final bool isLiquid;
  final SignerEntity signer;
  final Widget balanceText;
  final Widget fiatBalance;
  final Widget? eyeToggle;
  final Widget? syncingIndicator;

  @override
  Widget build(BuildContext context) {
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
              ? ColorFilter.mode(context.theme.secondaryHeaderColor, .color)
              : null,
        ),
        border: Border(
          bottom: BorderSide(
            color: isLiquid && signer == SignerEntity.local
                ? context.appColors.tertiary
                : !isLiquid && signer == SignerEntity.local
                ? context.appColors.onTertiary
                : context.appColors.secondary,
            width: 9,
          ),
        ),
        borderRadius: BorderRadius.circular(2),
      ),
      child: Stack(
        children: [
          ?syncingIndicator,
          Center(
            child: Column(
              mainAxisSize: .min,
              mainAxisAlignment: .center,
              children: [
                Row(
                  mainAxisAlignment: .center,
                  children: [
                    if (eyeToggle != null) const Gap(16),
                    balanceText,
                    if (eyeToggle != null) ...[const Gap(16), eyeToggle!],
                  ],
                ),
                const Gap(12),
                fiatBalance,
              ],
            ),
          ),
        ],
      ),
    );
  }
}
