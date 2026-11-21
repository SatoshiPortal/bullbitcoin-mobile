import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bull_ui/bull_ui.dart' show BullAmount, BullTypographyX;
import 'package:material_ui/material_ui.dart';

/// The wallet balance on the wallet detail screen: tap switches BTC/sats,
/// long press changes the default unit, as everywhere else in the app.
class WalletDetailBalanceAmount extends StatelessWidget {
  const WalletDetailBalanceAmount({super.key, required this.balanceSat});

  final int balanceSat;

  @override
  Widget build(BuildContext context) {
    return BullAmount.signedSats(
      balanceSat,
      style: context.bullType.headline.copyWith(
        color: context.appColors.onPrimary,
      ),
      interactive: true,
    );
  }
}
