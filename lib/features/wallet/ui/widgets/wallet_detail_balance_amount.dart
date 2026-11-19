import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/widgets/text/currency_text.dart';
import 'package:bull_ui/bull_ui.dart' show BullTypographyX;
import 'package:material_ui/material_ui.dart';

/// The wallet balance on the wallet detail screen: tap switches BTC/sats,
/// long press changes the default unit, as everywhere else in the app.
class WalletDetailBalanceAmount extends StatelessWidget {
  const WalletDetailBalanceAmount({super.key, required this.balanceSat});

  final int balanceSat;

  @override
  Widget build(BuildContext context) {
    return CurrencyText(
      balanceSat,
      style: context.bullType.headline.copyWith(
        color: context.appColors.onPrimary,
      ),
      showFiat: false,
      interactive: true,
    );
  }
}
