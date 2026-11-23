import 'package:bb_mobile/features/settings/public/settings_facade.dart';
import 'package:bb_mobile/features/wallet/ui/widgets/eye_toggle.dart';
import 'package:overview/overview.dart' show WalletDetailBalanceCard;
import 'package:bb_mobile/generated/flutter_gen/assets.gen.dart';
import 'package:bitcoin_price/bitcoin_price.dart';
import 'package:bull_ui/bull_ui.dart'
    show BullAmount, BullThemeX, BullTypographyX;
import 'package:material_ui/material_ui.dart';

abstract final class SilentWalletPresentation {
  static Widget balance(BuildContext context, int balanceSat) =>
      WalletDetailBalanceCard.localBitcoin(
        background: AssetImage(Assets.backgrounds.bgSecureWallet.path),
        balanceText: BullAmount.signedSats(
          balanceSat,
          style: context.bullType.headline.copyWith(
            color: context.bull.onPrimary,
          ),
          interactive: false,
        ),
        eyeToggle: const EyeToggle(),
        fiatBalance: HomeFiatBalance(
          balanceSat: balanceSat,
          onCurrencyChanged: SettingsFacade.changeDisplayCurrency,
        ),
      );

  static Widget settingsIcon(BuildContext context) => Image.asset(
    Assets.icons.settingsLine.path,
    width: 24,
    height: 24,
    color: context.bull.onSurface,
  );
}
