import 'package:bull_ui/bull_ui.dart';
import 'package:material_ui/material_ui.dart' show ImageProvider;

import 'wallet_detail_balance_card.dart';

/// Displays the Silent route's already observed balance. The route owner
/// supplies the artwork, preference control and fiat presentation.
class SilentWalletBalance extends StatelessWidget {
  final ImageProvider background;
  final int balanceSat;
  final Widget eyeToggle;
  final Widget fiatBalance;

  const SilentWalletBalance({
    super.key,
    required this.background,
    required this.balanceSat,
    required this.eyeToggle,
    required this.fiatBalance,
  });

  @override
  Widget build(BuildContext context) => WalletDetailBalanceCard.localBitcoin(
    background: background,
    balanceText: BullAmount.signedSats(
      balanceSat,
      style: context.bullType.headline.copyWith(color: context.bull.onPrimary),
      interactive: false,
    ),
    eyeToggle: eyeToggle,
    fiatBalance: fiatBalance,
  );
}
