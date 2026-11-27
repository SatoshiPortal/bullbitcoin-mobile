import 'package:settings/settings.dart';
import 'package:bb_mobile/features/wallet/presentation/bloc/wallet_bloc.dart';
import 'package:bb_mobile/localization/app_localizations_context.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:overview/overview.dart' show EyeToggle, WalletDetailBalanceCard;
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
        eyeToggle: Builder(
          builder: (context) => EyeToggle(
            hideAmounts: context.select(
              (WalletBloc bloc) => bloc.state.amountDisplay?.hideAmounts,
            ),
            showLabel: context.loc.walletShowAmountsTooltip,
            hideLabel: context.loc.walletHideAmountsTooltip,
            onChanged: (hide) => Settings.setAmountsHidden(context, hide),
          ),
        ),
        fiatBalance: HomeFiatBalance(
          balanceSat: balanceSat,
          onCurrencyChanged: Settings.changeDisplayCurrency,
        ),
      );

  static Widget settingsIcon(BuildContext context) => Image.asset(
    Assets.icons.settingsLine.path,
    width: 24,
    height: 24,
    color: context.bull.onSurface,
  );
}
