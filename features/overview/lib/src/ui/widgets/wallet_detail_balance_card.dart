import 'package:primitives/primitives.dart' show SignerEntity;
import 'package:bull_ui/app_theme.dart';
import 'package:material_ui/material_ui.dart';
import 'package:bull_ui/bull_ui.dart' show BullShapesX, Gap;

class WalletDetailBalanceCard extends StatelessWidget {
  const WalletDetailBalanceCard({
    super.key,
    required this.isLiquid,
    required this.signer,
    required this.background,
    required this.balanceText,
    required this.fiatBalance,
    this.eyeToggle,
    this.syncingIndicator,
  });

  const WalletDetailBalanceCard.localBitcoin({
    super.key,
    required this.background,
    required this.balanceText,
    required this.fiatBalance,
    this.eyeToggle,
    this.syncingIndicator,
  }) : isLiquid = false,
       signer = SignerEntity.local;

  final ImageProvider<Object> background;
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
          image: background,
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
        borderRadius: BorderRadius.circular(context.bullShapes.card),
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
                    if (eyeToggle case final toggle?) ...[const Gap(7), toggle],
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
