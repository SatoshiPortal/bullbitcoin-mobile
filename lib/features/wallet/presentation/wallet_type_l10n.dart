import 'package:bb_mobile/localization/app_localizations_context.dart';
import 'package:bb_mobile/features/wallet/domain/wallet.dart';
import 'package:flutter/widgets.dart';

/// What kind of wallet a card shows, in the app's language.
extension WalletTypeL10n on Wallet {
  String typeLabel(BuildContext context) {
    if (isWatchSigner) return context.loc.walletTypeWatchSigner;
    if (isWatchOnly) return context.loc.walletTypeWatchOnly;
    return network.isBitcoin
        ? context.loc.walletTypeBitcoinNetwork
        : context.loc.walletTypeLiquidAndLightning;
  }
}
